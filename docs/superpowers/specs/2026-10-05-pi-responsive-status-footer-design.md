# Pi responsive status footer design

## Goal

Restore Pi’s lower status area beneath `@eiei114/pi-sub-bar` without changing that package’s provider/context/quota bar. The restored footer must preserve the familiar Catppuccin-style metadata—model, token usage, model cost, effort level, and repository path—and add concise Langfuse, MCP, and LSP health summaries that remain readable in a vertical split.

## Scope

- Add one user-level Pi extension under `pi/.pi/agent/extensions/` that replaces only Pi’s built-in footer.
- Render model/session metadata and integration health from currently available Pi runtime/footer data.
- Make the output responsive to the available terminal width.
- Do not modify `@eiei114/pi-sub-bar`, MCP configuration, Langfuse configuration, or Pi Lens configuration.

## Layout

### Wide footer

At widths where both groups fit, render one lower line:

```text
◆ │ <model> │ <tokens> <cost> <effort> │ ⌁ <repo path>                    ● Langfuse │ ● MCP 2 │ ● LSP 5
```

The integration group is right-aligned. A width calculation based on terminal display columns—not JavaScript string length—decides whether this mode fits.

### Split/narrow footer

When the single-row form cannot fit, preserve the important metadata and use two rows:

```text
◆ │ <model> │ <tokens> <cost> <effort>
⌁ <repo path> │ ● Langfuse │ ● MCP 2 │ ● LSP 5
```

The repository path may be safely truncated by display width, but the status summaries are not dropped. If the terminal becomes exceptionally narrow, the footer prioritizes model then repository path before shortening labels.

## Data sources and status semantics

- **Model and effort:** read active model and thinking level from the Pi extension context.
- **Token usage and cost:** aggregate assistant-message usage over the active session branch, following Pi’s supported custom-footer example.
- **Repository identity:** use `footerData.getGitBranch()` and the active working directory; show a compact repository-relative identity.
- **Langfuse / MCP / LSP:** consume the extension-status strings exposed by `footerData.getExtensionStatuses()`. The extension classifies each status string by its status key/prefix and derives a compact label plus count where supplied. It must not attempt to call the services itself.
- **Fallback:** an integration that has not registered a status renders as muted/unknown rather than falsely reporting healthy. A state with an error/warning marker renders yellow/red; a known active/connected/sent state renders green; informational LSP activity can use blue.

## Styling

Use Pi’s active theme helpers so the existing `pi-catppuccin-mocha` theme controls terminal colors:

- model and repository: accent/mauve;
- token counts: lavender-like secondary accent;
- cost: warning/yellow;
- effort and healthy state: success/green;
- informational LSP state: accent/blue;
- separators and unknown state: dim/muted.

No ANSI sequences are stored across theme changes. The footer recomputes themed segments while rendering.

## Lifecycle and interaction

- Register the custom footer at session start and restore/update it for session/model changes.
- Subscribe to footer-data branch and extension-status changes so the display refreshes after Git branch, health, or session changes.
- Add a `/statusline` command to toggle the custom footer on/off for recovery and comparison with Pi’s default footer.
- The extension is presentation-only: it does not start polling, mutate settings, or alter the active provider, model, MCP servers, Langfuse, or Pi Lens.

## Error handling

All parsing is defensive. Missing usage, a detached Git repository, unknown status formats, a missing model, and absent integration statuses yield safe placeholder text rather than throwing. The footer is always constrained with Pi TUI column-aware utilities.

## Validation

1. Typecheck/load the extension with the installed Pi runtime.
2. Exercise `/statusline` enable/disable and a model change.
3. Check footer rendering in wide and approximately half-width terminals, including display-width truncation.
4. Confirm no LSP diagnostics in the added extension file.
5. Verify the upper `pi-sub-bar` remains unchanged and the custom footer does not mask its provider/context/quota line.
