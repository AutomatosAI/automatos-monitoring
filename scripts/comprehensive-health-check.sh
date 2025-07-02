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

# Function to test HTTP endpoint
test_http_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    echo -n "Testing $name... "
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null); then
        if [[ "$response" == "$expected_code" ]]; then
            echo -e "${GREEN}✅${NC} ($response)"
            results["$name"]="healthy"
        else
            echo -e "${RED}❌${NC} (HTTP $response)"
            results["$name"]="unhealthy"
            overall_status="degraded"
        fi
    else
        echo -e "${RED}❌${NC} (connection failed)"
        results["$name"]="unreachable"
        overall_status="degraded"
    fi
}

# Function to test Docker container
test_container() {
    local name="$1"
    local container_name="$2"
    
    echo -n "Testing container $name... "
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name.*Up"; then
        echo -e "${GREEN}✅${NC} (running)"
        results["container_$name"]="running"
    else
        echo -e "${RED}❌${NC} (not running)"
        results["container_$name"]="stopped"
        overall_status="degraded"
    fi
}

# Function to test Redis
test_redis() {
    echo -n "Testing Redis connection... "
    
    if docker exec xplaincrypto-redis redis-cli --no-auth-warning -a "redis_secure_pass_dev123" ping 2>/dev/null | grep -q "PONG"; then
        echo -e "${GREEN}✅${NC}"
        results["redis"]="healthy"
        
        # Test Redis databases
        echo -n "Testing Redis databases... "
        db_count=0
        for db in {0..3}; do
            if docker exec xplaincrypto-redis redis-cli --no-auth-warning -a "redis_secure_pass_dev123" -n "$db" ping 2>/dev/null | grep -q "PONG"; then
                ((db_count++))
            fi
        done
        
        if [[ $db_count -eq 4 ]]; then
            echo -e "${GREEN}✅${NC} (0-3 accessible)"
            results["redis_databases"]="healthy"
        else
            echo -e "${YELLOW}⚠️${NC} (only $db_count/4 accessible)"
            results["redis_databases"]="partial"
        fi
    else
        echo -e "${RED}❌${NC}"
        results["redis"]="unhealthy"
        overall_status="degraded"
    fi
}

# Function to test directories
test_directories() {
    echo "Testing required directories..."
    
    directories=(
        "/var/lib/xplaincrypto/redis"
        "/var/lib/xplaincrypto/prometheus" 
        "/var/lib/xplaincrypto/grafana"
        "/var/lib/xplaincrypto/loki"
        "/var/lib/xplaincrypto/alertmanager"
        "/var/log/xplaincrypto/nginx"
    )
    
    missing_dirs=()
    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            echo -e "  ${GREEN}✅${NC} $dir"
        else
            echo -e "  ${RED}❌${NC} $dir (missing)"
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        results["directories"]="healthy"
    else
        results["directories"]="missing_dirs"
        overall_status="degraded"
    fi
}

# Function to test Docker network
test_network() {
    echo -n "Testing Docker network... "
    
    if docker network ls | grep -q "xplaincrypto"; then
        echo -e "${GREEN}✅${NC}"
        results["network"]="healthy"
    else
        echo -e "${RED}❌${NC} (network missing)"
        results["network"]="missing"
        overall_status="degraded"
    fi
}

# Function to test volumes
test_volumes() {
    echo "Testing Docker volumes..."
    
    expected_volumes=(
        "xplaincrypto-infra_redis_data"
        "xplaincrypto-infra_prometheus_data"
        "xplaincrypto-infra_grafana_data"
        "xplaincrypto-infra_loki_data"
        "xplaincrypto-infra_alertmanager_data"
        "xplaincrypto-infra_nginx_logs"
    )
    
    for volume in "${expected_volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            echo -e "  ${GREEN}✅${NC} $volume"
        else
            echo -e "  ${YELLOW}⚠️${NC} $volume (will be created on startup)"
        fi
    done
    
    results["volumes"]="healthy"
}

# Run all tests
echo ""
echo "🐳 Docker Infrastructure Tests:"
test_network
test_volumes

echo ""
echo "📁 Directory Tests:"
test_directories

echo ""
echo "🐳 Container Tests:"
test_container "redis" "xplaincrypto-redis"
test_container "prometheus" "xplaincrypto-prometheus"
test_container "grafana" "xplaincrypto-grafana"
test_container "alertmanager" "xplaincrypto-alertmanager"
test_container "nginx" "xplaincrypto-nginx"

echo ""
echo "🔴 Redis Tests:"
test_redis

echo ""
echo "🌐 Service Endpoint Tests (DNS):"
test_http_endpoint "grafana" "http://grafana.xplaincrypto.ai/api/health"
test_http_endpoint "prometheus" "http://prometheus.xplaincrypto.ai/-/healthy"
test_http_endpoint "alertmanager" "http://alerts.xplaincrypto.ai/-/healthy"

echo ""
echo "🌐 Local Service Tests:"
test_http_endpoint "redis_exporter" "http://localhost:9121/metrics"
test_http_endpoint "node_exporter" "http://localhost:9100/metrics"
test_http_endpoint "pushgateway" "http://localhost:9091/metrics"
test_http_endpoint "nginx_health" "http://localhost/health"

# Generate JSON output for n8n
echo ""
echo "📊 Health Check Summary:"
echo "======================="

# Count healthy vs unhealthy
healthy_count=0
total_count=0

for key in "${!results[@]}"; do
    ((total_count++))
    if [[ "${results[$key]}" == "healthy" || "${results[$key]}" == "running" ]]; then
        ((healthy_count++))
    fi
done

echo "Status: $overall_status"
echo "Healthy: $healthy_count/$total_count"

# Create JSON output file for n8n
json_output=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overall_status": "$overall_status",
  "healthy_services": $healthy_count,
  "total_services": $total_count,
  "details": {
EOF

first=true
for key in "${!results[@]}"; do
    if [[ "$first" == true ]]; then
        first=false
    else
        json_output+=","
    fi
    json_output+="\n    \"$key\": \"${results[$key]}\""
done

json_output+="\n  }\n}"

echo "$json_output" > /tmp/infrastructure_health.json

echo ""
echo "📄 JSON report saved to: /tmp/infrastructure_health.json"

# Exit with appropriate code
if [[ "$overall_status" == "healthy" ]]; then
    exit 0
else
    exit 1
fi 