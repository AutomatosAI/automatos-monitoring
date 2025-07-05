# 🚀 XplainCrypto Development Monitoring

## Quick Start

```bash
# Deploy all monitoring for development
chmod +x scripts/deploy-dev-monitoring.sh
./scripts/deploy-dev-monitoring.sh
```

## What You Get

✅ **Prometheus** monitoring all your services  
✅ **Grafana** dashboards at http://localhost:3000  
✅ **AlertManager** sending alerts to n8n webhooks  
✅ **PostgreSQL Exporters** for 3 databases  
✅ **Redis Monitoring** for cache performance  
✅ **MindsDB Health Checks** for AI platform  

## Access Points

- **Grafana**: http://localhost:3000 (admin/grafana_admin_dev123)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

## What Gets Monitored

- **MindsDB AI**: 142.93.49.20:47334 (health + agents)
- **PostgreSQL**: 3 databases (crypto_data, user_data, fastapi_ops)
- **Redis**: Cache performance and memory usage
- **n8n Workflows**: 206.81.0.227:5678
- **System**: CPU, memory, disk usage

## n8n Integration

Upload this workflow to your n8n server (https://206.81.0.227:5678):
- File: `../xplaincrypto-n8n/workflows/phase1-monitoring-alerts.json`

Alert webhooks:
- General: `https://n8n.xplaincrypto.ai/webhook/alert`
- Critical: `https://n8n.xplaincrypto.ai/webhook/critical-alert`
- AI Team: `https://n8n.xplaincrypto.ai/webhook/ai-alert`
- Database: `https://n8n.xplaincrypto.ai/webhook/database-alert`

## Test Your Setup

```bash
# Test alert system
curl -X POST https://n8n.xplaincrypto.ai/webhook/alert \
  -H "Content-Type: application/json" \
  -d '{"test": "development alert"}'

# Check all services
docker-compose ps
```

## Troubleshooting

**Services not starting?**
```bash
docker-compose logs [service-name]
```

**Can't access Grafana?**
```bash
curl http://localhost:3000
# Should return HTML
```

**PostgreSQL exporters failing?**
```bash
# Check database connectivity
curl http://localhost:9187/metrics  # crypto_data
curl http://localhost:9188/metrics  # user_data  
curl http://localhost:9189/metrics  # fastapi_ops
```

## Files Used

- `docker-compose.yml` - Main services
- `monitoring/prometheus/prometheus.yml` - Prometheus config
- `monitoring/alertmanager/alertmanager.yml` - Alert routing
- `monitoring/prometheus/rules/xplaincrypto-alerts.yml` - Alert rules

That's it! Simple development monitoring for XplainCrypto. 