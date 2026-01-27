# AI Agent: Non-TTY Debug Pod Access via Tmux

AI agents running in non-TTY environments (like OpenCode) cannot use interactive `kubectl exec -it` directly. **Tmux provides a workaround** by creating a pseudo-TTY session that can be controlled programmatically.

## Contents

- [Architecture](#architecture)
- [Session Reuse](#session-reuse-recommended)
- [Connection Limits](#connection-limit-switching-clusters)
- [Step-by-Step Workflow](#step-by-step-workflow)
- [SQL Query Patterns](#critical-sending-sql-queries-with-semicolons)
- [Kafka Operations](#kafka-operations)
- [Troubleshooting](#troubleshooting)

## Architecture

```
AI Agent (non-TTY)
      |
      |-- tmux new-session -d -s debug-session
      |-- tmux send-keys "command" + Enter
      |-- tmux capture-pane -p (read output)
      |
      v
  Tmux Session (PTY)
      |
      |-- bash ~/.alias_repo/load_alias_debug.sh
      |
      v
  Debug Pod (interactive bash)
      |
      |-- psql_nvodbhost / list_topics / etc.
```

## Session Reuse (RECOMMENDED)

**Keep the tmux session alive between queries** to avoid the 15-25s debug pod startup time on each request.

### Why Session Reuse Matters

| Approach | First Query | Subsequent Queries |
|----------|-------------|-------------------|
| Fresh session each time | ~25s | ~25s |
| **Session reuse** | ~25s | **~2-4s** |

### Important: Cluster-Specific Sessions

Debug pods use **Kubernetes cluster-internal DNS** (e.g., `nvodbhost.nvo.svc.cluster.local`). This means:
- A debug pod in `stage-va-rdc` **cannot** query databases in `fra-rdc`
- Each cluster requires its own tmux session
- Use session naming convention: `k8s-debug-{cluster}`

### Session Naming Convention

| Cluster | Session Name |
|---------|--------------|
| stage-va-rdc | `k8s-debug-stage-va` |
| fra-rdc | `k8s-debug-fra` |
| eu0-gdc | `k8s-debug-eu0` |
| va-rdc | `k8s-debug-va` |
| jp-rdc | `k8s-debug-jp` |

### Session Reuse Workflow

```bash
# === FIRST QUERY (one-time setup ~25s) ===

# Check if session exists and is usable
if tmux has-session -t k8s-debug-stage-va 2>/dev/null; then
  # Session exists - verify debug pod is still active
  if tmux capture-pane -t k8s-debug-stage-va -p | grep -q "debuguser@"; then
    echo "Session ready - reusing existing debug pod"
  else
    # Session exists but debug pod exited - restart it
    tmux send-keys -t k8s-debug-stage-va 'bash ~/.alias_repo/load_alias_debug.sh' Enter
    # Wait for debug pod...
  fi
else
  # Create new session
  tmux new-session -d -s k8s-debug-stage-va
  tmux send-keys -t k8s-debug-stage-va 'export KUBECONFIG=~/.kube/config && tsh kube login stage-va-rdc' Enter
  # Wait for login...
  tmux send-keys -t k8s-debug-stage-va 'bash ~/.alias_repo/load_alias_debug.sh' Enter
  # Wait for debug pod (~15-25s)...
fi

# === SUBSEQUENT QUERIES (~2-4s each) ===

# Just send commands directly - no setup needed!
tmux send-keys -t k8s-debug-stage-va 'check_lag network_device-connect-events' Enter
sleep 3
tmux capture-pane -t k8s-debug-stage-va -p | tail -30
```

### Helper: Check Session Status

```bash
# Quick check if session is ready for queries
is_debug_ready() {
  local session="$1"
  tmux has-session -t "$session" 2>/dev/null && \
  tmux capture-pane -t "$session" -p | grep -q "debuguser@"
}

# Usage
if is_debug_ready "k8s-debug-stage-va"; then
  tmux send-keys -t k8s-debug-stage-va 'check_lag my-group' Enter
else
  # Need to set up session first
fi
```

### When to Clean Up

- **DO cleanup**: End of conversation, switching to different cluster, user explicitly done
- **DON'T cleanup**: Between multiple queries to same cluster, user might have follow-up questions

## Connection Limit: Switching Clusters

Teleport enforces a **maximum of 2 concurrent Kubernetes connections** per user. Attempting to connect to a third cluster while two are active results in:

```
warning: couldn't attach to pod/..., falling back to streaming logs: too many concurrent kubernetes connections for user "USER@extremenetworks.com" (max=2)
```

**MANDATORY: Close existing debug session before switching to a new cluster.**

### Cluster Switch Workflow

```bash
# === STEP 1: Close current session (if exists) ===

close_debug_session() {
  local session="$1"
  if tmux has-session -t "$session" 2>/dev/null; then
    # Exit psql if connected
    tmux send-keys -t "$session" '\q' C-j 2>/dev/null
    sleep 0.3
    # Exit debug pod
    tmux send-keys -t "$session" 'exit' Enter
    sleep 1
    # Kill tmux session
    tmux kill-session -t "$session"
    echo "Closed session: $session"
  fi
}

# Close stage-va before switching to jp-rdc
close_debug_session "k8s-debug-stage-va"

# === STEP 2: Create new session for target cluster ===

tmux new-session -d -s k8s-debug-jp
tmux send-keys -t k8s-debug-jp 'export KUBECONFIG=~/.kube/config && tsh kube login jp-rdc' Enter
# Wait for login...
tmux send-keys -t k8s-debug-jp 'bash ~/.alias_repo/load_alias_debug.sh' Enter
# Wait for debug pod (~15-25s)...
```

### Quick Reference: Session Management

| Action | Command |
|--------|---------|
| List active sessions | `tmux list-sessions` |
| Check if session exists | `tmux has-session -t SESSION 2>/dev/null && echo "exists"` |
| Close session cleanly | `tmux send-keys -t SESSION 'exit' Enter && sleep 1 && tmux kill-session -t SESSION` |
| Force kill session | `tmux kill-session -t SESSION` |

## Step-by-Step Workflow

### Timing Reference

| Operation | Typical Time | Recommended Wait |
|-----------|--------------|------------------|
| Cluster login (`tsh kube login`) | ~4-5s | Poll for "Logged into" or sleep 5 |
| Debug pod launch | ~15-25s | Poll for "debuguser@" or sleep 25 |
| `update_dbalias` | ~3-4s | Poll for prompt or sleep 4 |
| `psql_*` connect | ~1-2s | Poll for "=>", or sleep 2 |
| SQL query | ~1-4s | Poll for "(N row" or sleep 4 |

### Optimized Polling Pattern

```bash
# Generic polling function - wait for pattern in tmux output
wait_for_pattern() {
  local session="$1" pattern="$2" timeout="${3:-30}"
  local elapsed=0
  while ! tmux capture-pane -t "$session" -p | grep -q "$pattern"; do
    sleep 0.3
    elapsed=$((elapsed + 1))
    [ $elapsed -gt $((timeout * 3)) ] && echo "Timeout waiting for: $pattern" && return 1
  done
}

# Usage examples:
wait_for_pattern ai-debug "Logged into" 10       # Cluster login
wait_for_pattern ai-debug "debuguser@" 30        # Debug pod
wait_for_pattern ai-debug "platform_common_db=>" 10  # psql connect
wait_for_pattern ai-debug "(1 row)" 10           # SQL result
```

### 1. Create Tmux Session and Login

```bash
# Kill any existing session, then create fresh detached session
tmux kill-session -t ai-debug 2>/dev/null
tmux new-session -d -s ai-debug

# Login to target cluster
tmux send-keys -t ai-debug 'export KUBECONFIG=~/.kube/config && tsh kube login <cluster-name>' && tmux send-keys -t ai-debug Enter

# Poll for completion (~4-5s)
while ! tmux capture-pane -t ai-debug -p | grep -q "Logged into"; do sleep 0.5; done
tmux capture-pane -t ai-debug -p | tail -5
```

### 2. Launch Debug Pod

```bash
# Launch debug pod via bash (not source - avoids zsh compatibility issues)
tmux send-keys -t ai-debug 'bash ~/.alias_repo/load_alias_debug.sh' && tmux send-keys -t ai-debug Enter

# Poll for debug pod prompt (~15-25s)
while ! tmux capture-pane -t ai-debug -p | grep -q "debuguser@"; do sleep 0.5; done
tmux capture-pane -t ai-debug -p | tail -10
```

### 3. Update Database Aliases

```bash
# Load all available database aliases
tmux send-keys -t ai-debug 'update_dbalias' && tmux send-keys -t ai-debug Enter

# Poll for completion (~3-4s)
sleep 0.5
while tmux capture-pane -t ai-debug -p | tail -1 | grep -q "update_dbalias"; do sleep 0.3; done
tmux capture-pane -t ai-debug -p | tail -10
```

### 4. Connect to Database and Query

```bash
# Connect to platform_common_db (~1-2s)
tmux send-keys -t ai-debug 'psql_cs-platformdbhost' && tmux send-keys -t ai-debug Enter
while ! tmux capture-pane -t ai-debug -p | grep -q "platform_common_db=>"; do sleep 0.3; done

# Disable pager (<1s)
tmux send-keys -t ai-debug '\pset pager off' && tmux send-keys -t ai-debug C-j
sleep 0.5

# Run a query - USE printf + load-buffer for SQL with semicolons!
printf "SELECT count(*) FROM inferred_device WHERE deleted_at IS NULL;" | \
  tmux load-buffer - && tmux paste-buffer -t ai-debug && tmux send-keys -t ai-debug C-j

# Poll for result (~1-4s)
while ! tmux capture-pane -t ai-debug -p | grep -q "(1 row)"; do sleep 0.3; done
tmux capture-pane -t ai-debug -p | tail -15
```

### 5. Cleanup (Only When Done)

**Don't cleanup between queries!** Keep session alive for subsequent queries.

```bash
# Exit psql (if in psql) - backslash command
tmux send-keys -t ai-debug '\q' && tmux send-keys -t ai-debug C-j
sleep 0.5

# Exit debug pod
tmux send-keys -t ai-debug 'exit' && tmux send-keys -t ai-debug Enter
sleep 1

# Kill tmux session
tmux kill-session -t ai-debug
```

## CRITICAL: Sending SQL Queries with Semicolons

**The `-l $'...\n'` syntax STRIPS trailing semicolons!** This causes SQL queries to hang.

```bash
# WRONG: Semicolon gets stripped, query hangs
tmux send-keys -t ai-debug -l $'SELECT * FROM devices WHERE id = 1;\n'
# Result: "platform_common_db-> " (waiting for semicolon)

# WRONG: "Enter" is literal text, not a key
tmux send-keys -t ai-debug 'SELECT * FROM devices;' Enter

# CORRECT: Use printf + load-buffer + paste-buffer + C-j
printf "SELECT * FROM devices WHERE id = 1;" | tmux load-buffer - && tmux paste-buffer -t ai-debug && tmux send-keys -t ai-debug C-j
```

### Recommended Query Pattern

```bash
# 1. Build query with printf, paste via buffer, execute with C-j
printf "SELECT id, name FROM inferred_device WHERE deleted_at IS NULL LIMIT 20;" | \
  tmux load-buffer - && \
  tmux paste-buffer -t ai-debug && \
  tmux send-keys -t ai-debug C-j

# 2. Wait for result
sleep 3

# 3. Capture output
tmux capture-pane -t ai-debug -p | tail -30
```

### Simple Commands (No Semicolons)

For shell commands without semicolons, the simpler pattern works:

```bash
# Shell commands - use send-keys + Enter key
tmux send-keys -t ai-debug 'update_dbalias' && tmux send-keys -t ai-debug Enter

# Backslash commands in psql (no semicolon needed)
tmux send-keys -t ai-debug '\pset pager off' && tmux send-keys -t ai-debug C-j
tmux send-keys -t ai-debug '\dt *device*' && tmux send-keys -t ai-debug C-j
```

## Kafka Operations

```bash
# List Kafka topics (~1-2s)
tmux send-keys -t ai-debug 'list_topics' && tmux send-keys -t ai-debug Enter
while ! tmux capture-pane -t ai-debug -p | grep -q '"count":'; do sleep 0.3; done
tmux capture-pane -t ai-debug -p | tail -30

# Filter topics by pattern (~2s)
tmux send-keys -t ai-debug 'list_topics | grep -i device-connect' && tmux send-keys -t ai-debug Enter
sleep 2 && tmux capture-pane -t ai-debug -p | tail -20

# Consume messages from beginning (~3-5s)
# NOTE: Without --from-beginning, consumer waits for NEW messages (will hang)
tmux send-keys -t ai-debug 'consume_topic device-connect-events --from-beginning --max-messages 5' && tmux send-keys -t ai-debug Enter
while ! tmux capture-pane -t ai-debug -p | grep -q '"count":'; do sleep 0.3; done
tmux capture-pane -t ai-debug -p | tail -40

# Check consumer group lag (~2s)
tmux send-keys -t ai-debug 'check_lag my-consumer-group' && tmux send-keys -t ai-debug Enter
sleep 2 && tmux capture-pane -t ai-debug -p | tail -20
```

## Key Patterns Summary

| Action | Command |
|--------|---------|
| Simple command (no semicolon) | `tmux send-keys -t SESSION 'command' && tmux send-keys -t SESSION Enter` |
| SQL query (with semicolon) | `printf "SELECT...;" \| tmux load-buffer - && tmux paste-buffer -t SESSION && tmux send-keys -t SESSION C-j` |
| Capture output | `tmux capture-pane -t SESSION -p \| tail -N` |
| Quit pager (--More--) | `tmux send-keys -t SESSION 'q'` |
| Cancel current command | `tmux send-keys -t SESSION C-c` |

## Common Database Aliases

| Alias | Database | Common Tables |
|-------|----------|---------------|
| `psql_cs-platformdbhost` | platform_common_db | inferred_device, inferred_interface, asset_device |
| `psql_nvodbhost` | nvo_db | NVO-specific tables |
| `psql_systemdbhost` | system_db | System configuration |
| `psql_configdbhost1` | config_db | Configuration data |

## Troubleshooting

### Tmux Session Already Exists

```bash
tmux kill-session -t ai-debug 2>/dev/null
tmux new-session -d -s ai-debug
```

### SQL Query Hanging (Missing Semicolon)

```bash
# Symptom: psql shows "platform_common_db-> " (continuation prompt)
# Fix: Cancel and use printf + paste-buffer pattern
tmux send-keys -t ai-debug C-c
printf "SELECT * FROM devices WHERE id = 1;" | tmux load-buffer - && tmux paste-buffer -t ai-debug && tmux send-keys -t ai-debug C-j
```

### Command Not Executing

```bash
# WRONG: "Enter" is interpreted as literal text
tmux send-keys -t ai-debug 'command' Enter

# CORRECT: Send Enter as a separate send-keys call
tmux send-keys -t ai-debug 'command' && tmux send-keys -t ai-debug Enter
```

### Pager Blocking Output

```bash
# Symptom: Output shows "--More--" at bottom
# Fix 1: Disable pager before queries
tmux send-keys -t ai-debug '\pset pager off' && tmux send-keys -t ai-debug C-j

# Fix 2: Send 'q' to quit current pager
tmux send-keys -t ai-debug 'q'
```

### Debug Pod Not Starting

```bash
# Check for existing pod
kubectl get pods -n debug | grep middleware-debug-pod

# If stuck, pod may need manual cleanup or wait for auto-terminate
```

### Cluster Name Not Found

```bash
# List available clusters
tsh kube ls --format=json 2>/dev/null | jq -r '.[].kube_cluster_name' | grep -i <partial-name>

# Common naming: stage-va -> stage-va-rdc (add -rdc suffix)
```

## Important Notes

1. **Always use WHERE conditions** - Same rules apply as interactive access
2. **Debug pod auto-terminates in 2 hours** - Plan accordingly
3. **Use `sleep` between commands** - Allow time for execution
4. **Keep sessions alive for reuse** - Saves ~20s per query
5. **Bash, not source** - Use `bash ~/.alias_repo/load_alias_debug.sh` to avoid zsh issues
6. **Disable pager first** - Run `\pset pager off` after connecting to psql
