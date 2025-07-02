#!/bin/bash
# n8n Metrics Collection Script
# Runs every 5 minutes via cron

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "$(date): Starting n8n metrics collection..."

# Check if Python script exists
if [ ! -f "monitoring/n8n-exporter.py" ]; then
    echo "$(date): ERROR - n8n-exporter.py not found"
    exit 1
fi

# Check if required Python packages are installed
python3 -c "import prometheus_client, requests" 2>/dev/null || {
    echo "$(date): Installing required Python packages..."
    pip3 install prometheus_client requests
}

# Run the metrics exporter
python3 monitoring/n8n-exporter.py

echo "$(date): n8n metrics collection completed" 