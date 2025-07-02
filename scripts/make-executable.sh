#!/bin/bash
# Make all scripts executable

chmod +x scripts/create-required-directories.sh
chmod +x scripts/comprehensive-health-check.sh
chmod +x scripts/validate-environment.sh
chmod +x scripts/deploy-infrastructure.sh
chmod +x scripts/health-check.sh
chmod +x scripts/backup.sh
chmod +x scripts/test-infrastructure.sh

echo "✅ All scripts are now executable" 