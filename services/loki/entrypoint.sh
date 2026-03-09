#!/bin/sh
set -e

# Fix Railway volume permissions (mounted as root, Loki runs as loki:10001)
chown -R 10001:10001 /loki

exec su loki -s /bin/sh -c '/usr/bin/loki -config.file=/etc/loki/config.yaml'
