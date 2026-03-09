#!/bin/bash
set -euo pipefail

echo "=== Automatos Monitoring — Railway Setup ==="
echo ""

# Check prerequisites
if ! command -v railway &> /dev/null; then
    echo "ERROR: Railway CLI not installed. Run: npm install -g @railway/cli"
    exit 1
fi

echo "This script creates Railway services for the monitoring stack."
echo "Make sure you're linked to the correct Railway project first."
echo ""
echo "Current project:"
railway status 2>/dev/null || { echo "ERROR: Not linked to a Railway project. Run: railway link"; exit 1; }
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Deploying services..."

# Deploy each service
for service in prometheus grafana loki log-relay alertmanager postgres-exporter redis-exporter; do
    echo "  Deploying: $service"
    railway up --service "$service" --detach 2>/dev/null || echo "  WARNING: $service deployment may need manual setup"
done

echo ""
echo "=== Deployment initiated ==="
echo ""
echo "Next steps:"
echo "  1. Set environment variables for each service in Railway dashboard"
echo "  2. Add persistent volumes for prometheus, grafana, loki"
echo "  3. Configure Railway log drain pointing to log-relay /drain endpoint"
echo "  4. Verify services at Railway dashboard"
