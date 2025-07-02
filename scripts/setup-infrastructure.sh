#!/bin/bash

set -e

echo "🚀 Setting up XplainCrypto Infrastructure..."

# Create necessary directories
mkdir -p logs
mkdir -p data/prometheus
mkdir -p data/grafana
mkdir -p data/redis
mkdir -p data/loki
mkdir -p data/alertmanager

# Set permissions
chmod 755 scripts/*.sh
chmod -R 755 monitoring/

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env 2>/dev/null || echo "⚠️  Please create .env file manually"
fi

# Pull images first
echo "📦 Pulling Docker images..."
docker-compose pull

# Start infrastructure
echo "🏗️  Starting infrastructure stack..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 30

# Health checks
echo "🔍 Running health checks..."
./scripts/health-check.sh

echo "✅ Infrastructure setup complete!"
echo ""
echo "📊 Access URLs:"
echo "  - Grafana: http://localhost:3000 (admin/grafana_admin_dev123)"
echo "  - Prometheus: http://localhost:9090"
echo "  - AlertManager: http://localhost:9093"
echo "" 