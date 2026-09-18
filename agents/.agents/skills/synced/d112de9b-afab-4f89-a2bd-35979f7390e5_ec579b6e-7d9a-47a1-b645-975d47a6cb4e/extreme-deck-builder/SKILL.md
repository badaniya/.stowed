---
name: extreme-deck-builder
description: Build polished Extreme Networks branded PowerPoint decks that match the official corporate template (DM Sans, purple-and-black palette, logo/swoosh/footer chrome baked into 61 layouts). ALWAYS use this skill when the user asks for a presentation, deck, slides, or .pptx for an Extreme Networks audience — including phrasings like "XN slides", "Extreme deck", "branded deck", "exec summary deck", "usage report slides", or "put this in our template". It ships a clean layouts-only base file plus a python-pptx helper module (stat cards, bar rows, column fills) so decks come out looking like the brand examples instead of broken placeholder soup. Prefer this over generic pptx creation and over older Extreme template skills.
---

# Extreme Deck Builder

Builds branded Extreme Networks decks the way the best hand-made examples
were built: **layouts carry all the chrome; content is placed as free,
explicitly-positioned shapes.** Never enumerate or guess placeholder indices.

## Files

- `assets/extreme_base.pptx` — official template, stripped to 0 slides /
  61 branded layouts. Every new deck starts from this.
- `scripts/extreme.py` — helper module (`new_deck`, `add_slide`, `add_text`,
  `add_stat`, `add_card`, `add_bar_row`, `fill_columns`, brand colors,
  content-area constants).
- `references/layouts.md` — layout catalog + geometry. **Read it before
  choosing layouts.**

## Workflow

1. **Ask the user: dark or light background?** Before building, ask one
   quick question (use the tappable-options tool if available): "Dark or
   light background for the deck?" — dark = black slides with white text
   (high-impact, exec/keynote feel); light = white slides with ink text
   (working sessions, print-friendly). Skip the question only if the user
   already said (now or earlier in the conversation) which they want.
   A deck uses ONE theme for all content slides — never mix dark and light
   content slides. Cover and `End` slides always use the official dark
   brand artwork (the template has no light variants of these).
2. **Plan the deck**: list slides with (layout, title, content outline).
   Standard arc: `Cover-1` → optional `Agenda Slide` → content slides →
   `End`.
3. **Read `references/layouts.md`** and pick a layout per slide — via the
   theme-aware pickers `content_layout()` / `column_layout()`, not
   hardcoded names.
4. **Build with the helper module**:

```python
import sys; sys.path.insert(0, "<skill>/scripts")
from extreme import *

prs = new_deck()
set_theme("dark")          # or "light" — per the user's answer, set ONCE

s = add_slide(prs, COVER, title="Claude Usage Report\nMay 2026",
              subtitle="Executive Summary — API Performance & Spend",
              author="IT / Data Intelligence")

s = add_slide(prs, content_layout(), title="Executive Summary — May 2026")
add_stat(s, 0.6, 1.7, 3.9, value="26.3B", label="TOTAL TOKENS",
         sub="▲ 52% vs April")        # colors follow the theme
add_stat(s, 4.7, 1.7, 3.9, value="286.6K", label="API REQUESTS",
         sub="▲ 168% vs April")
add_stat(s, 8.8, 1.7, 3.9, value="$19,696", label="NET SPEND",
         sub="▲ 50% vs April")
add_text(s, 0.6, 3.8, 6.0, 0.35,
         [[{"text": "SPEND BY FUNCTIONAL AREA", "size": 11, "bold": True,
            "color": c_label()}]])
for i, (lbl, frac, val) in enumerate([("Products", 1.0, "58%"),
                                      ("IT", 0.26, "15%")]):
    add_bar_row(s, 0.6, 4.2 + i * 0.45, 6.0, lbl, frac, val)

s = add_slide(prs, column_layout(2), title="Trade-offs",
              keep_placeholders=True)
fill_columns(s, [[("Option A", 0, {"bold": True}), ("Lower cost", 1)],
                 [("Option B", 0, {"bold": True}), ("Faster rollout", 1)]])

add_slide(prs, END)
prs.save("deck.pptx")
```

5. **QA — required.** Render and inspect every slide:

```bash
python <pptx-skill>/scripts/office/soffice.py --headless --convert-to pdf deck.pptx
rm -f slide-*.jpg && pdftoppm -jpeg -r 150 deck.pdf slide
```

View each image. Fix overflow/overlap, regenerate, re-check the affected
slides, then stop (one fix cycle unless a new user-visible defect appears).
Note: DM Sans is substituted in the QA render — widths are approximate, so
leave ~10% slack in text boxes rather than chasing pixel fit.

## Design rules for this brand

- **One theme per deck.** All content slides are dark or all are light —
  set once with `set_theme()`, never mix. Pick layouts via
  `content_layout()` / `column_layout()` and colors via `c_head()`,
  `c_body()`, `c_muted()`, `c_label()`, `c_card()` so everything follows
  the theme automatically. Cover and `End` always use the dark brand art.
- **The chrome is already there.** Logo, header swoosh, footer, page number
  come from the layout. Never add your own logo, header bars, accent
  stripes, or footer text.
- **Content stays inside x 0.49–12.84, y 1.35–6.95** on Title Only–family
  slides. Nothing under the logo (top-right) or over the footer.
- **Color discipline**: use the theme accessors — `c_head()` for headings
  and big numbers, `c_body()` for body text, `c_label()` for section
  labels. Purple `5B059C` / violet `7519F9` are accents — stat labels,
  bars, highlight numbers — not body text.
- **Numbers big, labels small**: KPI values 28–36pt bold, labels 12–13pt,
  deltas 10–11pt. Use `add_stat` cards in rows of 3–4.
- **One idea per slide**, ≤ ~6 bullets, 11–14pt body. If a slide needs more,
  split it.
- **Vary structure** across content slides: stat-card row, two-column,
  bar rows, quote/big-stat slide — don't repeat one pattern.
- **Numeric breakdowns get bars, not bullets.** A list like
  "Products — $11,435 (58%)" belongs in `add_bar_row` panels (one per
  category group, side by side), anchored by a large total callout
  (`add_text`, 32–36pt) and finished with one insight `add_card` — not in a
  `1_Two Column` bullet list. Reserve the column layouts for prose:
  pros/cons, before/after, responsibilities.
- **No half-empty slides.** If content fills less than ~60% of the area
  below y=1.35, enrich it (callout, insight card, bars) or merge it into
  another slide.
- Titles are single-line (placeholder is 0.42" tall). Long title? Shorten it
  or use a `Subhead` layout.
- Cover titles wrap at ~9" — control line breaks yourself with `\n`
  (e.g. `"Claude Usage Report\nMay 2026"`), never let a date or trailing
  word wrap alone.
- Charts: prefer `add_bar_row` for simple comparisons; for real charts use
  python-pptx native charts sized to fit the content area, brand-colored
  (`VIOLET`, `PERIWINKLE`, `SKY`, `BLUE`), no chart border, 10pt DM Sans
  labels.

## When the user supplies data

Summarize, don't dump: pull the 3–5 headline numbers into stat cards, put
detail into a two/three-column slide or a compact table, and end content
decks with a "Key Highlights" or "Recommendations" slide.
