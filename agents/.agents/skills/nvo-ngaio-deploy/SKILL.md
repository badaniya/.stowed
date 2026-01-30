---
name: nvo-ngaio-deploy
description: |
  Deploy services (NVO, XIQ, XCP, NG-XCP, CCS, EP1 UI) to NG-AIO Kubernetes environments via Jenkins pipelines and helmfile.
  
  Use when:
  - User asks to deploy any service to NG-AIO (brianna-vm, pasu-vm, vaughan-vm, wired3-c9, etc.)
  - User asks to run Jenkins deployment jobs
  - User asks to build private images and push to registries
  - User asks to retag images to GCR/Prod
  - User needs to troubleshoot NG-AIO deployment issues
  - User asks about helmfile sync/diff/destroy operations
  - User mentions "deploy to testbed", "deploy to ng-aio", "run jenkins job"
  
  Trigger phrases: deploy, ng-aio, jenkins pipeline, helmfile sync, retag images, private build, redeploy
---

# NG-AIO Deployment Skill

Deploy services to NG-AIO (NextGen All-In-One) Kubernetes environments for ExtremePlatformOne.

## Quick Reference

### ⚠️ Critical Gotchas

| Pitfall | Wrong | Correct |
|---------|-------|---------|
| NVO version format | `24.8.0-11664-SNAPSHOT` | `24.8.0-11664` (no -SNAPSHOT) |
| Retag COMPONENTS | Default: only `edge` | Must specify ALL: `edge,network,scheduler,system,orchestration,ui,liquibase-deployment,postgres-db,runonce` |
| Deployment status | Poll Jenkins ReDeploy job | Use ArgoCD or kubectl on NG-AIO console |

### Service Quick Reference

