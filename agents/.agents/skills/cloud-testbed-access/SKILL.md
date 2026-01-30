---
name: cloud-testbed-access
description: |
  Access AWS-hosted cloud testbeds (ws1-4, nvo1-2, g2, dl1, cit, st2, etc.) via SSH jumphost for debugging NVO services. Provides multi-pane tmux sessions with console access, Postgres queries, Kafka monitoring, pod health checks, DB dump extraction, and pprof collection.

  Use when:
  - User asks to connect to a cloud testbed (ws3r1, nvo1r1, cit2r1, etc.)
  - User needs to query Postgres on a testbed (Aurora RDS)
  - User wants to check Kafka consumer lag on a testbed
  - User needs to extract database dumps from testbeds
  - User wants pprof heap/profile data from NVO services
  - User asks to check pod status across testbeds
  - User wants to start a tmuxinator session for a testbed

  Triggers: "cloud testbed", "ws4r1", "nvo1r1", "testbed postgres", "testbed kafka", "get db dump", "pprof data", "start_tmuxinator"
---

# Cloud Testbed Access

Access AWS-hosted NVO cloud testbeds via SSH jumphost. These testbeds run Kubernetes with NVO services and provide direct access to Aurora RDS (Postgres) and Kafka.

**Related skill**: For Teleport-based RDC/GDC clusters (va-rdc, fra-rdc, etc.), use the `teleport-kubernetes` skill instead.

## Contents

