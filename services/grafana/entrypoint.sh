#!/bin/sh
set -e

# Fix ownership on Railway volume mount (mounted as root)
chown -R 472:0 /var/lib/grafana /etc/grafana/provisioning

# Run Grafana's default entrypoint as grafana user
exec su grafana -s /bin/sh -c '/run.sh'
