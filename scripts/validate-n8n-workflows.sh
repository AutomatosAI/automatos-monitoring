#!/bin/bash
# Validate n8n workflow execution order and dependencies

set -e

echo "🔄 XplainCrypto n8n Workflow Validation"
echo "======================================"

N8N_URL="http://206.81.0.227:5678"

# Function to check workflow status
check_workflow() {
    local workflow_name="$1"
    local webhook_path="$2"
    
    echo -n "Validating workflow '$workflow_name'... "
    
    # Check if webhook endpoint exists
    response=$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL$webhook_path" 2>/dev/null || echo "000")
    
    if [[ "$response" == "405" || "$response" == "200" ]]; then
        echo -e "✅ Ready"
        return 0
    else
        echo -e "❌ Not accessible ($response)"
        return 1
    fi
}

# Workflow execution order validation
echo ""
echo "📋 Workflow Execution Order Validation:"
echo ""

# Phase 1: Infrastructure Setup
echo "🏗️  Phase 1: Infrastructure Setup"
check_workflow "manual-deploy-infrastructure" "/webhook/deploy-infrastructure"
check_workflow "manual-deploy-core-infra" "/webhook/deploy-core-infra"

# Phase 2: Service Deployment  
echo ""
echo "🚀 Phase 2: Service Deployment"
check_workflow "manual-deploy-mindsdb" "/webhook/deploy-mindsdb"
check_workflow "manual-deploy-fastapi" "/webhook/deploy-fastapi"
check_workflow "manual-deploy-user-database" "/webhook/deploy-user-database"

# Phase 3: Monitoring & Maintenance
echo ""
echo "📊 Phase 3: Monitoring & Maintenance"
check_workflow "scheduled-health-check-every-5min" "/webhook/health-check"
check_workflow "scheduled-backup-daily-2am" "/webhook/backup-daily"
check_workflow "monitoring-log-collector" "/webhook/collect-logs"

# Phase 4: Error Handling
echo ""
echo "🚨 Phase 4: Error Handling"
check_workflow "when-error-then-send-alerts" "/webhook/error-alert"
check_workflow "manual-restore-from-backup" "/webhook/restore-backup"

echo ""
echo "✅ Workflow validation completed"

# Generate workflow dependency map
cat > /tmp/workflow_execution_order.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "execution_phases": {
    "phase_1_infrastructure": [
      "manual-deploy-infrastructure",
      "manual-deploy-core-infra"
    ],
    "phase_2_services": [
      "manual-deploy-mindsdb",
      "manual-deploy-fastapi", 
      "manual-deploy-user-database"
    ],
    "phase_3_monitoring": [
      "scheduled-health-check-every-5min",
      "scheduled-backup-daily-2am",
      "monitoring-log-collector"
    ],
    "phase_4_maintenance": [
      "when-error-then-send-alerts",
      "manual-restore-from-backup"
    ]
  },
  "recommended_order": [
    "Infrastructure first",
    "Then core services", 
    "Enable monitoring",
    "Configure error handling"
  ]
}
EOF

echo "📄 Execution order guide: /tmp/workflow_execution_order.json" 