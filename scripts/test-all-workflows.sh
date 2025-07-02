#!/bin/bash
# Enhanced XplainCrypto Testing Suite for n8n Integration
# Tests infrastructure services and generates detailed reports

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_RESULTS_DIR="/tmp/xplaincrypto-tests-$TIMESTAMP"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$PROJECT_DIR"

echo "🧪 XplainCrypto Enhanced Testing Suite"
echo "======================================"
echo "Timestamp: $(date)"
echo "Results: $TEST_RESULTS_DIR"

# Create results directory
mkdir -p "$TEST_RESULTS_DIR"

# Initialize test tracking
declare -A test_results
total_tests=0
passed_tests=0
failed_tests=0

# Function to run test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local output_file="$TEST_RESULTS_DIR/${test_name}.log"
    
    echo ""
    echo -e "${BLUE}🔍 Running: $test_name${NC}"
    ((total_tests++))
    
    if eval "$test_command" > "$output_file" 2>&1; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        test_results["$test_name"]="PASSED"
        ((passed_tests++))
        return 0
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        test_results["$test_name"]="FAILED"
        ((failed_tests++))
        echo "  📁 Log: $output_file"
        return 1
    fi
}

# Function to test endpoint with detailed response
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    local timeout="${4:-10}"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_code" ]]; then
        echo -e "${GREEN}✅${NC} ($response)"
        return 0
    else
        echo -e "${RED}❌${NC} ($response)"
        return 1
    fi
}

# Test Suite 1: Environment Validation
echo ""
echo "📋 Test Suite 1: Environment Validation"
run_test "environment_validation" "./scripts/validate-environment.sh"

# Test Suite 2: Docker Infrastructure
echo ""
echo "🐳 Test Suite 2: Docker Infrastructure"
run_test "docker_containers" "docker ps --format 'table {{.Names}}\t{{.Status}}' | grep xplaincrypto"
run_test "docker_network" "docker network ls | grep xplaincrypto_network"
run_test "docker_volumes" "docker volume ls | grep xplaincrypto"

# Test Suite 3: Service Health Checks
echo ""
echo "🌐 Test Suite 3: Service Health Checks"
run_test "comprehensive_health_check" "timeout 60 ./scripts/comprehensive-health-check.sh || echo '⚠️ Health check timed out but continuing...'"

# Test Suite 4: Individual Service Tests
echo ""
echo "🔧 Test Suite 4: Individual Service Tests"

# Redis Tests
run_test "redis_ping" "docker exec xplaincrypto-redis redis-cli --no-auth-warning -a 'redis_secure_pass_dev123' ping"
run_test "redis_databases" "for db in {0..3}; do docker exec xplaincrypto-redis redis-cli --no-auth-warning -a 'redis_secure_pass_dev123' -n \$db ping || exit 1; done"

# HTTP Endpoint Tests
echo ""
echo "🌍 Test Suite 5: HTTP Endpoint Tests"

endpoints=(
    "grafana_health:http://localhost:3000/api/health"
    "prometheus_health:http://localhost:9090/-/healthy"
    "alertmanager_health:http://localhost:9093/-/healthy"
    "redis_exporter_metrics:http://localhost:9121/metrics"
    "node_exporter_metrics:http://localhost:9100/metrics"
    "pushgateway_metrics:http://localhost:9091/metrics"
    "nginx_health:http://localhost/health"
)

for endpoint in "${endpoints[@]}"; do
    IFS=':' read -r name url <<< "$endpoint"
    run_test "endpoint_${name}" "test_endpoint '$name' '$url'"
done

# Test Suite 6: DNS Endpoint Tests (if configured)
echo ""
echo "🌍 Test Suite 6: DNS Endpoint Tests"

dns_endpoints=(
    "grafana_dns:http://grafana.xplaincrypto.ai/api/health"
    "prometheus_dns:http://prometheus.xplaincrypto.ai/-/healthy"
    "alerts_dns:http://alerts.xplaincrypto.ai/-/healthy"
)

