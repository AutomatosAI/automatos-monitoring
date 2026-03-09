#!/bin/bash
set -euo pipefail

echo "=== Automatos Monitoring — Local Setup ==="

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose is not available"
    exit 1
fi

# Create shared network if it doesn't exist
echo "Creating automatos_network (if needed)..."
docker network create automatos_network 2>/dev/null && echo "  Created." || echo "  Already exists."

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "  IMPORTANT: Edit .env with your actual passwords before starting."
else
    echo ".env already exists, skipping."
fi

# Create secrets directory for AlertManager ingest token
echo "Creating secrets directory..."
mkdir -p secrets
if [ ! -f secrets/ingest-token ]; then
    # Generate a random token for local dev
    python3 -c "import secrets; print(secrets.token_urlsafe(32))" > secrets/ingest-token
    echo "  Generated alert ingest token: $(cat secrets/ingest-token)"
    echo "  Set this as ALERT_INGEST_TOKEN on the backend service."
else
    echo "  secrets/ingest-token already exists, skipping."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit .env with your database/redis passwords"
echo "  2. Ensure automatos-ai services are running"
echo "  3. Run: docker compose up -d"
echo "  4. Open Grafana: http://localhost:3030"
