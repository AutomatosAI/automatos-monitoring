#!/bin/bash
# Test n8n workflow integration and API connectivity

set -e

echo "🤖 n8n Integration Testing"
echo "========================="

N8N_URL="http://206.81.0.227:5678"
N8N_DNS="http://n8n.xplaincrypto.ai"

# Test n8n API connectivity
echo ""
echo "🔗 Testing n8n API connectivity..."

test_n8n_endpoint() {
    local name="$1"
    local url="$2"
    
    echo -n "Testing $name... "
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url/healthz" 2>/dev/null); then
        if [[ "$response" == "200" ]]; then
            echo -e "✅ ($response)"
            return 0
        else
            echo -e "❌ ($response)"
            return 1
        fi
    else
        echo -e "❌ (connection failed)"
        return 1
    fi
}

# Test both IP and DNS
test_n8n_endpoint "n8n IP" "$N8N_URL"
test_n8n_endpoint "n8n DNS" "$N8N_DNS"

# Test specific workflow endpoints
echo ""
echo "🔄 Testing workflow trigger endpoints..."

workflow_webhooks=(
    "infrastructure-deploy:/webhook/deploy-infrastructure"
    "health-check:/webhook/health-check"
    "backup-services:/webhook/backup-all"
)

for webhook in "${workflow_webhooks[@]}"; do
    IFS=':' read -r name endpoint <<< "$webhook"
    echo -n "Testing $name webhook... "
    
    # Test webhook endpoint exists (should return method not allowed for GET)
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$N8N_URL$endpoint" 2>/dev/null || echo "000")
    
    if [[ "$response" == "405" || "$response" == "200" ]]; then
        echo -e "✅ (endpoint exists)"
    else
        echo -e "❌ ($response)"
    fi
done

# Generate n8n integration report
cat > /tmp/n8n_integration_report.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "n8n_server": "$N8N_URL",
  "n8n_dns": "$N8N_DNS",
  "connectivity_status": "$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL/healthz" 2>/dev/null)",
  "webhook_tests": "completed"
}
EOF

echo ""
echo "✅ n8n integration tests completed"
echo "📄 Report: /tmp/n8n_integration_report.json" 