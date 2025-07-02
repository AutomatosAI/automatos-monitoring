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

echo ""
if [[ "$validation_failed" == true ]]; then
    echo "❌ Validation FAILED"
    exit 1
else
    echo "✅ Validation PASSED"
    exit 0
fi 