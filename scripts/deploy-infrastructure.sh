#!/bin/bash
# Deploy XplainCrypto infrastructure with monitoring

set -e

echo "🚀 Deploying XplainCrypto Infrastructure"
echo "========================================"

# Step 1: Environment validation
echo ""
echo "🔍 Step 1: Environment Validation"
./scripts/validate-environment.sh

# Step 2: Create required directories
echo ""
echo "📁 Step 2: Directory Setup"
sudo ./scripts/create-required-directories.sh

# Step 3: Ensure network exists - FIXED: Use full path to bypass aliases
echo ""
echo "🌐 Step 3: Network Setup"
/usr/bin/docker network rm xplaincrypto_network 2>/dev/null || true
/usr/bin/docker network create xplaincrypto_network
echo "✅ Network ensured"

# Step 4: Deploy services
echo ""
echo "🏗️ Step 4: Deploying Services"
docker-compose up -d

# Step 5: Health verification
echo ""
echo "🔍 Step 5: Health Verification"
./scripts/comprehensive-health-check.sh

echo ""
    echo "✅ All services are healthy and ready!"