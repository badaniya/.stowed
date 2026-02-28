---
description: Service Bottleneck & Gap Analysis
---

**NVO Network Service:**
```
{{SERVICE_NAME}}        = Network
{{SERVICE_NAME_UPPER}}  = Network
{{SERVICE_SOURCE_ROOT}} = /GoDCApp/NVO
{{PREFIX}}              = BN
```

## Quick Start

1. Replace `{{PLACEHOLDERS}}` in the prompt below
2. Attach the service source folder + `Common/src/` to the AI conversation
3. Run via `runSubagent` or paste into AI chat
4. Review output with service owner (~30 min)

| Placeholder | What | Examples |
|---|---|---|
| `{{SERVICE_NAME}}` | Service name | MetaFlow, PerfMonitor, ConfigState, IAM, Tagging, MetaStore |
| `{{SERVICE_NAME_UPPER}}` | Uppercase (filename) | METAFLOW, CONFIGSTATE |
| `{{SERVICE_SOURCE_ROOT}}` | Source path | `/home/user/ws/PlatformServices/MetaFlow/src/metaflow/` |
| `{{PREFIX}}` | Bottleneck ID prefix | MF, PM, CCS, IAM, TAG, MS |

---

## THE PROMPT

~~~
You are a Performance Architect. Analyze the {{SERVICE_NAME}} service to find every
performance bottleneck at scale that is 100% automatable with k6.

Think like someone who will be woken up at 3 AM when this service falls over in
production. Find the code paths that will break first.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 1 — READ THE CODE (no shortcuts)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Read ALL .go files recursively in:
  {{SERVICE_SOURCE_ROOT}}

Also check shared libraries this service uses:
  /home/user/ws/PlatformServices/Common/src/

For every component, map out:

  WHAT IT DOES         → Kafka consume, HTTP handle, gRPC serve, DB write, cache lookup
  WHAT IT CALLS        → Postgres, Kafka, Redis, gRPC, HTTP, filesystem
  WHAT CONTROLS IT     → batch sizes, timeouts, pool limits, concurrency caps (note defaults + env vars)
  WHAT HAPPENS ON FAIL → retry? sleep? silent drop? panic? fallback?
  WHERE IT PARALLELIZES→ goroutines, channels, mutexes, worker pools — effective parallelism?
  WHAT IT BUFFERS      → slices, maps, channels — size limits? flush triggers?
  THE FULL DATA PATH   → trace one request/event from ingress to egress, every I/O hop

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 2 — KNOW WHAT K6 CAN DO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Our framework: Go orchestrator → 3-tier YAML config → k6 binary execution.

k6 CAN:
  ✅ HTTP/REST, WebSocket, SSE at any concurrency
  ✅ Kafka produce/consume (xk6-kafka)
  ✅ gRPC calls (xk6-grpc)
  ✅ Custom metrics (Trend, Counter, Rate, Gauge)
  ✅ Thresholds (p95, p99, error rate, throughput)
  ✅ Prometheus export + Grafana annotations
  ✅ Multi-scenario orchestration (sequential/parallel phases)
  ✅ pprof endpoint polling for heap/goroutine/CPU

k6 CANNOT:
  ❌ Physical device interaction (gNMI/SNMP to hardware)
  ❌ Network partition / fault injection
  ❌ Kernel-level resource manipulation
  ❌ Internal goroutine profiling (only via pprof HTTP)

Executors available:
  shared-iterations | per-vu-iterations | constant-vus | ramping-vus
  constant-arrival-rate | ramping-arrival-rate | externally-controlled

Workflow YAML pattern:
  testData:   → Go setup (entities, CSVs, seed data)
  scenarios:  → k6 execution (executor, stages, VUs, exec function)
  thresholds: → pass/fail gates (latency, error rate)

Only include bottlenecks testable with the above. If k6 can't reach it, skip it.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 3 — PRODUCE THE ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Output: {{SERVICE_NAME_UPPER}}_BOTTLENECK_ANALYSIS.md
Place at: Test/src/automation/k6/

