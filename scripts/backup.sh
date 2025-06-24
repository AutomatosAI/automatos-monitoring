#!/bin/bash
# XplainCrypto Infrastructure Backup

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "💾 XplainCrypto Infrastructure Backup"
echo "===================================="

# Create backup directory
mkdir -p $BACKUP_DIR

echo "📦 Backing up Redis data..."
docker exec xplaincrypto-redis redis-cli -a redis_secure_pass_dev123 BGSAVE
sleep 5

echo "📦 Backing up Grafana data..."
docker run --rm --volumes-from xplaincrypto-grafana -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/grafana_$TIMESTAMP.tar.gz /var/lib/grafana

echo "📦 Backing up Prometheus data..."
docker run --rm --volumes-from xplaincrypto-prometheus -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/prometheus_$TIMESTAMP.tar.gz /prometheus

echo "✅ Backup complete!"
echo "📁 Backup files saved to: $BACKUP_DIR/"
ls -la $BACKUP_DIR/
