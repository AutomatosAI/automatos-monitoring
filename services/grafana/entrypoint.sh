#!/bin/sh
set -e

# Fix ownership on Railway volume mount (mounted as root)
chown -R grafana:root /var/lib/grafana /etc/grafana/provisioning

# Drop to grafana user and start
exec su-exec grafana /run.sh
