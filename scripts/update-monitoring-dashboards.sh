#!/bin/bash
# Update Grafana dashboards for enhanced n8n workflow monitoring

set -e

echo "📊 Updating XplainCrypto Monitoring Dashboards"
echo "=============================================="

# Read actual Grafana password from secrets (permanent fix)
GRAFANA_PASSWORD=$(cat /opt/secrets/xplaincrypto/grafana_admin_password.txt)
echo "Using Grafana password from secrets"

# Quick Grafana check - FIXED
echo "⏳ Quick Grafana check..."
if curl -s -u admin:$GRAFANA_PASSWORD http://grafana.xplaincrypto.ai/api/health >/dev/null 2>&1; then
    echo "✅ Grafana accessible via DNS"
else
    echo "❌ Grafana not accessible via DNS"
fi

echo "📁 Managing XplainCrypto folder..."
FOLDER_UID="xplaincryptofolder"
GRAFANA_URL="http://grafana.xplaincrypto.ai"
if ! curl -u admin:$GRAFANA_PASSWORD -f -s "$GRAFANA_URL/api/folders/$FOLDER_UID" > /dev/null; then
  curl -u admin:$GRAFANA_PASSWORD -X POST -H 'Content-Type: application/json' -d '{"uid": "$FOLDER_UID", "title": "XplainCrypto"}' $GRAFANA_URL/api/folders || echo "Folder creation failed"
else
  curl -u admin:$GRAFANA_PASSWORD -X PUT -H 'Content-Type: application/json' -d '{"uid": "$FOLDER_UID", "title": "XplainCrypto", "overwrite": true}' $GRAFANA_URL/api/folders/$FOLDER_UID || echo "Folder update failed"
fi

# Install dependencies quietly
pip install requests --quiet

# Import all dashboards
echo ""
echo "📊 Importing dashboards..."

# Cleanup old dashboards to avoid duplicates 
echo "🧹 Cleaning up existing dashboards..." 
dash_uids=$(curl -u admin:$GRAFANA_PASSWORD -s $GRAFANA_URL/api/search?folderIds=0 | jq -r '.[] | select(.folderUid == "$FOLDER_UID") | .uid') 
for uid in $dash_uids; do 
  curl -u admin:$GRAFANA_PASSWORD -X DELETE $GRAFANA_URL/api/dashboards/uid/$uid || echo "Failed to delete $uid" 
done 

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
        jq '.dashboard.folder = "$FOLDER_UID" | .dashboard.title |= (if . == null or . == "" then "Untitled Dashboard" else . end)' "$dashboard_file" | curl -u admin:$GRAFANA_PASSWORD -X POST -H 'Content-Type: application/json' -d @- "$GRAFANA_URL/api/dashboards/db" || echo "⚠️ Import failed for $(basename $dashboard_file)"
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