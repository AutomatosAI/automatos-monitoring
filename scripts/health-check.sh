#!/bin/bash
# XplainCrypto Infrastructure Health Check

echo "🩺 XplainCrypto Infrastructure Health Check"
echo "==========================================="

# Check Redis
echo -n "🔴 Redis: "
if docker exec xplaincrypto-redis redis-cli -a redis_secure_pass_dev123 ping >/dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

# Check Prometheus
echo -n "📊 Prometheus: "
if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

# Check Grafana
echo -n "📈 Grafana: "
if curl -f http://localhost:3000/api/health >/dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

echo ""
echo "📊 Container Status:"
docker-compose ps
