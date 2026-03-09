#!/bin/bash
set -euo pipefail

echo "=== Automatos Monitoring — Health Check ==="
echo ""

PASS=0
FAIL=0

check_service() {
    local name="$1"
    local url="$2"

    if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
        echo "  [OK]   $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name ($url)"
        FAIL=$((FAIL + 1))
    fi
}

echo "Services:"
check_service "Prometheus"       "http://localhost:${PROMETHEUS_PORT:-9090}/-/healthy"
check_service "Grafana"          "http://localhost:${GRAFANA_PORT:-3030}/api/health"
check_service "Loki"             "http://localhost:${LOKI_PORT:-3100}/ready"
check_service "AlertManager"     "http://localhost:${ALERTMANAGER_PORT:-9093}/-/healthy"
check_service "Log Relay"        "http://localhost:${LOG_RELAY_PORT:-3200}/health"
check_service "Postgres Exporter" "http://localhost:${PG_EXPORTER_PORT:-9187}/metrics"
check_service "Redis Exporter"   "http://localhost:${REDIS_EXPORTER_PORT:-9121}/metrics"

echo ""
echo "Prometheus Targets:"
TARGETS=$(curl -sf "http://localhost:${PROMETHEUS_PORT:-9090}/api/v1/targets" 2>/dev/null)
if [ -n "$TARGETS" ]; then
    echo "$TARGETS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for target in data.get('data', {}).get('activeTargets', []):
    status = target.get('health', 'unknown')
    job = target.get('labels', {}).get('job', 'unknown')
    icon = '[OK]' if status == 'up' else '[DOWN]'
    print(f'  {icon}  {job} ({status})')
" 2>/dev/null || echo "  Could not parse targets"
else
    echo "  Could not reach Prometheus"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
    exit 1
fi
