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

# Step 2: Wait for services to be ready
echo ""
echo "⏳ Step 2: Waiting for Services"
echo "Waiting for Grafana to be fully ready..."
timeout=120
count=0
until curl -s http://localhost:3000/api/health | grep -q '"database":"ok"'; do
    if [[ $count -ge $timeout ]]; then
        echo "❌ Grafana did not become ready within $timeout seconds"
        exit 1
    fi
    echo "  Waiting for Grafana... ($count/$timeout)"
    sleep 5
    ((count += 5))
done

# Step 3: Update dashboards
echo ""
echo "📊 Step 3: Dashboard Deployment"
./scripts/update-monitoring-dashboards.sh

# Step 4: Setup enhanced metrics collection
echo ""
echo "📈 Step 4: Enhanced Metrics Setup"
if [[ -f "monitoring/enhanced-n8n-exporter.py" ]]; then
    sudo ./scripts/setup-enhanced-monitoring.sh
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
echo "  🏗️ Infrastructure Testing:  http://localhost:3000/d/infrastructure-testing"
echo "  🤖 n8n Workflow Execution: http://localhost:3000/d/n8n-workflow-execution"
echo "  📈 Platform Status:        http://localhost:3000/d/platform-status-comprehensive"
echo "  ⭐ XplainCrypto Overview:   http://localhost:3000/d/xplaincrypto-overview"
echo "  🧠 AI Agents Performance:  http://localhost:3000/d/ai-agents-performance"
echo ""
echo "🌍 DNS Access (if configured):"
echo "  Grafana:     http://grafana.xplaincrypto.ai"
echo "  Prometheus:  http://prometheus.xplaincrypto.ai"
echo "  Alerts:      http://alerts.xplaincrypto.ai"
echo ""
echo "🔧 Monitoring Services:"
echo "  Prometheus:  http://localhost:9090"
echo "  AlertManager: http://localhost:9093"
echo "  Pushgateway: http://localhost:9091"
echo ""
echo "✅ All monitoring components are now active!" 