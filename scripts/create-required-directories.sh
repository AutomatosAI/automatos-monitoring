#!/bin/bash
# XplainCrypto Infrastructure Directory Setup
# Creates all required directories for Docker volume mounts

set -e

echo "📁 Creating XplainCrypto Infrastructure Directories"
echo "=================================================="

# Define required directories
DIRECTORIES=(
    "/var/lib/xplaincrypto/redis"
    "/var/lib/xplaincrypto/prometheus" 
    "/var/lib/xplaincrypto/grafana"
    "/var/lib/xplaincrypto/loki"
    "/var/lib/xplaincrypto/alertmanager"
    "/var/log/xplaincrypto/nginx"
)

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (for directory permissions)"
   exit 1
fi

# Create directories with proper permissions
for dir in "${DIRECTORIES[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        
        # Set appropriate ownership based on service
        case "$dir" in
            *redis*)
                chown 999:999 "$dir"  # Redis container user
                ;;
            *grafana*)
                chown 472:472 "$dir"  # Grafana container user
                ;;
            *prometheus*|*alertmanager*)
                chown 65534:65534 "$dir"  # Prometheus/AlertManager user
                ;;
            *loki*)
                chown 10001:10001 "$dir"  # Loki container user
                ;;
            *nginx*)
                chown 101:101 "$dir"  # Nginx container user
                ;;
        esac
        
        echo "✅ Created: $dir"
    else
        echo "ℹ️  Exists: $dir"
    fi
done

# Verify all directories exist and have correct permissions
echo ""
echo "🔍 Directory Verification:"
for dir in "${DIRECTORIES[@]}"; do
    if [[ -d "$dir" ]]; then
        permissions=$(ls -ld "$dir" | awk '{print $1, $3, $4}')
        echo "✅ $dir ($permissions)"
    else
        echo "❌ $dir - MISSING!"
    fi
done

echo ""
echo "✅ Directory setup complete!" 