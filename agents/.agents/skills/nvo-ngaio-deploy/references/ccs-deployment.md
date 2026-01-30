# CCS (Metaflow) Manual Deployment Guide

Comprehensive guide for manually deploying CCS (Common Configuration Services / Metaflow) on NG-AIO.

Based on Pavan Adurai's deployment guide.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Preparation](#deployment-preparation)
4. [Helm Chart Configuration](#helm-chart-configuration)
5. [Database Setup](#database-setup)
6. [Deploy CCS Services](#deploy-ccs-services)
7. [Post-Deployment Steps](#post-deployment-steps)
8. [Remove CCS](#remove-ccs)

---

## Overview

CCS (Common Configuration Services) includes:
- **ConfigState**: Configuration state management
- **Tagging**: Device tagging service
- **Perfmonitor**: Performance monitoring
- **Metaflow**: Data processing pipelines (Numaflow-based)
  - Cache Updater
  - Telemetry Server
  - Event/Metric processors (high/medium/low priority)

---

## Prerequisites

1. NG-AIO with XIQ deployed
2. SSH access to NG-AIO console
3. Private build images available in GCR

Reference NG-AIO with changes: `sshpass -p aerohive ssh root@newcs1-c9g1-console.qa.xcloudiq.com`

---

## Deployment Preparation

### Step 0: Deploy XIQ (Optional)

If XIQ not deployed:

```bash
# Run Jenkins: Redeploy-XIQ
https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/Redeploy-XIQ/
```

Fix license service ImagePullErr if needed:

```bash
cd /root/oss-orchestrator/gdc
export cluster="<cluster>g1"
helmfile -e $cluster -l name=xcloudiq-license-scheduler -l name=xcloudiq-license-mgmt sync --set global.hmVersion=25.2.0.130
```

### Step 1: Add ngxcp to Environment

```bash
grep -q "ngxcp" /root/oss-orchestrator/rdc/env.yaml || echo '    - environments/edge/<cluster>r1/ngxcp/*.y*ml' >> /root/oss-orchestrator/rdc/env.yaml
```

Result in env.yaml:

```yaml
environments:
  <cluster>r1:
    values:
    - environments/edge/<cluster>r1/*.y*ml
    - environments/edge/<cluster>r1/nvo/*.y*ml
    - environments/edge/<cluster>r1/ngxcp/*.y*ml
```

### Step 2: Create ngxcp Directory

```bash
mkdir -p /root/oss-orchestrator/rdc/environments/edge/<cluster>r1/ngxcp
```

---

## Helm Chart Configuration

### Step 3: Create Chart Version File

```bash
cat <<EOF > /root/oss-orchestrator/rdc/environments/edge/<cluster>r1/ngxcp/ngxcpChartVersion.yaml
ngxcpChartVersion:
  cs-configstate: ~25.2.0-10001
  cs-configstate-db-job: ~25.2.0-10001
  priorityclass: ~25.2.0-10001
  cs-tagging: ~25.2.0-10001
  cs-tagging-job: ~25.2.0-10001
  cs-metaflow-cacheupdater: 25.3.0-10121
  cs-metaflow-telemetry-server: 25.3.0-10121
  numaflow: 25.3.0-10121
  event-highpriority: 25.3.0-10121
  event-lowpriority: ~25.2.0-10001
  event-mediumpriority: ~25.2.0-10001
  infra-priorityclasschart: ~25.2.0-10001
  interstepbufferchart: 25.3.0-10121
  metric-highpriority: 25.3.0-10121
  metric-lowpriority: 25.3.0-14
  traefik: 26.0.0
  cs-perfmonitor: ~25.2.0-10001
  cs-ingressroute: ~25.2.0-10001
  cs-perfdatamigrator: ~25.2.0-10001
EOF
```

### Step 4: Create ngxcp Values File

Create `/root/oss-orchestrator/rdc/environments/edge/<cluster>r1/ngxcp/ngxcp.yaml`:

```yaml
imagePullSecrets:
    - name: gcr-json-key
enableNGXCP: true

cs-configstate:
  imagePullSecrets:
    - name: gcr-json-key
  replicaCount: 1
  image:
    repository: gcr.io/prod-hm/xcp/configstate
    tag: 25.2.0-10001
  configMap:
    data:
      CacheHost: "common-redis-cluster"
      CachePort: "6379"
      CacheClusterType: "non-cluster"
      DBHOST: "hm-postgresql-ha-postgresql.xiq.svc.cluster.local"
      DBUSER: "postgres"
      DBPASS: "aerohive"
      DBNAME: "platform_common_db"
      DBPORT: "5432"
      DBMAXOPENCONN: "40"
      DBMAXIDLECONN: "10"
      DBAUTOMIGRATE: "false"
      WorkerPoolSize: "100"
      XIQ_MessageBusWorkerPool: "100"
      XIQ_MessageBusHost: "common-kafka.common.svc.cluster.local"
      XIQ_MessageBusPort: "9092"
      ApplicationName: "configstate"
      LogDir: "/var/log/configstate"

# ... (full configuration available in user's ng_aio_deploy_ccs_manually.md)
```

See full ngxcp.yaml in `~/vaults/work/proj/nvo/ng_aio/ng_aio_deploy_ccs_manually.md`

### Step 5: Create Perfmon SQL Script

```bash
cat <<EOF > /root/oss-orchestrator/rdc/environments/edge/<cluster>r1/k3s/create_ngxcp_db.sql
CREATE DATABASE cs_timescaledb WITH OWNER = perfmonitor  ENCODING = 'UTF8';
CREATE DATABASE perfmonitor WITH OWNER = perfmonitor  ENCODING = 'UTF8';
alter role perfmonitor superuser;
EOF
```

### Step 6: Create CCS Helmfile for Debezium

Create `/root/oss-orchestrator/rdc/helmfiles/ccs.yaml`:

```yaml
helmDefaults:
  timeout: 1800

{{ $ENV := .Environment }}
{{ $chartRepo := .Environment.Values.global | getOrNil "chartRepo" | default "xcloudiq-qa" }}
templates:
  debezium: &debezium
    chart: {{ $chartRepo }}/debezium
    values:
    - templates/global.yaml.gotmpl
    - templates/{{`{{ .Release.Name }}`}}.yaml.gotmpl
    version: {{ .Environment.Values.chartVersion | getOrNil "debezium" | default "~0.6.2" }}
    namespace: common

releases:
- name: debezium-ccsdb
  <<: *debezium
  chart: {{ $chartRepo }}/debezium-ccsdb
  version: {{ .Environment.Values.chartVersion | getOrNil "debezium-ccsdb" | default "~25.3.0" }}
  labels:
    app: debezium-ccsdb
    kind: ccs

- name: ccsdb-common-kafka-gitops
  namespace: common
  chart: {{ $chartRepo }}/{{`{{ .Release.Name }}`}}
  version: {{ .Environment.Values.chartVersion | getOrNil "ccsdb-common-kafka-gitops" | default "~25.3.0" }}
  values:
    - templates/global.yaml.gotmpl
    - templates/{{`{{ .Release.Name }}`}}.yaml.gotmpl
  labels:
    app: ccsdb-common-kafka-gitops
    kind: ccsdb-common-kafka-gitops
```

### Step 7: Create Kafka Gitops Template

```bash
cat <<EOF > /root/oss-orchestrator/rdc/helmfiles/templates/ccsdb-common-kafka-gitops.yaml.gotmpl
{{ index .Values "ccsdb-common-kafka-gitops" | toYaml }}
EOF
```

### Step 8: Create Debezium Config

```bash
cat <<EOF > /root/oss-orchestrator/rdc/environments/edge/<cluster>r1/debezium-ccsdb.yaml
debezium-ccsdb:
  config:
    database.hostname: "hm-postgresql-ha-postgresql.xiq.svc.cluster.local"
    database.port: "5432"
    database.user: "configuser_1"
    database.password: "aerohive"
    database.dbname: "platform_common_db"
    database.server.name: "platform_common_db"
EOF
```

### Step 9: Create Global Config (Replication Override)

```bash
export cluster="<cluster>r1"
cat <<EOF > /root/oss-orchestrator/rdc/environments/edge/$cluster/global_config.yaml
global:
  env: qa
  domain_suffix: .qa.xcloudiq.com
  cluster_name: $cluster
  xiq_namespace: xiq
  DEFAULT_PARTITIONS: &DEFAULT_PARTITIONS 1
  DEFAULT_REPLICATION: &DEFAULT_REPLICATION 1
EOF
```

---

## Database Setup

### Step 10: Create Common PostgreSQL with PV Storage

```bash
export cluster="<cluster>r1"

# Add PV storage for common-postgresql
grep -q "common-postgresql" /root/oss-orchestrator/rdc/environments/edge/$cluster/local-static-provisioner.yaml || cat <<EOF >> /root/oss-orchestrator/rdc/environments/edge/$cluster/local-static-provisioner.yaml
  - blockCleanerCommand:
    - /scripts/shred.sh
    - "2"
    hostDir: /data/volumes/common-postgresql
    name: common-postgresql
    namePattern: '''*'''
    storageClass:
      isDefaultClass: false
      reclaimPolicy: Delete
    volumeMode: Filesystem
EOF

# Sync provisioner
helmfile -e $cluster -l name=local-static-provisioner sync

# Install PostgreSQL
helm -n common install common-postgresql-ha xcloudiq-qa/postgresql-ha \
  --set postgresql.image.tag=1.1.17.1 --version=3.8.0 \
  --set witness.create=false \
  --set postgresql.image.registry=gcr.io/prod-hm \
  --set postgresql.image.pullSecrets={gcr-json-key} \
  --set postgresql.replicaCount=1 \
  --set postgresql.resources.requests.cpu=1 \
  --set postgresql.resources.requests.memory=2Gi \
  --set postgresql.resources.limits.cpu=1 \
  --set postgresql.resources.limits.memory=4Gi \
  --set persistence.size=20G \
  --set persistence.storageClass=common-postgresql \
  --set metrics.enabled=false

# Create perfmonitor DB user
helm -n common install common-pg-db-user xcloudiq/common-pg-db-user \
  --set global.enableVault=false \
  --set global.cluster=$cluster \
  --set env.DBUSER_NAME="perfmonitor" \
  --set env.DBUSER_PASSWORD="aerohive" \
  --set env.POSTGRES_USER="postgres" \
  --set env.POSTGRES_PASSWORD="aerohive" \
  --set env.POSTGRES_HOST="common-postgresql-ha-postgresql-master" \
  --set image.registry=gcr.io/prod-hm \
  --set global.imagePullSecrets[0].name=gcr-json-key
```

### Step 11: Create platform_common_db (if NG-XCP not deployed)

```bash
# Create database
k exec -it hm-postgresql-ha-postgresql-0 -- /bin/bash -c "export PGPASSWORD='aerohive'; echo \"SELECT format('CREATE DATABASE %I', :'dbname') WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname=:'dbname') \gexec\" | psql -h hm-postgresql-ha-postgresql.xiq.svc.cluster.local -U postgres --set ON_ERROR_STOP=1 --set dbname=\"platform_common_db\""

# Delete if needed
k exec -it hm-postgresql-ha-postgresql-0 -- /bin/bash -c "export PGPASSWORD='aerohive'; psql -h hm-postgresql-ha-postgresql.xiq.svc.cluster.local -U postgres -c 'drop database platform_common_db WITH ( FORCE );'"
```

---

## Deploy CCS Services

### Build and Retag Images

```bash
# 1. Generate CCS Private Build
https://build-xcp.qa.xcloudiq.com/job/CS-Build-Private/

# 2. Retag to Prod (select ALL except xcp/xcp-kafka-raft-image)
https://build-nms.iq.extremenetworks.com/job/NG-XCP%20Jobs/job/Retag-NG-XCP-Images-to-Prod/
```

### Deploy via Helmfile

```bash
cd /root/oss-orchestrator/rdc
export cluster="<cluster>r1"
export image_version="25.3.0-38"

# Deploy ConfigState
helmfile -e $cluster -l app=configstate sync \
  --set image.tag=$image_version \
  --set databaseImage.tag=$image_version \
  --set liquibaseImage.tag=$image_version

# Deploy Tagging
helmfile -e $cluster -l app=tagging sync \
  --set image.tag=$image_version \
  --set liquibaseImage.tag=$image_version

# Deploy Perfmonitor
helmfile -e $cluster -l app=perfmonitor sync \
  --set image.tag=$image_version \
  --set liquibaseImageTsdb.tag=$image_version

# Deploy Metaflow
helmfile -e $cluster -l app=metaflow sync \
  --set image.tag=$image_version \
  --set transformerImage.tag=$image_version \
  --set udfMapImage.tag=$image_version \
  --set udfReduceImage.tag=$image_version
```

---

## Post-Deployment Steps

### Deploy Classic XCP

For proper device-connector and inlets-server:

```bash
# Run Jenkins: Redeploy-XCP
https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/Redeploy-XCP/
```

### Deploy NVO via ArgoCD

```bash
cd /root/deployment_automation/nvo
export image_version="24.4.0-29"
kubectl -n nvo delete jobs --all
argocd login <cluster>-argocd.qa.xcloudiq.com --skip-test-tls --grpc-web --username admin --password Aerohive123
argocd app create -f app-of-appset.yaml --revision $image_version --upsert
argocd app sync nvo/nvo --prune --force
argocd app list -l appset=nvo
```

---

## Remove CCS

### Remove CCS Helm Releases

```bash
cd /root/oss-orchestrator/rdc
export cluster="<cluster>r1"
helmfile -e $cluster -l app=configstate destroy
helmfile -e $cluster -l app=tagging destroy
helmfile -e $cluster -l app=perfmonitor destroy
helmfile -e $cluster -l app=metaflow destroy
```

### Remove NVO from ArgoCD

```bash
argocd login <cluster>-argocd.qa.xcloudiq.com --skip-test-tls --grpc-web --username admin --password Aerohive123
argocd app delete nvo/nvo
```
