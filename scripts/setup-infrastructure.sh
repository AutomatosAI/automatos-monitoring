#!/bin/bash

set -e

echo "🚀 Deploying XplainCrypto Infrastructure via n8n..."

# Just deploy - no directory creation
docker-compose up -d

echo "✅ Infrastructure deployed!" 