#!/bin/bash
# Create all required secret files

# Create secrets directory
mkdir -p secrets

# Database passwords
echo 'your_crypto_db_password' > secrets/postgres_crypto_password.txt
echo 'Ifr9eC7rtRMHZlIJ3kBzbqi2f' > secrets/postgres_users_password.txt
echo 'XJONccQ0vQ3JnwDT1bhi8Qfuy1inRwGP' > secrets/postgres_fastapi_password.txt

# Database exporter DSNs
echo 'postgresql://mindsdb:your_crypto_db_password@postgres-crypto:5432/crypto_data?sslmode=disable' > secrets/postgres_crypto_exporter_dsn.txt
echo 'postgresql://xplaincrypto:Ifr9eC7rtRMHZlIJ3kBzbqi2f@postgres-users:5432/user_data?sslmode=disable' > secrets/postgres_users_exporter_dsn.txt
echo 'postgresql://fastapi:XJONccQ0vQ3JnwDT1bhi8Qfuy1inRwGP@postgres-fastapi:5432/fastapi_ops?sslmode=disable' > secrets/postgres_fastapi_exporter_dsn.txt

# Application passwords
echo 'grafana_admin_secure_password' > secrets/grafana_admin_password.txt

# Set proper permissions
chmod 600 secrets/*
chown root:root secrets/*

echo "✅ All secrets created successfully" 