# XplainCrypto Infrastructure Deployment Guide

## Overview
This repository provides the foundational infrastructure for the XplainCrypto platform, including Redis, monitoring stack, and shared networking.

## Prerequisites

- Docker and Docker Compose installed
- Ports 3000, 6379, 9090, 9093, 9100, 9121 available
- At least 2GB RAM available for all services

## Quick Start

### 1. Deploy Infrastructure
```bash
./scripts/deploy.sh
```

### 2. Verify Deployment
```bash
./scripts/health-check.sh
```

### 3. Access Services
- **Grafana**: http://localhost:3000 (admin/grafana_admin_dev123)
- **Prometheus**: http://localhost:9090
- **Redis**: localhost:6379 (password: redis_secure_pass_dev123)

## Deployment Order

The XplainCrypto platform must be deployed in this specific order:

1. **xplaincrypto-infra** (this repository) - Foundation services
2. **xplaincrypto-mindsdb** - AI/ML engine
3. **xplaincrypto-user-database** - User data management
4. **xplaincrypto-fastapi** - API backend

## Redis Database Allocation

- **Database 0**: MindsDB cache (xplaincrypto-mindsdb)
- **Database 1**: User sessions (xplaincrypto-user-database)
- **Database 2**: FastAPI operations (xplaincrypto-fastapi)
- **Database 3**: n8n workflows (xplaincrypto-n8n)
- **Database 4-15**: Reserved for future services

## Monitoring

### Grafana Dashboards
- Redis Performance
- System Resources (CPU, Memory, Disk)
- Container Health

### Prometheus Metrics
- Redis metrics via Redis Exporter
- System metrics via Node Exporter
- Container metrics via cAdvisor

## Troubleshooting

### Redis Connection Issues
```bash
# Test Redis connection
docker exec xplaincrypto-redis redis-cli -a redis_secure_pass_dev123 ping

# Check Redis logs
docker logs xplaincrypto-redis
```

### Grafana Issues
```bash
# Reset Grafana admin password
docker exec xplaincrypto-grafana grafana-cli admin reset-admin-password new_password
```

### Network Issues
```bash
# Verify shared network exists
docker network ls | grep xplaincrypto_network

# Recreate network if needed
docker network create xplaincrypto_network
```

## Backup and Recovery

### Create Backup
```bash
./scripts/backup.sh
```

### Restore from Backup
```bash
# Stop services
docker-compose down

# Restore Grafana data
docker run --rm -v xplaincrypto_grafana_data:/var/lib/grafana -v $(pwd)/backups:/backup alpine tar xzf /backup/grafana_TIMESTAMP.tar.gz

# Restart services
docker-compose up -d
```

## Development vs Production

This configuration is optimized for development. For production:

1. Change all default passwords
2. Enable SSL/TLS
3. Configure proper backup schedules
4. Set up log rotation
5. Configure resource limits
6. Enable authentication for all services

## Support

For issues with infrastructure deployment:
1. Check container logs: `docker-compose logs [service_name]`
2. Verify port availability: `netstat -tulpn | grep LISTEN`
3. Check disk space: `df -h`
4. Monitor resource usage: `docker stats` 