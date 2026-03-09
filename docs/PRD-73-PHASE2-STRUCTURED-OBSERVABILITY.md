# PRD-73 Phase 2: Structured Observability & Predictive Alerting

**Version:** 1.0
**Status:** Active
**Priority:** P0
**Author:** Gar Kavanagh + Auto CTO
**Created:** 2026-03-09
**Dependencies:** PRD-73 Phase 1 (COMPLETE — Stack Deployed), PRD-55 (Agent Heartbeats), PRD-72 (Activity Command Centre)
**Repository:** `automatos-monitoring` (clients + log-relay) + `automatos-ai` (backend integration)

---

## Executive Summary

Phase 1 deployed the observability stack — 7 Railway services running, Prometheus scraping, Grafana rendering, AlertManager routing. But the logs are dumb. Flat text lines with `service` and `level` labels. No workspace context, no request tracing, no error fingerprinting, no way to correlate a user's bug report with the exact log trail.

Phase 2 makes logs **intelligent**. Every log entry carries structured context: workspace_id, user_id, agent_id, request_id, method, module, error fingerprints. The log-relay promotes these to Loki labels. LogQL alerting rules detect patterns — error spikes, repeated failures, token abuse, slow API trends — and fire into AlertManager before users notice. SENTINEL agents pull correlated logs from Loki to auto-diagnose issues.

### What We're Building

1. **Structured Log Enrichment** — Every log carries workspace_id, user_id, agent_id, request_id, method, correlation_id, error fingerprint, stack trace hash
2. **Smart Label Promotion** — Log-relay extracts high-value fields as Loki labels for fast filtering while keeping cardinality under control
3. **Error Fingerprinting** — Hash of exception type + file + function → group identical errors, detect repeats, track resolution
4. **LogQL Alert Rules** — Loki ruler fires alerts on log patterns: error spikes, OOM, auth failures, token abuse, slow trends
5. **Loki Query API** — Backend endpoint for SENTINEL to pull logs programmatically by workspace, service, time range, error fingerprint
6. **Dataflow Tracing** — Correlation IDs flow across service boundaries, enabling full request tracing without OpenTelemetry

### What This Enables

- **Automated bug detection**: Error fingerprint appears 5x in 10 minutes → alert fires → SENTINEL pulls stack traces → creates bug report
- **Token abuse detection**: Workspace exceeds token budget → alert fires → SENTINEL investigates usage patterns
- **Predictive degradation**: p95 latency trending up → alert fires before SLA breach
- **One-click debugging**: Click workspace_id in Grafana → see every log, every request, every error for that tenant
- **Thin API detection**: Endpoint returning empty/minimal responses → log pattern analysis catches it

---

## 1. Structured Log Schema

Every log entry shipped to log-relay follows this schema:

### 1.1 Log Entry Format (Client → Log-Relay)

```json
{
  "service": "automatos-backend",
  "level": "error",
  "message": "Failed to execute agent heartbeat",
  "timestamp": 1741500000.123,
  "context": {
    "request_id": "req_abc123",
    "correlation_id": "corr_xyz789",
    "workspace_id": "ws_550e8400-e29b",
    "user_id": "user_clerk_abc",
    "agent_id": "cto",
    "method": "POST",
    "path": "/api/agents/heartbeat",
    "module": "orchestrator.consumers.heartbeat",
    "function": "execute_heartbeat",
    "lineno": 142
  },
  "error": {
    "type": "ConnectionRefusedError",
    "message": "Connection refused: redis.railway.internal:6379",
    "fingerprint": "a1b2c3d4e5f6",
    "stack_hash": "f6e5d4c3b2a1",
    "traceback": "Traceback (most recent call last):\n  File ..."
  },
  "metrics": {
    "duration_ms": 1523,
    "tokens_in": 0,
    "tokens_out": 0
  }
}
```

### 1.2 Loki Label Strategy

Labels are indexed — high cardinality kills Loki. We promote only bounded fields:

| Field | Loki Label | Cardinality | Rationale |
|-------|-----------|-------------|-----------|
| `service` | `service` | ~5 | Core dimension |
| `level` | `level` | 5 | debug/info/warning/error/critical |
| `environment` | `environment` | 3 | dev/staging/production |
| `source` | `source` | 2 | direct-push / railway-drain |
| `module` | `module` | ~30 | Top-level module (not full path) |
| `method` | `method` | 7 | HTTP method |
| `error.type` | `error_type` | ~20 | Exception class name |

