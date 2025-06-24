# XplainCrypto Infrastructure Troubleshooting

## Common Issues and Solutions

### Container Startup Issues

#### Redis Container Won't Start
**Symptoms**: Redis container exits immediately
```bash
# Check Redis logs
docker logs xplaincrypto-redis

# Common causes:
# 1. Port 6379 already in use
# 2. Insufficient memory
# 3. Volume permission issues
```

**Solutions**:
```bash
# Check if port is in use
lsof -i :6379

# Free up memory
docker system prune -f

# Fix volume permissions
sudo chown -R 999:999 monitoring/redis/
```

#### Grafana Container Issues
**Symptoms**: Grafana shows "Internal Server Error"
```bash
# Reset Grafana data
docker-compose down
docker volume rm xplaincrypto_grafana_data
docker-compose up -d grafana
```

### Network Connectivity Issues

#### Services Can't Communicate
**Symptoms**: Connection refused between containers
```bash
# Verify network exists
docker network ls | grep xplaincrypto_network

# Check if containers are on the same network
docker inspect xplaincrypto-redis | grep NetworkMode
```

**Solutions**:
```bash
# Recreate network
docker network rm xplaincrypto_network
docker network create xplaincrypto_network

# Restart all services
docker-compose down && docker-compose up -d
```

#### Port Conflicts
**Symptoms**: "Port already in use" errors
```bash
# Check what's using the ports
netstat -tulpn | grep -E '(3000|6379|9090|9093|9100|9121)'

# Kill processes if needed
sudo kill -9 $(sudo lsof -t -i:3000)
```

### Performance Issues

#### High Memory Usage
**Symptoms**: System becomes slow, containers getting killed
```bash
# Check memory usage
docker stats

# Check system memory
free -h

# Check disk space
df -h
```

**Solutions**:
```bash
# Clean up Docker
docker system prune -a -f

# Restart services with lower memory limits
docker-compose down
# Edit docker-compose.yml to add memory limits
docker-compose up -d
```

#### Redis Memory Issues
**Symptoms**: Redis OOM errors
```bash
# Check Redis memory usage
docker exec xplaincrypto-redis redis-cli -a redis_secure_pass_dev123 info memory

# Check Redis configuration
docker exec xplaincrypto-redis redis-cli -a redis_secure_pass_dev123 config get maxmemory
```

### Data Issues

#### Lost Configuration
**Symptoms**: Grafana dashboards missing after restart
```bash
# Check if data volumes exist
docker volume ls | grep xplaincrypto

# Restore from backup
./scripts/backup.sh  # if you have backups
```

#### Redis Data Corruption
**Symptoms**: Redis won't start, mentions dump.rdb errors
```bash
# Remove corrupted data (WARNING: data loss)
docker-compose down
docker volume rm xplaincrypto_redis_data
docker-compose up -d redis
```

### Monitoring Issues

#### Prometheus Not Scraping Targets
**Symptoms**: Targets showing as "DOWN" in Prometheus
```bash
# Check Prometheus configuration
docker exec xplaincrypto-prometheus cat /etc/prometheus/prometheus.yml

# Check if targets are reachable
docker exec xplaincrypto-prometheus wget -qO- http://node-exporter:9100/metrics
```

#### Missing Metrics
**Symptoms**: Dashboards show "No data"
```bash
# Restart Prometheus
docker-compose restart prometheus

# Check exporter logs
docker logs xplaincrypto-node-exporter
docker logs xplaincrypto-redis-exporter
```

## Diagnostic Commands

### Health Check Everything
```bash
./scripts/health-check.sh
```

### Container Status
```bash
docker-compose ps
docker-compose logs [service_name]
```

### Resource Usage
```bash
docker stats
docker system df
```

### Network Debugging
```bash
# List networks
docker network ls

# Inspect network
docker network inspect xplaincrypto_network

# Test connectivity between containers
docker exec xplaincrypto-redis ping prometheus
```

### Redis Debugging
```bash
# Connect to Redis CLI
docker exec -it xplaincrypto-redis redis-cli -a redis_secure_pass_dev123

# Check Redis info
redis-cli> info
redis-cli> client list
redis-cli> config get "*"
```

## Emergency Recovery

### Complete Reset (WARNING: Data Loss)
```bash
# Stop everything
docker-compose down

# Remove all volumes
docker volume rm $(docker volume ls | grep xplaincrypto | awk '{print $2}')

# Remove network
docker network rm xplaincrypto_network

# Clean Docker
docker system prune -a -f

# Redeploy
./scripts/deploy.sh
```

### Partial Recovery
```bash
# Reset just one service
docker-compose down [service_name]
docker volume rm xplaincrypto_[service]_data
docker-compose up -d [service_name]
```

## Getting Help

### Log Collection
Before reporting issues, collect logs:
```bash
# Create log archive
mkdir -p troubleshooting/$(date +%Y%m%d_%H%M%S)
cd troubleshooting/$(date +%Y%m%d_%H%M%S)

# Collect container logs
docker-compose logs > docker-compose.log
docker stats --no-stream > docker-stats.log
docker system df > docker-df.log
docker network ls > docker-networks.log

# Collect system info
uname -a > system-info.log
free -h > memory-info.log
df -h > disk-info.log
```

### Support Checklist
When requesting help, include:
- [ ] Output of `./scripts/health-check.sh`
- [ ] Container logs for failing services
- [ ] System resource usage (`docker stats`)
- [ ] Docker version (`docker --version`)
- [ ] Operating system and version
- [ ] Steps to reproduce the issue
- [ ] Any recent changes made

## Performance Optimization

### Redis Optimization
```bash
# Connect to Redis and optimize
docker exec -it xplaincrypto-redis redis-cli -a redis_secure_pass_dev123

# Set memory policy
CONFIG SET maxmemory-policy allkeys-lru

# Set memory limit (adjust as needed)
CONFIG SET maxmemory 1gb

# Save configuration
CONFIG REWRITE
```

### Monitoring Optimization
```bash
# Reduce Prometheus retention if disk space is low
# Edit monitoring/prometheus/prometheus.yml:
# --storage.tsdb.retention.time=7d
``` 