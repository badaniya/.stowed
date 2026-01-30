# NG-AIO Troubleshooting Reference

Comprehensive troubleshooting guide for NG-AIO deployment issues.

## Table of Contents

1. [Kafka Configuration Issues](#kafka-configuration-issues)
2. [Database Fixes](#database-fixes)
3. [Device Onboarding Issues](#device-onboarding-issues)
4. [Pod Crash/OOM Issues](#pod-crashoom-issues)
5. [Login/Authentication Issues](#loginauthentication-issues)
6. [Nginx/Ingress Issues](#nginxingress-issues)
7. [Licensing Issues](#licensing-issues)
8. [Debezium Issues](#debezium-issues)
9. [Device Firmware Management](#device-firmware-management)

---

## Kafka Configuration Issues

### Helm-git-opts replica/broker count mismatch

**Symptom**: Kafka topics fail to create due to replication factor mismatch.

**Fix** (from Hengwen):

Edit both files:
- `/root/oss-aioConfig/rdc/environments/edge/<cluster>/nvo/nvo-kafka-values.yaml`
- `/root/oss-orchestrator/rdc/environments/edge/<cluster>/nvo/nvo-kafka-values.yaml`

Append:

```yaml
nvo-kafka-gitops:
 kafka-gitops:
  DEFAULT_PARTITIONS: &DEFAULT_PARTITIONS 1
  DEFAULT_REPLICATION: &DEFAULT_REPLICATION 1
  configmap:
    topics:
      NVOAPP_DEVICE:
        partitions: *DEFAULT_PARTITIONS
        replication: *DEFAULT_REPLICATION
      NVOAPP_SERVICE:
        partitions: *DEFAULT_PARTITIONS
        replication: *DEFAULT_REPLICATION
      NVOAPP_DEVICE_ONBOARD:
        partitions: *DEFAULT_PARTITIONS
        replication: *DEFAULT_REPLICATION
      NVOAPP_WEBSOCKETS:
        partitions: *DEFAULT_PARTITIONS
        replication: *DEFAULT_REPLICATION
      NVOAPP_LOGGING:
        partitions: *DEFAULT_PARTITIONS
        replication: *DEFAULT_REPLICATION
      NVOAPP_INFRA:
        partitions: *DEFAULT_PARTITIONS
        replication: *DEFAULT_REPLICATION
      NVOAPP_WIRED_DEVICE_CONNECT:
        partitions: *DEFAULT_PARTITIONS
        replication: *DEFAULT_REPLICATION
```

Sync:

```bash
cd ~/oss-orchestrator/rdc
helmfile -e <cluster>r1 -l name=nvo-kafka-gitops diff --context=1 --set global.hmVersion=24.5.41
```

### Kafka Memory Utilization (from Hengwen)

**Symptom**: Kafka pods consume too much memory, causing OOM.

Edit four files:
- `/root/oss-aioConfig/rdc/environments/edge/<cluster>/common-kafka-values.yaml`
- `/root/oss-orchestrator/rdc/environments/edge/<cluster>/common-kafka-values.yaml`
- `/root/oss-aioConfig/rdc/environments/edge/<cluster>/nvo/nvo-kafka-values.yaml`
- `/root/oss-orchestrator/rdc/environments/edge/<cluster>/nvo/nvo-kafka-values.yaml`

Change:

```yaml
# From
- name: KAFKA_HEAP_OPTS
  value: -Xmx8G -Xms8G
resources:
  limits:
    cpu: 1200m
    memory: 12Gi
  requests:
    cpu: "1"
    memory: 8Gi

# To
- name: KAFKA_HEAP_OPTS
  value: -Xmx1G -Xms1G
resources:
  limits:
    cpu: 500m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

Sync:

```bash
cd ~/oss-orchestrator/rdc
helmfile -e <cluster>r1 -l name=common-kafka -l name=nvo-kafka diff --context=1
helmfile -e <cluster>r1 -l name=common-kafka -l name=nvo-kafka destroy
helmfile -e <cluster>r1 -l name=common-kafka -l name=nvo-kafka sync
```

---

## Database Fixes

### Device-Connector Liquibase Parameters (from Frederico)

**Symptom**: device-connector pod fails to start due to missing liquibase config.

Edit both files:
- `/root/oss-aioConfig/rdc/environments/edge/<cluster>/commonsvcs.yaml`
- `/root/oss-orchestrator/rdc/environments/edge/<cluster>/commonsvcs.yaml`

Append to device-connector springboot section:

```yaml
device-connector:
  springboot:
    appConf:
      spring.liquibase.password: aerohive123
      spring.liquibase.url: jdbc:postgresql://dcsdbhost:5432/dcs_db
      spring.liquibase.user: dcsuser1
```

Sync:

```bash
cd ~/oss-orchestrator/rdc
helmfile -e <cluster>r1 -l name=device-connector diff --context=1 --set global.hmVersion=24.5.41
helmfile -e <cluster>r1 -l name=device-connector destroy
helmfile -e <cluster>r1 -l name=device-connector sync --set global.hmVersion=24.5.41
```

### Debezium Missing hm_stack_member Publication

**Symptom**: Device stack member changes not propagating.

Edit both files:
- `/root/oss-aioConfig/rdc/environments/edge/<cluster>/k3s/debezium-telemetry-init.sql`
- `/root/oss-orchestrator/rdc/environments/edge/<cluster>/k3s/debezium-telemetry-init.sql`

Add:

```sql
ALTER TABLE PUBLICATION dbz_publication ADD TABLE hm_stack_member;
ALTER TABLE hm_stack_member REPLICA IDENTITY FULL;
```

Sync:

```bash
cd ~/oss-orchestrator/rdc
helmfile -e <cluster>r1 -l name=debezium-telemetry diff --context=1
helmfile -e <cluster>r1 -l name=debezium-telemetry destroy
helmfile -e <cluster>r1 -l name=debezium-telemetry sync
```

### Drop and Recreate NVO Database

```bash
# Drop
k -n gdc exec -it gdc-postgresql-ha-postgresql-0 -- bash -c "export PGPASSWORD=aerohive; psql -h localhost -U postgres -c 'drop database nvo_db with (force)'"

# Recreate with runonce
export CLUSTER_NAME="<cluster-name>"
cd /root/oss-orchestrator/rdc
NVO_VERSION=$(cat environments/edge/${CLUSTER_NAME}r1/nvo/nvoChartVersion.yaml | awk '/nvo-job-runonce/ {print $2}')
helmfile -e ${CLUSTER_NAME}r1 -l name=nvo-schema sync --set global.hmVersion=EII-3.3.0
helmfile -e ${CLUSTER_NAME}r1 -l name=nvo-job-runonce sync --set image.tag=${NVO_VERSION} --set databaseImage.tag=${NVO_VERSION} --set liquibaseImage.tag=${NVO_VERSION}
```

### Subscription-Activation Missing CUID (from Roshan)

**Symptom**: Subscription activation fails with missing CUID.

Run SQL in accountdb:

```sql
INSERT INTO cuid_license_info 
        (id, created_at, updated_at, key_name, available_quantity, contract_number, cuid, end_date, license_key, license_type, product_feature, start_date ) VALUES 
(10000, NOW(), NOW(),'MASTER_KEY_A', 10000, '5-01673106', '070924DW6LZWby6FSGuYkj', '2040-07-01 00:00:00', 'c567473d-cd85-400c-860b-e5e2909da902.ff19c586-e521-43ba-975b-7bd341829c0c',' ' , 'PRD-EP1-STD-TD-S-C', '2025-07-01 00:00:00' );
```

---

## Device Onboarding Issues

### Unknown Failure on Onboarding

**Symptom**: Device onboarding fails with "Unknown failure".

**Cause**: NG-AIO shouldn't use redirector DB for onboarding.

Edit both files:
- `/root/oss-aioConfig/rdc/environments/edge/<cluster>/tomcat.yaml`
- `/root/oss-orchestrator/rdc/environments/edge/<cluster>/tomcat.yaml`

Add:

```yaml
hmweb:
  webapp:
    nms-properties:
      Overrides:
        device.onboarding.verify_via_redirector: "false"
```

Sync:

```bash
cd ~/oss-orchestrator/rdc
helmfile -n xiq -e <cluster>r1 -l name=hmweb sync --set global.hmVersion=24.6.0.74
```

---

## Pod Crash/OOM Issues

### hm-ignite-0 and hm-elastic-0 CrashLoopBackOff

**Symptom**: Pods stuck in CrashLoopBackOff.

**Fix**:

```bash
cat << EOF >> /etc/security/limits.conf
soft nproc 4096
hard nproc 4096
EOF

reboot
```

### Device-Connector OOM

Edit `/root/oss-orchestrator/rdc/environments/edge/<cluster>/commonsvcs.yaml`:

Change device-connector memory limit from 500Mi to 1Gi.

```bash
helmfile -e <cluster>r1 -l name=device-connector sync --set global.hmVersion=25.7.0-100
```

### TaskEngine Allocator (teall) OOM

Edit `/root/oss-orchestrator/rdc/environments/edge/<cluster>/taskengine.yaml`:

Change teall memory limit from 3Gi to 5Gi.

```bash
helmfile -e <cluster>r1 -l name=teall sync --set global.hmVersion=25.7.0-100
```

---

## Login/Authentication Issues

### MSP Login Failure

**Symptom**: MSP users can't log in.

Edit both files:
- `/root/oss-aioConfig/portal/environments/edge/<cluster>-portal/app.yaml`
- `/root/oss-orchestrator/portal/environments/edge/<cluster>-portal/app.yaml`

Change:

```yaml
# From
spring.redis.cluster.nodes: null

# To
spring.data.redis.cluster.nodes: null
```

Sync:

```bash
cd ~/oss-orchestrator/portal
helmfile -e <cluster>-portal -l name=acsportal diff --context=1 --set global.hmVersion=24.6.0.74
helmfile -e <cluster>-portal -l name=acsportal destroy
helmfile -e <cluster>-portal -l name=acsportal sync --set global.hmVersion=24.6.0.74
```

### IAM Service CrashLoopBackOff (from Avinash)

**Symptom**: iam-acct-gateway and iam-svc-gateway in CrashLoopBackOff.

**Fix**: Update nginx-acct chart version from ~3.9.0 to ~3.10.0 in:
`/root/oss-orchestrator/gdc/environments/edge/<cluster>/chartVersion.yaml`

---

## Nginx/Ingress Issues

### Workspace UI Version Mismatch

**Symptom**: Redeploy-Workspace-UI Jenkins Pipeline doesn't update versions.

Edit both files:
- `/root/oss-aioConfig/gdc/environments/edge/<cluster>/nginx.yaml`
- `/root/oss-orchestrator/gdc/environments/edge/<cluster>/nginx.yaml`

Update version numbers to match deployed versions.

Pin nginx-cloudapi version in chartVersion.yaml:

```yaml
chartVersion:
  nginx-cloudapi: 3.4.4
```

Sync:

```bash
cd ~/oss-orchestrator/gdc
helmfile -e <cluster> -l name=nginx-ws -l name=nginx-cloudapi diff --context=1 --set global.hmVersion=24.3.7
helmfile -e <cluster> -l name=nginx-ws -l name=nginx-cloudapi destroy
helmfile -e <cluster> -l name=nginx-ws -l name=nginx-cloudapi sync --set global.hmVersion=24.3.7
```

### Fix Workspace Nginx Ingress

```bash
cd /root/oss-orchestrator/gdc
export cluster="<cluster>"
helm repo update
helmfile -e $cluster -l name=tls-secret sync
helmfile -e $cluster -l name=common-ingress sync
helmfile -e $cluster -l name=ws-ingress sync
helmfile -e $cluster -l name=cloudapi-ingress sync
helmfile -e $cluster -l name=default-ingress-nginx sync
helmfile -e $cluster -l name=nginx-cloudapi sync
```

---

## Licensing Issues

### License Service ImagePullBackOff

**Symptom**: xcloudiq-license-mgmt has ImagePullBackOff.

**Fix**:

```bash
cd /root/oss-orchestrator/gdc
export cluster="<cluster>"
helmfile -e $cluster -l name=xcloudiq-license-scheduler -l name=xcloudiq-license-mgmt sync --set global.hmVersion=25.2.0.130
```

### C9 License Update (from Avinash)

Edit both files:
- `/root/oss-aioConfig/gdc/environments/edge/<cluster>/app.yaml`
- `/root/oss-orchestrator/gdc/environments/edge/<cluster>/app.yaml`

Add:

```yaml
xcloudiq-license-mgmt:
   springboot:
      replicaCount: 1
      appConf:
            use.lem.middleware.license.server: false
```

Sync:

```bash
cd /root/oss-orchestrator/gdc/
helmfile -n gdc -e $cluster -l name=xcloudiq-license-mgmt sync --set global.hmVersion=${XIQ_VERSION}
```

---

## Device Firmware Management

### Download and Copy Device Firmware

[NOS Firmware Images](http://iq-release.iq.extremenetworks.com)

```bash
# Copy to NG-AIO
scp 5420.9.3.0.0.voss* root@<ng-aio-ip>:/data/nfs/xiq-efs-fileserver-pv/hiveos/images/
scp summit_arm-33.5.1.6.xos* root@<ng-aio-ip>:/data/nfs/xiq-efs-fileserver-pv/hiveos/images/
```

### Verify Firmware Metadata

```sql
-- Connect to systemdb
SELECT * FROM hm_device_image_metadata;
```

The teall service's periodic job picks up new firmware images automatically.
