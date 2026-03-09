#!/bin/sh
set -e

# Fix Railway volume permissions (mounted as root, AlertManager runs as nobody)
chown -R nobody:nobody /alertmanager

# Write the ingest token from env var to file (AlertManager reads credentials from file)
mkdir -p /etc/alertmanager/secrets
if [ -n "${ALERT_INGEST_TOKEN:-}" ]; then
    echo -n "$ALERT_INGEST_TOKEN" > /etc/alertmanager/secrets/ingest-token
else
    echo "WARNING: ALERT_INGEST_TOKEN not set, webhook auth will fail"
    echo -n "not-configured" > /etc/alertmanager/secrets/ingest-token
fi

exec su nobody -s /bin/sh -c '/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/alertmanager'
