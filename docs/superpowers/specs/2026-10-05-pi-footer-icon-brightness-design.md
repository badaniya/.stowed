# Pi Footer Icon Brightness Design

## Goal

Make the model, effort level, Nerd Font directory (`󰉋`), Git branch (`󰊢`), elapsed-time icon, and LSP/MCP/Langfuse health indicators in Pi's custom status footer consistent, monochrome, and visually balanced while preserving the Catppuccin Mocha hierarchy. The model must be bold Catppuccin Mocha peach, effort regular mauve, directory label bold lavender, and Git branch label bold mauve.

## Approved approach

Keep directory and Git icon metadata parts in `pi/.pi/agent/extensions/lib/statusline-format.ts` at the semantic `muted` color. Replace the elapsed-time glyph with Nerd Font Material Design `clock` (`󰥔`, `U+F0954`) and format it as `󰥔 <duration>` with one ASCII space. Replace the health block's filled-circle indicator (`●`) in `pi/.pi/agent/extensions/statusline.ts` with the smaller Nerd Font filled-circle glyph (``, `U+F444`).

`muted` resolves to Catppuccin Mocha `overlay0` (`#6c7086`) in `pi/.pi/agent/themes/pi-catppuccin-mocha.json`, retaining the brighter icon treatment. The model uses bold peach `#fab387` (`{ kind: 'rgb', r: 250, g: 179, b: 135 }`); effort uses regular mauve `#cba6f7` (`{ kind: 'rgb', r: 203, g: 166, b: 247 }`); the directory label uses bold lavender `#b4befe` (`{ kind: 'rgb', r: 180, g: 190, b: 254 }`); and the Git branch label uses bold mauve `#cba6f7` (`{ kind: 'rgb', r: 203, g: 166, b: 247 }`). The extension must render those labels with `theme.style(..., { fg: color, bold })`, because `theme.fg()` accepts only named theme tokens and the built-in token set has no lavender role. The four direct colors and the three bold flags are deliberately confined to these requested footer labels; the theme JSON is not changed.

## Layout contract

This is a color-and-glyph-only refinement. Preserve the existing footer ordering and grouping exactly:

`model effort │ context ↑input ↓output $cost 󰥔 duration │ 󰉋 PWD 󰊢 branch` → right-aligned `│ health`

In particular, do not add, remove, or move metadata separators; do not regroup token, cost, and duration segments; retain the large gap that right-aligns the health block; and retain `attachToPrevious` behavior except for the one space inside `󰥔 <duration>`.

## Scope

- Retain the two `muted` icon colors in `buildMetadataParts()`.
- Replace `󰅐` with `󰥔` plus one following space in `formatElapsed()`.
- Represent exact footer metadata colors and weights as typed metadata styles in the formatter and render them through `theme.style()`.
- Render the model bold in `#fab387`, effort regular in `#cba6f7`, directory label bold in `#b4befe`, and branch label bold in `#cba6f7`.
- Retain `` in the health-status renderer.
- Update formatter tests to assert the exact elapsed format, typed RGB label colors, `muted` icons, and unchanged one-column health-width accounting.
- Run focused formatter tests and strict TypeScript validation.

## Non-goals

- Do not change footer layout, metadata ordering/grouping, metadata separators, right-aligned health gap, directory/Git icon glyphs, health tones, or the Catppuccin palette.
- Do not change global theme roles. The only hard-coded RGB values are the user-requested directory and branch label colors.

## Validation

1. The formatter test asserts both directory/Git icon parts have `color: 'muted'`; elapsed output is `󰥔 <duration>`; model, effort, directory, and branch styles equal the exact RGB/weight values (bold peach, regular mauve, bold lavender, bold mauve); and health indicator width remains one column.
2. `node --experimental-strip-types --test extensions/lib/statusline-format.test.ts` passes.
3. `npx tsc --noEmit --project tsconfig.json` exits successfully.
4. After reloading or restarting Pi through its supported interface, the live footer visibly preserves the established metadata grouping and right-aligned health block while showing the solid clock with a space, bold peach model, regular mauve effort, bold lavender PWD, and bold mauve branch.
