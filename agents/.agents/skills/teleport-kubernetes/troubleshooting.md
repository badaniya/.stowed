# Troubleshooting Teleport Kubernetes

Common errors and their fixes.

## Authentication & Session

### Expired Session

```
ERROR: Active profile expired.
```

**Fix:** Run `tsh login --proxy=extreme-cloud.teleport.sh`

### Client Version Mismatch

```
client version X is not compatible with cluster version Y
```

**Fix:** Download Teleport Connect ONLY from:
1. Go to https://extreme-cloud.teleport.sh/web
2. SSO login
3. Click your name (top right) → Download → Teleport Connect

**DO NOT** download from any other source.

### Too Many Connections

```
too many concurrent kubernetes connections for user (max=2)
```

**Fix:** Close existing Teleport K8s session before connecting to a new cluster. See [ai-agent-tmux.md](ai-agent-tmux.md#connection-limit-switching-clusters) for workflow.

## Kubeconfig Issues

### Wrong Kubeconfig

```bash
# Symptoms: kubectl connects to wrong cluster
kubectl config current-context  # Shows unexpected context

# Fix: Ensure Teleport kubeconfig
export KUBECONFIG=~/.kube/config
```

### Permission Denied on Kubeconfig

```
ERROR: open /etc/rancher/k3s/k3s.yaml: permission denied
```

**Fix:** Set KUBECONFIG explicitly before tsh commands:

```bash
export KUBECONFIG=~/.kube/config && tsh kube login <cluster>
```

## Debug Pod Issues

### Debug Pod Already Exists

```
error: pod already exists
```

**Handled automatically** by tkl debug - it execs into existing pod if Running.

### Debug Pod Not Starting

```bash
# Check for existing pod
kubectl get pods -n debug | grep middleware-debug-pod

# If stuck, wait for pod to auto-terminate (2 hours) or contact admin
```

### Missing Cluster Aliases

```bash
# After tkl, aliases not working
alias | grep kubectl  # Empty

# Fix: Re-run tkl to reload aliases
tkl <cluster-name>
```

## Cluster Names

### Cluster Name Not Found

```
ERROR: kubernetes cluster "stage-va" not found
```

**Root Cause:** Cluster names ALWAYS include a suffix (`-rdc`, `-gdc`, `-uz`). User input often omits this.

**Resolution Rules (for AI Agents):**
1. If name already ends with `-rdc` or `-gdc` → use as-is
2. If name matches known GDC pattern → append `-gdc`:
   - `eu0`, `eu1`, `us0`, `us1` (global data centers)
   - `cal` (California GDC)
   - Any of the above with `-staging` suffix
3. Otherwise → append `-rdc` (default to Regional Data Center)

**Known GDC clusters:** `cal-gdc`, `eu0-gdc`, `eu0-staging-gdc`, `eu1-gdc`, `eu1-staging-gdc`, `us0-gdc`, `us0-staging-gdc`, `us1-gdc`, `us1-staging-gdc`

**Verification:**
```bash
# List available clusters
tsh kube ls --format=json 2>/dev/null | jq -r '.[].kube_cluster_name'

# Filter by partial name
tsh kube ls --format=json | jq -r '.[].kube_cluster_name' | grep -i <partial>
```

### Common Naming Patterns

| User Input | Actual Cluster Name | Rule |
|------------|---------------------|------|
| `stage-va` | `stage-va-rdc` | Default → append `-rdc` |
| `va` | `va-rdc` | Default → append `-rdc` |
| `fra` | `fra-rdc` | Default → append `-rdc` |
| `jp` | `jp-rdc` | Default → append `-rdc` |
| `eu0` | `eu0-gdc` | Known GDC → append `-gdc` |
| `us1` | `us1-gdc` | Known GDC → append `-gdc` |
| `cal` | `cal-gdc` | Known GDC → append `-gdc` |
| `eu0-staging` | `eu0-staging-gdc` | Known GDC → append `-gdc` |
| `stage` | `stage-rdc` | Default → append `-rdc` |

## Database Queries

### Query Hanging in psql

**Symptom:** psql shows `platform_common_db-> ` (continuation prompt)

**Cause:** Missing semicolon at end of query

**Fix:**
```sql
-- Cancel current input
Ctrl+C

-- Re-run with semicolon
SELECT * FROM table WHERE id = 1;
```

### Pager Blocking Output

**Symptom:** Output shows `--More--` at bottom

**Fix:**
```sql
-- Disable pager for session
\pset pager off

-- Or quit current pager
q
```

### Full Table Scan Warning

If you accidentally start a query without WHERE:
```sql
-- Cancel immediately!
Ctrl+C
```

Then rewrite with proper WHERE condition.

## Tmux Issues (AI Agent)

See [ai-agent-tmux.md](ai-agent-tmux.md#troubleshooting) for tmux-specific issues.
