#!/bin/bash
# XplainCrypto Infrastructure Health Check

echo "🔍 XplainCrypto Infrastructure Health Check"
echo "========================================="

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    local expected_code=${3:-200}
    
    echo -n "Checking $service_name... "
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_code"; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

# Check Redis
echo -n "Checking Redis... "
if docker exec xplaincrypto-redis redis-cli --no-auth-warning -a redis_secure_pass_dev123 ping | grep -q PONG; then
    echo "✅ OK"
else
    echo "❌ FAILED"
fi

# Check web services
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"
check_service "AlertManager" "http://localhost:9093/-/healthy"
check_service "Node Exporter" "http://localhost:9100/metrics"
check_service "Redis Exporter" "http://localhost:9121/metrics"
check_service "Pushgateway" "http://localhost:9091/metrics"

echo ""
echo "Health check complete!"
