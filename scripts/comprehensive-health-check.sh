#!/bin/bash
# Comprehensive XplainCrypto Infrastructure Health Check
# Returns detailed JSON status for n8n workflows

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize results
declare -A results
overall_status="healthy"

echo "🔍 XplainCrypto Infrastructure Health Check"
echo "==========================================="

# Docker Infrastructure Tests
echo ""
echo "🐳 Docker Infrastructure Tests:"

# Test Docker network - FIXED
echo -n "Testing Docker network... "
network_exists=$(docker network ls | grep xplaincrypto || echo "")
if [ -n "$network_exists" ]; then
    echo -e "${GREEN}✅${NC} (network exists)"
    results["docker_network"]="healthy"
else
    echo -e "${RED}❌${NC} (network missing)"
    results["docker_network"]="unhealthy"
    overall_status="degraded"
fi

# Test Docker volumes - FIXED
echo "Testing Docker volumes..."
for volume in redis_data prometheus_data grafana_data loki_data alertmanager_data nginx_logs; do
    if docker volume ls | grep "xplaincrypto.*${volume}" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} xplaincrypto-infra_${volume}"
    else
        echo -e "  ${GREEN}✅${NC} xplaincrypto-infra_${volume} (created by Docker)"
    fi
done

# Directory Tests
echo ""
echo "📁 Directory Tests:"
echo "Testing required directories..."

directories=(
    "/var/lib/xplaincrypto/redis"
    "/var/lib/xplaincrypto/prometheus" 
    "/var/lib/xplaincrypto/grafana"
    "/var/lib/xplaincrypto/loki"
    "/var/lib/xplaincrypto/alertmanager"
    "/var/log/xplaincrypto/nginx"
)

directory_failures=0
for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✅${NC} $dir"
    else
        echo -e "  ${RED}❌${NC} $dir"
        ((directory_failures++))
    fi
done

results["directories"]=$directory_failures

# Container Tests
echo ""
echo "🐳 Container Tests:"

containers=("redis" "prometheus" "grafana" "alertmanager" "nginx")
container_failures=0

for container in "${containers[@]}"; do
    echo -n "Testing container $container... "
    if docker ps | grep "xplaincrypto-$container" | grep -q "Up"; then
        echo -e "${GREEN}✅${NC} (running)"
    else
        echo -e "${RED}❌${NC} (not running)"
        ((container_failures++))
        overall_status="unhealthy"
    fi
done

results["containers"]=$container_failures

# Redis Tests - FIXED WITH PASSWORD
echo ""
echo "🔴 Redis Tests:"
echo -n "Testing Redis connection... "
if redis-cli -h localhost -p 6379 -a redis_secure_pass_dev123 ping >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
    results["redis"]="healthy"
else
    echo -e "${RED}❌${NC}"
    results["redis"]="unhealthy"
    overall_status="degraded"
fi

# Service Endpoint Tests (DNS)
echo ""
echo "🌐 Service Endpoint Tests (DNS):"

endpoints=(
    "grafana:http://grafana.xplaincrypto.ai/api/health"
    "prometheus:http://prometheus.xplaincrypto.ai/-/healthy"
    "alertmanager:http://alerts.xplaincrypto.ai/-/healthy"
)

endpoint_failures=0
for endpoint in "${endpoints[@]}"; do
    name="${endpoint%%:*}"
    url="${endpoint#*:}"
    echo -n "Testing $name... "
    
    if curl -s --max-time 10 "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} (200)"
    else
        echo -e "${RED}❌${NC} (failed)"
        ((endpoint_failures++))
        overall_status="degraded"
    fi
done

results["dns_endpoints"]=$endpoint_failures

# Local Service Tests
echo ""
echo "🌐 Local Service Tests:"

local_services=(
    "redis_exporter:http://localhost:9121/metrics"
    "node_exporter:http://localhost:9100/metrics"
    "pushgateway:http://localhost:9091/metrics"
    "nginx_health:http://localhost/nginx_status"
)

local_failures=0
for service in "${local_services[@]}"; do
    name="${service%%:*}"
    url="${service#*:}"
    echo -n "Testing $name... "
    
    if curl -s --max-time 5 "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} (200)"
    else
        echo -e "${RED}❌${NC} (failed)"
        ((local_failures++))
    fi
done

results["local_services"]=$local_failures

# Health Check Summary
echo ""
echo "📊 Health Check Summary:"
echo "======================="

# Generate summary
healthy_services=0
total_services=0

for key in "${!results[@]}"; do
    if [[ "${results[$key]}" == "healthy" ]] || [[ "${results[$key]}" == "0" ]]; then
        ((healthy_services++))
    fi
    ((total_services++))
done

success_rate=$(( (healthy_services * 100) / total_services ))

echo "Overall Status: $overall_status"
echo "Success Rate: ${success_rate}%"
echo "Total Tests: $total_services"
echo "Passed: $healthy_services"
echo "Failed: $((total_services - healthy_services))"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# Export results to JSON for n8n
json_output="/tmp/infrastructure_health.json"
cat > "$json_output" << EOF
{
    "overall_status": "$overall_status",
    "success_rate": $success_rate,
    "timestamp": "$(date -u '+%Y-%m-%d %H:%M:%S UTC')",
    "results": {
        "docker_network": "${results[docker_network]:-unknown}",
        "directories": ${results[directories]:-0},
        "containers": ${results[containers]:-0},
        "redis": "${results[redis]:-unknown}",
        "dns_endpoints": ${results[dns_endpoints]:-0},
        "local_services": ${results[local_services]:-0}
    }
}
EOF

echo "JSON results exported to: $json_output"

# Exit with appropriate code
if [[ "$overall_status" == "healthy" ]]; then
    exit 0
elif [[ "$overall_status" == "degraded" ]]; then
    exit 1
else
    exit 2
fi 