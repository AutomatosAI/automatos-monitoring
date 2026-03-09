# PRD-73 Deploy Runbook

**Goal:** Deploy the observability stack on Railway with minimal false failures and a clean validation path.

**Source:** Auto CTO implementation checklist, 2026-03-08

---

## Deploy Order

```
1. Loki              ← storage first, everything depends on it
2. log-relay         ← needs Loki before Railway log drain can be wired
3. Prometheus        ← starts early, some targets will be down initially (fine)
4. AlertManager      ← needs Prometheus, webhook target may not exist yet (fine)
5. postgres-exporter ← needs backing postgres + env vars
6. redis-exporter    ← needs backing redis + env vars
7. Grafana           ← last monitoring service, depends on datasources
8. Backend /api/alerts/ingest  ← must exist before AlertManager fires real webhooks
9. Railway log drain ← wire only after log-relay is reachable + authenticated
10. Alert rules + dashboard verification
```

**Why this order:** Loki must exist before anything forwards logs. Log-relay needs Loki. Prometheus can start early but won't be fully healthy until targets exist. Exporters need backing services and env vars. Grafana is last among monitoring services because it depends on datasources. Backend ingest should exist before AlertManager starts firing real webhooks. Railway log drain should be wired only after relay is reachable and authenticated.

---

## Phase 0 — Preflight

Do this before deploying anything.

### 0.1 Verify repo contents

```bash
# All of these must exist
ls docker-compose.yml \
   monitoring/prometheus/prometheus.yml \
   monitoring/prometheus/rules/*.yml \
   monitoring/loki/local-config.yaml \
   monitoring/alertmanager/alertmanager.yml \
   monitoring/grafana/provisioning/datasources/datasources.yml \
   monitoring/grafana/provisioning/dashboards/dashboards.yml \
   monitoring/grafana/dashboards/*.json \
   services/log-relay/Dockerfile \
   services/log-relay/main.py \
   .env.example
```

### 0.2 Clean out dead crypto baggage

```bash
grep -RniE "xplaincrypto|crypto-overview|n8n|promtail|nginx" . --include='*.yml' --include='*.yaml' --include='*.json' --include='*.py' --include='*.sh'
```

**Expected:** No relevant hits.

### 0.3 Confirm Railway prerequisites

- [ ] Railway project linked (`railway status` works)
- [ ] Private networking enabled (default on Railway)
- [ ] Backend service exists and is running
- [ ] PostgreSQL service exists and is running
- [ ] Redis service exists and is running
- [ ] Workspace-worker exists (can be down)
- [ ] Volumes available for: Loki (10GB), Prometheus (5GB), Grafana (1GB)

### 0.4 Confirm secrets/env design

Define these **before first deploy**. Do not improvise mid-deploy.

| Variable | Service | Value |
|----------|---------|-------|
| `GF_SECURITY_ADMIN_PASSWORD` | Grafana | Strong password |
| `LOG_RELAY_SECRET` | log-relay | Shared secret for Railway log drain auth |
| `DATA_SOURCE_NAME` | postgres-exporter | `postgresql://postgres:${{postgres.POSTGRES_PASSWORD}}@postgres.railway.internal:5432/orchestrator_db?sslmode=disable` |
| `REDIS_ADDR` | redis-exporter | `redis://default:${{redis.REDIS_PASSWORD}}@redis.railway.internal:6379` |
| `ALERT_INGEST_TOKEN` | backend + alertmanager | Bearer token for `/api/alerts/ingest` auth |
| `LOKI_PUSH_URL` | log-relay | `http://loki.railway.internal:3100/loki/api/v1/push` |

---

## Phase 1 — Storage-Backed Core Services

### Step 1: Deploy Loki

**Why first:** Everything log-related depends on it.

**Checklist:**
- [ ] Service created on Railway
- [ ] Volume mounted (10GB)
- [ ] Config path correct (`/etc/loki/config.yaml`)
- [ ] Port exposed internally: `3100`
- [ ] Public domain **NOT** enabled (Loki stays private)
- [ ] Startup logs show config loaded successfully

