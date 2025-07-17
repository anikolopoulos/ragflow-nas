# RAGFlow Troubleshooting Guide

## Common Issues and Solutions

### 1. Service Won't Start

#### Symptoms
- `docker compose up` fails
- Services show as "Exited" in `docker compose ps`

#### Solutions

**Check logs first**:
```bash
docker compose logs [service-name]
# Example: docker compose logs ragflow
```

**Common causes**:

1. **Port conflicts**:
   ```bash
   # Check if ports are in use
   netstat -tuln | grep 9380
   lsof -i :9380
   
   # Solution: Change port in docker-compose.yml
   ```

2. **Permission issues**:
   ```bash
   # Fix permissions
   sudo chown -R $USER:$USER .
   chmod -R 755 data logs tmp
   ```

3. **Resource limits**:
   ```bash
   # Check Docker resources
   docker system df
   docker system prune -a
   ```

### 2. Cannot Access Web Interface

#### Symptoms
- Browser shows "Connection refused"
- "Site cannot be reached" error

#### Solutions

1. **Verify services are running**:
   ```bash
   docker compose ps
   # All services should show "Up"
   ```

2. **Check Nginx Proxy Manager**:
   ```bash
   # Check NPM logs
   docker compose logs npm
   
   # Verify proxy configuration exists
   ls -la /Volumes/docker/npm/npm_data/nginx/proxy_host/
   ```

3. **Test direct access**:
   ```bash
   # Bypass proxy, test direct access
   curl http://localhost:9380/api/health
   ```

4. **DNS issues**:
   ```bash
   # Test DNS resolution
   nslookup ragflow.leadetic.com
   ping ragflow.leadetic.com
   ```

### 3. MCP Connection Failed

#### Symptoms
- Claude Desktop shows "Failed to connect to MCP server"
- SSE connection errors

#### Solutions

1. **Verify MCP server is running**:
   ```bash
   # Check MCP logs
   tail -f logs/mcp_server.log
   
   # Test SSE endpoint
   curl -N -H "api_key: your-api-key" http://ragflow.leadetic.com:9380/sse
   ```

2. **API key issues**:
   - Log into RAGFlow web interface
   - Go to Settings > API Keys
   - Verify key matches config
   - Generate new key if needed

3. **Claude Desktop config**:
   ```bash
   # macOS - Check config
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
   
   # Validate JSON syntax
   python -m json.tool < ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

### 4. Document Upload Failures

#### Symptoms
- "Upload failed" error
- Documents stuck in "Processing"

#### Solutions

1. **Check MinIO**:
   ```bash
   # MinIO logs
   docker compose logs minio
   
   # Verify MinIO is accessible
   curl http://localhost:9000/minio/health/live
   ```

2. **Task executor issues**:
   ```bash
   # Check task executor logs
   tail -f logs/task_executor_*.log
   
   # Restart task executors
   docker compose restart ragflow
   ```

3. **File size limits**:
   - Default limit: 100MB
   - Increase in `service_conf.yaml`:
   ```yaml
   max_file_size: 200  # MB
   ```

### 4. Search Not Working

#### Symptoms
- Search returns no results
- "Elasticsearch error" messages

#### Solutions

1. **Check Elasticsearch**:
   ```bash
   # Elasticsearch logs
   docker compose logs elasticsearch
   
   # Check cluster health
   curl -X GET "localhost:9200/_cluster/health?pretty"
   ```

2. **Reindex documents**:
   ```bash
   # Via RAGFlow API
   curl -X POST -H "api_key: your-key" \
     http://localhost:9380/api/kb/reindex
   ```

3. **Memory issues**:
   ```yaml
   # Increase ES memory in docker-compose.yml
   environment:
     - ES_JAVA_OPTS=-Xms4g -Xmx4g
   ```

### 5. High Memory/CPU Usage

#### Symptoms
- System becomes slow
- Docker using excessive resources

#### Solutions

1. **Monitor resource usage**:
   ```bash
   docker stats
   htop
   ```

2. **Limit container resources**:
   ```yaml
   # In docker-compose.yml
   services:
     elasticsearch:
       deploy:
         resources:
           limits:
             memory: 4G
             cpus: '2'
   ```

3. **Optimize services**:
   ```bash
   # Reduce Elasticsearch shards
   # Decrease MySQL buffer pool
   # Limit Redis memory
   ```

### 6. Database Connection Errors

#### Symptoms
- "Can't connect to MySQL" errors
- Database timeout messages

#### Solutions

1. **Check MySQL status**:
   ```bash
   docker compose logs mysql
   docker exec ragflow-mysql mysql -u root -p -e "SHOW STATUS;"
   ```

2. **Connection pool issues**:
   ```yaml
   # Increase max connections
   command: --max_connections=500
   ```

3. **Disk space**:
   ```bash
   df -h
   # Clear old binlogs if needed
   ```

### 7. Backup/Restore Issues

#### Problem: Backup fails

```bash
# Check backup directory permissions
ls -la backups/

