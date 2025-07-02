#!/bin/bash
# Test complete monitoring integration

set -e

echo "🧪 XplainCrypto Monitoring Integration Test"
echo "=========================================="

# Test all components
components=(
    "prometheus:http://localhost:9090/-/healthy:Prometheus is Healthy"
    "grafana:http://localhost:3000/api/health:database.*ok"
    "alertmanager:http://localhost:9093/-/healthy:Alertmanager is Healthy"
    "pushgateway:http://localhost:9091/metrics:push_gateway"
    "redis_exporter:http://localhost:9121/metrics:redis_"
    "node_exporter:http://localhost:9100/metrics:node_"
)

all_passed=true

for component in "${components[@]}"; do
    IFS=':' read -r name url pattern <<< "$component"
    
    echo -n "Testing $name... "
    
    if response=$(curl -s "$url" 2>/dev/null) && echo "$response" | grep -q "$pattern"; then
        echo "✅"
    else
        echo "❌"
        all_passed=false
    fi
done

# Test dashboard accessibility
echo ""
echo "📊 Testing Dashboard Access:"

dashboards=(
    "infrastructure-testing"
    "n8n-workflow-execution"
    "platform-status-comprehensive"
    "xplaincrypto-overview"
)

for dashboard in "${dashboards[@]}"; do
    echo -n "Testing $dashboard dashboard... "
    
    if curl -s "http://localhost:3000/d/$dashboard" | grep -q "XplainCrypto"; then
        echo "✅"
    else
        echo "❌"
        all_passed=false
    fi
done

# Test metrics ingestion
echo ""
echo "📈 Testing Metrics Ingestion:"

# Run enhanced metrics collection
if python3 monitoring/enhanced-n8n-exporter.py; then
    echo "✅ Enhanced metrics collection successful"
else
    echo "❌ Enhanced metrics collection failed"
    all_passed=false
fi

# Check if metrics appear in Prometheus
sleep 5
echo -n "Testing metrics in Prometheus... "
if curl -s "http://localhost:9090/api/v1/query?query=n8n_server_up" | grep -q '"result"'; then
    echo "✅"
else
    echo "❌"
    all_passed=false
fi

echo ""
if [[ "$all_passed" == true ]]; then
    echo "🎉 All monitoring integration tests PASSED!"
    echo ""
    echo "🚀 Your XplainCrypto monitoring is fully operational:"
    echo "  📊 Dashboards: http://localhost:3000"
    echo "  📈 Prometheus: http://localhost:9090" 
    echo "  🚨 Alerts: http://localhost:9093"
    exit 0
else
    echo "❌ Some monitoring integration tests FAILED!"
    echo "Please check the logs above and fix any issues."
    exit 1
fi 