**Validate:**
```bash
curl http://loki.railway.internal:3100/ready
# Expected: "ready"
```

**If not ready:** Check volume path, schema config, retention/storage settings.

### Step 2: Deploy log-relay

**Why second:** Needed before Railway log drain is configured.

**Checklist:**
- [ ] Public domain **enabled** (Railway log drain target)
- [ ] `LOG_RELAY_SECRET` configured
- [ ] `LOKI_PUSH_URL` = `http://loki.railway.internal:3100/loki/api/v1/push`
- [ ] Health endpoint responds

**Validate:**
```bash
# Health check
curl https://<log-relay-domain>/health

# Test log push
curl -X POST https://<log-relay-domain>/drain \
  -H "Content-Type: application/json" \
  -H "X-Railway-Secret: <secret>" \
  -d '[{"message":"test log from deploy","severity":"info","service":"deploy-test"}]'
# Expected: 204 No Content

# Verify in Loki (from internal network or Grafana later)
# Query: {service="deploy-test"}
```

**Gate:** Do NOT configure Railway log drain until this works.

---

## Phase 2 — Metrics and Alerting Backbone

### Step 3: Deploy Prometheus

**Checklist:**
- [ ] Volume mounted (5GB)
- [ ] Config file loaded (`/etc/prometheus/prometheus.yml`)
- [ ] Rule files present (`/etc/prometheus/rules/*.yml`)
- [ ] Scrape config uses Railway internal DNS
- [ ] Retention set (`15d`)
- [ ] Web UI internal only (no public domain)

**Validate:**
```bash
curl http://prometheus.railway.internal:9090/-/ready
# Expected: "Prometheus Server is Ready."
```

**Expected initially:** Some targets UP, some DOWN (exporters not deployed yet). That's fine.

### Step 4: Deploy AlertManager

**Checklist:**
- [ ] Config loaded
- [ ] Route tree valid
- [ ] Webhook receiver points to `http://backend.railway.internal:8000/api/alerts/ingest`
- [ ] Inhibition rules valid
- [ ] Internal only (no public domain)

**Validate:**
```bash
curl http://alertmanager.railway.internal:9093/-/ready
```

**Important:** If backend ingest endpoint isn't ready yet, AlertManager will fail to deliver webhooks. This is fine — it retries. But don't let it spam a dead endpoint for hours. Deploy backend ingest (Step 8) promptly.

---

## Phase 3 — Exporters

### Step 5: Deploy postgres-exporter

**Checklist:**
- [ ] `DATA_SOURCE_NAME` correct (uses Railway variable reference)
- [ ] Target DB reachable
- [ ] Internal port `9187`

**Validate:**
```bash
curl http://postgres-exporter.railway.internal:9187/metrics | head -5
# Then check Prometheus targets page
```

**Common failure modes:** Bad password interpolation, wrong DB name, SSL mode mismatch, Railway DNS typo.

### Step 6: Deploy redis-exporter

**Checklist:**
- [ ] `REDIS_ADDR` correct
- [ ] Password correct
- [ ] Internal port `9121`

**Validate:**
```bash
curl http://redis-exporter.railway.internal:9121/metrics | head -5
# Then confirm Prometheus can scrape it
```

**Common failure modes:** Auth mismatch, wrong Redis URL format, exporter can't reach internal host.

---

## Phase 4 — Visualisation

### Step 7: Deploy Grafana

**Checklist:**
- [ ] Volume mounted (1GB)
- [ ] Admin password set via env var
- [ ] Root URL set to Railway public domain
- [ ] Prometheus datasource provisioned
- [ ] Loki datasource provisioned
- [ ] Dashboards provisioned (6 JSON files)
- [ ] Public domain **enabled**

**Validate:**
- [ ] Login works with admin credentials
- [ ] Datasources show healthy (green) in Settings → Datasources
- [ ] Dashboards load without broken panels
- [ ] Platform Overview shows service health data