# Test manual backup
docker exec ragflow-mysql mysqldump -u root -p ai_lab_ragflow > test_backup.sql
```

#### Problem: Restore fails

```bash
# Stop services first
docker compose stop ragflow

# Restore database
docker exec -i ragflow-mysql mysql -u root -p ai_lab_ragflow < backup.sql

# Restart services
docker compose start ragflow
```

## Performance Optimization

### Slow Document Processing

1. **Increase task executors**:
   ```yaml
   deploy:
     replicas: 3
   ```

2. **Optimize chunk size**:
   ```yaml
   chunk_size: 500  # Adjust based on document types
   ```

### Slow Search Results

1. **Elasticsearch tuning**:
   ```bash
   # Increase refresh interval
   curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d'
   {
     "index" : {
       "refresh_interval" : "30s"
     }
   }'
   ```

2. **Add search replicas**:
   ```bash
   # Increase replica count
   curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d'
   {
     "index" : {
       "number_of_replicas" : 2
     }
   }'
   ```

## Debug Mode

Enable debug logging:

1. **RAGFlow debug**:
   ```yaml
   # In service_conf.yaml
   log_level: DEBUG
   ```

2. **Docker compose debug**:
   ```bash
   docker compose --verbose up
   ```

3. **MCP debug**:
   ```json
   {
     "mcpServers": {
       "ragflow": {
         "transport": "sse",
         "url": "...",
         "debug": true
       }
     }
   }
   ```

## Getting Help

### Collect Diagnostic Information

```bash
# Create diagnostic bundle
cat > collect_diagnostics.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
DIAG_DIR="diagnostics_$DATE"
mkdir -p $DIAG_DIR

# Collect versions
docker version > $DIAG_DIR/docker_version.txt
docker compose version > $DIAG_DIR/compose_version.txt

# Service status
docker compose ps > $DIAG_DIR/services.txt

# Recent logs
docker compose logs --tail=100 > $DIAG_DIR/logs.txt

# Resource usage
docker stats --no-stream > $DIAG_DIR/stats.txt

# Disk usage
df -h > $DIAG_DIR/disk.txt

# Create archive
tar -czf diagnostics_$DATE.tar.gz $DIAG_DIR
rm -rf $DIAG_DIR

echo "Diagnostics saved to diagnostics_$DATE.tar.gz"
EOF

chmod +x collect_diagnostics.sh
./collect_diagnostics.sh
```

### Support Channels

1. **GitHub Issues**: https://github.com/infiniflow/ragflow/issues
2. **Community Forum**: [RAGFlow Discussions]
3. **Documentation**: https://ragflow.io/docs

### Emergency Recovery

If all else fails:

```bash
# 1. Stop all services
docker compose down

# 2. Backup current state
tar -czf emergency_backup.tar.gz .

# 3. Reset to clean state
docker compose down -v  # WARNING: Deletes all data
docker system prune -a

# 4. Restore from backup
# Copy backup files and restart
```

## Prevention Tips

1. **Regular backups**: Automate daily backups
2. **Monitor logs**: Set up log rotation and monitoring
3. **Update regularly**: Keep services updated
4. **Resource monitoring**: Set up alerts for high usage
5. **Test changes**: Use staging environment first