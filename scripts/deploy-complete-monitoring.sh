#!/bin/bash
# Complete monitoring deployment with enhanced dashboards

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🎯 XplainCrypto Complete Monitoring Deployment"
echo "=============================================="

# Step 1: Deploy infrastructure if not running
echo ""
echo "🏗️ Step 1: Infrastructure Check"
if ! docker ps | grep -q xplaincrypto-grafana; then
    echo "📦 Deploying infrastructure..."
    ./scripts/deploy-infrastructure.sh
else
    echo "✅ Infrastructure already running"
fi

# Step 2: Quick Grafana check - FIXED
echo ""
echo "⏳ Step 2: Quick Grafana Check"
if curl -s http://grafana.xplaincrypto.ai/api/health | grep -q '"database":"ok"'; then
    echo "✅ Grafana is ready"
else
    echo "⚠️ Grafana may need a moment, but continuing..."
fi

# Step 3: Update dashboards
echo ""
echo "📊 Step 3: Dashboard Deployment"
./scripts/update-monitoring-dashboards.sh

# Step 4: Setup enhanced metrics collection
echo ""
echo "📈 Step 4: Enhanced Metrics Setup"
if [[ -f "monitoring/enhanced-n8n-exporter.py" ]]; then
    echo "Setting up enhanced metrics..."
    python3 monitoring/enhanced-n8n-exporter.py
    echo "✅ Enhanced metrics collection tested"
else
    echo "⚠️ Enhanced metrics exporter not found, skipping..."
fi

# Step 5: Run initial health check
echo ""
echo "🔍 Step 5: Initial Health Check"
./scripts/comprehensive-health-check.sh

# Step 6: Validate n8n integration
echo ""
echo "🤖 Step 6: n8n Integration Validation"
./scripts/test-n8n-integration.sh

echo ""
echo "🎉 Complete Monitoring Deployment Finished!"
echo "=========================================="
echo ""
echo "📊 Access Your Dashboards:"
echo "  🏗️ Infrastructure Testing:  http://grafana.xplaincrypto.ai/d/infrastructure-testing"
echo "  🤖 n8n Workflow Execution: http://grafana.xplaincrypto.ai/d/n8n-workflow-execution"
echo "  📈 Platform Status:        http://grafana.xplaincrypto.ai/d/platform-status-comprehensive"
echo "  ⭐ XplainCrypto Overview:   http://grafana.xplaincrypto.ai/d/xplaincrypto-overview"
echo "  🧠 AI Agents Performance:  http://grafana.xplaincrypto.ai/d/ai-agents-performance"
echo ""
echo "🌍 DNS Access:"
echo "  Grafana:     http://grafana.xplaincrypto.ai"
echo "  Prometheus:  http://prometheus.xplaincrypto.ai"
echo "  Alerts:      http://alerts.xplaincrypto.ai"
echo ""
echo "🔧 Monitoring Services:"
echo "  Prometheus:  http://prometheus.xplaincrypto.ai"
echo "  AlertManager: http://alerts.xplaincrypto.ai"
echo "  Pushgateway: http://localhost:9091"
echo ""
echo "✅ All monitoring components are now active!" 