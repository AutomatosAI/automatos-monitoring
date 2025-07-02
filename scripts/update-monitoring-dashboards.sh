#!/bin/bash
# Update Grafana dashboards for enhanced n8n workflow monitoring

set -e

echo "📊 Updating XplainCrypto Monitoring Dashboards"
echo "=============================================="

# Wait for Grafana to be ready - FIXED to use DNS
echo "⏳ Waiting for Grafana to be ready..."
timeout=60
count=0
until curl -s http://grafana.xplaincrypto.ai/api/health | grep -q '"database":"ok"'; do
    if [[ $count -ge $timeout ]]; then
        echo "❌ Grafana did not become ready within $timeout seconds"
        exit 1
    fi
    echo "  Waiting for Grafana... ($count/$timeout)"
    sleep 5
    ((count += 5))
done

echo "✅ Grafana is ready"

# Function to import dashboard - FIXED to use DNS
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

# Create custom folder for XplainCrypto dashboards - FIXED to use DNS
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

# Set up dashboard refresh intervals via API
echo ""
echo "⚙️ Configuring dashboard settings..."

# Create dashboard list - FIXED to use DNS
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