
#!/bin/bash
set -e

echo "🔐 Creating unified infrastructure secrets..."
echo "⚠️  Reading passwords from environment variables - NO HARDCODED SECRETS!"

# Create secrets directory in SYSTEM location
mkdir -p /opt/secrets/xplaincrypto

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

# Database passwords (to SYSTEM location)
echo "$POSTGRES_CRYPTO_PASSWORD" > /opt/secrets/xplaincrypto/postgres_crypto_password.txt
echo "$POSTGRES_USERS_PASSWORD" > /opt/secrets/xplaincrypto/postgres_users_password.txt  
echo "$POSTGRES_FASTAPI_PASSWORD" > /opt/secrets/xplaincrypto/postgres_fastapi_password.txt

# Redis password
echo "$REDIS_PASSWORD" > /opt/secrets/xplaincrypto/redis_password.txt

# Database connection strings for exporters
echo "postgresql://mindsdb:$POSTGRES_CRYPTO_PASSWORD@postgres-crypto:5432/crypto_data?sslmode=disable" > /opt/secrets/xplaincrypto/postgres_crypto_dsn.txt
echo "postgresql://xplaincrypto:$POSTGRES_USERS_PASSWORD@postgres-users:5432/user_data?sslmode=disable" > /opt/secrets/xplaincrypto/postgres_users_dsn.txt
echo "postgresql://fastapi:$POSTGRES_FASTAPI_PASSWORD@postgres-fastapi:5432/operational_data?sslmode=disable" > /opt/secrets/xplaincrypto/postgres_fastapi_dsn.txt

# Application passwords
echo "$GRAFANA_ADMIN_PASSWORD" > /opt/secrets/xplaincrypto/grafana_admin_password.txt
echo "$MINDSDB_PASSWORD" > /opt/secrets/xplaincrypto/mindsdb_password.txt

# Set proper permissions
chmod 600 /opt/secrets/xplaincrypto/*.txt
chown root:root /opt/secrets/xplaincrypto/* 2>/dev/null || echo "Note: chown requires sudo"

echo "✅ All secrets created successfully in /opt/secrets/xplaincrypto/" 
