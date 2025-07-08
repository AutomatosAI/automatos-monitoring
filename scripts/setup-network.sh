#!/bin/bash
echo "🌐 Creating XplainCrypto network..."

# Remove existing network if it exists
docker network rm xplaincrypto_network 2>/dev/null || echo "No existing network to remove"

# Create new network
docker network create xplaincrypto_network

echo "✅ Network created successfully" 