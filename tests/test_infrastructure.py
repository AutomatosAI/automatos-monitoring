#!/usr/bin/env python3
"""
XplainCrypto Infrastructure Tests
Tests for Redis, Grafana, and Prometheus services
"""

import requests
import redis
import time
import subprocess
import json
import sys

class InfrastructureTests:
    def __init__(self):
        self.redis_host = "localhost"
        self.redis_port = 6379
        self.redis_password = "redis_secure_pass_dev123"
        self.grafana_url = "http://localhost:3000"
        self.prometheus_url = "http://localhost:9090"
        self.redis_exporter_url = "http://localhost:9121"
        self.node_exporter_url = "http://localhost:9100"
        self.pushgateway_url = "http://localhost:9091"
        
    def test_redis_connection(self):
        """Test Redis connectivity"""
        print("🔴 Testing Redis connection...")
        try:
            r = redis.Redis(
                host=self.redis_host,
                port=self.redis_port,
                password=self.redis_password,
                decode_responses=True
            )
            
            # Test basic operations
            r.set("test_key", "test_value")
            value = r.get("test_key")
            r.delete("test_key")
            
            if value == "test_value":
                print("   ✅ Redis connection successful")
                return True
            else:
                print("   ❌ Redis value mismatch")
                return False
                
        except Exception as e:
            print(f"   ❌ Redis connection failed: {e}")
            return False

    def test_redis_databases(self):
        """Test Redis database allocation"""
        print("🗄️  Testing Redis databases...")
        try:
            results = []
            for db in range(4):  # Test databases 0-3
                r = redis.Redis(
                    host=self.redis_host,
                    port=self.redis_port,
                    password=self.redis_password,
                    db=db,
                    decode_responses=True
                )
                
                # Test database access
                test_key = f"test_db_{db}"
                r.set(test_key, f"value_{db}")
                value = r.get(test_key)
                r.delete(test_key)
                
                if value == f"value_{db}":
                    print(f"   ✅ Database {db} accessible")
                    results.append(True)
                else:
                    print(f"   ❌ Database {db} failed")
                    results.append(False)
                    
            return all(results)
                
        except Exception as e:
            print(f"   ❌ Redis database test failed: {e}")
            return False

    def test_grafana_health(self):
        """Test Grafana health"""
        print("📊 Testing Grafana health...")
        try:
            response = requests.get(f"{self.grafana_url}/api/health", timeout=10)
            if response.status_code == 200:
                print("   ✅ Grafana health check passed")
                return True
            else:
                print(f"   ❌ Grafana health check failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"   ❌ Grafana connection failed: {e}")
            return False

    def test_prometheus_health(self):
        """Test Prometheus health"""
        print("📈 Testing Prometheus health...")
        try:
            response = requests.get(f"{self.prometheus_url}/-/healthy", timeout=10)
            if response.status_code == 200:
                print("   ✅ Prometheus health check passed")
                return True
            else:
                print(f"   ❌ Prometheus health check failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"   ❌ Prometheus connection failed: {e}")
            return False

    def test_prometheus_targets(self):
        """Test Prometheus targets"""
        print("🎯 Testing Prometheus targets...")
        try:
            response = requests.get(f"{self.prometheus_url}/api/v1/targets", timeout=10)
            if response.status_code == 200:
                data = response.json()
                active_targets = data.get('data', {}).get('activeTargets', [])
                
                if len(active_targets) > 0:
                    print(f"   ✅ Found {len(active_targets)} active targets")
                    return True
                else:
                    print("   ❌ No active targets found")
                    return False
            else:
                print(f"   ❌ Failed to fetch targets: {response.status_code}")
                return False
        except Exception as e:
            print(f"   ❌ Prometheus targets test failed: {e}")
            return False

    def test_redis_exporter(self):
        """Test Redis Exporter"""
        print("📊 Testing Redis Exporter...")
        try:
            response = requests.get(f"{self.redis_exporter_url}/metrics", timeout=10)
            if response.status_code == 200 and "redis_" in response.text:
                print("   ✅ Redis Exporter responding with metrics")
                return True
            else:
                print(f"   ❌ Redis Exporter failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"   ❌ Redis Exporter connection failed: {e}")
            return False

    def test_node_exporter(self):
        """Test Node Exporter"""
        print("🖥️  Testing Node Exporter...")
        try:
            response = requests.get(f"{self.node_exporter_url}/metrics", timeout=10)
            if response.status_code == 200 and "node_" in response.text:
                print("   ✅ Node Exporter responding with metrics")
                return True
            else:
                print(f"   ❌ Node Exporter failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"   ❌ Node Exporter connection failed: {e}")
            return False

    def test_pushgateway(self):
        """Test Pushgateway"""
        print("📤 Testing Pushgateway...")
        try:
            response = requests.get(f"{self.pushgateway_url}/metrics", timeout=10)
            if response.status_code == 200:
                print("   ✅ Pushgateway responding")
                return True
            else:
                print(f"   ❌ Pushgateway failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"   ❌ Pushgateway connection failed: {e}")
            return False

    def test_docker_containers(self):
        """Test Docker containers status"""
        print("🐳 Testing Docker containers...")
        try:
            result = subprocess.run(
                ["docker", "ps", "--format", "table {{.Names}}\t{{.Status}}"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                output = result.stdout
                expected_containers = [
                    "xplaincrypto-redis",
                    "xplaincrypto-grafana", 
                    "xplaincrypto-prometheus",
                    "xplaincrypto-redis-exporter",
                    "xplaincrypto-node-exporter",
                    "xplaincrypto-pushgateway"
                ]
                
                running_containers = []
                for container in expected_containers:
                    if container in output and "Up" in output:
                        running_containers.append(container)
                        print(f"   ✅ {container} is running")
                    else:
                        print(f"   ❌ {container} not found or not running")
                
                return len(running_containers) == len(expected_containers)
            else:
                print(f"   ❌ Docker ps command failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"   ❌ Docker containers test failed: {e}")
            return False

    def run_all_tests(self):
        """Run all infrastructure tests"""
        print("🧪 XplainCrypto Infrastructure Tests")
        print("=" * 50)
        
        tests = [
            ("Docker Containers", self.test_docker_containers),
            ("Redis Connection", self.test_redis_connection),
            ("Redis Databases", self.test_redis_databases),
            ("Grafana Health", self.test_grafana_health),
            ("Prometheus Health", self.test_prometheus_health),
            ("Prometheus Targets", self.test_prometheus_targets),
            ("Redis Exporter", self.test_redis_exporter),
            ("Node Exporter", self.test_node_exporter),
            ("Pushgateway", self.test_pushgateway)
        ]
        
        results = []
        for test_name, test_func in tests:
            print(f"\n🔍 Running {test_name} test...")
            result = test_func()
            results.append((test_name, result))
            time.sleep(1)  # Brief pause between tests
        
        # Summary
        print("\n" + "=" * 50)
        print("📋 TEST SUMMARY")
        print("=" * 50)
        
        passed = 0
        failed = 0
        
        for test_name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{test_name:25} {status}")
            if result:
                passed += 1
            else:
                failed += 1
        
        print(f"\nTotal: {len(results)} tests")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        
        if failed == 0:
            print("\n🎉 All infrastructure tests passed!")
            return True
        else:
            print(f"\n⚠️  {failed} test(s) failed. Check the output above.")
            return False

if __name__ == "__main__":
    tester = InfrastructureTests()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
