#!/bin/bash
set -e

echo "🔐 Creating unified infrastructure secrets..."
echo "⚠️  Reading passwords from environment variables - NO HARDCODED SECRETS!"

# Create secrets directory
mkdir -p secrets

# Check required environment variables
required_vars=(
    "POSTGRES_CRYPTO_PASSWORD"
    "POSTGRES_USERS_PASSWORD" 
    "POSTGRES_FASTAPI_PASSWORD"
    "REDIS_PASSWORD"
    "GRAFANA_ADMIN_PASSWORD"
    "MINDSDB_PASSWORD"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ ERROR: Environment variable $var is not set!"
        echo "Please set all required environment variables before running this script."
        exit 1
    fi
done

# Database passwords (from environment variables)
echo "$POSTGRES_CRYPTO_PASSWORD" > secrets/postgres_crypto_password.txt
echo "$POSTGRES_USERS_PASSWORD" > secrets/postgres_users_password.txt  
echo "$POSTGRES_FASTAPI_PASSWORD" > secrets/postgres_fastapi_password.txt

# Redis password (from environment)
echo "$REDIS_PASSWORD" > secrets/redis_password.txt

# Database connection strings for exporters (using env vars)
echo "postgresql://mindsdb:$POSTGRES_CRYPTO_PASSWORD@postgres-crypto:5432/crypto_data?sslmode=disable" > secrets/postgres_crypto_dsn.txt
echo "postgresql://xplaincrypto:$POSTGRES_USERS_PASSWORD@postgres-users:5432/user_data?sslmode=disable" > secrets/postgres_users_dsn.txt
echo "postgresql://fastapi:$POSTGRES_FASTAPI_PASSWORD@postgres-fastapi:5432/operational_data?sslmode=disable" > secrets/postgres_fastapi_dsn.txt

# Application passwords (from environment)
echo "$GRAFANA_ADMIN_PASSWORD" > secrets/grafana_admin_password.txt
echo "$MINDSDB_PASSWORD" > secrets/mindsdb_password.txt

# Set proper permissions (security critical)
chmod 600 secrets/*.txt
chown root:root secrets/* 2>/dev/null || echo "Note: chown requires sudo"

echo "✅ All secrets created successfully from environment variables:"
echo "📁 Database secrets: postgres_crypto, postgres_users, postgres_fastapi"
echo "🔴 Redis secret: redis_password"  
echo "📊 Grafana secret: grafana_admin_password"
echo "🔗 Database DSN secrets: postgres_*_dsn (for exporters)"
echo "🤖 MindsDB secret: mindsdb_password"
echo ""
echo "🔒 Permissions set to 600 (owner read/write only)"
echo "🛡️  ALL PASSWORDS FROM ENVIRONMENT VARIABLES - NO HARDCODED SECRETS!"
echo "✅ Secrets creation complete!" 