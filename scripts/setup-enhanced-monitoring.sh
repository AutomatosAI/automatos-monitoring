#!/bin/bash
# Setup enhanced monitoring with n8n integration

set -e

echo "📊 Setting up Enhanced XplainCrypto Monitoring"
echo "=============================================="

# Install required Python packages
echo "📦 Installing Python dependencies..."
pip3 install prometheus_client requests

# Copy enhanced exporter to monitoring directory
echo "📄 Setting up enhanced metrics exporter..."
cp monitoring/enhanced-n8n-exporter.py /usr/local/bin/enhanced-n8n-exporter.py
chmod +x /usr/local/bin/enhanced-n8n-exporter.py

# Create systemd service for metrics collection
echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/xplaincrypto-metrics.service <<EOF
[Unit]
Description= XplainCrypto Metrics Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/xplaincrypto/xplaincrypto-infra/monitoring/enhanced-n8n-exporter.py
User=root
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer for regular execution
cat > /etc/systemd/system/xplaincrypto-metrics.timer <<EOF
[Unit]
Description= XplainCrypto Metrics Timer
[Timer]
OnUnitActiveSec=5m
Persistent=true
[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
echo "⏰ Enabling metrics collection timer..."
systemctl daemon-reload
systemctl enable xplaincrypto-metrics.timer
systemctl start xplaincrypto-metrics.timer

# Run initial collection
echo "🔄 Running initial metrics collection..."
python3 /usr/local/bin/enhanced-n8n-exporter.py

echo ""
echo "✅ Enhanced monitoring setup completed!"
echo ""
echo "📊 Monitoring Details:"
echo "  - Metrics collected every 5 minutes"
echo "  - Service: xplaincrypto-metrics.service"
echo "  - Timer: xplaincrypto-metrics.timer"
echo "  - Pushgateway: http://localhost:9091"
echo "  - Check status: systemctl status xplaincrypto-metrics.timer" 