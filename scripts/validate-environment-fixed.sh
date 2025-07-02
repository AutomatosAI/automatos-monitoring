#!/bin/bash
# Fixed environment validation

set -e

echo "🔍 XplainCrypto Environment Validation (Fixed)"
echo "============================================="

validation_failed=false

# Check Docker with better detection
echo -n "Checking Docker daemon... "
if docker info >/dev/null 2>&1 || docker ps >/dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    validation_failed=true
fi

# Check Docker Compose with version detection
echo -n "Checking Docker Compose... "
if docker compose version >/dev/null 2>&1; then
    echo "✅ (new syntax)"
elif docker-compose --version >/dev/null 2>&1; then
    echo "✅ (legacy syntax)"
else
    echo "❌"
    validation_failed=true
fi

# Check if containers are actually running
echo -n "Checking container status... "
if docker ps | grep -q "xplaincrypto"; then
    echo "✅ (containers running)"
else
    echo "⚠️ (no containers running)"
fi

if [[ "$validation_failed" == true ]]; then
    echo "❌ Validation FAILED"
    exit 1
else
    echo "✅ Validation PASSED"
    exit 0
fi 