**NOT promoted to labels** (query via log line parsing):
- `workspace_id` — unbounded (thousands of workspaces)
- `user_id` — unbounded
- `request_id` — unique per request
- `agent_id` — low cardinality but changes over time
- `error.fingerprint` — used in log line, queryable via `|= "fingerprint=abc"`
- `path` — semi-bounded but can explode with dynamic segments

### 1.3 Structured Log Line Format

The log-relay formats the Loki log line as structured JSON for parsing:

```
{"msg":"Failed to execute agent heartbeat","ctx":{"rid":"req_abc123","cid":"corr_xyz789","ws":"ws_550e8400","uid":"user_clerk_abc","aid":"cto","path":"/api/agents/heartbeat","fn":"execute_heartbeat:142"},"err":{"type":"ConnectionRefusedError","fp":"a1b2c3d4e5f6","tb":"Traceback..."},"dur":1523}
```

This enables LogQL queries like:
```logql
{service="automatos-backend", level="error"} | json | ctx_ws="ws_550e8400"
{service="automatos-backend"} | json | err_fp="a1b2c3d4e5f6" | count_over_time([5m]) > 5
```

---

## 2. Error Fingerprinting

### 2.1 Fingerprint Algorithm

```python
fingerprint = sha256(f"{exception_type}:{file_path}:{function_name}").hexdigest()[:12]
```

Same exception in the same function = same fingerprint, regardless of:
- Error message content (which may contain variable data)
- Timestamp
- User/workspace context

### 2.2 Stack Hash

```python
stack_hash = sha256(normalized_traceback_frames).hexdigest()[:12]
```

Captures the full call path. Two different functions hitting the same underlying error get different stack hashes but may share the same root cause.

### 2.3 Use Cases

| Pattern | Detection | Action |
|---------|-----------|--------|
| Same fingerprint 5x in 10m | LogQL alert rule | SENTINEL investigates |
| New fingerprint (never seen) | LogQL alert rule | Flag as new bug |
| Fingerprint resolved then returns | LogQL correlation | Regression detection |
| Fingerprint concentrated in 1 workspace | LogQL grouping | Tenant-specific issue |

---

## 3. LogQL Alert Rules

### 3.1 Loki Ruler Configuration

Added to `services/loki/loki-config.yaml`:

```yaml
ruler:
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /loki/rules-temp
  alertmanager_url: http://alertmanager.railway.internal:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
```

### 3.2 Alert Rules

```yaml
# /loki/rules/automatos/alerts.yml
groups:
  - name: error-detection
    rules:
      - alert: ErrorSpike
        expr: |
          sum(count_over_time({service=~".+"} |= "ERROR" [5m])) by (service) > 50
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Error spike in {{ $labels.service }}"
          description: "{{ $labels.service }} logged >50 errors in 5 minutes"

      - alert: CriticalErrorBurst
        expr: |
          sum(count_over_time({level="error"} | json | err_type!="" [2m])) by (service) > 20
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Critical error burst in {{ $labels.service }}"
          description: "{{ $labels.service }} threw >20 exceptions in 2 minutes"

      - alert: RepeatedError
        expr: |
          sum(count_over_time({level="error"} | json | err_fp!="" [10m])) by (service, err_fp) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Repeated error fingerprint in {{ $labels.service }}"
          description: "Error fingerprint {{ $labels.err_fp }} appeared >10 times in 10 minutes"

  - name: security-detection
    rules:
      - alert: AuthFailureSpike
        expr: |
          sum(count_over_time({service="automatos-backend"} |= "401" [5m])) > 20
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Authentication failure spike"
          description: ">20 auth failures in 5 minutes — possible brute force or token expiry"

      - alert: TokenAbuseDetected
        expr: |
          sum(count_over_time({service="automatos-backend"} | json | ctx_path="/api/chat" [1h])) by (ctx_ws) > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Excessive API usage from workspace {{ $labels.ctx_ws }}"
          description: "Workspace {{ $labels.ctx_ws }} made >1000 chat requests in 1 hour"

  - name: infrastructure-logs
    rules:
      - alert: OOMDetected
        expr: |
          count_over_time({service=~".+"} |~ "(?i)(oom|out of memory|killed)" [5m]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "OOM detected in {{ $labels.service }}"
          description: "Out-of-memory condition detected in service logs"

      - alert: DatabaseConnectionExhaustion
        expr: |
          count_over_time({service="automatos-backend"} |~ "(?i)(connection pool|too many connections|connection refused.*5432)" [5m]) > 3
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Database connection exhaustion"
          description: "Backend logging repeated database connection failures"

      - alert: RedisConnectionFailure
        expr: |
          count_over_time({service=~".+"} |~ "(?i)(redis.*connection refused|redis.*timeout|ECONNREFUSED.*6379)" [5m]) > 3
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Redis connection failures detected"
          description: "Multiple Redis connection failures in service logs"

  - name: performance-prediction
    rules:
      - alert: SlowEndpointTrend
        expr: |
          avg(avg_over_time({service="automatos-backend", level="info"} | json | dur > 0 | unwrap dur [15m])) by (ctx_path) > 5000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Slow endpoint trend: {{ $labels.ctx_path }}"
          description: "Average response time >5s for {{ $labels.ctx_path }} over 15 minutes"

      - alert: ThinAPIResponse
        expr: |
          count_over_time({service="automatos-backend"} | json | ctx_path=~"/api/.*" | dur < 10 | line_format "{{.msg}}" |~ "(?i)(empty|no data|not found|null)" [15m]) > 20
        for: 5m
        labels:
          severity: info
        annotations:
          summary: "Possible thin API responses on {{ $labels.ctx_path }}"
          description: "Endpoint returning empty/null responses frequently — possible broken integration"
```

