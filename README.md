# 🏗️ XplainCrypto Infrastructure

**Core infrastructure services for the XplainCrypto platform**

## 🌟 What This Provides

- ✅ **Single Redis Instance** (multiple databases for all services)
- ✅ **Complete Monitoring Stack** (Prometheus, Grafana)
- ✅ **Centralized Secrets Management** (all API keys)
- ✅ **Shared Docker Network** (`xplaincrypto_network`)
- ✅ **Health Monitoring & Exporters**

## 🚀 Quick Start

```bash
# Clone repository
git clone git@github.com:Gerard161-Site/xplaincrypto-infra.git
cd xplaincrypto-infra


# Deploy infrastructure
docker-compose up -d

# Check status
docker-compose ps
```

## 📊 Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **Grafana** | http://localhost:3000 | Monitoring dashboards |
| **Prometheus** | http://localhost:9090 | Metrics collection |
| **Redis** | localhost:6379 | Shared cache |

## 🗃️ Redis Database Allocation

| Database | Purpose | Used By |
|----------|---------|---------|
| **0** | MindsDB cache | xplaincrypto-mindsdb |
| **1** | User sessions | xplaincrypto-user-database |
| **2** | FastAPI operations | xplaincrypto-fastapi |
| **3** | n8n workflows | xplaincrypto-n8n |
| **4-15** | Reserved | Future services |

## 🔑 Secrets Management

All API keys are centrally managed in `./secrets/`:

- `coinmarketcap_api_key.txt`
- `dune_api_key.txt` (Sim API key)
- `openai_api_key.txt`
- `timegpt_api_key.txt`
- `anthropic_api_key.txt`
- `whale_alerts_api_key.txt`
- `redis_password.txt`
- `grafana_admin_password.txt`

## 🌐 Network Architecture

This repository creates the **`xplaincrypto_network`** that all other repositories connect to:

```yaml
# Other repos connect like this:
networks:
  default:
    name: xplaincrypto_network
    external: true
```

## 🏗️ Repository Dependencies

This infrastructure must be deployed **first** before other repositories:

1. **xplaincrypto-infra** ← Deploy first (this repo)
2. **xplaincrypto-mindsdb** ← Connects to this network
3. **xplaincrypto-user-database** ← Connects to this network
4. **xplaincrypto-fastapi** ← Connects to this network

---
**Repository**: https://github.com/Gerard161-Site/xplaincrypto-infra  
**Part of**: XplainCrypto Platform 