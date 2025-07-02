#!/bin/bash
# Simple health check for n8n monitoring

# Test core services
redis_status=$(docker-compose exec -T redis redis-cli --no-auth-warning -a redis_secure_pass_dev123 ping 2>/dev/null | grep -q PONG && echo "✅" || echo "❌")
grafana_status=$(curl -s http://localhost:3000/api/health | grep -q '"database":"ok"' && echo "✅" || echo "❌")
prometheus_status=$(curl -s http://localhost:9090/-/healthy | grep -q "Prometheus is Healthy" && echo "✅" || echo "❌")

echo "Redis: $redis_status | Grafana: $grafana_status | Prometheus: $prometheus_status"
