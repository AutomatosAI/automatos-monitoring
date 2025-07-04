#!/bin/bash
# SSH into production server and run tests

PROD_SERVER="142.93.49.20"
SCRIPT_TO_RUN="cd /root/xplaincrypto-infra && ./scripts/test-all-workflows.sh"

echo "🔗 SSH Infrastructure Testing"
echo "============================"
echo "Connecting to production server: $PROD_SERVER"

ssh root@$PROD_SERVER "$SCRIPT_TO_RUN"

echo ""
echo "✅ Remote SSH testing complete!" 