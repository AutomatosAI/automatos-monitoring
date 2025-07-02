#!/bin/bash
# XplainCrypto Infrastructure Automated Deployment
# Complete deployment with validation and monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🚀 XplainCrypto Infrastructure Automated Deployment"
echo "=================================================="

# Step 1: Validate environment
echo ""
echo "📋 Step 1: Environment Validation"
if ./scripts/validate-environment.sh; then
    echo "✅ Environment validation passed"
else
    echo "❌ Environment validation failed - aborting deployment"
    exit 1
fi

# Step 2: Create required directories
echo ""
echo "📁 Step 2: Directory Setup"
if sudo ./scripts/create-required-directories.sh; then
    echo "✅ Directories created successfully"
else
    echo "❌ Directory creation failed - aborting deployment"
    exit 1
fi

# Step 3: Check for existing containers
echo ""
echo "🐳 Step 3: Container Cleanup"
existing_containers=$(docker ps -a --format "{{.Names}}" | grep "xplaincrypto-" || true)

if [[ -n "$existing_containers" ]]; then
    echo "⚠️  Found existing XplainCrypto containers:"
    echo "$existing_containers"
    
    read -p "Remove existing containers? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🧹 Removing existing containers..."
        docker-compose down -v --remove-orphans 2>/dev/null || true
        
        # Force remove any remaining containers
        echo "$existing_containers" | while read container; do
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        done
        
        echo "✅ Cleanup complete"
    else
        echo "❌ Cannot proceed with existing containers - aborting"
        exit 1
    fi
else
    echo "✅ No existing containers found"
fi

# Step 4: Deploy infrastructure
echo ""
echo "🚀 Step 4: Infrastructure Deployment"
echo "Starting Docker Compose deployment..."

if docker-compose up -d; then
    echo "✅ Docker Compose deployment successful"
else
    echo "❌ Docker Compose deployment failed"
    exit 1
fi

# Step 5: Wait for services to start
echo ""
echo "⏳ Step 5: Waiting for Services"
echo "Waiting 30 seconds for services to initialize..."
sleep 30

# Step 6: Health check
echo ""
echo "🔍 Step 6: Health Verification"
if ./scripts/comprehensive-health-check.sh; then
    echo "✅ Health check passed"
    deployment_status="success"
else
    echo "⚠️  Some services may not be fully ready yet"
    deployment_status="partial"
fi

# Step 7: Display access information
echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "📊 Service Access URLs:"
echo "  Grafana:     http://localhost:3000 (admin/grafana_admin_dev123)"
echo "  Prometheus:  http://localhost:9090"
echo "  AlertManager: http://localhost:9093" 
echo "  Redis:       localhost:6379 (password: redis_secure_pass_dev123)"
echo ""
echo "🌍 DNS URLs (if configured):"
echo "  Grafana:     http://grafana.xplaincrypto.ai"
echo "  Prometheus:  http://prometheus.xplaincrypto.ai"
echo "  Alerts:      http://alerts.xplaincrypto.ai"
echo ""
echo "🗄️  Redis Database Allocation:"
echo "  Database 0: MindsDB cache"
echo "  Database 1: User sessions"  
echo "  Database 2: FastAPI operations"
echo "  Database 3: n8n workflows"
echo ""
echo "📁 Data Persistence:"
echo "  All data is persisted in /var/lib/xplaincrypto/"
echo "  Logs are stored in /var/log/xplaincrypto/"
echo ""

if [[ "$deployment_status" == "success" ]]; then
    echo "✅ All services are healthy and ready!"
    exit 0
else
    echo "⚠️  Deployment completed but some services need more time"
    echo "   Run './scripts/comprehensive-health-check.sh' in a few minutes"
    exit 0
fi 