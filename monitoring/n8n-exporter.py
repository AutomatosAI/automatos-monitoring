#!/usr/bin/env python3
"""
n8n Execution Metrics Exporter for Prometheus
Collects workflow execution data and pushes to Prometheus
"""

import requests
import time
import json
from prometheus_client import CollectorRegistry, Gauge, Counter, push_to_gateway
from datetime import datetime, timedelta
import sys
import os

class N8nMetricsExporter:
    def __init__(self):
        self.n8n_url = "http://206.81.0.227:5678"
        self.pushgateway_url = "localhost:9091"
        self.registry = CollectorRegistry()
        
        # Define metrics
        self.workflow_executions_total = Counter(
            'n8n_workflow_executions_total',
            'Total workflow executions',
            ['workflow_name', 'status'],
            registry=self.registry
        )
        
        self.workflow_duration_seconds = Gauge(
            'n8n_workflow_duration_seconds',
            'Workflow execution duration in seconds',
            ['workflow_name'],
            registry=self.registry
        )
        
        self.workflow_errors_total = Counter(
            'n8n_workflow_errors_total',
            'Total workflow errors',
            ['workflow_name', 'error_type'],
            registry=self.registry
        )
        
        self.workflow_success_rate = Gauge(
            'n8n_workflow_success_rate',
            'Workflow success rate percentage',
            ['workflow_name'],
            registry=self.registry
        )
        
        self.n8n_up = Gauge(
            'n8n_up',
            'n8n service availability',
            registry=self.registry
        )

    def get_executions(self, hours=1):
        """Get recent executions from n8n API"""
        try:
            response = requests.get(
                f"{self.n8n_url}/api/v1/executions",
                params={
                    'limit': 1000,
                    'includeData': 'false'  # Don't need full data for metrics
                },
                timeout=30
            )
            response.raise_for_status()
            self.n8n_up.set(1)
            return response.json()
        except Exception as e:
            print(f"❌ Error fetching executions: {e}")
            self.n8n_up.set(0)
            return {'data': []}

    def get_workflows(self):
        """Get list of workflows"""
        try:
            response = requests.get(
                f"{self.n8n_url}/api/v1/workflows",
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"❌ Error fetching workflows: {e}")
            return {'data': []}

    def process_executions(self, executions_data):
        """Process executions and update metrics"""
        workflow_stats = {}
        
        # Process recent executions
        for execution in executions_data.get('data', []):
            workflow_name = execution.get('workflowData', {}).get('name', 'unknown')
            status = execution.get('status', 'unknown')
            
            # Initialize workflow stats
            if workflow_name not in workflow_stats:
                workflow_stats[workflow_name] = {
                    'success': 0, 'error': 0, 'running': 0, 'waiting': 0,
                    'durations': [], 'errors': {}
                }
            
            # Count executions by status
            if status in workflow_stats[workflow_name]:
                workflow_stats[workflow_name][status] += 1
            
            # Track duration for completed executions
            if execution.get('startedAt') and execution.get('stoppedAt'):
                try:
                    start = datetime.fromisoformat(execution['startedAt'].replace('Z', '+00:00'))
                    stop = datetime.fromisoformat(execution['stoppedAt'].replace('Z', '+00:00'))
                    duration = (stop - start).total_seconds()
                    workflow_stats[workflow_name]['durations'].append(duration)
                except Exception as e:
                    print(f"⚠️ Error parsing timestamps: {e}")
            
            # Track error types
            if status == 'error':
                error_type = 'general_error'
                try:
                    if execution.get('data', {}).get('resultData', {}).get('error'):
                        error_msg = str(execution['data']['resultData']['error'])
                        error_type = error_msg.split(':')[0] if ':' in error_msg else 'unknown_error'
                except:
                    pass
                
                workflow_stats[workflow_name]['errors'][error_type] = \
                    workflow_stats[workflow_name]['errors'].get(error_type, 0) + 1

        # Update Prometheus metrics
        for workflow_name, stats in workflow_stats.items():
            # Execution counts
            for status in ['success', 'error', 'running', 'waiting']:
                if stats[status] > 0:
                    self.workflow_executions_total.labels(
                        workflow_name=workflow_name, 
                        status=status
                    )._value._value += stats[status]
            
            # Average duration
            if stats['durations']:
                avg_duration = sum(stats['durations']) / len(stats['durations'])
                self.workflow_duration_seconds.labels(workflow_name=workflow_name).set(avg_duration)
            
            # Success rate
            total_completed = stats['success'] + stats['error']
            if total_completed > 0:
                success_rate = (stats['success'] / total_completed) * 100
                self.workflow_success_rate.labels(workflow_name=workflow_name).set(success_rate)
            
            # Error counts by type
            for error_type, count in stats['errors'].items():
                self.workflow_errors_total.labels(
                    workflow_name=workflow_name,
                    error_type=error_type
                )._value._value += count

    def export_metrics(self):
        """Export metrics to Prometheus Pushgateway"""
        try:
            push_to_gateway(
                self.pushgateway_url,
                job='n8n-workflow-metrics',
                registry=self.registry
            )
            print(f"✅ Metrics pushed to Prometheus at {datetime.now()}")
            return True
        except Exception as e:
            print(f"❌ Error pushing metrics: {e}")
            return False

    def run(self):
        """Main execution loop"""
        print(f"🚀 Starting n8n metrics export at {datetime.now()}")
        
        # Get data
        executions = self.get_executions()
        workflows = self.get_workflows()
        
        print(f"📊 Found {len(executions.get('data', []))} recent executions")
        print(f"📋 Found {len(workflows.get('data', []))} workflows")
        
        # Process and export
        self.process_executions(executions)
        success = self.export_metrics()
        
        if success:
            print("🎉 n8n metrics export completed successfully")
        else:
            print("💥 n8n metrics export failed")
            sys.exit(1)

if __name__ == "__main__":
    exporter = N8nMetricsExporter()
    exporter.run() 