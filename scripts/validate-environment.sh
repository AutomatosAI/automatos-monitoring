#!/bin/bash
# Fixed environment validation for XplainCrypto

set -e

echo "🔍 XplainCrypto Environment Validation"
echo "======================================"

validation_failed=false

# Check Docker with better detection - FIXED
echo -n "Checking Docker daemon... "
if docker info >/dev/null 2>&1; then
    echo "✅"
elif docker ps >/dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    validation_failed=true
fi

# Check Docker Compose with version detection - FIXED  
echo -n "Checking Docker Compose... "
if command -v docker-compose >/dev/null 2>&1; then
    echo "✅ (legacy syntax: docker-compose)"
elif docker compose version >/dev/null 2>&1; then
    echo "✅ (new syntax: docker compose)"
else
    echo "❌"
    validation_failed=true
fi

# Check system requirements
echo -n "Checking system memory... "
total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_gb=$((total_mem_kb / 1024 / 1024))
if [[ $total_mem_gb -ge 2 ]]; then
    echo "✅ (${total_mem_gb}GB)"
else
    echo "❌ (${total_mem_gb}GB, need 2GB)"
    validation_failed=true
fi

echo -n "Checking disk space... "
available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $available_gb -ge 10 ]]; then
    echo "✅ (${available_gb}GB available)"
else
    echo "❌ (${available_gb}GB available, need 10GB)"
    validation_failed=true
fi

# Check if containers are actually running
echo -n "Checking container status... "
if docker ps | grep -q "xplaincrypto"; then
    echo "✅ (containers running)"
else
    echo "⚠️ (no containers running - normal for fresh install)"
fi

# Check network connectivity
echo -n "Checking internet connectivity... "
if ping -c 1 8.8.8.8 &>/dev/null; then
    echo "✅"
else
    echo "❌"
    validation_failed=true
fi

echo "🔄 Installing chrony if needed... "
apt-get update && apt-get install -y chrony debsig-verify
# Migrate Docker key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
echo "🔄 Checking and forcing system clock sync... "
systemctl enable chrony.service
systemctl start chrony.service
chronyc makestep
chronyc sources || { echo "⚠️ Clock sync failed— check chronyc sources"; validation_failed=true; exit 1; }
sleep 2  # Give time for FS sync
if [ ! -f ./scripts/validate-environment.sh ]; then echo "❌ Validation script missing"; validation_failed=true; exit 1; fi

echo ""
if [[ "$validation_failed" == true ]]; then
    echo "❌ Validation FAILED"
    exit 1
else
    echo "✅ Validation PASSED"
    exit 0
fi 