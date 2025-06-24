# XplainCrypto Infrastructure Troubleshooting

## Common Issues

### Redis Connection Issues
```bash
# Test Redis connection
docker exec xplaincrypto-redis redis-cli -a redis_secure_pass_dev123 ping

# Check Redis logs
docker logs xplaincrypto-redis
```

### Container Issues
```bash
# Check all container status
docker-compose ps

# Check specific container logs
docker-compose logs [service_name]

# Restart all services
docker-compose down && docker-compose up -d
```

### Port Conflicts
```bash
# Check what's using required ports
netstat -tulpn | grep -E '(3000|6379|9090|9093|9100|9121)'
```

## Health Checks
```bash
# Run infrastructure health check
./scripts/health-check.sh

# Manual health checks
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9090/-/healthy   # Prometheus
```

## Recovery
```bash
# Complete reset (WARNING: Data loss)
docker-compose down
docker system prune -a -f
./scripts/deploy.sh
```
