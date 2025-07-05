#!/bin/bash

# XplainCrypto Development Monitoring Deployment
# Simple script to deploy enhanced monitoring for DEV environment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

main() {
    log "🚀 Starting XplainCrypto DEV Monitoring Deployment"
    echo "=================================================="
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ Please run this script from the xplaincrypto-infra directory"
        exit 1
    fi
    
    # Stop existing containers
    log "Stopping existing containers..."
    docker-compose down --remove-orphans || true
    
    # Start the enhanced monitoring stack
    log "Starting enhanced monitoring stack..."
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to initialize..."
    sleep 30
    
    # Check service health
    log "Checking service health..."
    
    services=("prometheus:9090" "grafana:3000" "alertmanager:9093" "redis:6379")
    failed_services=()
    
    for service_port in "${services[@]}"; do
        service=${service_port%%:*}
        port=${service_port##*:}
        
        if curl -s --connect-timeout 5 http://localhost:$port > /dev/null; then
            info "✅ $service is healthy"
        else
            warning "❌ $service is not responding"
            failed_services+=("$service")
        fi
    done
    
    # Check PostgreSQL exporters
    log "Checking PostgreSQL exporters..."
    pg_exporters=("9187" "9188" "9189")
    pg_names=("crypto-data" "user-data" "fastapi-ops")
    
    for i in "${!pg_exporters[@]}"; do
        port=${pg_exporters[$i]}
        name=${pg_names[$i]}
        
        if curl -s --connect-timeout 5 http://localhost:$port/metrics > /dev/null; then
            info "✅ PostgreSQL exporter ($name) is healthy"
        else
            warning "❌ PostgreSQL exporter ($name) on port $port not responding"
        fi
    done
    
    echo ""
    log "🎉 DEV Monitoring Deployment Complete!"
    echo ""
    echo "📊 Access URLs:"
    echo "  • Grafana:      http://localhost:3000 (admin/grafana_admin_dev123)"
    echo "  • Prometheus:   http://localhost:9090"
    echo "  • AlertManager: http://localhost:9093"
    echo ""
    echo "🚨 Alert Webhooks (n8n):"
    echo "  • General:   https://n8n.xplaincrypto.ai/webhook/alert"
    echo "  • Critical:  https://n8n.xplaincrypto.ai/webhook/critical-alert"
    echo "  • AI Team:   https://n8n.xplaincrypto.ai/webhook/ai-alert"
    echo "  • Database:  https://n8n.xplaincrypto.ai/webhook/database-alert"
    echo ""
    echo "📈 Monitoring Targets:"
    echo "  • MindsDB:         142.93.49.20:47334"
    echo "  • PostgreSQL DBs:  3 databases (ports 9187, 9188, 9189)"
    echo "  • Redis:           localhost:6379"
    echo "  • n8n Server:      206.81.0.227:5678"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Import n8n workflow: xplaincrypto-n8n/workflows/phase1-monitoring-alerts.json"
    echo "  2. Test alerts: curl -X POST https://n8n.xplaincrypto.ai/webhook/alert -d '{}'"
    echo "  3. Check Grafana dashboards"
    echo ""
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log "✅ All core services are running successfully!"
    else
        warning "⚠️  Some services failed to start: ${failed_services[*]}"
        echo "Check logs with: docker-compose logs [service-name]"
    fi
}

# Execute main function
main "$@" 