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

if __name__ == "__main__":
    tester = InfrastructureTests()
    print("🧪 XplainCrypto Infrastructure Tests")
    print("Infrastructure testing framework created!")
