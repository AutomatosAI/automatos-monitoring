# Automatos Monitoring Stack

Infrastructure observability for the [Automatos AI Platform](https://github.com/Automatos-AI-Platform/automatos-ai).

**PRD:** [PRD-73 — Observability & Monitoring Stack](../automatos-ai/docs/PRDS/73-OBSERVABILITY-MONITORING-STACK.md)

## Architecture

| Service | Purpose | Port |
|---------|---------|------|
| Prometheus | Metrics collection & alerting rules | 9090 |
| Grafana | Dashboards & visualisation | 3030 |
| Loki | Log aggregation | 3100 |
| Log Relay | Railway log drain → Loki transformer | 3200 |
| AlertManager | Alert routing to backend webhook | 9093 |
| Postgres Exporter | PostgreSQL metrics for Prometheus | 9187 |
| Redis Exporter | Redis metrics for Prometheus | 9121 |

## Quick Start (Local)

### Prerequisites

- Docker & Docker Compose
- `automatos_network` Docker network (created by automatos-ai)
- automatos-ai services running (postgres, redis, backend)

### Setup

```bash
# 1. Create .env from template
cp .env.example .env
# Edit .env with your database/redis passwords

# 2. Ensure the shared network exists
docker network create automatos_network 2>/dev/null || true

# 3. Start the stack
docker compose up -d

# 4. Access Grafana
open http://localhost:3030
# Login: admin / <your GRAFANA_ADMIN_PASSWORD>
```

### Verify

```bash
# Check all services are healthy
docker compose ps

# Prometheus targets
open http://localhost:9090/targets

# AlertManager status
open http://localhost:9093
```

## Railway Deployment

Each service deploys as a separate Railway service within the same project. See `railway/` directory for service configs.

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and link to project
railway login
railway link

# Deploy each service
railway up --service prometheus
railway up --service grafana
railway up --service loki
railway up --service log-relay
railway up --service alertmanager
railway up --service postgres-exporter
railway up --service redis-exporter
```

### Railway Log Drain Setup

After deploying the log-relay service:

1. Get the log-relay public URL from Railway dashboard
2. Go to Railway Project Settings → Log Drains
3. Add HTTP Drain with the log-relay URL + `/drain` path
4. Set the shared secret header

## Dashboards

| Dashboard | Description |
|-----------|-------------|
| Platform Overview | Service health matrix, active alerts, error count |
| Database Health | PostgreSQL connections, cache hit ratio, dead tuples |
| Redis & Queues | Memory usage, ops/sec, evicted keys, client count |
| Agent Performance | Heartbeat success rates, execution stats (Phase 2) |
| Workspace Worker | Task queue depth, throughput, errors (Phase 2) |
| Logs Explorer | Filterable log viewer with volume charts |

## Alert Routing

Alerts flow: Prometheus → AlertManager → Backend API webhook → Agent self-healing

| Severity | Group Wait | Repeat | Action |
|----------|-----------|--------|--------|
| Critical | 10s | 1h | Triggers self-healing agent heartbeat |
| Warning | 60s | 4h | Surfaces in Activity Command Centre |
| Info | 5m | 12h | Logged only |

## File Structure

```
automatos-monitoring/
├── docker-compose.yml              # Local development
├── .env.example
├── services/log-relay/             # Railway log drain → Loki
├── monitoring/
│   ├── prometheus/                 # Scrape config + alert rules
│   ├── grafana/                    # Provisioning + dashboards
│   ├── loki/                       # Log storage config
│   └── alertmanager/               # Alert routing
├── railway/                        # Railway service configs
└── scripts/                        # Setup & health checks
```
# automatos-monitoring
