#!/bin/bash
set -e

echo "🔐 Creating unified infrastructure secrets..."

# Create secrets directory
mkdir -p secrets

# Database passwords (from your credential matrix)
echo 'QmTJL6k24h7R3zK9p8wN1F2xV5Y' > secrets/postgres_crypto_password.txt
echo 'Ifr9eC7rtRMHZlIJ3kBzbqi2f' > secrets/postgres_users_password.txt  
echo 'XJONccQ0vQ3JnwDT1bhi8Qfuy1inRwGP' > secrets/postgres_fastapi_password.txt

# Application passwords
echo 'redis_secure_pass_dev123' > secrets/redis_password.txt
echo 'grafana_admin_dev123' > secrets/grafana_admin_password.txt

# MindsDB integration password
echo 'mindsdb_secure_pass_2024!' > secrets/mindsdb_password.txt

# Set proper permissions (security critical)
chmod 600 secrets/*.txt
chown root:root secrets/* 2>/dev/null || echo "Note: chown requires sudo"

echo "✅ All secrets created successfully:"
echo "📁 Database secrets: postgres_crypto, postgres_users, postgres_fastapi"
echo "🔴 Cache secret: redis_password"  
echo "📊 Grafana secret: grafana_admin_password"
echo "🤖 MindsDB secret: mindsdb_password"
echo ""
echo "🔒 Permissions set to 600 (owner read/write only)"
echo "✅ Secrets creation complete!" 