**Gate:** If datasources fail, fix provisioning files and redeploy. Do NOT manually configure datasources in the UI — manual click-ops are how future-you gets betrayed.

---

## Phase 5 — Backend Integration

### Step 8: Deploy `/api/alerts/ingest`

**Required pieces:**
- [ ] Endpoint exists at `POST /api/alerts/ingest`
- [ ] Auth token validation (`Authorization: Bearer <ALERT_INGEST_TOKEN>`)
- [ ] Payload validation (AlertManager webhook format)
- [ ] Dedupe by fingerprint
- [ ] Persistence to `infrastructure_alerts` table
- [ ] Resolved alert handling
- [ ] Logs on ingest success/failure

**Validate:**
```bash
curl -X POST http://backend.railway.internal:8000/api/alerts/ingest \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {"alertname": "TestAlert", "severity": "info", "service": "deploy-test"},
      "annotations": {"summary": "Deploy validation test", "description": "Testing alert ingest"},
      "startsAt": "2026-03-08T12:00:00Z",
      "fingerprint": "deploy-test-001"
    }]
  }'
# Expected: 2xx response
```

**DB validation:**
- [ ] Row inserted in `infrastructure_alerts`
- [ ] Severity stored correctly
- [ ] Fingerprint stored
- [ ] Status = `firing`
- [ ] Timestamps handled correctly

---

## Phase 6 — Connect the Platform Plumbing

### Step 9: Configure Railway log drain

**Only now.** Not before.

**Checklist:**
- [ ] Railway Project Settings → Log Drains → Add HTTP Drain
- [ ] Target: `https://<log-relay-domain>/drain`
- [ ] Secret header configured (if Railway supports custom headers)
- [ ] Log-relay reachable
- [ ] Loki healthy

**Validate:**
- [ ] Generate a known app log (hit any backend endpoint)
- [ ] Confirm it reaches log-relay (check relay logs)
- [ ] Confirm it appears in Loki
- [ ] Confirm it's queryable in Grafana Logs Explorer

**Expected latency:** Under 10s.

### Step 10: Enable real alert routes and verify

**Prerequisites met:**
- [ ] Prometheus targets are healthy
- [ ] AlertManager is up
- [ ] Backend ingest exists and works

**Validate:**
```bash
# Option A: Force a test alert via Prometheus (temporary always-firing rule)
# Option B: Use amtool if available
# Option C: Trigger a real condition (e.g., create 151+ DB connections)
```

**Confirm:**
- [ ] Alert appears in AlertManager UI
- [ ] Webhook hits backend
- [ ] DB row created in `infrastructure_alerts`
- [ ] If Activity Command Centre is live, event appears there

---

## Smoke Tests

Run these after full deployment.

### Smoke 1 — Log Pipeline
1. Emit a known backend error log
2. Verify log-relay received it
3. Verify Loki stored it
4. Verify Grafana Logs Explorer can query it

### Smoke 2 — Metrics Pipeline
1. Check Prometheus sees: postgres-exporter, redis-exporter, loki, alertmanager
2. Verify dashboard panels populate with real data

### Smoke 3 — Alert Pipeline
1. Create temporary test alert rule
2. AlertManager fires
3. Backend ingest receives it
4. DB row created
5. Clean up test alert rule

### Smoke 4 — Restart Tolerance
1. Restart Loki → verify log-relay handles temporary failure gracefully (buffers, retries)
2. Restart Prometheus → verify volume persistence (data survives restart)
3. Restart Grafana → verify datasources and dashboards persist (provisioned, not manual)

---

## Validation Checklist by Component

