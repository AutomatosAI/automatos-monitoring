#!/bin/bash
# Update Grafana dashboards for enhanced n8n workflow monitoring

set -e

echo "📊 Updating XplainCrypto Monitoring Dashboards"
echo "=============================================="

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
until curl -s http://localhost:3000/api/health | grep -q '"database":"ok"'; do
    echo "  Waiting for Grafana..."
    sleep 5
done

echo "✅ Grafana is ready"

# Dashboard update function
update_dashboard() {
    local dashboard_name="$1"
    local dashboard_file="$2"
    
    echo "📈 Updating dashboard: $dashboard_name"
    
    # Import dashboard via API (basic auth: admin/grafana_admin_dev123)
    curl -X POST \
        -H "Content-Type: application/json" \
        -u admin:grafana_admin_dev123 \
        -d @"$dashboard_file" \
        "http://localhost:3000/api/dashboards/db" \
        2>/dev/null || echo "  ⚠️ Dashboard import may have failed"
}

# Update all dashboards
if [[ -d "monitoring/grafana/dashboards" ]]; then
    for dashboard in monitoring/grafana/dashboards/*.json; do
        if [[ -f "$dashboard" ]]; then
            dashboard_name=$(basename "$dashboard" .json)
            update_dashboard "$dashboard_name" "$dashboard"
        fi
    done
fi

echo ""
echo "✅ Dashboard updates completed"
echo "🌍 Access Grafana: http://localhost:3000 (admin/grafana_admin_dev123)" 