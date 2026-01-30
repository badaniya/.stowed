# Testbed Database Hosts

Aurora RDS endpoints for each cloud testbed.

## Database Connection Patterns

### nvo_db (NVO Application Database)

Connect as `nvouser` with password `aerohive123`:

```bash
PGPASSWORD=aerohive123 psql -h <aurora-host> -U nvouser nvo_db
```

Or via kubectl exec into postgres pod:

```bash
kubectl -n nvo exec -it postgresql-ha-postgresql-0 -- /bin/bash -c "PGPASSWORD=aerohive123 psql -U nvouser nvo_db -P pager=off"
```

### platform_common_db (Platform Common Database)

Connect as `postgres` with password `aerohive`:

```bash
PGPASSWORD=aerohive psql -h <aurora-host> -U postgres platform_common_db
```

## Known Aurora Endpoints

| Testbed | Aurora Endpoint | Region |
|---------|-----------------|--------|
| ws4r1 | `aurora-ws4r1.cluster-ciwa6umsjipp.us-east-2.rds.amazonaws.com` | us-east-2 |
| st2r1 | `aurora-st2r1.cluster-crg8mk08o8lx.us-west-2.rds.amazonaws.com` | us-west-2 |
| st2r2 | `aurora-st2r2.cluster-cb0s8ose8cyx.us-east-2.rds.amazonaws.com` | us-east-2 |

For other testbeds, get the hostname dynamically:

```bash
get_nvo_cloud_db_host <testbed>
# Example: get_nvo_cloud_db_host nvo1r1
```

## Key Tables

### platform_common_db

| Table | Description |
|-------|-------------|
| `inferred_device` | Discovered devices |
| `inferred_interface` | Device interfaces |
| `asset_device` | Asset inventory |
| `discovery_event` | Discovery activity log |

### nvo_db

| Table | Description |
|-------|-------------|
| `device` | NVO device records |
| `site` | Site definitions |
| `fabric` | Fabric configurations |

## Query Safety

**ALWAYS use WHERE conditions** to avoid full table scans:

```sql
-- GOOD
SELECT * FROM inferred_device WHERE serial_number = 'ABC123';
SELECT count(*) FROM discovery_event WHERE created_at > NOW() - INTERVAL '1 hour';

-- BAD (will overload database)
SELECT * FROM inferred_device;
```

## Credentials Reference

| Database | User | Password |
|----------|------|----------|
| nvo_db | nvouser | aerohive123 |
| platform_common_db | postgres | aerohive |
