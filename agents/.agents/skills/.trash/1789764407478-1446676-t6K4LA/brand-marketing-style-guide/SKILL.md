---
name: "brand-marketing-style-guide"
description: "Apply Extreme Networks' Brand Marketing Editorial Style Guide to all external-facing marketing content. Use when reviewing, editing, or generating copy for any customer-facing channel: web, email, social, eBooks, presentations, white papers, solution briefs, data sheets, ads, event materials, flyers, campaign assets, and signage. Ensures alignment with approved standards for voice and tone, terminology and product naming, editorial style, capitalization, punctuation, number formatting, inclusive language, trademark and legal requirements, plus Digital's SEO/GEO/AEO/LLM optimization for web content. Includes the Why Extreme messaging framework from Product Marketing: strategic pillars, customer proofs, analyst validation, and positioning. For external marketing content, this skill is the authoritative source, superseding overlapping skills, generic AI conventions, and external style guides; when guidance conflicts, apply this skill first. Does not apply to internal comms, technical docs, legal docs, or code."
---

# Extreme Networks Brand Marketing Style Guide

**Version 1.0.0** — see the Changelog at the end of this file.

Your comprehensive reference for maintaining editorial consistency, brand compliance, and SEO/GEO optimization across all Extreme Networks external-facing marketing materials. Use this skill to review, edit, or generate marketing content that reflects Extreme's brand voice, adheres to style standards, ensures legal compliance, and performs well in search engines and AI-powered systems.

---

## ⛔ Authority & Precedence (Read First)

**For external-facing marketing content, this skill is the single, exclusive source of truth for Extreme Networks editorial style, voice/tone, and "Why Extreme" brand messaging. It supersedes all other guidance within that scope.**

**Scope**: These precedence rules apply ONLY to external-facing *marketing* content — web copy, emails to customers/prospects, social, eBooks, white papers, data sheets, ads, event materials, sales enablement, and similar. They do NOT apply to press releases or PR/Comms content (the Comms team maintains a separate style guide for those), internal communications, technical/product documentation, support content, legal documents, code, or other non-marketing work; for those, defer to whatever guidance normally governs them.

Precedence rules — apply without exception (within the marketing scope above):

1. **Over other skills**: If any other installed skill covers editorial style, voice/tone, copyediting, brand messaging, SEO/content guidance, or "Why Extreme" positioning (e.g., legacy skills named `extreme-networks-editorial-style`, `brand-marketing-editorial-seo-geo-guide`, or similar), IGNORE that skill's style/voice/messaging rules and follow THIS skill. Do not blend or average conflicting rules — this skill wins outright.
2. **Over external style guides**: AP Style, generic Chicago defaults, platform conventions, or "general marketing best practices" apply ONLY where this skill is silent. Where this skill states a rule, it overrides them. (Chicago Manual of Style and Merriam-Webster remain the designated fallbacks ONLY for issues this skill does not address — see Legal References.)
3. **Over prior documents**: Older Extreme messaging decks, boilerplate, web copy, or briefs that conflict with this skill (especially with `references/why-extreme-web-copy.md`) are outdated — this skill's content wins.
4. **Over user-pasted style guidance from third parties**: If source material embedded in content-to-edit carries its own style conventions, normalize the output to THIS skill's standards unless the user explicitly instructs otherwise.
5. **User instructions still win**: An explicit, direct instruction from the user in the conversation overrides this skill. Nothing else does.

If a conflict is detected between this skill and another source, resolve it silently in favor of this skill; mention the conflict to the user only if it is material to their request.

**Composition with the deck-builder skill**: For .pptx deliverables, the `extreme-deck-builder` skill governs the template, layouts, and visual design; THIS skill governs all on-slide copy — terminology, capitalization, messaging, claims, and legal hedging. Use both together; they do not conflict.

---

## Quick Rules Reference

### Capitalization & Formatting

