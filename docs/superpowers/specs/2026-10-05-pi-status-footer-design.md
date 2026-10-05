# Pi status footer design

## Goal

Refine the custom Pi footer while retaining its existing model, thinking effort, cost, responsive layout, and right-aligned LSP/MCP/Langfuse health indicators.

## Layout

The metadata row retains its current order for model and effort. The usage information is a single visually grouped sequence:

```text
<model> <effort> │ <context> <token usage> <duration> │ <directory group>
```

The directory group is:

```text
󰉋 <pwd> 󰊢 <git branch>
```

- `󰉋` is the Nerd Font folder/home-style marker for the current working directory.
- `󰊢` is the Nerd Font Git marker for the branch.
- Icons and separators use Pi's `dim` semantic theme color so they appear light gray in the active palette.
- The duration uses Pi's `muted` semantic theme color, matching the thinking-effort label rather than the dim separators/icons.
- The path and branch retain distinct semantic colors for readability.
- The branch icon and branch label are omitted when no branch is available.

## Behavior

- Preserve the existing accumulated input/output token calculation, context percentage color thresholds, elapsed timer, optional cost, path shortening, terminal-width truncation, and Git-branch rerender subscription.
- Preserve responsive behavior: when the combined metadata and health block do not fit, render metadata on the first line and the health block right-aligned on a second line.
- Preserve the existing TUI-only lifecycle behavior and restore Pi's built-in footer on session shutdown.

## Implementation boundaries

- Keep layout and formatting decisions in `/home/badaniya/.pi/agent/extensions/lib/statusline-format.ts` so they remain unit-testable.
- Keep `/home/badaniya/.pi/agent/extensions/statusline.ts` limited to session wiring, usage aggregation, theme rendering, and footer component lifecycle.
- Update formatter tests to cover grouped ordering, icon-bearing directory/branch output, missing-branch behavior, and narrow-width layout selection.

## Validation

Run the extension formatter test suite and TypeScript checks available to its local package. Verify the footer manually in Pi after reloading the extension, including a Git repository and a non-Git directory.
