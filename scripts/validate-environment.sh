#!/bin/bash
# XplainCrypto Infrastructure Environment Validation
# Validates system requirements before deployment

set -e

echo "🔍 XplainCrypto Environment Validation"
echo "======================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

validation_failed=false

# Function to check requirement
check_requirement() {
    local name="$1"
    local command="$2"
    local min_version="$3"
    
    echo -n "Checking $name... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        validation_failed=true
        return 1
    fi
}

# Function to check port availability
check_port() {
    local port="$1"
    local service="$2"
    
    echo -n "Checking port $port ($service)... "
    
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${RED}❌${NC} (port in use)"
        validation_failed=true
        return 1
    else
        echo -e "${GREEN}✅${NC} (available)"
        return 0
    fi
}

# Function to check disk space
check_disk_space() {
    local path="$1"
    local min_gb="$2"
    
    echo -n "Checking disk space for $path... "
    
    available_gb=$(df -BG "$path" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $available_gb -ge $min_gb ]]; then
        echo -e "${GREEN}✅${NC} (${available_gb}GB available)"
        return 0
    else
        echo -e "${RED}❌${NC} (${available_gb}GB available, need ${min_gb}GB)"
        validation_failed=true
        return 1
    fi
}

# Function to check memory
check_memory() {
    local min_gb="$1"
    
    echo -n "Checking system memory... "
    
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_mem_gb=$((total_mem_kb / 1024 / 1024))
    
    if [[ $total_mem_gb -ge $min_gb ]]; then
        echo -e "${GREEN}✅${NC} (${total_mem_gb}GB total)"
        return 0
    else
        echo -e "${RED}❌${NC} (${total_mem_gb}GB total, need ${min_gb}GB)"
        validation_failed=true
        return 1
    fi
}

echo ""
echo "🐳 Docker Requirements:"
check_requirement "Docker daemon" "docker info"
check_requirement "Docker Compose" "docker-compose --version"

echo ""
echo "🔧 System Requirements:"
check_memory 2
check_disk_space "/" 10
check_disk_space "/var/lib" 5

echo ""
echo "🔌 Port Availability:"
check_port 80 "nginx"
check_port 3000 "grafana"
check_port 6379 "redis"
check_port 9090 "prometheus"
check_port 9093 "alertmanager"
check_port 9100 "node-exporter"
check_port 9121 "redis-exporter"
check_port 9091 "pushgateway"
check_port 3100 "loki"

echo ""
echo "📁 Directory Permissions:"
echo -n "Checking /var/lib write access... "
if [[ -w /var/lib ]]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC} (need write access to /var/lib)"
    validation_failed=true
fi

echo -n "Checking /var/log write access... "
if [[ -w /var/log ]]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC} (need write access to /var/log)"
    validation_failed=true
fi

echo ""
echo "🌐 Network Connectivity:"
echo -n "Checking internet connectivity... "
if ping -c 1 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC} (no internet connection)"
    validation_failed=true
fi

echo -n "Checking Docker Hub access... "
if curl -s --connect-timeout 5 https://hub.docker.com &>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️${NC} (Docker Hub may not be accessible)"
fi

echo ""
echo "📊 Validation Summary:"
echo "====================="

if [[ "$validation_failed" == true ]]; then
    echo -e "${RED}❌ Validation FAILED${NC}"
    echo "Please fix the issues above before proceeding with deployment."
    exit 1
else
    echo -e "${GREEN}✅ Validation PASSED${NC}"
    echo "Environment is ready for XplainCrypto infrastructure deployment."
    exit 0
fi 