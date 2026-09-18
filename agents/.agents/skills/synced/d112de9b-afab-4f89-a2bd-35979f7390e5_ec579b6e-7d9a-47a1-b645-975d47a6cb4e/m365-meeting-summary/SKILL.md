---
name: m365-meeting-summary
description: Pull meeting data from the Microsoft 365 connector and produce a meeting summary. ALWAYS use this skill when the user asks to summarize a meeting, recap a call, get meeting notes, find action items or decisions from a meeting, "catch me up" on a meeting they missed, or asks "what happened in" a named meeting — even if they don't say the word "summary". Also use for multi-meeting requests like "recap all my meetings yesterday", prep briefs on upcoming meetings, or when the user says "write up notes from my standup", "what were the action items from yesterday's planning call", "recap the client sync and send it to the team", or "summarize my 1:1 with Dana". Requires the Microsoft 365 connector (outlook_calendar_search, read_resource, chat_message_search, outlook_email_search).
---

# M365 Meeting Summary

Produce a meeting summary by locating the meeting on the user's Outlook calendar, then synthesizing three sources in priority order: the Teams transcript, the Teams meeting chat, and any recap/follow-up emails. Deliver the summary inline in chat by default.

The hard part of this task is not the writing — it's (1) reliably locating the right transcript and (2) producing notes that the user can forward without editing, which means **never inventing owners, decisions, or due dates that the sources don't support**. A recap that confidently assigns an action to the wrong person is worse than no recap at all.

## Step 1 — Resolve the meeting

Parse the user's input for whatever identifiers they gave: meeting name (full or partial), date/time references ("yesterday", "this morning", "last Tuesday"), attendee or organizer names.

Call `outlook_calendar_search` with the best combination of filters:
- `query`: distinctive words from the meeting name (or `*` if only date/people given)
- `afterDateTime` / `beforeDateTime`: natural-language dates are accepted — bound the range as tightly as the user's phrasing allows
- `attendee` or `organizer`: email (full or partial) when the user names a person
- All filters are AND-ed; if a tight search returns nothing, loosen one filter at a time (drop `query` first, widen dates second)

For **"most recent" / "my last meeting"**: search with `query: "*"`, `order: "newest"`, a `beforeDateTime` of now, and a `limit` of ~8 (not 1). **Don't just take the top result** — the newest calendar entry is often a solo prep block, a focus hold, or an all-day item. Walk down the list and pick the most recent event that is an actual meeting: it has `attendees` (more than just the user) and/or an `onlineMeeting`. Better still, if the first real meeting has no transcript (Step 3a), keep walking back rather than stopping. Tell the user which meeting you landed on.

Disambiguation rules:
- Exactly one match → proceed silently.
- Multiple plausible matches → list them (subject, date/time, organizer) and ask which one. Exception: if the user said "my last X meeting" or similar, take the most recent past occurrence and proceed.
- Zero matches after loosening → tell the user what was searched and ask for a correction; do not fabricate a meeting.
- If the user asks about someone else's calendar, pass `calendarOwnerEmail` (requires delegate access; surface the error plainly if denied).

Present event times using the returned `dateTime` + `timeZone` pair as-is — do not re-convert.

## Step 2 — Read the full event

Call `read_resource` with `calendar:///events/{eventId}` (add `?owner={email}` for delegated calendars). Capture:
- Subject, start/end, organizer, attendee list (and responses if present)
- Body/invite text (agenda often lives here)
- `meetingTranscriptUrl` — the key to the transcript in Step 3a

## Step 3 — Gather sources (in priority order)

Attempt all three; the summary is best when they're combined. Track which sources were actually retrieved — the final output must state this.

**3a. Teams transcript (primary source)**

If the event read returned a `meetingTranscriptUrl`, call `read_resource` with it **verbatim** as the URI. The value is an opaque base64url token — do not decode, trim, or "clean" it.

For a recurring series, the URI should be scoped to the specific occurrence with `?start={iso}&end={iso}`. Omitting those parameters returns only the most recent series transcripts, which may be the wrong occurrence.

**Recurring series are the main failure point.** The calendar search may report `recurrence: null` even for an occurrence of a recurring series. A scoped read can return `NOT_FOUND` with `no_transcript_in_occurrence_window` even when the series has many transcripts — because that specific occurrence wasn't transcribed, or the meeting ran outside its scheduled slot.

**Fallback when a scoped read misses:** re-read the series by stripping the `?start&end` query string. That returns the series' transcripts, each with its own `createdDateTime`/`endDateTime`. Pick the transcript whose time window best matches the occurrence requested. Allow a tolerance window when matching — scheduled slots and real meeting times often differ by a few minutes.

If the requested date genuinely has no transcript, **don't silently substitute another day** — tell the user that occurrence wasn't transcribed, list the dates that *are* available, and confirm which one they want (or, for "most recent", use the latest available and say so).

The transcript content comes back as **WEBVTT**: timestamped cues with the speaker wrapped in `<v Speaker Name>…</v>` tags. Parse those speaker tags — they're what let you attribute decisions and actions correctly. Collapse consecutive cues from the same speaker into one turn before reading, so the conversation is legible.

**3b. Teams meeting chat**

