#!/bin/bash
# Manual testing script following the documented build flow

set -e

echo "🎯 XplainCrypto Manual Build Flow Test"
echo "====================================="
echo "Following documented build process step by step"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
passed_phases=0
total_phases=6

# Function to run phase and wait for user confirmation
run_phase() {
    local phase_num="$1"
    local phase_name="$2"
    local phase_command="$3"
    local expected_output="$4"
    
    echo ""
    echo -e "${BLUE}📋 Phase $phase_num: $phase_name${NC}"
    echo "============================================="
    echo "Command: $phase_command"
    echo "Expected: $expected_output"
    echo ""
    
    read -p "Press Enter to execute this phase..."
    
    echo "🔄 Executing..."
    if eval "$phase_command"; then
        echo ""
        echo -e "${GREEN}✅ Phase $phase_num completed successfully${NC}"
        ((passed_phases++))
        
        echo ""
        read -p "Verify the output matches expected result. Press Enter to continue..."
    else
        echo ""
        echo -e "${RED}❌ Phase $phase_num failed${NC}"
        echo "Please check the error above and fix before continuing"
        
        read -p "Fix the issue and press Enter to retry, or Ctrl+C to abort..."
        run_phase "$phase_num" "$phase_name" "$phase_command" "$expected_output"
    fi
}

echo "This script will test each phase of the build flow manually."
echo "You'll be prompted before each phase execution."
echo ""
read -p "Ready to start? Press Enter to begin..."

# Phase 1: Pre-Deployment Validation
run_phase "1.1" "Environment Validation" \
    "./scripts/validate-environment.sh" \
    "✅ Validation PASSED"

run_phase "1.2" "Directory Setup" \
    "sudo ./scripts/create-required-directories.sh" \
    "✅ Directory setup complete!"

# Phase 2: Infrastructure Deployment
run_phase "2.1" "Core Infrastructure Deployment" \
    "./scripts/deploy-infrastructure.sh" \
    "✅ All services are healthy and ready!"

run_phase "2.2" "Health Verification" \
    "./scripts/comprehensive-health-check.sh" \
    "JSON report saved to: /tmp/infrastructure_health.json"

# Phase 3: Monitoring Enhancement
run_phase "3.1" "Dashboard Deployment" \
    "./scripts/update-monitoring-dashboards.sh" \
    "✅ Dashboard updates completed"

run_phase "3.2" "Enhanced Metrics Setup" \
    "sudo ./scripts/setup-enhanced-monitoring.sh" \
    "✅ Enhanced monitoring setup completed!"

echo ""
echo "🎯 Manual Build Flow Test Summary"
echo "================================"
echo "Phases Completed: $passed_phases/$total_phases"

if [[ $passed_phases -eq $total_phases ]]; then
    echo -e "${GREEN}🎉 ALL PHASES PASSED!${NC}"
    echo ""
    echo "📊 Quick Access Verification:"
    echo "  Grafana: http://localhost:3000 (admin/grafana_admin_dev123)"
    echo "  Prometheus: http://localhost:9090"
    echo "  AlertManager: http://localhost:9093"
    echo ""
    echo "🧪 Run additional tests:"
    echo "  ./scripts/test-all-workflows.sh"
    echo "  ./scripts/test-n8n-integration.sh"
    echo "  ./scripts/validate-n8n-workflows.sh"
    
    echo ""
    read -p "Run complete testing suite now? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🧪 Running complete test suite..."
        ./scripts/run-complete-test-suite.sh
    fi
    
else
    echo -e "${RED}❌ Some phases failed${NC}"
    echo "Please review the errors above and retry failed phases"
fi

echo ""
echo "✅ Manual testing completed!" 