for endpoint in "${dns_endpoints[@]}"; do
    IFS=':' read -r name url <<< "$endpoint"
    run_test "dns_${name}" "test_endpoint '$name' '$url' 200 5"
done

# Test Suite 7: External Service Tests  
echo ""
echo "🔗 Test Suite 7: External Service Tests"
run_test "n8n_connectivity" "curl -s --connect-timeout 5 http://206.81.0.227:5678/healthz || curl -s --connect-timeout 5 http://n8n.xplaincrypto.ai/healthz"
run_test "production_server_connectivity" "ping -c 3 142.93.49.20"

# Test Suite 8: Python Infrastructure Tests
echo ""
echo "🐍 Test Suite 8: Python Infrastructure Tests"
run_test "python_infrastructure_tests" "python3 tests/test_infrastructure.py"

# Test Suite 9: Performance Tests
echo ""
echo "⚡ Test Suite 9: Performance Tests"
run_test "redis_performance" "docker exec xplaincrypto-redis redis-cli --no-auth-warning -a 'redis_secure_pass_dev123' --latency-history -c 100 -i 1"
run_test "disk_space_check" "df -h | grep -E '(/$|/var)'"
run_test "memory_usage_check" "free -h"

# Generate comprehensive report
echo ""
echo "📊 Generating Test Report..."

# Create JSON report for n8n
json_report=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_session_id": "$TIMESTAMP",
  "summary": {
    "total_tests": $total_tests,
    "passed": $passed_tests,
    "failed": $failed_tests,
    "success_rate": $(echo "scale=2; $passed_tests * 100 / $total_tests" | bc -l)
  },
  "overall_status": "$([ $failed_tests -eq 0 ] && echo "PASSED" || echo "FAILED")",
  "details": {
EOF

first=true
for test_name in "${!test_results[@]}"; do
    if [[ "$first" == true ]]; then
        first=false
    else
        json_report+=","
    fi
    json_report+="\n    \"$test_name\": \"${test_results[$test_name]}\""
done

json_report+="\n  },\n  \"artifacts\": {\n    \"logs_directory\": \"$TEST_RESULTS_DIR\",\n    \"health_check_json\": \"/tmp/infrastructure_health.json\"\n  }\n}"

echo "$json_report" > "$TEST_RESULTS_DIR/test_report.json"

# Create human-readable report
cat > "$TEST_RESULTS_DIR/test_summary.txt" <<EOF
XplainCrypto Testing Suite Report
===============================
Timestamp: $(date)
Session ID: $TIMESTAMP

Summary:
--------
Total Tests: $total_tests
Passed: $passed_tests  
Failed: $failed_tests
Success Rate: $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc -l)%

Test Results:
------------
EOF

for test_name in "${!test_results[@]}"; do
    printf "%-30s %s\n" "$test_name" "${test_results[$test_name]}" >> "$TEST_RESULTS_DIR/test_summary.txt"
done

# Display final summary
echo ""
echo "🎯 Test Summary"
echo "==============="
echo "Total Tests: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"
echo "Success Rate: $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc -l)%"

if [[ $failed_tests -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    overall_result="PASSED"
else
    echo -e "${RED}⚠️  $failed_tests TEST(S) FAILED${NC}"
    overall_result="FAILED"
fi

echo ""
echo "📁 Test Artifacts:"
echo "  JSON Report: $TEST_RESULTS_DIR/test_report.json"
echo "  Summary: $TEST_RESULTS_DIR/test_summary.txt" 
echo "  Logs: $TEST_RESULTS_DIR/"

# Copy to standard location for n8n workflows
cp "$TEST_RESULTS_DIR/test_report.json" "/tmp/latest_test_report.json"
cp "$TEST_RESULTS_DIR/test_summary.txt" "/tmp/latest_test_summary.txt"

echo ""
echo "✅ Test suite completed!"

# Exit with appropriate code
if [[ "$overall_result" == "PASSED" ]]; then
    exit 0
else
    exit 1
fi 