---

## 4. Loki Query API (for SENTINEL)

### 4.1 New Backend Endpoint

```
GET /api/logs/query
Authorization: Bearer <ALERT_INGEST_TOKEN>
```

**Query Parameters:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `query` | string | Yes | LogQL query |
| `start` | ISO8601 | No | Start time (default: 1h ago) |
| `end` | ISO8601 | No | End time (default: now) |
| `limit` | int | No | Max entries (default: 100, max: 1000) |
| `direction` | string | No | `backward` (default) or `forward` |

**Convenience Parameters (build LogQL automatically):**

| Param | Type | Description |
|-------|------|-------------|
| `workspace_id` | string | Filter by workspace |
| `service` | string | Filter by service label |
| `level` | string | Filter by log level |
| `error_fingerprint` | string | Filter by error fingerprint |
| `request_id` | string | Filter by request ID |

**Response:**

```json
{
  "status": "ok",
  "results": [
    {
      "timestamp": "2026-03-09T10:30:00Z",
      "labels": {"service": "automatos-backend", "level": "error"},
      "message": "...",
      "parsed": {"workspace_id": "ws_abc", "error_type": "ConnectionError", ...}
    }
  ],
  "stats": {
    "entries_scanned": 1523,
    "entries_returned": 42,
    "query_time_ms": 89
  }
}
```

### 4.2 SENTINEL Integration

When an alert fires, SENTINEL:

1. Reads the alert from `infrastructure_alerts` table
2. Calls `/api/logs/query` with relevant filters:
   - For `ErrorSpike`: `service={service}, level=error, last 15m`
   - For `RepeatedError`: `error_fingerprint={fp}, last 30m`
   - For `TokenAbuseDetected`: `workspace_id={ws}, last 2h`
3. Groups errors by fingerprint
4. Identifies root cause pattern
5. Writes investigation report to `infrastructure_alerts.agent_response`
6. Creates bug report if new fingerprint detected

---

## 5. Dataflow Tracing

### 5.1 Correlation ID Flow

```
Browser → Backend (generates correlation_id) → Worker (passes correlation_id) → Agent (passes correlation_id)
```

Every log entry in the chain carries the same `correlation_id`. Query in Grafana:

```logql
{service=~".+"} | json | ctx_cid="corr_xyz789"
```

Returns the complete request lifecycle across all services.

### 5.2 Request Context Middleware

The backend's FastAPI middleware (already exists in `logging_adapter.py`) sets ContextVars:

```python
# Already defined:
request_id_var    # Unique per request
workflow_id_var   # Workflow execution ID
agent_id_var      # Agent performing work
tenant_id_var     # Workspace/tenant ID

# New in Phase 2:
correlation_id_var  # Flows across service boundaries
method_var          # HTTP method
path_var            # Request path
```

The `LogRelayHandler` auto-captures these ContextVars — no `extra={}` needed at call sites.

