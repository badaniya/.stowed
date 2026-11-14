#!/usr/bin/env bash
# todo.sh — Herdr TODO workspace: tab 1 = tuxedo todo list, tab 2 = Claude Haiku agent.
# The terminal-browser split under tab 1 is created by the todo-agent morning cron, not here.
set -euo pipefail

TODO_DIR="$HOME/workspace/badaniya"
TODO_AGENT_DIR="$TODO_DIR/todo-agent"

if [[ ! -d "$TODO_AGENT_DIR" ]]; then
  printf 'TODO agent directory does not exist: %s\n' "$TODO_AGENT_DIR" >&2
  exit 1
fi

WS_JSON=$(herdr workspace create --cwd "$TODO_DIR" --label TODO --focus)
PANE=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
WS=$(echo "$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")

herdr tab rename "$T1" "1 - TODO List" > /dev/null
herdr pane run "$PANE" "tuxedo"

T2_JSON=$(herdr tab create --workspace "$WS" --cwd "$TODO_AGENT_DIR" --no-focus)
T2=$(echo "$T2_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
AGENT_PANE=$(echo "$T2_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
herdr tab rename "$T2" "2 - Agent" > /dev/null
herdr pane run "$AGENT_PANE" "claude --model haiku"
