---
name: teleport-kubernetes
description: Use when accessing Kubernetes clusters via Teleport, running kubectl commands through tsh, debugging pods in RDC/GDC clusters, or connecting to databases (Postgres, Kafka) via Teleport proxy.
---

# Teleport Kubernetes Access

Access Kubernetes clusters, pods, and databases through Teleport's secure proxy.

**Reference**: [Quick Start with Teleport Wiki](https://extremenetworks.atlassian.net/wiki/spaces/EOP/pages/250644303/1.+For+End+Users+Quick+Start+with+Teleport)

## Contents

- [Quick Start](#quick-start)
- [RBAC & Safety Rules](#critical-dos-and-donts)
- [Cluster Login](#cluster-login-workflow)
- [kubectl Operations](#kubectl-via-teleport)
- [Debug Pod (Kafka/Postgres)](#middleware-debug-pod) → See [debug-pod.md](debug-pod.md)
- [AI Agent Workflow](#ai-agent-non-tty-access) → See [ai-agent-tmux.md](ai-agent-tmux.md)
- [Troubleshooting](#common-mistakes) → See [troubleshooting.md](troubleshooting.md)

## Quick Start

```bash
# 1. Login to Teleport (if expired)
tsh login --proxy=extreme-cloud.teleport.sh

# 2. Login to cluster
tkl va-rdc        # or: tsh kube login va-rdc

# 3. Run kubectl commands (read-only)
kubectl get pods -n nvo
kubectl logs -f deployment/nvo-network -n nvo

# 4. Access debug pod for Kafka/Postgres
tkl debug
```

## When to Use

- Accessing Kubernetes clusters managed by Teleport
- Running kubectl commands against RDC/GDC clusters
- Debugging with the middleware-access-util pod (Kafka, Postgres tools)
- Connecting to databases through Teleport proxy
- Checking pod health across multiple clusters
- **AI Agent database queries via tmux** → See [ai-agent-tmux.md](ai-agent-tmux.md)

## ⚠️ CRITICAL: Dos and Don'ts

### Role-Based Access Control

Scrum teams access production through **read-only privileges** only.

| User Role | Privileges | Namespace |
|-----------|------------|-----------|
| `co-nvo-ro` | Readonly | `nvo` |
| `co-common-ro` | Readonly | `common` |
| `co-xiq-ro` | Readonly | `$cluster-name` |
| `co-sdwan-ro` | Readonly | `sdwan` |

### ✅ Permitted Actions

| Action | Example |
|--------|---------|
| View Pod, Job, Deployment status | `kubectl get pods -n nvo` |
| View logs and events | `kubectl logs <pod> -n nvo` |
| List/describe resources | `kubectl describe pod <name> -n nvo` |
| Launch debug container | `tkl debug` |
| Query databases with WHERE | `SELECT * FROM devices WHERE id = 123;` |

### 🚫 Forbidden Actions

| Action | Why |
|--------|-----|
| Modify/delete resources | Read-only access only |
| `kubectl rollout restart` | No write permissions |
| Exec into running containers | Only debug pod allowed |
| Queries without WHERE | Full table scan → DB overload |

### ⚠️ Important Warnings

1. **All activities are monitored and recorded**
2. **Debug pod auto-terminates in 2 hours**
3. **Database queries MUST use WHERE conditions**

## Prerequisites

```bash
# Verify tsh is installed
which tsh  # /usr/local/bin/tsh

# Check login status
tsh status

# Login if expired
tsh login --proxy=extreme-cloud.teleport.sh
```

## AI Agent Usage

When running kubectl commands programmatically, set KUBECONFIG explicitly:

```bash
# Recommended: Inline KUBECONFIG export
export KUBECONFIG=~/.kube/config && tsh kube login <cluster-name>
kubectl get pods -n nvo

# Alternative: Use tkl via interactive zsh
zsh -ic 'tkl <cluster-name> && kubectl get pods -n nvo'
```

**For full AI agent workflow with database access via tmux**: See [ai-agent-tmux.md](ai-agent-tmux.md)

## Cluster Login Workflow

### Using tkl (Recommended)

```bash
tkl va-rdc        # Virginia RDC
tkl eu0-gdc       # EU0 GDC
tkl stage-rdc     # Staging RDC
tkl k3s           # Switch to local k3s
```

**What tkl does:**
1. Sets KUBECONFIG to `~/.kube/config`
2. Clears existing Teleport session
3. Sources cluster-specific aliases
4. Runs `tsh kube login <cluster>`

### Manual tsh Commands

```bash
# List available clusters
tsh kube ls
tsh kube ls --format=json | jq -r '.[].kube_cluster_name'

# Login to specific cluster
tsh kube login va-rdc

# Check current context
tsh status
kubectl config current-context
```

### Common Cluster Types

| Suffix | Type | Examples |
|--------|------|----------|
| `-rdc` | Regional Data Center | `va-rdc`, `fra-rdc`, `jp-rdc`, `stage-rdc`, `stage-va-rdc` |
| `-gdc` | Global Data Center | `eu0-gdc`, `us1-gdc`, `cal-gdc`, `eu0-staging-gdc` |

### ⚠️ Cluster Name Resolution (IMPORTANT for AI Agents)

**Cluster names ALWAYS include the suffix** (`-rdc`, `-gdc`). When a user provides a partial name, you MUST append the appropriate suffix:

| User Says | Actual Cluster Name | Rule Applied |
|-----------|---------------------|--------------|
| `stage-va` | `stage-va-rdc` | Append `-rdc` for staging/regional |
| `va` | `va-rdc` | Append `-rdc` for regional |
| `fra` | `fra-rdc` | Append `-rdc` for regional |
| `eu0` | `eu0-gdc` | Append `-gdc` for global |
| `us1` | `us1-gdc` | Append `-gdc` for global |
| `cal` | `cal-gdc` | Known GDC → append `-gdc` |
| `stage` | `stage-rdc` | Append `-rdc` for staging |

**Resolution Rules:**
1. If name already ends with `-rdc`, `-gdc`, or `-uz` → use as-is
2. If name matches known GDC pattern → append `-gdc`:
   - `eu0`, `eu1`, `us0`, `us1` (global data centers)
   - `cal` (California GDC)
   - Any of the above with `-staging` suffix (e.g., `eu0-staging` → `eu0-staging-gdc`)
3. Otherwise → append `-rdc` (default to Regional Data Center)

**Known GDC clusters:** `cal-gdc`, `eu0-gdc`, `eu0-staging-gdc`, `eu1-gdc`, `eu1-staging-gdc`, `us0-gdc`, `us0-staging-gdc`, `us1-gdc`, `us1-staging-gdc`

**When in doubt**, run `tsh kube ls | grep -i <partial-name>` to find the exact cluster name.

## kubectl via Teleport

After `tsh kube login`, kubectl works for **read-only operations**:

```bash
# View operations
kubectl get pods -n nvo
kubectl logs -f deployment/nvo-network -n nvo
kubectl describe pod <pod-name> -n nvo
kubectl get events -n nvo

# With cluster aliases (loaded by tkl)
kn get pods           # kubectl -n nvo get pods
kc get pods           # kubectl -n common get pods
km get pods           # kubectl -n monitoring get pods
```

### Common Alias Mappings

| Alias | Expands To |
|-------|------------|
| `kn` | `kubectl -n nvo` |
| `kc` | `kubectl -n common` |
| `km` | `kubectl -n monitoring` |
| `kd` | `kubectl -n xcd` |

## Middleware Debug Pod

Access Kafka, Postgres, and other middleware from inside the cluster.

```bash
# Login to cluster first
tkl va-rdc

# Launch debug pod
tkl debug
```

**For complete Kafka/Postgres operations**: See [debug-pod.md](debug-pod.md)

## Database Access via Teleport

```bash
# List available databases
tsh db ls

# Connect interactively
tsh db connect <db-name> --db-user=postgres --db-name=nvo_db

# Get connection info
tsh db config <db-name>
```

## Multi-Cluster Health Checks

```bash
# Check all prod clusters
check_nvo_pods_rdc prod

# Check specific clusters
check_nvo_pods_rdc fra-rdc jp-rdc va-rdc
```

## Quick Reference

| Task | Command |
|------|---------|
| Login to cluster | `tkl <cluster-name>` |
| List clusters | `tsh kube ls` |
| Check status | `tsh status` |
| Switch to local k3s | `tkl k3s` |
| Start debug pod | `tkl debug` |
| List databases | `tsh db ls` |
| Check RDC health | `check_nvo_pods_rdc <env>` |

## Common Mistakes

| Issue | Fix |
|-------|-----|
| Expired session | `tsh login --proxy=extreme-cloud.teleport.sh` |
| Wrong kubeconfig | `export KUBECONFIG=~/.kube/config` |
| Missing aliases | Re-run `tkl <cluster-name>` |
| Cluster not found | Append `-rdc`/`-gdc` suffix (e.g., `stage-va` → `stage-va-rdc`) |
| Partial cluster name | Run `tsh kube ls \| grep -i <name>` to find exact name |

**For full troubleshooting guide**: See [troubleshooting.md](troubleshooting.md)

## Architecture

```
User Machine                    Teleport Proxy                   K8s Cluster
     |                               |                               |
     |-- tsh kube login cluster ---->|                               |
     |<-- kubeconfig updated --------|                               |
     |                               |                               |
     |-- kubectl get pods ---------->|-- proxy to K8s API ---------->|
     |<-- pod list ------------------|<-- response ------------------|
```

## Debugging Workflow

1. **Login to cluster:** `tkl <cluster-name>`
2. **Check pod status:** `kn get pods`
3. **View logs:** `kn logs -f <pod-name>`
4. **For middleware issues:** `tkl debug` → See [debug-pod.md](debug-pod.md)
5. **For database issues:** `tsh db connect` for direct access
