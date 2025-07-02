#!/bin/bash
# XplainCrypto Infrastructure Test Script
# Run comprehensive tests on all infrastructure services

set -e

echo "🚀 XplainCrypto Infrastructure Testing"
echo "======================================"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

# Check if required Python modules are available
echo "📦 Checking Python dependencies..."
python3 -c "import requests, redis" 2>/dev/null || {
    echo "❌ Missing Python dependencies. Installing..."
    pip3 install requests redis
}

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Run the infrastructure tests
echo "🧪 Running infrastructure tests..."
echo ""

cd "$(dirname "$0")/.."
python3 tests/test_infrastructure.py

echo ""
echo "✅ Infrastructure testing complete!" 