# Layout catalog — extreme_base.pptx (61 layouts, 1 master)

All branded chrome lives in the layouts: Extreme Networks logo (top right),
gray header swoosh band, corner arcs, footer copyright line, and `<#>` page
number. Never redraw any of these — pick the right layout and it's there.

Slide size: 13.333" x 7.5" (16:9). Theme font: DM Sans. Theme colors:
purple `5B059C`, violet `7519F9`, periwinkle `7D76F2`, sky `9CE0F1`,
indigo `240691`, blue `0F82F3`, ink `20004C`.

## Workhorse layouts (cover ~95% of decks)

| Layout name | Look | Title placeholders (fill via `add_slide`) |
|---|---|---|
| `Cover-1` | Dark purple gradient + orb, logo top right | title, subtitle, author block |
| `Agenda Slide` | Light; "Agenda" label left, two list columns | title + 2 column OBJECT placeholders |
| `Title Only` | **Light content slide** — header band, logo, footer | title (H1) at (0.49, 0.44) |
| `Title Only Subhead` | Light + second line under title | title, subtitle |
| `Title Only Dark` | **Dark content slide** — same chrome on black | title |
| `Title Only Dark Subhead` | Dark + subtitle | title, subtitle |
| `1_Two Column` | Light, title + two body columns at y=1.65, each 6.10" wide | title + 2 OBJECT columns |
| `1_Three Column` | Light, title + three body columns at y=1.65, each 3.87" wide | title + 3 OBJECT columns |
| `1_Content_Quote` | Light, oversized quote/stat center + attribution | title (the quote), attribution |
| `4_Light-No-title` | Light, minimal chrome — full-canvas freeform | none |
| `End` | Dark closing slide, Extreme orb logo centered | none |

Dark variants of the column layouts exist: `1_Two Column Dark`,
`1_Three Column Dark`, plus `... Subhead` versions of each.

## Other families (use when asked / when they clearly fit)

- `Cover-3`, `Cover-5`, `Cover-6`, `Cover-9`, `Cover-10` — alternate cover art.
- `Title-1/2/3` — section divider slides.
- `Content_Text_&_Image-*` — text + photo placeholder splits (several ratios,
  numbered variants flip sides).
- `Content_Lists-2`, `2_Content_Lists-2` — multi-list layouts.
- `Content_Graph` — chart placeholder layout.
- `No Image Slide` family (`1_` … `15_`, plus `... Dark`) — prebuilt text
  arrangements; placeholder-heavy, harder to control. Prefer `Title Only` +
  free shapes instead.
- `Subhead Dark`, `1_Subhead` — divider/intro variants.
- `1_Image Slide Dark`, `2_Image Slide Dark` — full-bleed dark image slides.

## Geometry to respect on Title Only–family slides

- Content area: x 0.49 → 12.84, y **1.35** → **6.95** (header band ends
  ~1.04"; footer text sits at y≈7.15).
- Title placeholder is one line tall (0.42"). Keep titles ≤ ~70 chars; for a
  second line use a `... Subhead` layout, don't wrap the title.
- Logo occupies x 11.5 → 12.9 at the top — never place content there.

## Placeholder mechanics

`add_slide()` fills title/subtitle by *position* (topmost text placeholder =
title) and deletes unfilled placeholders so no "Click to edit" ghosts remain.
For `1_Two Column` / `1_Three Column` / `Agenda Slide`, pass
`keep_placeholders=True` and use `fill_columns()` — their column placeholders
carry correct brand text styling.
