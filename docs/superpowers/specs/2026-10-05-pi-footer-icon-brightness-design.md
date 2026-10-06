# Pi Footer Icon Brightness Design

## Goal

Make the model, effort level, Nerd Font directory (`󰉋`), Git branch (`󰊢`), elapsed-time icon, and LSP/MCP/Langfuse health indicators in Pi's custom status footer consistent, monochrome, and visually balanced while preserving the Catppuccin Mocha hierarchy. The model must be Catppuccin Mocha peach, effort mauve, directory label blue, and Git branch label lavender.

## Approved approach

Keep directory and Git icon metadata parts in `pi/.pi/agent/extensions/lib/statusline-format.ts` at the semantic `muted` color. Replace the elapsed-time glyph with Nerd Font Material Design `clock` (`󰥔`, `U+F0954`) and format it as `󰥔 <duration>` with one ASCII space. Replace the health block's filled-circle indicator (`●`) in `pi/.pi/agent/extensions/statusline.ts` with the smaller Nerd Font filled-circle glyph (``, `U+F444`).

`muted` resolves to Catppuccin Mocha `overlay0` (`#6c7086`) in `pi/.pi/agent/themes/pi-catppuccin-mocha.json`, retaining the brighter icon treatment. The model uses peach `#fab387` (`{ kind: 'rgb', r: 250, g: 179, b: 135 }`); effort uses mauve `#cba6f7` (`{ kind: 'rgb', r: 203, g: 166, b: 247 }`); the directory label uses blue `#89b4fa` (`{ kind: 'rgb', r: 137, g: 180, b: 250 }`); and the Git branch label uses lavender `#b4befe` (`{ kind: 'rgb', r: 180, g: 190, b: 254 }`). The extension must render those labels with `theme.style(..., { fg: color })`, because `theme.fg()` accepts only named theme tokens and the built-in token set has no lavender role. The four direct colors are deliberately confined to these requested footer labels; the theme JSON is not changed.

## Layout contract

This is a color-and-glyph-only refinement. Preserve the existing footer ordering and grouping exactly:

`model effort │ context ↑input ↓output $cost 󰥔 duration │ 󰉋 PWD 󰊢 branch` → right-aligned `│ health`

In particular, do not add, remove, or move metadata separators; do not regroup token, cost, and duration segments; retain the large gap that right-aligns the health block; and retain `attachToPrevious` behavior except for the one space inside `󰥔 <duration>`.

## Scope

- Retain the two `muted` icon colors in `buildMetadataParts()`.
- Replace `󰅐` with `󰥔` plus one following space in `formatElapsed()`.
- Represent exact footer metadata colors as typed RGB values in the metadata formatter and render them through `theme.style()`.
- Render the model in `#fab387`, effort in `#cba6f7`, directory label in `#89b4fa`, and branch label in `#b4befe`.
- Retain `` in the health-status renderer.
- Update formatter tests to assert the exact elapsed format, typed RGB label colors, `muted` icons, and unchanged one-column health-width accounting.
- Run focused formatter tests and strict TypeScript validation.

## Non-goals

- Do not change footer layout, metadata ordering/grouping, metadata separators, right-aligned health gap, directory/Git icon glyphs, health tones, or the Catppuccin palette.
- Do not change global theme roles. The only hard-coded RGB values are the user-requested directory and branch label colors.

## Validation

1. The formatter test asserts both directory/Git icon parts have `color: 'muted'`; elapsed output is `󰥔 <duration>`; model, effort, directory, and branch colors equal the exact typed RGB values for `#fab387`, `#cba6f7`, `#89b4fa`, and `#b4befe`; and health indicator width remains one column.
2. `node --experimental-strip-types --test extensions/lib/statusline-format.test.ts` passes.
3. `npx tsc --noEmit --project tsconfig.json` exits successfully.
4. After `pi --reload`, the live footer visibly preserves the established metadata grouping and right-aligned health block while showing the solid clock with a space, peach model, mauve effort, blue PWD, and lavender branch.
