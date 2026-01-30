# Middleware Debug Pod

Access Kafka, Postgres, and other middleware from inside the cluster. This is the **ONLY** way scrum teams can exec into a container.

## Contents

- [Warnings](#warnings)
- [Starting Debug Session](#starting-debug-session)
- [Available Tools](#tools-available-in-debug-pod)
- [Kafka Operations](#kafka-operations)
- [Postgres Operations](#postgres-operations)

## Warnings

- **All activities are monitored and recorded**
- **User privileges are strictly limited to read-only access**
- **Pod auto-terminates in 2 hours** to save resources
- **Pod auto-terminates when you exit** the container
- **Any attempt to modify/delete data without documented approval is a violation**

## Starting Debug Session

```bash
# Login to cluster first
tkl va-rdc

# Launch debug pod (or exec into existing)
tkl debug

# Alternative: tkl qadebug (uses hardcoded image version)
tkl qadebug
```

**What debug does:**
1. Creates `debug` namespace if missing
2. Creates pod named `<username>-middleware-debug-pod`
3. Uses `middleware-access-util` image with pre-installed tools
4. Opens interactive bash session

## Tools Available in Debug Pod

| Tool | Purpose |
|------|---------|
| `psql` | PostgreSQL client |
| `curl`, `wget` | HTTP requests |
| `jq` | JSON processing |
| `nc`, `telnet` | Network connectivity testing |
| `openssl` | TLS/SSL debugging, certificate inspection |
| `vi` | Text editor (note: `vim`/`nano` not available) |
| Standard utilities | `grep`, `awk`, `sed`, `cat`, `less`, `head`, `tail`, `sort`, `uniq`, `wc`, `tr`, `cut`, `xargs`, `find`, `base64` |
| File operations | `ls`, `cp`, `mv`, `rm`, `mkdir`, `touch`, `chmod`, `chown` |
| System info | `env`, `printenv`, `date`, `hostname`, `df`, `du` |

**Not available:** `dig`, `nslookup`, `ping`, `host`, `traceroute`, `nmap`, `vim`, `nano`, `which`

Type `helps` inside debug pod to list all available wrapper commands.

---

## Kafka Operations

**Use the wrapper commands below for Kafka operations.**

### Available Kafka Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `list_clusters` | List all configured Kafka clusters | `list_clusters` |
| `list_topics` | List Kafka topics | `list_topics [--exclude-internal [true\|false]] [--cluster <name>]` |
| `list_groups` | List all Kafka consumer groups | `list_groups [--cluster <name>]` |
| `describe_topic` | Describe a specific Kafka topic | `describe_topic <topic_name> [--cluster <name>]` |
| `describe_group` | Describe a specific consumer group | `describe_group <group_name> [--cluster <name>]` |
| `consume_topic` | Consume messages from a topic | `consume_topic <topic_name> [options]` |
| `get_offsets` | Get offsets for a topic | `get_offsets <topic_name> [--cluster <name>]` |
| `check_lag` | Check consumer lag for a group | `check_lag <group_name> [--cluster <name>]` |
| `verify_replicas` | Verify replicas for a topic | `verify_replicas <topic_name> [--cluster <name>]` |

### consume_topic Options

```
consume_topic <topic_name> [--cluster <cluster_name>] [--from-beginning]|[--offset <offset> --partition <partition>] [--max-messages <number>]
```

| Option | Description |
|--------|-------------|
| `--from-beginning` | Start consuming from the earliest message |
| `--max-messages <n>` | Limit number of messages returned |
| `--offset <n> --partition <p>` | Consume from specific offset and partition |
| `--cluster <name>` | Specify non-default Kafka cluster |

### Common Kafka Examples

```bash
# List all topics
list_topics

# Filter topics by name pattern
list_topics | grep -i device-connect

# Consume 5 messages from beginning of topic
consume_topic device-connect-events --from-beginning --max-messages 5

# Consume from specific offset/partition
consume_topic my-topic --offset 100 --partition 0

# Check consumer group lag
check_lag my-consumer-group

# Describe topic configuration and partitions
describe_topic device-connect-events

# Get current offsets for a topic
get_offsets device-connect-events

# List available Kafka clusters
list_clusters
```

### Key Notes

- **Without `--from-beginning`**, `consume_topic` waits for NEW messages (will hang if no activity)
- All commands return **JSON output** for easy parsing
- Use `--cluster <name>` when targeting a non-default cluster
- Use `-h` or `--help` on any command to see usage

---

## Postgres Operations

```bash
# Use pre-defined aliases (type 'helps' to list all)
psql_nvodbhost        # Connect to NVO database
psql_commondbhost     # Connect to common database
update_dbalias        # Update all available database aliases
```

### Manual Connection

```bash
PGHOST=$(kubectl get svc nvodbhost -n nvo -o jsonpath='{.spec.externalName}')
PGPASSWORD=<password> psql -h $PGHOST -U postgres -d nvo_db
```

### ⚠️ CRITICAL: Always Use WHERE Conditions

```sql
-- ✅ GOOD: Specific query with WHERE condition
SELECT * FROM devices WHERE id = 12345;
SELECT count(*) FROM events WHERE created_at > NOW() - INTERVAL '1 hour';

-- 🚫 BAD: Full table scan - can crash production DB!
-- SELECT * FROM devices;           -- NEVER do this!
-- SELECT * FROM large_table;       -- Will overload database
```

### Safe Operations

```bash
\dt                    # List tables
\d+ table_name         # Describe table
SELECT count(*) FROM devices;  # Count is OK
```

### Common Database Aliases

| Alias | Database | Common Tables |
|-------|----------|---------------|
| `psql_cs-platformdbhost` | platform_common_db | inferred_device, inferred_interface, asset_device |
| `psql_nvodbhost` | nvo_db | NVO-specific tables |
| `psql_systemdbhost` | system_db | System configuration |
| `psql_configdbhost1` | config_db | Configuration data |
