#!/bin/bash
# Fix all testing script issues

echo "🔧 Fixing testing script issues..."

# Fix 1: Docker Compose syntax
sed -i 's/docker compose network/docker network/g' scripts/comprehensive-health-check.sh
sed -i 's/docker compose volume/docker volume/g' scripts/comprehensive-health-check.sh

# Fix 2: Redis connection with password
sed -i 's/redis-cli -h localhost -p 6379 ping/redis-cli -h localhost -p 6379 -a redis_secure_pass_dev123 ping/g' scripts/comprehensive-health-check.sh

echo "✅ Testing script fixes applied!" 