---

## 6. Detection Patterns

### 6.1 What We Can Detect

| Pattern | Detection Method | Alert |
|---------|-----------------|-------|
| **Error spike** | `count_over_time({level="error"} [5m]) > 50` | ErrorSpike |
| **Same bug recurring** | Error fingerprint count > threshold | RepeatedError |
| **New bug introduced** | New fingerprint not seen in last 7d | NewErrorDetected |
| **Regression** | Fingerprint that was resolved reappears | RegressionDetected |
| **Token abuse** | Chat requests per workspace per hour | TokenAbuseDetected |
| **Brute force** | Auth failures per IP/workspace | AuthFailureSpike |
| **OOM kill** | Log pattern match | OOMDetected |
| **DB connection exhaustion** | Connection refused pattern | DatabaseConnectionExhaustion |
| **Redis failure** | Connection timeout pattern | RedisConnectionFailure |
| **Slow endpoint trend** | Average duration trending up | SlowEndpointTrend |
| **Thin API response** | Empty/null response pattern | ThinAPIResponse |
| **Workspace-specific degradation** | Errors concentrated in 1 workspace | WorkspaceDegradation |

### 6.2 Future Detections (Phase 3)

- **Cost anomaly**: Token spend per workspace trending 3x above historical average
- **Agent loop detection**: Agent making circular tool calls (same tool, same args, repeated)
- **Memory leak trend**: RSS growing linearly over hours without plateau
- **Query plan regression**: PostgreSQL log analysis showing seq scans on indexed columns
- **Rate limit approaching**: Request rate per workspace trending toward limit

---

## 7. Implementation Tasks

### 7.1 Monitoring Repo (`automatos-monitoring`)

| Task | Priority | File(s) |
|------|----------|---------|
| Upgrade `automatos_logging.py` — ContextVar capture, error fingerprinting, structured context | P0 | `clients/python/automatos_logging.py` |
| Upgrade log-relay — label promotion, structured log lines, new fields | P0 | `services/log-relay/main.py` |
| Add Loki ruler config | P0 | `services/loki/loki-config.yaml` |
| Add LogQL alert rules | P0 | `services/loki/rules/automatos/alerts.yml` |
| Add Loki ruler entrypoint flags | P1 | `services/loki/entrypoint.sh` |
| Update Grafana log explorer dashboard with structured queries | P1 | `services/grafana/dashboards/logs-explorer.json` |

### 7.2 Backend Repo (`automatos-ai`)

| Task | Priority | File(s) |
|------|----------|---------|
| Copy upgraded `automatos_logging.py` to `core/monitoring/` | P0 | `orchestrator/core/monitoring/automatos_logging.py` |
| Add correlation_id middleware | P0 | `orchestrator/api/main.py` |
| Wire ContextVars into request lifecycle | P0 | `orchestrator/core/utils/logging_adapter.py` |
| Add `/api/logs/query` endpoint (Loki proxy) | P1 | `orchestrator/core/monitoring/automatos_logs_api.py` |
| Instrument agent consumers with structured logging | P1 | `orchestrator/consumers/` |
| Instrument LLM calls with token tracking | P1 | `orchestrator/modules/llm/` |

---

## 8. Success Criteria

| Metric | Target |
|--------|--------|
| Every log entry carries workspace_id when available | 100% of authenticated requests |
| Error fingerprint generated for all exceptions | 100% of ERROR/CRITICAL logs |
| LogQL alerts fire within 5 minutes of pattern | < 5 minute detection latency |
| Grafana log query by workspace_id returns results | < 2s query time |
| Correlation ID traces complete request lifecycle | Across backend + worker |
| SENTINEL can pull logs via API for investigation | `/api/logs/query` operational |
| Zero high-cardinality labels in Loki | < 50 unique values per label |

---

## 9. Relationship to Phase 1

| Phase 1 (COMPLETE) | Phase 2 (THIS PRD) |
|--------------------|--------------------|
| Flat log lines with service + level | Structured JSON with full context |
| Prometheus metric alerts only | LogQL pattern-based alerts |
| Manual Grafana log browsing | Workspace-scoped log queries |
| Alert fires → stored in DB | Alert fires → SENTINEL investigates → bug report |
| No error grouping | Fingerprint-based error deduplication |
| No cross-service tracing | Correlation ID across services |
| Health check monitoring | Predictive degradation detection |
