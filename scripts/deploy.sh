#!/bin/bash
# XplainCrypto Infrastructure Deployment Script

set -e

echo "🏗️ XplainCrypto Infrastructure Deployment"
echo "=========================================="

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

echo "📋 Step 1: Stopping any existing services..."
docker-compose down 2>/dev/null || true

echo "📋 Step 2: Starting infrastructure services..."
docker-compose up -d

echo "📋 Step 3: Waiting for services to be ready..."
sleep 30

echo "📋 Step 4: Health checks..."
# Test Redis
echo "🔴 Testing Redis..."
if docker exec xplaincrypto-redis redis-cli -a redis_secure_pass_dev123 ping >/dev/null 2>&1; then
    echo "   ✅ Redis is healthy"
else
    echo "   ❌ Redis is not responding"
fi

echo ""
echo "🎉 Infrastructure deployment complete!"
echo "📊 Service URLs:"
echo "   Grafana:    http://localhost:3000"
echo "   Prometheus: http://localhost:9090"
echo "   Redis:      localhost:6379"
