# Pi Footer Icon Brightness Design

## Goal

Make the Nerd Font directory (`󰉋`) and Git branch (`󰊢`) icons in Pi's custom status footer slightly brighter while preserving the Catppuccin Mocha hierarchy.

## Approved approach

Change both icon metadata parts in `pi/.pi/agent/extensions/lib/statusline-format.ts` from the semantic `dim` color to `muted`.

`muted` resolves to Catppuccin Mocha `overlay0` (`#6c7086`) in `pi/.pi/agent/themes/pi-catppuccin-mocha.json`, making the icons brighter than their current `dim` / `surface1` (`#45475a`) appearance. The semantic token keeps the footer compatible with alternative Pi themes.

## Scope

- Update the two icon color values in `buildMetadataParts()`.
- Update formatter tests to assert `muted` for the directory and Git icons.
- Run focused formatter tests and strict TypeScript validation.

## Non-goals

- Do not change footer layout, spacing, icon glyphs, directory label color, branch label color, or the Catppuccin palette.
- Do not introduce a new theme role or hard-coded color.

## Validation

1. The formatter test asserts both icon parts have `color: 'muted'`.
2. `node --experimental-strip-types --test extensions/lib/statusline-format.test.ts` passes.
3. `npx tsc --noEmit --project tsconfig.json` exits successfully.