| Service | Build Job | Retag Job | Deploy Job |
|---------|-----------|-----------|------------|
| NVO | [NVO-Build-Private](https://build-nvo.extremenetworks.com/job/NVO-Build-Private/) | [Retag-NVO-Images-to-GCR](https://build-nms.iq.extremenetworks.com/job/NextGen-AIO/job/Retag-NVO-Images-to-GCR/) | [ReDeploy-NVO-DA4](https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/ReDeploy-NVO-DA4/) |
| XIQ | N/A | N/A | [Redeploy-XIQ](https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/Redeploy-XIQ/) |
| XCP (legacy) | N/A | N/A | [Redeploy-XCP](https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/Redeploy-XCP/) |
| NG-XCP (new) | [CS-Build-Private](https://build-xcp.qa.xcloudiq.com/job/CS-Build-Private/) | [Retag-NG-XCP-Images-to-Prod](https://build-nms.iq.extremenetworks.com/job/XCP/job/NG-XCP/job/Retag-NG-XCP-Images-to-Prod/) | [upgrade-New-XCP](https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/upgrade-New-XCP/) |
| EP1 UI | N/A | N/A | [EP1-UIShell-Release-Deploy](https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/EP1-UIShell-Release-Deploy-NGAIO-post-r25.5/) |

## Available NG-AIO Environments

| Environment | Console SSH | Cluster Names |
|-------------|-------------|---------------|
| brianna-vm | `sshpass -p aerohive ssh root@brianna-vmg1-console.qa.xcloudiq.com` | brianna-vmg1 (GDC), brianna-vmr1 (RDC) |
| pasu-vm | `sshpass -p aerohive ssh root@pasu-vmg1-console.qa.xcloudiq.com` | pasu-vmg1, pasu-vmr1 |
| vaughan-vm | `sshpass -p aerohive ssh root@vaughan-vmg1-console.qa.xcloudiq.com` | vaughan-vmg1, vaughan-vmr1 |
| prpandey-vm | `sshpass -p aerohive ssh root@prpandey-vmg1-console.qa.xcloudiq.com` | prpandey-vmg1, prpandey-vmr1 |
| wired3-c9 | `sshpass -p aerohive ssh root@wired3-c9g1-console.qa.xcloudiq.com` | wired3-c9g1, wired3-c9r1 |

**User has bash aliases**: `ngaio-brianna-vm`, `ngaio-pasu-vm`, `ngaio-vaughan-vm`, etc.

## Deployment Workflow

### Standard Deployment Order

Execute pipelines in this order for a full deployment:

```
1. Reset-NGAIO-Configs (one-time setup)
     ↓
2. Redeploy-XIQ
     ↓
3. upgrade-New-XCP (or Redeploy-New-XCP for older versions)
     ↓
4. Redeploy-XCP (legacy, for capwap-gateway and device-connector)
     ↓
5. ReDeploy-NVO-DA4
     ↓
6. EP1-UIShell-Release-Deploy-NGAIO-post-r25
     ↓
7. Subscription-Activation (for EP1 licensing)
```

### Private Build Deployment (NVO)

When deploying private NVO builds:

```
1. NVO-Build-Private
   - URL: https://build-nvo.extremenetworks.com/job/NVO-Build-Private/
   - Check: AWS_ECR_PUSH, UPLOAD_TO_CDN
     ↓
2. Retag-NVO-Images-to-GCR
   - URL: https://build-nms.iq.extremenetworks.com/job/NextGen-AIO/job/Retag-NVO-Images-to-GCR/
     ↓
3. ReDeploy-NVO-DA4
   - Use version WITHOUT -SNAPSHOT suffix (e.g., 24.8.0-11664)
   - NOTE: -SNAPSHOT suffix is ONLY for EP1 UI and NVO MFE versions
```

### Private Build Deployment (NG-XCP/CCS)

When deploying private Common Services builds:

```
1. CS-Build-Private
   - URL: https://build-xcp.qa.xcloudiq.com/job/CS-Build-Private/
     ↓
2. Retag-NG-XCP-Images-to-Prod
   - URL: https://build-nms.iq.extremenetworks.com/job/XCP/job/NG-XCP/job/Retag-NG-XCP-Images-to-Prod/
     ↓
3. upgrade-New-XCP
   - Run `helm repo update` on NG-AIO first to pick up chart changes
```

## Helmfile Operations

All helmfile operations are run from the NG-AIO console.

### Common Patterns

```bash
# Set cluster name
export cluster="brianna-vmr1"  # RDC cluster
export cluster="brianna-vmg1"  # GDC cluster

# Preview changes
helmfile -e $cluster -l name=<service> diff --context=1 --set global.hmVersion=<version>

# Apply changes
helmfile -e $cluster -l name=<service> sync --set global.hmVersion=<version>

# Remove service
helmfile -e $cluster -l name=<service> destroy
```

### Directories

| Directory | Purpose |
|-----------|---------|
| `/root/oss-orchestrator/rdc` | RDC (edge) deployments - NVO, device-connector, kafka |
| `/root/oss-orchestrator/gdc` | GDC deployments - XIQ services, workspace UI |
| `/root/oss-orchestrator/portal` | Portal deployments |
| `/root/oss-aioConfig/...` | Config backup (edit both when making changes) |

### Examples

```bash
# Sync device-connector
cd /root/oss-orchestrator/rdc
helmfile -e brianna-vmr1 -l name=device-connector diff --context=1 --set global.hmVersion=25.7.0-100
helmfile -e brianna-vmr1 -l name=device-connector sync --set global.hmVersion=25.7.0-100

# Sync NVO kafka
helmfile -e brianna-vmr1 -l name=nvo-kafka-gitops diff --context=1 --set global.hmVersion=24.5.41

# Sync nginx-ws (GDC)
cd /root/oss-orchestrator/gdc
helmfile -e brianna-vmg1 -l name=nginx-ws -l name=nginx-cloudapi sync --set global.hmVersion=24.3.7
```

## ArgoCD (NVO Deployment)

NVO uses ArgoCD for deployment management.

```bash
# Login
argocd login brianna-vmg1-argocd.qa.xcloudiq.com --skip-test-tls --grpc-web --username admin --password Aerohive123

# Deploy NVO
cd /root/deployment_automation/nvo
export image_version="24.4.0-29"
kubectl -n nvo delete jobs --all
argocd app create -f app-of-appset.yaml --revision $image_version --upsert
argocd app sync nvo/nvo --prune --force

# Check status
argocd app list -l appset=nvo
argocd app get nvo/nvo
```

**ArgoCD CLI credentials**: `nvo_admin` / `extreme123`

## Common Troubleshooting

### Pod OOM Issues

```bash
# device-connector: increase memory from 500Mi to 1Gi
vi /root/oss-orchestrator/rdc/environments/edge/brianna-vmr1/commonsvcs.yaml
# Edit resource limits
helmfile -e brianna-vmr1 -l name=device-connector sync --set global.hmVersion=25.7.0-100

# TaskEngine Allocator: increase from 3Gi to 5Gi
vi /root/oss-orchestrator/rdc/environments/edge/brianna-vmr1/taskengine.yaml
helmfile -e brianna-vmr1 -l name=teall sync --set global.hmVersion=25.7.0-100
```

### CrashLoopBackOff for hm-ignite-0 / hm-elastic-0

```bash
# Fix system limits
cat << EOF >> /etc/security/limits.conf
soft nproc 4096
hard nproc 4096
EOF
reboot
```

### Unknown Failure on Device Onboarding

```bash
# Disable redirector verification
# Edit: /root/oss-orchestrator/rdc/environments/edge/<cluster>/tomcat.yaml
hmweb:
  webapp:
    nms-properties:
      Overrides:
        device.onboarding.verify_via_redirector: "false"

# Sync hmweb
cd ~/oss-orchestrator/rdc
helmfile -n xiq -e brianna-vmr1 -l name=hmweb sync --set global.hmVersion=24.6.0.74
```

### Drop and Recreate NVO Database

```bash
# Drop NVO DB
k -n gdc exec -it gdc-postgresql-ha-postgresql-0 -- bash -c "export PGPASSWORD=aerohive; psql -h localhost -U postgres -c 'drop database nvo_db with (force)'"

# Run schema and runonce jobs
export CLUSTER_NAME="brianna-c9"
cd /root/oss-orchestrator/rdc
NVO_VERSION=$(cat environments/edge/${CLUSTER_NAME}r1/nvo/nvoChartVersion.yaml | awk '/nvo-job-runonce/ {print $2}')
helmfile -e ${CLUSTER_NAME}r1 -l name=nvo-schema sync --set global.hmVersion=EII-3.3.0
helmfile -e ${CLUSTER_NAME}r1 -l name=nvo-job-runonce sync --set image.tag=${NVO_VERSION} --set databaseImage.tag=${NVO_VERSION} --set liquibaseImage.tag=${NVO_VERSION}
```

### ImagePullBackOff for License Services

```bash
# Sync license services with working version
cd /root/oss-orchestrator/gdc
export cluster="brianna-vmg1"
helmfile -e $cluster -l name=xcloudiq-license-scheduler -l name=xcloudiq-license-mgmt sync --set global.hmVersion=25.2.0.130
```

## Jenkins API Automation (Preferred)

Use Jenkins REST API instead of browser automation. Credentials stored in `~/.private_bash_aliases`.

### Setup

```bash
# Load credentials
source ~/.private_bash_aliases

# Available environment variables:
# JENKINS_NVO_API_USER / JENKINS_NVO_API_TOKEN  - for build-nvo.extremenetworks.com
# JENKINS_NMS_API_USER / JENKINS_NMS_API_TOKEN  - for build-nms.iq.extremenetworks.com (email format required)
```

### Triggering Jobs

**Important**: build-nms.iq.extremenetworks.com requires CRUMB (CSRF token).

```bash
# NVO Build (no CRUMB needed)
source ~/.private_bash_aliases
curl -s -k -X POST -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
  "https://build-nvo.extremenetworks.com/job/NVO-Build-Private/buildWithParameters" \
  --data-urlencode "GODCF_BRANCH=badaniya/GoDCApp/NVO-13930" \
  --data-urlencode "RELEASE=24.8.0" \
  --data-urlencode "AWS_ECR_PUSH=true" \
  --data-urlencode "UPLOAD_TO_CDN=true" \
  -w "\nHTTP Status: %{http_code}\n"

# NMS Jobs (CRUMB required)
source ~/.private_bash_aliases
CRUMB=$(curl -s -k -u "$JENKINS_NMS_API_USER:$JENKINS_NMS_API_TOKEN" \
  "https://build-nms.iq.extremenetworks.com/crumbIssuer/api/json" | jq -r '.crumb')

# Retag NVO Images - MUST include all COMPONENTS
# Available: edge,network,scheduler,system,orchestration,ui,liquibase-deployment,postgres-db,runonce
# WARNING: Default is only "edge" - you MUST specify all components!
curl -s -k -X POST -u "$JENKINS_NMS_API_USER:$JENKINS_NMS_API_TOKEN" \
  -H "Jenkins-Crumb: $CRUMB" \
  "https://build-nms.iq.extremenetworks.com/job/NextGen-AIO/job/Retag-NVO-Images-to-GCR/buildWithParameters" \
  --data-urlencode "NVO_VERSION=24.8.0-11664" \
  --data-urlencode "COMPONENTS=edge,network,scheduler,system,orchestration,ui,liquibase-deployment,postgres-db,runonce" \
  -w "\nHTTP Status: %{http_code}\n"

# Deploy NVO DA4 - NO -SNAPSHOT suffix for NVO!
curl -s -k -X POST -u "$JENKINS_NMS_API_USER:$JENKINS_NMS_API_TOKEN" \
  -H "Jenkins-Crumb: $CRUMB" \
  "https://build-nms.iq.extremenetworks.com/job/NextGen-AIO/job/ReDeploy-NVO-DA4/buildWithParameters" \
  --data-urlencode "CLUSTER=brianna-vm" \
  --data-urlencode "NVO_VERSION=24.8.0-11664" \
  -w "\nHTTP Status: %{http_code}\n"
```

HTTP 201 = job queued successfully.

### Checking Build Status

**Important**: Use `?tree=` parameter to avoid JSON truncation.

```bash
# Basic status check
curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
  "https://build-nvo.extremenetworks.com/job/NVO-Build-Private/1965/api/json?tree=number,result,building,description"

# Response when running:
# {"building":true,"description":"BUILD: 24.8.0-48\nBranch: badaniya/GoDCApp/NVO-13930","number":1965,"result":null}

# Response when complete:
# {"building":false,"description":"Release Tag: 24.8.0-11664\nBranch: ...","number":1965,"result":"SUCCESS"}
```

### Blue Ocean API for Stage Progress (Recommended)

Blue Ocean API provides detailed pipeline stage information - use for polling.

```bash
# NVO Build stages
curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
  "https://build-nvo.extremenetworks.com/blue/rest/organizations/jenkins/pipelines/NVO-Build-Private/runs/1965/nodes/" | \
  jq '.[] | {displayName, state, result}'

# NMS job stages (nested pipeline path)
curl -s -k -u "$JENKINS_NMS_API_USER:$JENKINS_NMS_API_TOKEN" \
  "https://build-nms.iq.extremenetworks.com/blue/rest/organizations/jenkins/pipelines/NextGen-AIO/pipelines/ReDeploy-NVO-DA4/runs/804/nodes/" | \
  jq '.[] | {displayName, state, result}'
```

**Stage states**:
- `FINISHED` + `SUCCESS` = stage completed successfully
- `FINISHED` + `FAILURE` = stage failed
- `RUNNING` + `UNKNOWN` = stage in progress
- `SKIPPED` + `NOT_BUILT` = stage skipped
- `null` + `null` = stage not yet started

### Polling Pattern

```bash
# Poll until build completes
while true; do
  STATUS=$(curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
    "https://build-nvo.extremenetworks.com/job/NVO-Build-Private/1965/api/json?tree=building,result")
  
  BUILDING=$(echo "$STATUS" | jq -r '.building')
  RESULT=$(echo "$STATUS" | jq -r '.result')
  
  if [ "$BUILDING" = "false" ]; then
    echo "Build finished with result: $RESULT"
    break
  fi
  
  echo "Still building... checking stages:"
  curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
    "https://build-nvo.extremenetworks.com/blue/rest/organizations/jenkins/pipelines/NVO-Build-Private/runs/1965/nodes/" | \
    jq '.[] | select(.state == "RUNNING") | {displayName, state}'
  
  sleep 30
done
```

### Getting Console Output

```bash
# Full console log
curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
  "https://build-nvo.extremenetworks.com/job/NVO-Build-Private/1965/consoleText"

# Last 100 lines
curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
  "https://build-nvo.extremenetworks.com/job/NVO-Build-Private/1965/consoleText" | tail -100
```

### Finding Latest Build Number

```bash
# Get last build info
curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
  "https://build-nvo.extremenetworks.com/job/NVO-Build-Private/api/json" | jq '.lastBuild'

# Get queued item location (from Location header after triggering)
curl -s -k -X POST -u "$USER:$TOKEN" \
  "https://build-nvo.extremenetworks.com/job/NVO-Build-Private/buildWithParameters" \
  --data-urlencode "..." \
  -D - | grep -i "^Location:"
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| HTTP 403 | Missing CRUMB for NMS | Get CRUMB first from crumbIssuer/api/json |
| Truncated JSON | Missing tree parameter | Add `?tree=field1,field2,...` |
| Chart not found | Charts not published to prod repo | Check Upload to CDN step; may need manual chart publish |
| Empty response | API path wrong | For nested jobs use `/job/Folder/job/JobName/...` |
| ImagePullBackOff | Retag job only retagged 'edge' | Must include ALL COMPONENTS in retag job |
| NVO deploy fails at install | Wrong version format | NVO uses NO -SNAPSHOT suffix (e.g., 24.8.0-11664) |

## Deployment Status Monitoring (Preferred Methods)

**For NVO deployments, prefer ArgoCD or direct kubectl over Jenkins polling.**

### Method 1: ArgoCD Status (Recommended for NVO)

SSH to NG-AIO console and check ArgoCD app status:

```bash
# SSH to console
sshpass -p aerohive ssh -o StrictHostKeyChecking=no root@brianna-vmg1-console.qa.xcloudiq.com

# Check NVO apps status (after login or in single command)
argocd login brianna-vmg1-argocd.qa.xcloudiq.com --skip-test-tls --grpc-web --username nvo_admin --password extreme123
argocd app list -l appset=nvo

# One-liner from local machine
sshpass -p aerohive ssh -o StrictHostKeyChecking=no root@brianna-vmg1-console.qa.xcloudiq.com \
  "argocd login brianna-vmg1-argocd.qa.xcloudiq.com --skip-test-tls --grpc-web --username nvo_admin --password extreme123 && argocd app list -l appset=nvo"

# Compact status view
sshpass -p aerohive ssh -o StrictHostKeyChecking=no root@brianna-vmg1-console.qa.xcloudiq.com \
  "argocd app list -l appset=nvo 2>/dev/null | awk '{print \$1, \$5, \$6}'"
```

**Status meanings**:
- `Synced` + `Healthy` = ✅ Deployed successfully
- `Synced` + `Progressing` = 🔄 Still rolling out
- `OutOfSync` + `Missing` = ⚠️ Not yet synced
- `Synced` + `Degraded` = ❌ Pod issues

### Method 2: Direct kubectl (Quick Pod Check)

```bash
# Check NVO pods directly
sshpass -p aerohive ssh -o StrictHostKeyChecking=no root@brianna-vmg1-console.qa.xcloudiq.com \
  "kubectl get pods -n nvo"

# Watch pods in real-time
sshpass -p aerohive ssh -o StrictHostKeyChecking=no root@brianna-vmg1-console.qa.xcloudiq.com \
  "kubectl get pods -n nvo -w"

# Check for non-running pods
sshpass -p aerohive ssh -o StrictHostKeyChecking=no root@brianna-vmg1-console.qa.xcloudiq.com \
  "kubectl get pods -n nvo | grep -v Running | grep -v Completed"
```

### Method 3: Jenkins Blue Ocean API (Build-Phase Only)

Use Jenkins API only for monitoring the build job itself, not deployment status:

```bash
# Check NVO-Build-Private stages
curl -s -k -u "$JENKINS_NVO_API_USER:$JENKINS_NVO_API_TOKEN" \
  "https://build-nvo.extremenetworks.com/blue/rest/organizations/jenkins/pipelines/NVO-Build-Private/runs/<BUILD_NUM>/nodes/" | \
  jq '.[] | {displayName, state, result}'
```

For ReDeploy-NVO-DA4, the Jenkins job may complete but ArgoCD sync continues - always verify with ArgoCD/kubectl.

## Jenkins Pipeline Automation with Playwright (Alternative)

Use browser automation only if API is unavailable or for complex interactions.

**Key Jenkins URLs**:
- NVO-Build-Private: `https://build-nvo.extremenetworks.com/job/NVO-Build-Private/build?delay=0sec`
- Retag-NVO-Images-to-GCR: `https://build-nms.iq.extremenetworks.com/job/NextGen-AIO/job/Retag-NVO-Images-to-GCR/build?delay=0sec`
- ReDeploy-NVO-DA4: `https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/ReDeploy-NVO-DA4/build?delay=0sec`

## EP1 User/Subscription Setup

### Customer Portal Access

```
URL: https://brianna-vmg1-portal.qa.xcloudiq.com/portal/customers
User: cloudops-admin@extremenetworks.com
Pass: Extreme@123
```

### Subscription Activation

Use Jenkins job: [Subscription-Activation](https://build-nms.iq.extremenetworks.com/job/NEXTGEN-AIO/job/Subscription-Activation/)

```
Email: badaniya+user1@extremenetworks.com
Cluster: brianna-vm
```

## UI Access

| Service | URL |
|---------|-----|
| XIQ | http://brianna-vmg1.qa.xcloudiq.com/sso?sso=true |
| EP1 | https://brianna-vmg1.ep1test.com/ |

## References

For detailed troubleshooting and manual configuration steps, see:
- [references/troubleshooting.md](references/troubleshooting.md) - Common fixes and workarounds
- [references/ccs-deployment.md](references/ccs-deployment.md) - Manual CCS/Metaflow deployment