- [Quick Reference](#quick-reference)
- [Available Testbeds](#available-testbeds)
- [Connection Methods](#connection-methods)
- [Tmuxinator Sessions](#tmuxinator-sessions)
- [Postgres Operations](#postgres-operations)
- [Kafka Monitoring](#kafka-monitoring)
- [Pod Health Checks](#pod-health-checks)
- [DB Dump Extraction](#db-dump-extraction)
- [Pprof Collection](#pprof-collection)
- [AI Agent Direct Access](#ai-agent-direct-access-critical) ← **For programmatic access**

## Quick Reference

| Task | Command |
|------|---------|
| SSH to testbed | `ssh_nvo_cloud_testbed <testbed>` |
| Start tmux session | `start_tmuxinator cloud-testbed-<name>` |
| Stop tmux session | `stop_tmuxinator cloud-testbed-<name>` |
| Get DB dump | `get_nvo_cloud_db_dump <testbed> <destination>` |
| Get pprof data | `get_nvo_cloud_pprof_data <testbed> <service> <destination>` |
| Check pod health | Via tmuxinator session (watch command) |

## Available Testbeds

### Cloud Testbed Naming Convention

| Prefix | Description | Console Host |
|--------|-------------|--------------|
| `ws1`-`ws4` | Workstation testbeds | `ws4-console.qa.xcloudiq.com` |
| `ws1r1`-`ws4r1` | Workstation RDC region | `ws4r1-console.qa.xcloudiq.com` |
| `nvo1`, `nvo2` | NVO dedicated testbeds | `nvo1-console.qa.xcloudiq.com` |
| `nvo1r1`, `nvo2r1` | NVO RDC regions | `nvo1r1-console.qa.xcloudiq.com` |
| `g2`, `g2r1` | G2 testbed | `g2r1-console.qa.xcloudiq.com` |
| `dl1`, `dl1r1` | DL1 testbed | `dl1r1-console.qa.xcloudiq.com` |
| `cit`, `citr2`, `cit2r1` | CIT testbeds | `cit-console.qa.xcloudiq.com` |
| `st2r1`, `st2r2` | ST2 multi-region | `st2r1-console.qa.xcloudiq.com` |
| `cp8` | CP8 testbed | `cp8-console.qa.xcloudiq.com` |
| `lab1` | Lab1 testbed | `lab1-console.qa.xcloudiq.com` |

### Tmuxinator Configs Available

Located at `~/.private-cloud-testbed-<name>.yml`:

```
cloud-testbed-ws1    cloud-testbed-ws2    cloud-testbed-ws3    cloud-testbed-ws4
cloud-testbed-nvo1   cloud-testbed-nvo2   cloud-testbed-g2     cloud-testbed-dl1
cloud-testbed-cit    cloud-testbed-cit2   cloud-testbed-st2    cloud-testbed-cp8
cloud-testbed-lab1

# Kafka lag variants
cloud-testbed-ws2-kafka-lag  cloud-testbed-ws3-kafka-lag
cloud-testbed-ws4-kafka-lag  cloud-testbed-g2-kafka-lag
cloud-testbed-dl1-kafka-lag
```

## Connection Methods

### SSH to Cloud Testbed

```bash
# Basic SSH connection
ssh_nvo_cloud_testbed <testbed> [options]

# Examples
ssh_nvo_cloud_testbed ws4r1                    # Interactive shell
ssh_nvo_cloud_testbed ws4r1 -t 'sudo -i'       # Root shell
ssh_nvo_cloud_testbed nvo1r1 -t 'kubectl -n nvo get pods'  # Run command
```

**How it works**: Uses SSH key (`~/.ssh/2026-01-08_id_ed25519`) via AWS jumphost (`usnc-awsgtwy-02.extremenetworks.com`) to reach `<testbed>-console.qa.xcloudiq.com`.

### SCP File Transfer

```bash
# Copy FROM testbed
scp_from_nvo_cloud_testbed <testbed> <source> <destination>

# Copy TO testbed
scp_to_nvo_cloud_testbed <testbed> <source> <destination>

# Examples
scp_from_nvo_cloud_testbed ws4r1 /var/log/nvo/network/network.log ./
scp_to_nvo_cloud_testbed nvo1r1 ./config.yaml /tmp/
```

## Tmuxinator Sessions

Start pre-configured multi-pane sessions with console access, pod watching, and database connections.

### Start/Stop Sessions

```bash
# Start a testbed session
start_tmuxinator cloud-testbed-ws4

# Stop a testbed session
stop_tmuxinator cloud-testbed-ws4
```

### Session Layout (Typical)

Each tmuxinator session creates windows with these panes:

**Window: g1-console (GDC panes)**
- Pane 1: Pod watch (`kubectl -n <gdc-ns> get pods`)
- Pane 2: Interactive root shell

**Window: r1-console (RDC panes)**
- Pane 1: Pod/resource watch (`kubectl -n nvo get pods; kubectl -n nvo top pods`)
- Pane 2-3: Interactive root shells
- Pane 4: nvo_db Postgres session
- Pane 5: platform_common_db Postgres session

**Window: notes** - Nvim for notes

**Window: test** - Empty shell for testing

### Kafka Lag Variants

For Kafka consumer lag monitoring:

```bash
start_tmuxinator cloud-testbed-ws4-kafka-lag
```

Adds panes with:
- Common Kafka consumer group monitoring
- NVO Kafka consumer group monitoring (filtered by topic)

## Postgres Operations

### Connection Details

| Testbed | DB Host Pattern | Databases |
|---------|-----------------|-----------|
| ws4r1 | `aurora-ws4r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com` | nvo_db, platform_common_db |
| st2r1 | `aurora-st2r1.cluster-crg8mk08o8lx.us-west-2.rds.amazonaws.com` | nvo_db, platform_common_db |
| (other) | `aurora-<testbed>.cluster-*.rds.amazonaws.com` | nvo_db, platform_common_db |

### Connect via Tmuxinator

The tmuxinator sessions auto-connect to databases:

```bash
# nvo_db (nvouser)
PGPASSWORD=aerohive123 psql -U nvouser nvo_db

# platform_common_db (postgres user)
PGPASSWORD=aerohive psql -h aurora-<testbed>.cluster-*.rds.amazonaws.com -U postgres platform_common_db
```

### Get DB Host Programmatically

```bash
# Get Aurora DB hostname
get_nvo_cloud_db_host ws4r1
# Returns: aurora-ws4r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com
```

### Common Queries

```sql
-- Always use WHERE conditions!

-- Count devices
SELECT count(*) FROM inferred_device WHERE deleted_at IS NULL;

-- Device by serial
SELECT * FROM inferred_device WHERE serial_number = 'ABC123';

-- Recent discovery events
SELECT * FROM discovery_event WHERE created_at > NOW() - INTERVAL '1 hour' LIMIT 50;
```

## Kafka Monitoring

### Via Tmuxinator Session

The kafka-lag variants show consumer group lag in real-time:

```bash
start_tmuxinator cloud-testbed-ws4-kafka-lag
```

Shows:
- `common-kafka-0` consumer groups (common namespace)
- `nvo-kafka-0` consumer groups (nvo namespace)

### Manual Kafka Commands

```bash
# SSH to testbed and run kafka commands
ssh_nvo_cloud_testbed ws4r1 -t 'sudo -i'

# List consumer groups
kubectl -n common exec -it common-kafka-0 -- /bin/bash -c "unset JMX_PORT; /opt/bitnami/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list"

# Describe consumer group lag
kubectl -n common exec -it common-kafka-0 -- /bin/bash -c "unset JMX_PORT; /opt/bitnami/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group network"

# Filter by topic
kubectl -n nvo exec -it nvo-kafka-0 -- /bin/bash -c "unset JMX_PORT; /opt/bitnami/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group network | grep -e TOPIC -e NVOAPP_DEVICE_ONBOARD"
```

## Pod Health Checks

### Via Tmuxinator Session

All tmuxinator sessions include a pane with:

```bash
watch "kubectl -n nvo get pods; kubectl -n nvo top pods"
```

### Check Multiple Testbeds (RDC)

For Teleport-accessible RDC clusters, use:

```bash
check_nvo_pods_rdc prod              # All prod RDC clusters
check_nvo_pods_rdc fra-rdc jp-rdc    # Specific clusters
```

**Note**: `check_nvo_pods_rdc` is for Teleport clusters. For SSH testbeds, use tmuxinator or manual SSH.

## DB Dump Extraction

### Get Database Dump

```bash
get_nvo_cloud_db_dump <testbed> <destination>

# Example
get_nvo_cloud_db_dump ws4r1 /tmp/
```

**What it does**:
1. Connects to testbed via SSH
2. Gets Aurora DB hostname
3. Runs `pg_dump` for both nvo_db and platform_common_db
4. SCPs dump files to local destination
5. Cleans up remote files

**Output files**:
- `database_dump_<testbed>_nvo_db_<timestamp>.sql`
- `database_dump_<testbed>_platform_common_db_<timestamp>.sql`

### Restore in Local Docker

```bash
# Copy dumps to docker container
copy_nvo_db_dump_to_docker_db /tmp/database_dump_ws4r1*.sql

# Create required roles
create_nvo_db_dump_user_roles_in_docker

# Restore dumps
restore_nvo_db_dump_in_docker "database_dump_ws4r1*.sql"
```

### Full Workflow (Get + Restore)

```bash
get_nvo_cloud_db_dump_and_restore_in_docker ws4r1
```

## Pprof Collection

### CRITICAL: Pprof Port Information

**NVO services expose pprof on port 8081, NOT the default 6060.**

| Service | Pprof Endpoint | Health Endpoint |
|---------|----------------|-----------------|
| nvo-network | `http://localhost:8081/debug/pprof/` | `http://localhost:8081/nvo/v1/health` |
| nvo-edge | `http://localhost:8081/debug/pprof/` | `http://localhost:8081/nvo/v1/health` |
| nvo-system | `http://localhost:8081/debug/pprof/` | `http://localhost:8081/nvo/v1/health` |
| nvo-scheduler | `http://localhost:8081/debug/pprof/` | `http://localhost:8081/nvo/v1/health` |

### Get Pprof Data (Shell Function)

```bash
get_nvo_cloud_pprof_data <testbed> <service> <destination>

# Examples
get_nvo_cloud_pprof_data ws4r1 network /tmp/
get_nvo_cloud_pprof_data nvo1r1 edge /tmp/
get_nvo_cloud_pprof_data ws4r1 system /tmp/
```

**Services**: `network`, `edge`, `system`, `scheduler`

**Output files**:
- `pprof_<testbed>_heap_<pod>_<timestamp>.out`
- `pprof_<testbed>_profile_<pod>_<timestamp>.out`

### Analyze Pprof Data

```bash
analyze_pprof pprof_ws4r1_heap_nvo-network-abc123_2025-01-29.out
# Opens browser at http://localhost:8080 with pprof UI
```

### AI Agent Pprof Collection (CRITICAL)

**Port 6060 does NOT work** - NVO services use port 8081 for pprof.

**Step 1: Get pod name**
```bash
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J $USER@usnc-awsgtwy-02.extremenetworks.com \
    $USER@<testbed>-console.qa.xcloudiq.com \
    "sudo kubectl -n nvo get pods | grep nvo-network | head -1 | awk '{print \$1}'"
```

**Step 2: Collect heap profile (exec into pod, use port 8081)**
```bash
ssh ... "sudo kubectl -n nvo exec <POD_NAME> -c main -- sh -c 'wget -q -O /tmp/heap.out http://localhost:8081/debug/pprof/heap && echo Heap saved'"
```

**Step 3: Collect CPU profile (30 seconds)**
```bash
ssh ... "sudo kubectl -n nvo exec <POD_NAME> -c main -- sh -c 'wget -q -O /tmp/profile.out \"http://localhost:8081/debug/pprof/profile?seconds=30\" && echo CPU profile saved'"
```

**Step 4: Copy files to console host**
```bash
ssh ... "sudo kubectl -n nvo cp <POD_NAME>:/tmp/heap.out /tmp/pprof_heap_<POD_NAME>.out -c main"
ssh ... "sudo kubectl -n nvo cp <POD_NAME>:/tmp/profile.out /tmp/pprof_profile_<POD_NAME>.out -c main"
```

**Step 5: Fix permissions and SCP to local**
```bash
ssh ... "sudo chmod 644 /tmp/pprof_*.out"

scp -o StrictHostKeyChecking=no -o ConnectTimeout=30 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J $USER@usnc-awsgtwy-02.extremenetworks.com \
    "$USER@<testbed>-console.qa.xcloudiq.com:/tmp/pprof_*.out" \
    /tmp/
```

### Complete Working Example (Verified January 2026)

Collect pprof from g2r1 nvo-network:
```bash
# Get pod name
POD=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J badaniya@usnc-awsgtwy-02.extremenetworks.com \
    badaniya@g2r1-console.qa.xcloudiq.com \
    "sudo kubectl -n nvo get pods | grep nvo-network | head -1 | awk '{print \$1}'" 2>/dev/null | tail -1)

# Collect heap
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J badaniya@usnc-awsgtwy-02.extremenetworks.com \
    badaniya@g2r1-console.qa.xcloudiq.com \
    "sudo kubectl -n nvo exec ${POD} -c main -- sh -c 'wget -q -O /tmp/heap.out http://localhost:8081/debug/pprof/heap'"

# Collect 30s CPU profile
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=90 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J badaniya@usnc-awsgtwy-02.extremenetworks.com \
    badaniya@g2r1-console.qa.xcloudiq.com \
    "sudo kubectl -n nvo exec ${POD} -c main -- sh -c 'wget -q -O /tmp/profile.out \"http://localhost:8081/debug/pprof/profile?seconds=30\"'"

# Copy to console, fix permissions, SCP locally
ssh ... "sudo kubectl -n nvo cp ${POD}:/tmp/heap.out /tmp/pprof_heap.out -c main && \
         sudo kubectl -n nvo cp ${POD}:/tmp/profile.out /tmp/pprof_profile.out -c main && \
         sudo chmod 644 /tmp/pprof_*.out"

scp ... "badaniya@g2r1-console.qa.xcloudiq.com:/tmp/pprof_*.out" /tmp/
```

### Pprof Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection refused` on port 6060 | Wrong port | Use port **8081** instead |
| `wget: can't connect to remote host` | Pprof not enabled or wrong port | Verify with `netstat -tlnp` in pod - should show 8081 |
| `Permission denied` on SCP | Files owned by root | Run `sudo chmod 644` on console host first |
| Empty profile file | Service not under load | For CPU profile, generate load or use longer duration |

## Environment Variables

These are set in `~/.private_zsh_functions.zsh`:

| Variable | Value | Description |
|----------|-------|-------------|
| `CLOUD_TESTBED_KEY` | `~/.ssh/2026-01-08_id_ed25519` | SSH key for testbed access |
| `CLOUD_JUMPHOST` | `usnc-awsgtwy-02.extremenetworks.com` | AWS jumphost |
| `DOCKER_DB_CONTAINER` | `infra-database` | Local docker postgres container |

## AI Agent Direct Access (CRITICAL)

**Shell functions like `ssh_nvo_cloud_testbed` are NOT available in non-interactive shells.**
AI agents MUST use direct SSH commands instead.

### Direct SSH Command Pattern

```bash
# Template - use this exact pattern
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J $USER@usnc-awsgtwy-02.extremenetworks.com \
    $USER@<testbed>-console.qa.xcloudiq.com \
    "<command>"
```

**Example:**
```bash
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J badaniya@usnc-awsgtwy-02.extremenetworks.com \
    badaniya@g2r1-console.qa.xcloudiq.com \
    "sudo kubectl -n nvo get pods"
```

### Database Query Pattern (CRITICAL - Follow Exactly)

**Step 1: Get DB host from configmap (DO NOT GUESS)**
```bash
ssh ... "<testbed>-console" "sudo kubectl -n nvo get cm db-init-env -o jsonpath='{.data.DBHOST}'"
```

**Step 2: Query the correct database**

| Data Type | Database | User | Password | Schema |
|-----------|----------|------|----------|--------|
| NVO application data (discovery events, configs) | `nvo_db` | `nvouser` | `aerohive123` | `public` |
| **Device/Asset data (inferred_device, asset_device, asset_device_connection_detail)** | `platform_common_db` | `postgres` | `aerohive` | `public` |

**CRITICAL**: Asset and device tables are in `platform_common_db`, NOT `nvo_db`!

**Step 3: Use psql directly on console (psql IS available on console hosts)**
```bash
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J $USER@usnc-awsgtwy-02.extremenetworks.com \
    $USER@<testbed>-console.qa.xcloudiq.com \
    "PGPASSWORD=aerohive psql -h <DB_HOST> -U postgres platform_common_db -c \"<SQL_QUERY>\""
```

**DO NOT exec into pods for psql** - network pods don't have psql installed.

### Known DB Hosts (Verified January 2026)

| Testbed | AWS Region | DB Host |
|---------|------------|---------|
| g2r1 | us-east-1 | `aurora-g2r1.cluster-cjwdlyjsvxif.us-east-1.rds.amazonaws.com` |
| ws3r1 | us-east-2 | `aurora-ws3r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com` |
| ws4r1 | us-east-2 | `aurora-ws4r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com` |
| st2r1 | us-west-2 | `aurora-st2r1.cluster-crg8mk08o8lx.us-west-2.rds.amazonaws.com` |

**If DB host is unknown**: Always get it from configmap first (Step 1).

### Pod Naming Convention

**NVO pods are Deployments, NOT StatefulSets:**
- ❌ Wrong: `nvo-network-0`, `nvo-edge-0`
- ✅ Correct: `nvo-network-<replicaset-hash>-<pod-id>` (e.g., `nvo-network-89f4fb44b-596pd`)

**To get pod names:**
```bash
ssh ... "sudo kubectl -n nvo get pods | grep network | head -1 | awk '{print \$1}'"
```

### Common Device/Asset Queries

**Tables in platform_common_db (public schema):**
- `inferred_device` - Device instances with MAC, serial, managed status
- `asset_device` - Asset info including `brand_name`
- `asset_device_connection_detail` - Connection info including `device_make`

**Compare brand_name vs device_make:**
```sql
SELECT ad.serial_number, ad.brand_name, adc.device_make 
FROM asset_device ad 
LEFT JOIN asset_device_connection_detail adc ON ad.id = adc.asset_device_id 
WHERE ad.deleted_at IS NULL 
LIMIT 20;
```

**Count by device_make and brand_name:**
```sql
SELECT adc.device_make, ad.brand_name, COUNT(*) as count 
FROM asset_device ad 
LEFT JOIN asset_device_connection_detail adc ON ad.id = adc.asset_device_id 
WHERE ad.deleted_at IS NULL 
GROUP BY adc.device_make, ad.brand_name 
ORDER BY count DESC;
```

**Find devices where brand_name ≠ device_make (bug scenarios):**
```sql
SELECT ad.serial_number, adc.device_model, ad.brand_name, adc.device_make 
FROM asset_device ad 
LEFT JOIN asset_device_connection_detail adc ON ad.id = adc.asset_device_id 
WHERE ad.deleted_at IS NULL 
  AND adc.device_make = 'Aerohive' 
  AND ad.brand_name = 'Extreme Networks' 
LIMIT 15;
```

### Complete Working Example

Query g2r1 for brand_name vs device_make data:
```bash
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    -i ~/.ssh/2026-01-08_id_ed25519 \
    -J badaniya@usnc-awsgtwy-02.extremenetworks.com \
    badaniya@g2r1-console.qa.xcloudiq.com \
    "PGPASSWORD=aerohive psql -h aurora-g2r1.cluster-cjwdlyjsvxif.us-east-1.rds.amazonaws.com -U postgres platform_common_db -c \"SELECT adc.device_make, ad.brand_name, COUNT(*) FROM asset_device ad LEFT JOIN asset_device_connection_detail adc ON ad.id = adc.asset_device_id WHERE ad.deleted_at IS NULL GROUP BY adc.device_make, ad.brand_name ORDER BY count DESC;\""
```

### Filtering SSH Output

Add `2>&1 | grep -v "warning\|WARNING\|Permanently\|Disconnect\|Authorized"` to filter noise:
```bash
ssh ... "command" 2>&1 | grep -v "warning\|WARNING\|Permanently\|Disconnect\|Authorized"
```

### Troubleshooting Checklist

| Error | Cause | Fix |
|-------|-------|-----|
| `ssh_nvo_cloud_testbed: command not found` | Shell function not available | Use direct SSH command pattern |
| `could not translate host name` | Wrong DB host (wrong region) | Get host from `db-init-env` configmap |
| `relation "asset_device" does not exist` | Wrong database | Use `platform_common_db` for asset tables |
| `relation "nvo.asset_device" does not exist` | Wrong schema | Tables are in `public` schema (no prefix needed) |
| `pods "nvo-network-0" not found` | Wrong pod naming | NVO uses Deployments, get pod name with kubectl |
| `can't execute 'psql': No such file or directory` | Tried psql in network pod | Run psql directly on console host |
| `Error from server (NotFound): secrets "nvo-db-secret" not found` | Wrong secret name | Use `db-init-env` configmap instead |
| `Connection refused` on pprof port 6060 | Wrong pprof port | NVO uses port **8081** for pprof, not 6060 |

## Troubleshooting

### SSH Connection Fails

```bash
# Check SSH key exists
ls -la ~/.ssh/2026-01-08_id_ed25519

# Test jumphost connectivity
ssh -i ~/.ssh/2026-01-08_id_ed25519 $USER@usnc-awsgtwy-02.extremenetworks.com
```

### Tmuxinator Session Won't Start

```bash
# Check config exists
ls ~/.private-cloud-testbed-ws4.yml

# Validate YAML
cat ~/.private-cloud-testbed-ws4.yml | yq .
```

### Postgres Connection Timeout

Aurora RDS is only accessible from within the testbed. Connect via SSH:

```bash
ssh_nvo_cloud_testbed ws4r1 -t 'PGPASSWORD=aerohive psql -h aurora-ws4r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com -U postgres platform_common_db'
```
