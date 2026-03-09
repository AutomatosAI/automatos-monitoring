#!/bin/sh
set -e

# Fix Railway volume permissions (mounted as root, Loki runs as loki:10001)
chown -R 10001:10001 /loki

# Ensure ruler temp directory exists
mkdir -p /loki/rules-temp
chown -R 10001:10001 /loki/rules-temp

exec su loki -s /bin/sh -c '/usr/bin/loki -config.file=/etc/loki/config.yaml'
