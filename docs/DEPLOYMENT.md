# XplainCrypto Infrastructure Deployment Guide

## Overview
This repository provides the foundational infrastructure for the XplainCrypto platform.

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
1. **xplaincrypto-infra** (this repository) - Foundation services
2. **xplaincrypto-mindsdb** - AI/ML engine
3. **xplaincrypto-user-database** - User data management
4. **xplaincrypto-fastapi** - API backend

## Support
For issues with infrastructure deployment, check container logs with `docker-compose logs`.
