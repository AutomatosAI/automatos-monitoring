#!/usr/bin/env python3
"""
Enhanced n8n Metrics Exporter for XplainCrypto
Collects comprehensive workflow execution data and infrastructure health
"""

import requests
import time
import json
from prometheus_client import CollectorRegistry, Gauge, Counter, Histogram, push_to_gateway
from datetime import datetime, timedelta
import sys
import os

class EnhancedN8nMetricsExporter:
    def __init__(self):
        self.n8n_url = "http://206.81.0.227:5678"
        self.pushgateway_url = "localhost:9091"
        self.registry = CollectorRegistry()
        
        # Define comprehensive metrics
        self.server_up = Gauge(
            'n8n_server_up',
            'n8n server availability',
            registry=self.registry
        )
        
        self.active_workflows = Gauge(
            'n8n_active_workflows',
            'Number of active workflows',
            registry=self.registry
        )
        
        self.workflow_executions_total = Counter(
            'n8n_workflow_executions_total',
            'Total workflow executions',
            ['workflow', 'status'],
            registry=self.registry
        )
        
        self.workflow_duration_seconds = Histogram(
            'n8n_workflow_duration_seconds',
            'Workflow execution duration',
            ['workflow'],
            buckets=[1, 5, 10, 30, 60, 300, 600],
            registry=self.registry
        )
        
        self.workflow_phase_status = Gauge(
            'n8n_workflow_phase_status',
            'Workflow phase execution status',
            ['phase', 'workflow'],
            registry=self.registry
        )
        
        self.infrastructure_test_status = Gauge(
            'infrastructure_test_overall_status',
            'Infrastructure test overall status',
            registry=self.registry
        )
        
        self.infrastructure_health = Gauge(
            'infrastructure_overall_health',
            'Overall infrastructure health',
            registry=self.registry
        )
        
        self.infrastructure_test_success_rate = Gauge(
            'infrastructure_test_success_rate',
            'Infrastructure test success rate percentage',
            registry=self.registry
        )
        
        self.infrastructure_test_total_count = Gauge(
            'infrastructure_test_total_count',
            'Total number of infrastructure tests',
            registry=self.registry
        )
        
        self.infrastructure_test_passed_count = Gauge(
            'infrastructure_test_passed_count',
            'Number of passed infrastructure tests',
            registry=self.registry
        )
        
        self.infrastructure_test_failed_count = Gauge(
            'infrastructure_test_failed_count',
            'Number of failed infrastructure tests',
            registry=self.registry
        )

    def collect_n8n_metrics(self):
        """Collect n8n-specific metrics"""
        try:
            # Test n8n connectivity
            response = requests.get(f"{self.n8n_url}/healthz", timeout=10)
            if response.status_code == 200:
                self.server_up.set(1)
                print("✅ n8n server is accessible")
            else:
                self.server_up.set(0)
                print(f"⚠️ n8n server returned status {response.status_code}")
                
            # Get workflow data
            try:
                workflows_response = requests.get(f"{self.n8n_url}/api/v1/workflows", timeout=10)
                if workflows_response.status_code == 200:
                    workflows = workflows_response.json()
                    workflow_count = len(workflows.get('data', []))
                    self.active_workflows.set(workflow_count)
                    print(f"📋 Found {workflow_count} active workflows")
                    
                    # Set workflow phase status based on workflow names
                    self._update_workflow_phases(workflows.get('data', []))
                    
            except Exception as e:
                print(f"⚠️ Could not fetch workflow data: {e}")
                
        except Exception as e:
            print(f"❌ Error connecting to n8n: {e}")
            self.server_up.set(0)

    def _update_workflow_phases(self, workflows):
        """Update workflow phase status based on workflow patterns"""
        phases = {
            'phase_1_infrastructure': ['deploy-infrastructure', 'deploy-core-infra'],
            'phase_2_services': ['deploy-mindsdb', 'deploy-fastapi', 'deploy-user-database'],
            'phase_3_monitoring': ['health-check', 'backup-daily', 'collect-logs'],
            'phase_4_maintenance': ['error-alert', 'restore-backup']
        }
        
        for phase, keywords in phases.items():
            for workflow in workflows:
                workflow_name = workflow.get('name', '').lower()
                for keyword in keywords:
                    if keyword in workflow_name:
                        # Assume workflow is ready if it exists
                        self.workflow_phase_status.labels(phase=phase, workflow=workflow_name).set(1)

    def collect_infrastructure_metrics(self):
        """Collect infrastructure test results"""
        try:
            # Read infrastructure test results
            if os.path.exists('/tmp/latest_test_report.json'):
                with open('/tmp/latest_test_report.json', 'r') as f:
                    test_data = json.load(f)
                    
                summary = test_data.get('summary', {})
                
                if test_data.get('overall_status') == 'PASSED':
                    self.infrastructure_test_status.set(1)
                else:
                    self.infrastructure_test_status.set(0)
                
                # Set detailed metrics
                self.infrastructure_test_total_count.set(summary.get('total_tests', 0))
                self.infrastructure_test_passed_count.set(summary.get('passed', 0))
                self.infrastructure_test_failed_count.set(summary.get('failed', 0))
                self.infrastructure_test_success_rate.set(summary.get('success_rate', 0))
                
                print(f"📊 Infrastructure tests: {summary.get('passed', 0)}/{summary.get('total_tests', 0)} passed")
                
        except FileNotFoundError:
            print("ℹ️ No infrastructure test results found")
        except Exception as e:
            print(f"⚠️ Error reading infrastructure test results: {e}")

    def collect_health_metrics(self):
        """Collect infrastructure health data"""
        try:
            if os.path.exists('/tmp/infrastructure_health.json'):
                with open('/tmp/infrastructure_health.json', 'r') as f:
                    health_data = json.load(f)
                    
                if health_data.get('overall_status') == 'healthy':
                    self.infrastructure_health.set(1)
                    print("✅ Infrastructure health: HEALTHY")
                else:
                    self.infrastructure_health.set(0)
                    print("⚠️ Infrastructure health: DEGRADED")
                    
        except FileNotFoundError:
            print("ℹ️ No infrastructure health data found")
        except Exception as e:
            print(f"⚠️ Error reading infrastructure health data: {e}")

    def export_metrics(self):
        """Export metrics to Prometheus Pushgateway"""
        retries = 3
        for attempt in range(retries):
        try:
            push_to_gateway(
                self.pushgateway_url,
                job='xplaincrypto-enhanced-metrics',
                registry=self.registry
            )
            print(f"✅ Enhanced metrics exported at {datetime.now()}")
            return True
        except Exception as e:
                print(f"⚠️ Retry {attempt+1}/{retries}: Error exporting metrics: {e}")
                time.sleep(5)  # Wait before retry
        print("❌ All retries failed")
            return False

    def run(self):
        """Main execution method"""
        print(f"🚀 Starting enhanced metrics collection at {datetime.now()}")
        print("=" * 60)
        
        # Collect all metrics
        self.collect_n8n_metrics()
        self.collect_infrastructure_metrics()
        self.collect_health_metrics()
        
        # Export to Prometheus
        success = self.export_metrics()
        
        print("=" * 60)
        if success:
            print("🎉 Enhanced metrics collection completed successfully")
        else:
            print("💥 Enhanced metrics collection failed")
            sys.exit(1)

if __name__ == "__main__":
    exporter = EnhancedN8nMetricsExporter()
    exporter.run() 