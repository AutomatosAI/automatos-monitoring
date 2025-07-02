#!/bin/bash
# Update Grafana dashboards for enhanced n8n workflow monitoring

set -e

echo "📊 Updating XplainCrypto Monitoring Dashboards"
echo "=============================================="

# Quick Grafana check - FIXED
echo "⏳ Quick Grafana check..."
if curl -s http://grafana.xplaincrypto.ai/api/health >/dev/null 2>&1; then
    echo "✅ Grafana accessible via DNS"
else
    echo "❌ Grafana not accessible via DNS"
fi

# Function to import dashboard
import_dashboard() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)
    
    echo "📈 Importing dashboard: $dashboard_name"
    
    # Prepare the dashboard JSON for import
    local dashboard_json=$(cat "$dashboard_file")
    local import_payload=$(cat <<EOF
{
  "dashboard": $dashboard_json,
  "overwrite": true,
  "inputs": [],
  "folderId": 0
}
EOF
)
    
    # Import dashboard via API using DNS
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u admin:grafana_admin_dev123 \
        -d "$import_payload" \
        "http://grafana.xplaincrypto.ai/api/dashboards/import" 2>/dev/null || echo '{"status":"error"}')
    
    if echo "$response" | grep -q '"status":"success"'; then
        echo "  ✅ Successfully imported $dashboard_name"
    else
        echo "  ⚠️ Import may have failed for $dashboard_name"
    fi
}

# Create custom folder for XplainCrypto dashboards
echo ""
echo "📁 Creating XplainCrypto folder..."
folder_payload='{"title":"XplainCrypto","uid":"xplaincrypto"}'
curl -s -X POST \
    -H "Content-Type: application/json" \
    -u admin:grafana_admin_dev123 \
    -d "$folder_payload" \
    "http://grafana.xplaincrypto.ai/api/folders" 2>/dev/null || echo "Folder may already exist"

# Import all dashboards
echo ""
echo "📊 Importing dashboards..."

dashboard_files=(
    "monitoring/grafana/dashboards/infrastructure-testing.json"
    "monitoring/grafana/dashboards/n8n-workflow-execution.json" 
    "monitoring/grafana/dashboards/platform-status-comprehensive.json"
    "monitoring/grafana/dashboards/xplaincrypto-overview.json"
    "monitoring/grafana/dashboards/ai-agents-performance.json"
    "monitoring/grafana/dashboards/crypto-overview.json"
    "monitoring/grafana/dashboards/n8n-monitoring.json"
    "monitoring/grafana/dashboards/n8n-workflows.json"
)

for dashboard_file in "${dashboard_files[@]}"; do
    if [[ -f "$dashboard_file" ]]; then
        import_dashboard "$dashboard_file"
    else
        echo "  ⚠️ Dashboard file not found: $dashboard_file"
    fi
done

echo ""
echo "📋 Available Dashboards:"
echo "  🏗️  Infrastructure Testing: http://grafana.xplaincrypto.ai/d/infrastructure-testing"
echo "  🤖 n8n Workflow Execution: http://grafana.xplaincrypto.ai/d/n8n-workflow-execution"
echo "  📊 Platform Status: http://grafana.xplaincrypto.ai/d/platform-status-comprehensive"
echo "  ⭐ XplainCrypto Overview: http://grafana.xplaincrypto.ai/d/xplaincrypto-overview"
echo "  🧠 AI Agents Performance: http://grafana.xplaincrypto.ai/d/ai-agents-performance"
echo "  💰 Crypto Overview: http://grafana.xplaincrypto.ai/d/crypto-overview"

echo ""
echo "✅ Dashboard updates completed"
echo "🌍 Access Grafana: http://grafana.xplaincrypto.ai (admin/grafana_admin_dev123)" 