Call `chat_message_search` with distinctive keywords from the meeting subject as `query`, bounded by `afterDateTime`/`beforeDateTime` around the meeting window (start minus ~1 hour to end plus ~24 hours — links, action items, and follow-ups often land after the call). Chat is useful for links shared, side decisions, and attachments even when a transcript exists.

**3c. Recap / follow-up emails**

Call `outlook_email_search` with subject keywords from the meeting name, `afterDateTime` = meeting start, `beforeDateTime` = ~3 days after. Also try `sender` = organizer email. Read promising hits via `read_resource` (`mail:///messages/{messageId}`). Prioritize emails titled "recap", "notes", "follow-up", "action items", or replies on the invite thread.

**Fallback ladder:** transcript → chat → recap emails → invite body/agenda. If only the invite body is available, produce a metadata summary (who, when, stated agenda) and say explicitly that no discussion content was found.

When there's no transcript at all — not recorded, not yet processed, or permission denied — say so plainly rather than fabricating notes. Check whether you were searching the right calendar; if the user wasn't the organizer, the transcript may sit on the organizer's side. Offer chat-based or email-based alternatives and be clear that they are weaker than transcript-based summaries.

## Step 4 — Synthesize and deliver

Read all retrieved sources before writing. Default output is an inline chat summary in this structure (omit empty sections rather than writing "none"):

```
**{Meeting subject}** — {date, time, timezone} · {organizer} · {N attendees}

**Summary** — 2–3 sentences capturing the outcome of the meeting, not its agenda.

**Decisions** — each decision the group actually settled on. If something was discussed but left open, it goes in Open Questions, not here.

**Action Items**
| Owner | Action | Due |
|-------|--------|-----|
| [name or "Unassigned"] | [what they committed to do] | [date or "—"] |

**Key Discussion** — 3–6 tight bullets of the substantive threads. Attribute positions to named speakers when the transcript supports it; never invent attribution.

**Open Questions / Parked Items** — anything explicitly deferred or unresolved.

**Sources** — one line stating what fed the summary, e.g. "Transcript + meeting chat" or "Invite only — no transcript or recap found."
```

Grounding rules — these are the whole point of the skill:
- **Owners:** assign a name only when the source shows that person taking the action ("I'll write up the deck", or someone accepting "can you take that, Sam?"). Otherwise write "Unassigned". Never infer an owner from job title or context.
- **Due dates:** only when actually stated ("by Friday", "before the next sync"). Otherwise "—". Convert relative dates to a concrete date using the meeting date as the anchor, and keep the original phrasing in parentheses if it's ambiguous.
- **Decisions vs. discussion:** a decision is something the group concluded. Hedged or unresolved items are Open Questions.
- If sources conflict (e.g., recap email differs from transcript), prefer the transcript and note the discrepancy.
- If the transcript is partial or garbled in places, note that briefly rather than smoothing over the gap.
- Match depth to the ask: "quick recap" → Summary + action items only; "detailed notes" → full structure.
- If the user asks a pointed question ("did we decide on the vendor?"), answer it directly first, then offer the full summary.

## Step 5 — Draft the recap for delivery

The M365 connector is **read-only — it cannot send messages or post to Teams.** Your job is to hand the user a finished, ready-to-send draft and let them send it. Never claim you've sent or posted something you haven't.

Use `message_compose_v1` to produce the draft:
- **Email** → `kind: "email"`, include a subject line like "Notes — [Meeting] — [date]". Suggest the attendees as recipients but let the user confirm; don't put recipient addresses anywhere except where they can review them.
- **Teams post** → `kind: "other"` (gives a Copy button). Keep it more concise — a short summary line, decisions, and the action-item table read well in a Teams message.

If the user hasn't said which channel, ask once (Teams vs. email) since the formatting differs. Then show the notes inline in chat as well, so they have them even if they choose not to send.

If a send-capable tool ever becomes available, offer to send only after showing the exact recipients and content and receiving an explicit yes for that specific action. Treat sending as irreversible.

## Variations

**Multiple meetings** ("summarize my meetings yesterday"): search the date range with `query: '*'`, then run Steps 2–4 per meeting, compressing each to subject + Summary + action items. Skip declined/cancelled events and events with no other attendees unless asked.

**Upcoming meeting** (start time is in the future): there is no transcript — pivot to a prep brief using the agenda from the invite body, the attendee list, and (if useful) the most recent prior occurrence's summary plus related recent emails/chat on the topic.

**Recurring series**: confirm which occurrence the user means if ambiguous ("this week's staff meeting" vs. the series). Always scope the transcript URI to that occurrence with `start`/`end`.

## A note on trust

People forward these notes to their colleagues and act on them. The failure mode that matters most here isn't a clunky sentence — it's a plausible-sounding action item assigned to someone who never agreed to it, or a "decision" that was actually still up in the air. When in doubt, under-claim: "Unassigned", "—", or an Open Question is always safer than a confident fabrication. That restraint is what makes the output something the user can send without re-checking against the recording.

## Privacy

Transcripts and chats can contain sensitive content. Summarize only for the signed-in user's own meetings or calendars they have legitimate delegate access to; never work around a permission error. Do not forward or send summary content anywhere without explicit user confirmation.
