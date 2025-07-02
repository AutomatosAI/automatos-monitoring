#!/bin/bash
# Continuous service monitoring for n8n workflows

set -e

MONITOR_DURATION="${1:-300}"  # Default 5 minutes
INTERVAL="${2:-30}"           # Default 30 seconds

echo "📊 XplainCrypto Service Monitoring"
echo "================================="
echo "Duration: ${MONITOR_DURATION}s"
echo "Interval: ${INTERVAL}s"

MONITOR_LOG="/tmp/service_monitor_$(date +%Y%m%d_%H%M%S).log"

echo "timestamp,redis_status,grafana_status,prometheus_status,alertmanager_status,nginx_status,memory_usage,cpu_usage" > "$MONITOR_LOG"

start_time=$(date +%s)
end_time=$((start_time + MONITOR_DURATION))

while [[ $(date +%s) -lt $end_time ]]; do
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Check service statuses - FIXED TO USE DNS
    redis_status=$(docker exec xplaincrypto-redis redis-cli --no-auth-warning -a "redis_secure_pass_dev123" ping 2>/dev/null | grep -q "PONG" && echo "UP" || echo "DOWN")
    grafana_status=$(curl -s http://grafana.xplaincrypto.ai/api/health | grep -q '"database":"ok"' && echo "UP" || echo "DOWN")
    prometheus_status=$(curl -s http://prometheus.xplaincrypto.ai/-/healthy | grep -q "Prometheus is Healthy" && echo "UP" || echo "DOWN")
    alertmanager_status=$(curl -s http://alerts.xplaincrypto.ai/-/healthy | grep -q "Alertmanager is Healthy" && echo "UP" || echo "DOWN")
    nginx_status=$(curl -s http://localhost/health | grep -q "healthy" && echo "UP" || echo "DOWN")
    
    # Get system metrics
    memory_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    
    # Log metrics
    echo "$timestamp,$redis_status,$grafana_status,$prometheus_status,$alertmanager_status,$nginx_status,$memory_usage,$cpu_usage" >> "$MONITOR_LOG"
    
    # Console output
    echo "$(date +%H:%M:%S) | Redis:$redis_status | Grafana:$grafana_status | Prometheus:$prometheus_status | AlertMgr:$alertmanager_status | Nginx:$nginx_status | Mem:${memory_usage}% | CPU:${cpu_usage}%"
    
    sleep "$INTERVAL"
done

echo ""
echo "✅ Monitoring completed"
echo "📊 Results: $MONITOR_LOG"

# Generate summary
total_checks=$(( MONITOR_DURATION / INTERVAL ))
echo ""
echo "📈 Monitoring Summary:"
echo "  Duration: ${MONITOR_DURATION}s"
echo "  Checks: $total_checks"
echo "  Log file: $MONITOR_LOG" 