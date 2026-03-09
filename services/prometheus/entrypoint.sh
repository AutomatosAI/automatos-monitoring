#!/bin/sh
set -e

# Fix Railway volume permissions (mounted as root, Prometheus runs as nobody)
chown -R nobody:nobody /prometheus

exec su nobody -s /bin/sh -c '/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --storage.tsdb.retention.time=15d \
    --web.enable-lifecycle \
    --web.enable-admin-api'
