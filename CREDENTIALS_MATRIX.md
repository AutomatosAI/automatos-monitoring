# XplainCrypto Infrastructure Credentials Matrix

## Database Credentials

### Database 1: Crypto Data (Port 5432)
- **Host**: 142.93.49.20 (external) / postgres-crypto (internal)
- **Port**: 5432
- **Database**: crypto_data
- **Username**: mindsdb
- **Password**: [File: secrets/postgres_crypto_password.txt]
- **Purpose**: MindsDB AI/ML data storage
- **Container**: xplaincrypto-postgres-crypto

### Database 2: User Data (Port 5433)
- **Host**: 142.93.49.20 (external) / postgres-users (internal)
- **Port**: 5433
- **Database**: user_data
- **Username**: xplaincrypto
- **Password**: [File: secrets/postgres_users_password.txt]
- **Purpose**: User accounts, portfolios, social features
- **Container**: xplaincrypto-postgres-users

### Database 3: FastAPI Operations (Port 5434)
- **Host**: 142.93.49.20 (external) / postgres-fastapi (internal)
- **Port**: 5434
- **Database**: fastapi_ops
- **Username**: fastapi
- **Password**: [File: secrets/postgres_fastapi_password.txt]
- **Purpose**: API logs, sessions, operational data
- **Container**: xplaincrypto-postgres-fastapi

## Application Credentials

### Redis Cache
- **Host**: 142.93.49.20 (external) / redis (internal)
- **Port**: 6379
- **Password**: 
- **Databases**: 
  - DB 0: MindsDB cache
  - DB 1: User sessions
  - DB 2: Application cache
  - DB 3: FastAPI cache
- **Container**: xplaincrypto-redis

### Grafana
- **URL**: http://grafana.xplaincrypto.ai
- **Port**: 3000
- **Username**: admin
- **Password**: [File: secrets/grafana_admin_password.txt]
- **Container**: xplaincrypto-grafana

### Prometheus
- **URL**: http://prometheus.xplaincrypto.ai
- **Port**: 9090
- **Authentication**: None (internal only)
- **Container**: xplaincrypto-prometheus

### AlertManager
- **URL**: http://alerts.xplaincrypto.ai
- **Port**: 9093
- **Authentication**: None (internal only)
- **Container**: xplaincrypto-alertmanager

## Monitoring Exporters

### PostgreSQL Exporters
- **Crypto DB Exporter**: Port 9187
- **Users DB Exporter**: Port 9188
- **FastAPI DB Exporter**: Port 9189

### System Exporters
- **Node Exporter**: Port 9100
- **Redis Exporter**: Port 9121 