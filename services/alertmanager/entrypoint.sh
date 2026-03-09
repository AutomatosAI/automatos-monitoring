#!/bin/sh
set -e

# Write the ingest token from env var to file (AlertManager reads credentials from file)
mkdir -p /etc/alertmanager/secrets
if [ -n "${ALERT_INGEST_TOKEN:-}" ]; then
    echo -n "$ALERT_INGEST_TOKEN" > /etc/alertmanager/secrets/ingest-token
else
    echo "WARNING: ALERT_INGEST_TOKEN not set, webhook auth will fail"
    echo -n "not-configured" > /etc/alertmanager/secrets/ingest-token
fi

exec /bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/alertmanager