| Component | Check | Pass |
|-----------|-------|------|
| **Loki** | `/ready` returns OK | [ ] |
| **Loki** | Receives logs from relay | [ ] |
| **Loki** | Retention config loaded | [ ] |
| **Loki** | No filesystem permission errors | [ ] |
| **log-relay** | Health endpoint OK | [ ] |
| **log-relay** | Rejects bad secret | [ ] |
| **log-relay** | Accepts valid payload | [ ] |
| **log-relay** | Forwards to Loki successfully | [ ] |
| **log-relay** | Handles malformed JSON safely | [ ] |
| **Prometheus** | `/targets` shows expected jobs | [ ] |
| **Prometheus** | Exporters UP | [ ] |
| **Prometheus** | Self-scrape UP | [ ] |
| **Prometheus** | Rules loaded without syntax errors | [ ] |
| **AlertManager** | Config valid | [ ] |
| **AlertManager** | Routes active | [ ] |
| **AlertManager** | Inhibition works | [ ] |
| **AlertManager** | Webhook delivery successful | [ ] |
| **postgres-exporter** | Metrics present | [ ] |
| **postgres-exporter** | `pg_up` = 1 | [ ] |
| **redis-exporter** | Metrics present | [ ] |
| **redis-exporter** | `redis_up` = 1 | [ ] |
| **Grafana** | Login works | [ ] |
| **Grafana** | Prometheus datasource green | [ ] |
| **Grafana** | Loki datasource green | [ ] |
| **Grafana** | Dashboards render | [ ] |
| **Backend ingest** | Accepts valid alert | [ ] |
| **Backend ingest** | Rejects bad auth | [ ] |
| **Backend ingest** | Stores rows | [ ] |
| **Backend ingest** | Dedupes repeat alerts | [ ] |
| **Backend ingest** | Handles resolved events | [ ] |

---

## Day-of Deploy Batches

### Batch 1
Deploy: **Loki**, **log-relay**
Validate fully before touching log drain.

### Batch 2
Deploy: **Prometheus**, **AlertManager**, **postgres-exporter**, **redis-exporter**
Validate internal metrics scrape.

### Batch 3
Deploy: **Grafana**
Validate dashboards and datasources.

### Batch 4
Deploy: **backend ingest endpoint** + DB migration
Validate alert persistence.

### Batch 5
Configure: **Railway log drain**, test alerts, dashboard review, retention review.

---

## Common Railway Gotchas

### 1. Wrong internal hostnames
Be exact: `service-name.railway.internal`. No creativity. No vibes. Exact strings.

### 2. Missing volumes
Prometheus/Loki/Grafana without persistence behave like goldfish with amnesia.

### 3. Public/private confusion
Keep: Grafana public, log-relay public. **Everything else private.**

### 4. Env var reference mistakes
Railway variable interpolation (`${{service.VAR}}`) is handy, but if one reference is wrong, exporters just quietly die in a corner.

### 5. Config file mount/path mismatch
Very common. If the container starts with default config instead of yours, you'll lose half a day wondering why none of your rules exist.

### 6. Alert storms
Do NOT enable all alert routes before: ingestion works, inhibition works, thresholds are sane. Otherwise you've built a machine for sending yourself stress.

---

## What to Defer If Time Gets Tight

**Defer:**
- Fancy dashboards / non-essential panels
- Advanced alert tuning
- Log-derived alert rules (Loki ruler)
- Agent-triggered investigation workflows
- Anything OpenTelemetry-shaped

**Keep the core:**
- Logs in Loki
- Metrics in Prometheus
- Dashboards in Grafana
- Alerts through AlertManager
- Backend ingest working

That's a successful v1.

---

## Rollback Points

| After Batch | Rollback if... | Action |
|-------------|---------------|--------|
| Batch 1 | Loki won't start | Check volume + config. Delete and recreate service. |
| Batch 1 | log-relay can't reach Loki | Verify internal DNS. Check LOKI_PUSH_URL. |
| Batch 2 | Prometheus config invalid | Fix YAML, redeploy. Rules syntax: `promtool check rules rules/*.yml` |
| Batch 2 | Exporters can't auth | Fix env var references. Check Railway variable interpolation. |
| Batch 3 | Grafana datasources broken | Fix provisioning YAML, redeploy. Never fix in UI. |
| Batch 4 | Ingest endpoint errors | Check migration ran. Check auth token matches. |
| Batch 5 | Log drain floods relay | Add rate limiting or temporarily disable drain. |
