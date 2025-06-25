#!/bin/bash
# Setup n8n Monitoring Infrastructure

set -e

echo "🚀 Setting up n8n monitoring infrastructure..."

# Make scripts executable
chmod +x scripts/n8n-metrics-collect.sh

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install prometheus_client requests

# Setup cron job for metrics collection
echo "⏰ Setting up cron job for metrics collection..."
CRON_JOB="*/5 * * * * /root/xplaincrypto-infra/scripts/n8n-metrics-collect.sh >> /var/log/n8n-metrics.log 2>&1"

# Remove existing cron job if it exists
(crontab -l 2>/dev/null | grep -v "n8n-metrics-collect") | crontab -

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "✅ Cron job added: Metrics collection every 5 minutes"

# Create log file
touch /var/log/n8n-metrics.log
chmod 644 /var/log/n8n-metrics.log

# Run initial metrics collection
echo "🔄 Running initial metrics collection..."
python3 monitoring/n8n-exporter.py

echo "🎉 n8n monitoring setup completed successfully!"
echo ""
echo "📊 Monitoring Details:"
echo "  - Metrics collected every 5 minutes"
echo "  - Logs: /var/log/n8n-metrics.log"
echo "  - Pushgateway: http://localhost:9091"
echo "  - Grafana dashboards will show n8n workflow metrics" 