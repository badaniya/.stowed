# Pi Footer Icon Brightness Design

## Goal

Make the Nerd Font directory (`󰉋`), Git branch (`󰊢`), elapsed-time icon, and LSP/MCP/Langfuse health indicators in Pi's custom status footer consistent, monochrome, and visually balanced while preserving the Catppuccin Mocha hierarchy.

## Approved approach

Change the directory and Git icon metadata parts in `pi/.pi/agent/extensions/lib/statusline-format.ts` from the semantic `dim` color to `muted`. Replace the emoji watch (`⌚`) in `formatElapsed()` with Nerd Font Material Design `clock-outline` (`󰅐`, `U+F0150`). Replace the health block's filled-circle indicator (`●`) in `pi/.pi/agent/extensions/statusline.ts` with Nerd Font Material Design `circle-medium` (`󰧞`, `U+F09DE`).

`muted` resolves to Catppuccin Mocha `overlay0` (`#6c7086`) in `pi/.pi/agent/themes/pi-catppuccin-mocha.json`, making the directory and Git icons brighter than their current `dim` / `surface1` (`#45475a`) appearance. `󰅐` is a monochrome Nerd Font glyph, so it honors its existing semantic footer color instead of rendering as a color emoji. Semantic tokens keep the footer compatible with alternative Pi themes.

## Scope

- Update the two icon color values in `buildMetadataParts()`.
- Replace `⌚` with `󰅐` in `formatElapsed()`.
- Replace `●` with `󰧞` in the health-status renderer.
- Update formatter tests to assert `muted` for the directory and Git icons, `󰅐` for elapsed time, and unchanged one-column health-width accounting.
- Run focused formatter tests and strict TypeScript validation.

## Non-goals

- Do not change footer layout, spacing, directory/Git icon glyphs, directory label color, branch label color, health tones, or the Catppuccin palette.
- Do not introduce a new theme role or hard-coded color.

## Validation

1. The formatter test asserts both directory/Git icon parts have `color: 'muted'`, elapsed output begins with `󰅐`, and health indicator width remains one column.
2. `node --experimental-strip-types --test extensions/lib/statusline-format.test.ts` passes.
3. `npx tsc --noEmit --project tsconfig.json` exits successfully.
