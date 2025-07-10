#!/bin/bash
set -e

echo "🔐 Creating unified infrastructure secrets..."
echo "⚠️  Reading passwords from environment variables - NO HARDCODED SECRETS!"

# Create secrets directory with proper structure
mkdir -p /opt/secrets/xplaincrypto
cd /opt/secrets/xplaincrypto

# Check required environment variables
required_vars=(
    "POSTGRES_CRYPTO_PASSWORD"
    "POSTGRES_USERS_PASSWORD" 
    "POSTGRES_FASTAPI_PASSWORD"
    "REDIS_PASSWORD"
    "GRAFANA_ADMIN_PASSWORD"
    "MINDSDB_PASSWORD"
    "JWT_SECRET_KEY"
    "COINMARKETCAP_API_KEY"
    "ANTHROPIC_API_KEY"
    "OPENAI_API_KEY"
    "TIMEGPT_API_KEY"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ ERROR: Environment variable $var is not set!"
        echo "Please set all required environment variables before running this script."
        exit 1
    fi
done

echo "📁 Creating infrastructure secrets..."

# Database passwords (from environment variables)
echo "$POSTGRES_CRYPTO_PASSWORD" > postgres_crypto_password.txt
echo "$POSTGRES_USERS_PASSWORD" > postgres_users_password.txt  
echo "$POSTGRES_FASTAPI_PASSWORD" > postgres_fastapi_password.txt

# Redis password (from environment)
echo "$REDIS_PASSWORD" > redis_password.txt

# Database connection strings for exporters (internal network)
echo "postgresql://mindsdb:$POSTGRES_CRYPTO_PASSWORD@postgres-crypto:5432/crypto_data?sslmode=disable" > postgres_crypto_dsn.txt
echo "postgresql://xplaincrypto:$POSTGRES_USERS_PASSWORD@postgres-users:5432/user_data?sslmode=disable" > postgres_users_dsn.txt
echo "postgresql://fastapi:$POSTGRES_FASTAPI_PASSWORD@postgres-fastapi:5432/operational_data?sslmode=disable" > postgres_fastapi_dsn.txt

# Application passwords (from environment)
echo "$GRAFANA_ADMIN_PASSWORD" > grafana_admin_password.txt
echo "$MINDSDB_PASSWORD" > mindsdb_password.txt

echo "🚀 Creating FastAPI-specific secrets..."

# JWT Secret Key for FastAPI
echo "$JWT_SECRET_KEY" > jwt_secret_key.txt

# Database URLs for external connections (FastAPI connects from outside)
echo "postgresql://mindsdb:$POSTGRES_CRYPTO_PASSWORD@142.93.49.20:5432/crypto_data" > crypto_database_url.txt
echo "postgresql://xplaincrypto:$POSTGRES_USERS_PASSWORD@142.93.49.20:5433/user_data" > user_database_url.txt
echo "postgresql://fastapi:$POSTGRES_FASTAPI_PASSWORD@142.93.49.20:5434/operational_data" > ops_database_url.txt

echo "🔑 Creating API keys for external services..."

# External API keys
echo "$COINMARKETCAP_API_KEY" > coinmarketcap_api_key.txt
echo "$ANTHROPIC_API_KEY" > anthropic_api_key.txt
echo "$OPENAI_API_KEY" > openai_api_key.txt
echo "$TIMEGPT_API_KEY" > timegpt_api_key.txt

# Set proper permissions (security critical)
chmod 600 *.txt
chown root:root * 2>/dev/null || echo "Note: chown requires sudo"

echo "✅ All secrets created successfully from environment variables:"
echo ""
echo "📊 Infrastructure Secrets:"
echo "  - Database passwords: postgres_crypto, postgres_users, postgres_fastapi"
echo "  - Redis password: redis_password"  
echo "  - Grafana admin: grafana_admin_password"
echo "  - Database DSN strings: postgres_*_dsn (for exporters)"
echo "  - MindsDB password: mindsdb_password"
echo ""
echo "🚀 FastAPI Secrets:"
echo "  - JWT secret: jwt_secret_key"
echo "  - External database URLs: crypto_database_url, user_database_url, ops_database_url"
echo ""
echo "🔑 API Keys:"
echo "  - CoinMarketCap: coinmarketcap_api_key"
echo "  - Anthropic Claude: anthropic_api_key"
echo "  - OpenAI GPT: openai_api_key"
echo "  - TimeGPT: timegpt_api_key"
echo ""
echo "🔒 Permissions set to 600 (owner read/write only)"
echo "🛡️  ALL PASSWORDS FROM ENVIRONMENT VARIABLES - NO HARDCODED SECRETS!"
echo "✅ Secrets creation complete in /opt/secrets/xplaincrypto/" 