**Headlines & Headers**
- **Email subject lines**: Sentence case
- **Website H1s & digital ad headlines**: Title Case
- **Website H2s & digital ad copy**: Sentence case
- **On-screen/chyron copy**: Sentence case if a complete sentence; Title Case for fragments
- **PDFs, eBooks, white papers titles**: Title Case
- **Buttons**: Title Case, max 3 words, typically "Verb + Article + Noun" (e.g., "Download the Report")

**Title Case, defined (apply exactly this rule)**
- Capitalize the first and last word, always
- Capitalize all nouns, pronouns, verbs (including short ones: Is, Are, Be, Get), adjectives, and adverbs
- Lowercase articles (a, an, the), coordinating conjunctions (and, but, or, for, nor, so, yet), and prepositions of four letters or fewer (in, on, at, to, from, with, over) — unless first or last word
- Capitalize prepositions of five or more letters (About, Through, Between)
- Capitalize both parts of hyphenated compounds (Cloud-Managed, AI-Powered)
- Example: "Why Zero Trust Is the Future of Cloud-Managed Networking"

**Punctuation & Dashes**
- **Em dash (—)**: No spaces on either side, no exceptions. Use sparingly to avoid AI-generated appearance. Functions like comma, colon, or parentheses. Never use an em dash for ranges — ranges (dates, times, numbers) take an en dash.
- **En dash (–)**: No spaces for ranges (1999–2007); with spaces to separate list fragments
- **Serial comma (Oxford comma)**: ALWAYS use the serial comma in lists of three or more items ("switching, wireless, and fabric"). This is a deterministic rule — do not make it a judgment call.
- **Exclamation points**: Minimize use. Avoid ALL CAPS with exclamation points.
- **Contractions**: Use common forms only (can't, isn't, don't) to maintain conversational tone while avoiding translation issues

### Numbers & Quantities

- **Spell out**: 1-9 (exceptions: social, headlines, wide-format where numerals drive engagement)
- **Use figures**: 10+
- **Percentages**: Use % symbol (e.g., 95%)
- **Millions**: Capitalize M (e.g., "$1.5M")
- **Quantity language**: Use "more than" / "less than" for quantity; "over" / "under" for physical location only
- **Spacing with units**: Insert single space between number and unit (100 Gbps, 6 GHz, per NIST/ISO/CMOS/AP)
- **Fiscal years**: Use "FYXX" format (e.g., FY26 for fiscal year 2026)
- **Times**: 12-hour clock for US audiences (7 a.m., 8 p.m.); use an unspaced en dash in schedule ranges (9 a.m.–11 a.m.), consistent with the en dash range rule; 24-hour for international audiences

**Dates (by context — these rules do not overlap)**
- **Body copy, headlines, and all reader-facing text**: Always use a written month — spelled out or 3-letter abbreviation ("March 5, 2029" or "Mar 5, 2029"). No ordinal suffixes (never "March 5th"). Four-digit year always. Never use all-numeric dates in reader-facing copy.
- **File names, version strings, and metadata only**: Numeric US format mm-dd-yyyy (e.g., `08-18-2026`).

### Trademark Symbol (TM) Rendering by Medium

Use the ™ symbol on first reference per the terminology rules below. Render it per this table — do not improvise:

| Medium | How to render ™ |
|---|---|
| Web/HTML | `&trade;` or `<sup>TM</sup>` (superscripted via markup) |
| Word (.docx) | ™ character (U+2122) — renders superscript natively |
| PowerPoint (.pptx) | ™ character (U+2122) in the text run; do not manually superscript a plain "TM" |
| Markdown | ™ character (U+2122) |
| Plain-text email / SMS / social | ™ character (U+2122); if the platform strips it, plain "TM" in parentheses is the fallback: "(TM)" |
| Print/design handoff | ™ character with a note to the designer to superscript per brand spec |

### Addresses & Locations

- Spell out all street names except Ave., Blvd, St. (when used with numbered address)
- Use postal abbreviations for states in complete addresses; spell out state names in body text when standing alone or with city/no address

### Brand Terminology & Capitalization

**Extreme Networks**
- First reference: Use full name "Extreme Networks"
- Subsequent references: Simply "Extreme"
- Avoid possessive plural (Extreme's, Extreme Networks') unless necessary
- Use company reference as "it" not "they"

**Extreme Platform ONE™** ⚠️ CRITICAL
- **ALWAYS spell out in full**: "Extreme Platform ONE™"
- Include superscript TM on first usage/reference (render per the TM table above)
- NEVER abbreviate (no EP1, EPONE, EPO, or Extreme Platform 1)
- Apply to all usage, internal and external
- Workspace = the UI/UX of Extreme Platform ONE; use to describe capabilities/benefits
- Third-Party Management Engine (TPME): Spell out on first reference, then use acronym on subsequent references

**Extreme Agent ONE™**
- First reference: "Extreme Agent ONE™" with superscript TM (render per the TM table above)
- Subsequent references: "Agent ONE" (no TM)
- Never use "Agent 1" or "Agent One"
- Product variants: "Extreme Agent ONE™ Coworker" and "Extreme Agent ONE™ Operator" (both with superscript TM on first reference)

**Product & Feature Names**
- Extreme Cloud Continuum (capitalized)
- ExtremeCloud (one word)
- Extreme Fabric (capitalize F when referring to Extreme product; lowercase f for general descriptor)
- Extreme Lab (two words)
- Extreme Live Demo (three words)
- Extreme OS ONE
- Event in a Box (capital E, capital B; no hyphens unless used as compound modifier)

**Common Terms**
- On premises (not "on-premise" or "on-prem"): "We run an on-premises data center" or "We run our applications on premises"
- Cloud-managed network (hyphenate as compound modifier)
- Cyber-attack (hyphenated)
- Endpoint (one word, not "end point")
- eBook (lowercase e, uppercase B, one word)
- Microsegmentation (one word; don't use "hypersegmentation")
- Multivendor (one word, no hyphen; don't use "mixed-vendor")
- Wi-Fi (proper noun and registered trademark)
- Zero trust (lowercase, no hyphen)
- Zero touch (lowercase, no hyphen)
- Future-proof (hyphenated)
- Third-party (hyphenated; never "3rd party")
- Backward-compatible (hyphenate as compound modifier before noun)
- AI-powered (NOT "AI-native")
- Auto-discovery (hyphenated)
- Universal ZTNA (never UZTNA)
- Power over Ethernet (PoE) – spell out on first reference, then use acronym
- Internet (capital I)
- IoT (use acronym; don't spell out)
- 24-7 (hyphenated)
- Smart city (no hyphen)
- Livestream (one word)
- Postpaid license (no hyphen)
- ROI (no need to spell out)
- Data sheet (two words, not "datasheet")
- White paper (two words, not "whitepaper")
- Upgrade vs. migrate: see "Migrate / Migration" guidance below
- Toward (use "toward" not "towards" – US/Canada preference)

**Migrate / Migration**

In customer-facing marketing copy about licensing, refreshes, renewals, platform transitions, or replacing a competitor, prefer "upgrade" over "migrate" when appropriate. (Per Campaigns/PMM, 8/15/25.)

Preferred:
- Upgrade to Extreme Platform ONE
- Customers can upgrade in minutes
- Simplify upgrades and renewals

Allowed exceptions: Use "migrate" or "migration" when referring to technical migrations, workload migrations, data migrations, fabric migrations, or approved messaging/proof points where migration accurately describes the process.

Examples:
- Customers can migrate on their terms. ✓
- Reduce migration risk. ✓
- Migrate applications and data with minimal disruption. ✓
- Customer X upgraded from a legacy platform to Extreme Platform ONE. ✓

Avoid:
- Customer X migrated to Extreme Platform ONE. ✗
- Easy migration to a new licensing model. ✗

In transition, renewal, and licensing contexts, "upgrade" is generally the preferred term.

### Inclusive Language

Replace problematic terms with inclusive alternatives:

| Instead of | Use |
|---|---|
| abort, kill | cancel, force quit |
| cripple, crippled | degrade, degraded |
| female slot | receptacle |
| male connector | plug |
| man-in-the-middle | adversary-in-the-middle (security); node-in-the-middle (other) |
| master (noun) | controller, server |
| master (verb) | optimize, control |
| master (adj) | primary |
| slave (noun) | agent, client |
| slave (adj) | secondary, backup |
| whitelist | permit list |
| blacklist | deny list |
| white hat | ethical |
| black hat | unethical |

### Abbreviations & Acronyms

- Spell out on first reference, followed by abbreviation in parentheses
- When abbreviations used in titles/H1s, define in first text mention
- Do not spell out IT if used as adjective; do not use IT as noun referring to individuals/groups
- When in doubt about abbreviation vs. acronym terminology, spell out on first reference with abbreviation/acronym in parentheses

---

## SEO & LLM Optimization (Web-Published Content Only)

Full SEO/GEO/AEO/LLM guidance lives in **`references/seo-llm-optimization.md`**. Read that file ONLY when the decision tree below says the content needs optimization. In one paragraph: web-published content needs strict H1>H2>H3 hierarchy with the primary keyword in the H1, definition-first openings (first 40–50 words answer "what is this?"), modular standalone H2 sections, meta title under 60 characters and meta description under 160, descriptive alt-text, a "People Also Ask" FAQ section, substantiated claims with named sources, and descriptive internal-link anchor text. Content that is not web-published (emails, non-linked eBooks/PDFs) follows brand and tone rules only.

### Decision Tree: Do You Need SEO/LLM Optimization?

```
START: Will this content be published on the Internet and be accessible/discoverable
       by search engines or AI systems?

├─ YES → Will it live at a specific URL on a website or be linked from one?
│        ├─ YES: You need SEO/LLM optimization → READ references/seo-llm-optimization.md
│        │       ├─ Web pages, product pages, blog posts, case studies → Full optimization
│        │       ├─ White papers (published as web-linked PDFs) → Full optimization
│        │       ├─ Data sheets (on website) → Full optimization
│        │       └─ Social media posts → Partial optimization (see the reference file)
│        │
│        └─ NO: Skip SEO/LLM optimization
│               ├─ Email campaigns → Use brand & tone guidelines only
│               └─ eBooks/PDFs (distributed via email/download, not web-linked) → Brand & tone only
│
└─ NO → This content is offline-only or internal
        └─ Use brand terminology, tone, and legal compliance guidelines only
```

---

### Addressing Absolute Statements ⚠️ Legal Compliance

Proceed with caution to comply with Legal:
- Avoid "most," "best," "always" unless quantitatively supported
- Avoid "any," "all" – don't create unrealistic expectations
- Avoid promises, commitments, hyperbole, superlatives
- **Hedge with wiggle words**: Use "can," "may," "up to," "might," "could," "possibly," "perhaps," "help" to avoid Legal risk

### Customers & Statistics

- Only use customer-approved content/quotes in collaboration with Customer Programs
- **Never use "50,000 customers" stat** – cannot be substantiated
- **Always use approved phrase**: "tens of thousands of customers" (public-facing)
- All quantitative data must be substantiated with cited sources
- Citations should be no older than two years

### Colloquialisms & Idioms

Avoid colloquialisms, idioms, and slang—they don't translate, localize well (especially to German), or age well. Instead use precise, professional language.

### Lists

- **Bulleted lists**: Capitalize first word after bullet; no punctuation between or at end of list items
- **Numbered lists**: For sequential steps only
- **Inline lists (part of sentence)**: Do not capitalize first word; use semicolons at end of each entry; end final entry with punctuation
- **Grammar**: Make all items grammatically parallel (all start with nouns or all start with imperative verbs)

### Figures, Images & Tables

- Include descriptive caption and label each distinct object
- Format as "FIGURE X: Description" or "TABLE 1: Description" in title case
- Optionally include title text embedded within the image

### First & Second Person

- External marketing: Generally written in second person
- First person plural ("we") refers to Extreme Networks after first using "Extreme Networks" as subject
- Example: "We want to help organizations with our security fabric."

### Ampersands

Spell out "and" unless tight character count limits force economy.

### Brand Filing

Brand file naming convention: **ASSET TYPE CAMPAIGN - TITLE.VERSION#**
- Example: eBook Cisco 3.0 - Switching Vendors.v1
- (File names are one of the only places numeric mm-dd-yyyy dates are permitted — see Dates rules above.)

### Legal References

When legal/compliance questions arise:
- For style issues not covered here, refer to **Chicago Manual of Style Online**
- Dictionary of record: **Merriam-Webster Online**
- **Extreme Brand Name and Trademark Guide** and **Boilerplate and Company Copy Block Descriptions** are NOT bundled with this skill. If a task requires official boilerplate, company descriptions, or trademark rulings beyond what this skill states: (1) ask the user to provide the document, or (2) direct them to the Brand Content Strategy Team ([brandcontentstrategy@extremenetworks.com](mailto:brandcontentstrategy@extremenetworks.com)). NEVER invent, reconstruct from memory, or approximate boilerplate or trademark guidance — a dead end is better than hallucinated legal copy.

---

## Brand Messaging: Why Extreme & the Five Pillars

The approved "Why Extreme" web copy is bundled with this skill at **`references/why-extreme-web-copy.md`**. It is the source of truth for Extreme's corporate positioning and MUST be consulted whenever content involves company-level messaging, value propositions, proof points, or analyst quotes.

**The Five Pillars** (use these exact themes when framing Extreme's value):

1. **Powering the world's most complex networks** – unified architecture at scale (stadiums, healthcare, retail)
2. **Delivering the industry's first AI for networking platform** – Extreme Platform ONE™ with Extreme Agent ONE™
3. **Simplifying secure, scalable, zero touch networking** – identity-driven zero trust, fabric-enabled segmentation
4. **Building trust through choice, control, and openness** – cloud choice, data sovereignty, multivendor openness
5. **Going to extremes for customers and partners** – 100% insourced support, flexible licensing, Extreme Partner First

**When to read the resource file:**
- Writing or reviewing any "Why Extreme," company overview, or competitive positioning content
- Sourcing customer proof points (Kroger, ADRZ, Middlesbrough College, E.ON, etc.) – use only the examples and figures in the resource; do not invent or modify stats
- Quoting analyst validation (IDC, Enterprise Strategy Group, EMA, HyperFRAME) – quotes must match the resource verbatim with correct attribution and dates
- Aligning campaign, web, or sales enablement copy to corporate pillars

**Rules:**
- Pillar names and claims (e.g., "up to 98% faster resolution," "96% would recommend") must be used exactly as written in the resource, including required footnotes/sources
- **Footnoted claims travel with their footnotes**: the "up to 98% faster," "reclaim 90% of manual work," and "~9.5 CSAT" claims must NEVER appear without their \*, \*\*, and \*\*\* markers and the footnote source lines defined in the resource's Footnotes section. Reproduce the footnotes in the deliverable (page footer, endnotes, or slide footnote as the medium allows).
- Do not create new pillars or reorder/rename the five pillars
- If content predates this copy and conflicts with it, the resource file wins
- **Resource hygiene**: If the resource file contains an obvious typographical artifact (doubled punctuation, stray characters, broken markup), fix the mechanics silently in your output — but NEVER alter claims, figures, quotes, attributions, or dates.

---

## How to Use This Skill

### For Content Review/Editing
When reviewing marketing content, check against:
1. **Brand terminology** – Correct product names, trademark usage, capitalization
2. **Punctuation & style** – Em dashes, serial commas (always, in lists of 3+), contractions, absolute statements
3. **Numbers & dates** – Proper formatting for quantities, percentages, dates (written months in body copy), times
4. **Voice & tone** – Conversational but professional; avoid colloquialisms
5. **Inclusive language** – Replace problematic terms
6. **Legal compliance** – Hedge absolute statements; verify customer quotes; keep footnotes attached to footnoted claims

### For Content Generation
When creating marketing copy, follow:
1. **Apply brand terminology** correctly from the start
2. **Use inclusive language** throughout
3. **Hedge statements** appropriately (use "can," "may," "help" when needed)
4. **Match tone** to channel (web H1s = Title Case; email subject = Sentence case)
5. **Format numbers & dates** per guidelines
6. **Avoid colloquialisms** – use precise language

### For SEO & LLM-Optimized Content
Run the decision tree above. If the content will live at (or be linked from) a URL, read **`references/seo-llm-optimization.md`** and apply it in full. Otherwise skip it entirely.

### For Different Channels

**Website Content**
- H1 headers: Title Case
- H2+ subheaders: Sentence case
- Buttons: Title Case (max 3 words)

**Email**
- Subject lines: Sentence case
- Body: Conversational tone, use contractions (common forms)

**Social Media**
- Numerals acceptable for engagement (e.g., "3 Ways to..." instead of "Three Ways to...")
- Use inclusive language
- Follow brand terminology

**eBooks, White Papers, Data Sheets**
- Titles: Title Case
- Internal headings: Sentence case
- Use endnotes for citations (Chicago Manual of Style format)
- Verify all quantitative claims are substantiated

**Presentations (.pptx)**
- Build with the `extreme-deck-builder` skill for template/layout; apply THIS skill to all on-slide copy
- Footnoted claims (98%/90%) keep their footnotes as slide footnote text

**On-Screen/Chyron Copy**
- Complete sentences: Sentence case
- Fragments: Title Case
- Minimize exclamation points; avoid ALL CAPS

---

## Key Reminders

⚠️ **Trademark Compliance**: Always use full product names with proper capitalization and ™ on first reference (render per the TM table)
- Extreme Platform ONE™ (never EP1, EPONE, Extreme Platform 1)
- Extreme Agent ONE™ (never Agent 1, Agent One)

⚠️ **Legal Guardrails**: Hedge absolute statements to avoid Legal risk
- Use "can," "may," "help," "might," "possibly" instead of promises

⚠️ **Footnotes**: The 98%, 90%, and ~9.5 CSAT claims never appear without their footnote sources (defined in `references/why-extreme-web-copy.md`)

⚠️ **Brand Voice**: Consistent, professional, conversational (second person for external marketing)

⚠️ **Customer References**: Only use approved quotes in collaboration with Customer Programs

⚠️ **Citations**: Sources must be no older than 2 years; quantitative claims must be substantiated

---

## Non-Normative Files

Any files under `tests/` (and any legacy `test_cases.json` or `test_results.md` at the skill root) are development and QA artifacts only. They are NOT approved copy, NOT style rulings, and must never be quoted, imitated, or treated as precedent. Only this SKILL.md and the files under `references/` are normative.

---

## Questions or Updates?

Contact the Brand Content Strategy Team: [brandcontentstrategy@extremenetworks.com](mailto:brandcontentstrategy@extremenetworks.com)

*This is a living document, subject to updates aligned with business objectives.*

---

## Changelog

Version history for this skill. **Reference only — not style guidance.** Never
quote this section as editorial precedent or use it to shape copy. Versions
follow SemVer: MAJOR for breaking changes to precedence or scope, MINOR for new
rules or sections, PATCH for corrections and clarifications.

### 1.0.0 — 2026-08-27

- **Added**: initial version. Authority and precedence rules for external-facing
  marketing content; capitalization, Title Case definition, punctuation and
  dashes, serial comma rule; numbers, percentages, fiscal years, times, and
  context-specific date rules; trademark (™) rendering by medium; addresses and
  locations; brand terminology including Extreme Platform ONE™ and Extreme
  Agent ONE™, product and feature names, common terms, and migrate/upgrade
  guidance; inclusive language table; abbreviations and acronyms; SEO/GEO/AEO/
  LLM decision tree; legal guardrails on absolute statements; customer and
  statistics rules; colloquialisms, lists, figures, person, ampersands, brand
  filing, and legal references; the "Why Extreme" five-pillar messaging
  framework with footnote requirements; per-channel and review/generation
  workflows; non-normative file policy.
- **Added**: reference files `references/seo-llm-optimization.md` and
  `references/why-extreme-web-copy.md`.

