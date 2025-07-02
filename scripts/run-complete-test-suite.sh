#!/bin/bash
# Master test orchestrator for XplainCrypto platform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "🎯 XplainCrypto Complete Test Suite"
echo "=================================="
echo "Timestamp: $(date)"

# Make all scripts executable
chmod +x scripts/*.sh

# Test execution order
test_phases=(
    "environment_validation:Environment Validation:./scripts/validate-environment.sh"
    "infrastructure_tests:Infrastructure Tests:./scripts/test-all-workflows.sh"
    "n8n_integration:n8n Integration:./scripts/test-n8n-integration.sh"
    "workflow_validation:Workflow Validation:./scripts/validate-n8n-workflows.sh"
    "service_monitoring:Service Monitoring:./scripts/monitor-services.sh 60 10"
)

results=()
failed_phases=()

for phase in "${test_phases[@]}"; do
    IFS=':' read -r phase_id phase_name phase_command <<< "$phase"
    
    echo ""
    echo "🔄 Phase: $phase_name"
    echo "Command: $phase_command"
    echo "----------------------------------------"
    
    start_time=$(date +%s)
    if eval "$phase_command"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "✅ $phase_name completed in ${duration}s"
        results+=("$phase_name:PASSED:${duration}s")
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "❌ $phase_name failed after ${duration}s"
        results+=("$phase_name:FAILED:${duration}s")
        failed_phases+=("$phase_name")
    fi
done

# Final summary
echo ""
echo "🎯 Complete Test Suite Summary"
echo "============================="

for result in "${results[@]}"; do
    IFS=':' read -r name status duration <<< "$result"
    printf "%-25s %-8s %s\n" "$name" "$status" "$duration"
done

if [[ ${#failed_phases[@]} -eq 0 ]]; then
    echo ""
    echo "🎉 ALL TEST PHASES PASSED!"
    echo "✅ XplainCrypto platform is fully validated"
    exit 0
else
    echo ""
    echo "⚠️  FAILED PHASES: ${failed_phases[*]}"
    echo "❌ Some test phases failed - review logs above"
    exit 1
fi 