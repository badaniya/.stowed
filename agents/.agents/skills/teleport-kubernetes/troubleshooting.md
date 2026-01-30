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

```bash
# List available clusters
tsh kube ls --format=json 2>/dev/null | jq -r '.[].kube_cluster_name'

# Filter by partial name
tsh kube ls --format=json | jq -r '.[].kube_cluster_name' | grep -i <partial>
```

### Common Naming Patterns

| Input | Actual Cluster Name |
|-------|---------------------|
| stage-va | stage-va-rdc |
| va | va-rdc |
| fra | fra-rdc |
| jp | jp-rdc |
| eu0 | eu0-gdc |

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
