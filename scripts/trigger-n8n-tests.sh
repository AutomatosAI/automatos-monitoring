#!/bin/bash
# Trigger infrastructure tests via n8n workflows

echo "🤖 Triggering Infrastructure Tests via n8n"
echo "=========================================="

N8N_BASE="http://n8n.xplaincrypto.ai"

# Function to trigger workflow
trigger_workflow() {
    local workflow_name="$1"
    local webhook_path="$2"
    
    echo "🔄 Triggering: $workflow_name"
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"trigger":"infrastructure_test","source":"remote_mac"}' \
        "$N8N_BASE$webhook_path" 2>/dev/null || echo "failed")
    
    if [[ "$response" != "failed" ]]; then
        echo "✅ $workflow_name triggered successfully"
    else
        echo "❌ Failed to trigger $workflow_name"
    fi
    
    sleep 2
}

# Trigger test workflows in order
trigger_workflow "Infrastructure Health Check" "/webhook/health-check"
trigger_workflow "Complete Infrastructure Test" "/webhook/test-infrastructure"
trigger_workflow "Deploy Infrastructure" "/webhook/deploy-infrastructure"

echo ""
echo "✅ All workflows triggered! Check n8n.xplaincrypto.ai for results" 