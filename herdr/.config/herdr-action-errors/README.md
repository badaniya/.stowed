# Shared Herdr Plus action errors

All configured quick actions in `../herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/` run through `../herdr-spreader/herdr-action-errors.py`. This local plugin supplies the popup and log terminal entrypoints; installed third-party plugins are unchanged.

## Behavior

- Run the original command with its existing arguments, working directory, environment, and stdin. Stream combined stdout/stderr while retaining a temporary capture.
- Success: return zero and discard the capture; no notification.
- Failure: preserve the command's exit status and keep a unique private log and metadata file.
- Reuse the workspace named `HERDR-ACTION-ERRORS`, or create it without taking focus. Display the first log over the newly created workspace's initial pane, so its first tab is used rather than left empty. Later errors open new log tabs without touching existing panes. Each log view displays the complete log and leaves a shell there; tabs are labeled with time and action name.
- Show a centered, scrollable terminal popup using the terminal-default background, with action name, status, error summary, log path, and recent output. Enter, Escape, or `q` dismisses it; arrows/Page Up/Page Down scroll.
- When called inside the quick-action picker, a detached reporter waits for the picker to exit before opening the popup.
- Never type commands into existing panes. Do not change `[ui.toast]`; agent system notifications remain unchanged.
- If Herdr is unavailable or UI reporting fails, retain the log and print its location. Reporting failures do not replace the original exit status.

The six older `*-notify.sh` entrypoints now delegate here. An inherited marker prevents duplicate logs/popups when an action calls a legacy wrapper.

## Evaluated action paths

- All 44 configured quick actions: tested by substituting harmless failing launchers in an isolated HOME and checking the retained exit status and action metadata for each action.
- NVO / EMULATOR / review sandbox bootstrap: the detached worker explicitly reports a failure after the launcher has returned, snapshotting the worker log and all failed stage logs. This bypasses inherited nesting markers without changing bootstrap/workspace behavior.
- Sandbox Control: lifecycle and snapshot create/restore backend command failures are captured inside the dialog, before it becomes an inspection shell.
- Sandbox Exposure: backend failures are captured inside its dialog, including the original command output and status, before opening an inspection shell.
- Cancellation, successful commands, and long-lived agent/SSH/database sessions are not treated as action errors.
- The local `~/.config/herdr-spreader/import-ng-aio.sh` generator was updated so new NG-AIO quick actions opt into the shared runner. That script is outside this repository; no private content was copied into tracked files.

## Install / activate

Stow the `herdr` package as usual, then register the local plugin:

```sh
herdr plugin link "$HOME/.config/herdr-action-errors"
```

The current installation is linked directly to the repository's `herdr/.config/herdr-action-errors` directory. No Herdr restart is needed; the quick-action picker reloads action configurations when opened.

## Add an action

For an argv-style command:

```toml
name = "Example action"
command = "python3 ~/.config/herdr-spreader/herdr-action-errors.py run --name 'Example action' -- bash ~/.config/herdr-spreader/example.sh"
```

Herdr Plus's existing form/template handling remains in place. Form values omitted from the template are still appended as one argument by Herdr Plus. For a shell pipeline or compound command, explicitly put that whole command behind `-- sh -c '...'` rather than prefixing only the first pipeline stage. Future actions must opt in; the integration test checks every configured TOML action.

For a direct non-destructive smoke test (intentionally returns 7):

```sh
python3 ~/.config/herdr-spreader/herdr-action-errors.py run \
  --name 'TEST: error reporting' -- \
  bash -c 'echo "Error: deliberate smoke test; nothing was destroyed" >&2; exit 7'
```

Background jobs with existing logs can explicitly report a completed failure:

```sh
python3 ~/.config/herdr-spreader/herdr-action-errors.py notify \
  --name 'Background task' --status 1 --message 'Error: background task failed' \
  --source-log /path/to/worker.log --source-log /path/to/stage.log
```

This snapshots logs rather than moving them, and reports even if a launcher nesting marker was inherited. `notify` returns zero after recording/reporting; the worker remains responsible for its own original exit status.

## Logs and limits

Logs live in `${XDG_STATE_HOME:-$HOME/.local/state}/herdr/action-errors/`: directory mode `0700`, log/metadata files `0600`. Logs can contain sensitive command output; they are retained until manually removed. Closing a tab does not delete its log. `.report.log` files record failures of the deferred reporter itself.

The runner captures synchronous exit failures, not an `Error:` string followed by exit zero. Other work deliberately launched into another pane or remote jobs is outside its lifetime; those jobs must invoke `run` or `notify` themselves to report eventual failures. The built-in sandbox bootstrap workers and dialog backend commands listed above now do so. Existing interactive dialogs continue to run in their own panes. Commands requiring stdout itself to be a TTY need a dedicated interactive pane rather than this capturing runner.

The popup shows the last 128 KiB to bound memory; the log tab displays the complete file with ANSI/control sequences stripped for safe terminal display. Raw logs remain unchanged on disk.

## Tests

```sh
python3 -m unittest discover -s tests/herdr -p '*_test.py'
for test in tests/herdr/*_test.sh; do
  env -u HERDR_ENV -u HERDR_SOCKET_PATH -u HERDR_ACTION_ERROR_ACTIVE bash "$test"
done
```