═══ Required Sections ═══

1. ARCHITECTURE SUMMARY
   - Data flow diagram (ASCII or Mermaid)
   - Write path vs Read path (if applicable)
   - Dependency map with pool sizes and timeouts

2. BOTTLENECK CATALOG — for each bottleneck:

   ### {{PREFIX}}-BN-NNN: Title

   | Field | Value |
   |-------|-------|
   | **Category** | Ingestion / API / Database / Memory / Concurrency / Config / Resource / Integrity / Health / Network |
   | **Severity** | CRITICAL / HIGH / MEDIUM / LOW |
   | **File** | path/to/file.go:line-numbers |
   | **Code Evidence** | the exact variable, constant, or pattern |

   **What:** 2-3 sentences — the bottleneck and why it matters.
   **At Scale:** 2-3 sentences — what breaks at 10x/100x load.
   **k6 Test:** 3-5 bullets — endpoint, load pattern, metrics, thresholds.

3. TEST AUTOMATION MATRIX
   | ID | Protocol | Target | Metrics | Executor | Pattern |

4. CONFIGURATION PARAMETERS
   | Param | Default | Env Var | File | Impact |

5. PRIORITY RANKING
   | Priority | ID | Title | Why |

6. TEST PHASES
   Baseline → Scale Up → Combined Load → Stress → Endurance (4h+) → Recovery

═══ Ground Rules ═══

→ REAL CODE ONLY — cite actual file paths and code. No hypotheticals.
→ QUANTIFY — "100 max connections" not "could be slow"
→ DEFAULTS MATTER — note the actual value from code, not guesses
→ CROSS-PACKAGE — follow calls into Common/src/; bottlenecks often live there
→ PRECISION > VOLUME — 15 solid findings beat 30 hand-wavy ones
→ SEVERITY = IMPACT:
    CRITICAL = service down or data loss
    HIGH     = major degradation, still running
    MEDIUM   = measurable under specific conditions
    LOW      = theoretical, extreme conditions only

Be creative in how you think about failure modes. Consider: what if every device
in a 10K-device deployment sends data at the same second? What if a dependency
goes slow but doesn't fail? What if the cache is cold after a restart? What if
duplicate data arrives? Think adversarially.
~~~

---

## Run Examples


**MetaStore:**
```
{{SERVICE_NAME}}        = MetaStore
{{SERVICE_NAME_UPPER}}  = METASTORE
{{SERVICE_SOURCE_ROOT}} = /home/user/ws/PlatformServices/MetaStore/src/
{{PREFIX}}              = MS
```

---

## Output Summary

Each analysis delivers:

| Section | Audience |
|---|---|
| Architecture diagram | Everyone |
| Bottleneck catalog (with code evidence) | Dev + QA |
| Test automation matrix | QA Engineers |
| Config parameters table | DevOps / SRE |
| Priority ranking | Tech Leads |
| Test phases | QA Leads |

---

## Results Tracker

| Service | Found | Critical | High | Med+ | Document | Status |
|---|---|---|---|---|---|---|
| **MetaFlow** | 22 | 5 | 10 | 7 | `METAFLOW_BOTTLENECK_ANALYSIS.md` | Done |
| **PerfMonitor** | 17 | 3 | 4 | 10 | `PERFMONITOR_BOTTLENECK_ANALYSIS.md` | Done |
| ConfigState | — | — | — | — | — | Pending |
| IAM | — | — | — | — | — | Pending |
| Tagging | — | — | — | — | — | Pending |
| MetaStore | — | — | — | — | — | Pending |

---

## Tips

- **Attach full source + Common/src/** — bottlenecks often live in shared code
- **Use `runSubagent`** — gives the agent autonomy for deep recursive reads
- **Review with service owner** — 30 min to separate intentional patterns from bugs
- **Update after fixes** — keep the doc as living inventory
- **Feed incidents back** — production issue maps to a listed bottleneck? Validates the analysis. Doesn't map? Add it 
