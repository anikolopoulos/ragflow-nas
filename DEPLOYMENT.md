# RAGFlow Deployment Guide

## Prerequisites

### System Requirements
- **OS**: Linux, macOS, or Windows with Docker support
- **CPU**: 4+ cores recommended
- **RAM**: Minimum 8GB, 16GB+ recommended
- **Storage**: 50GB+ available space
- **Docker**: Version 20.10+ 
- **Docker Compose**: Version 2.0+

### Network Requirements
- Port 9380: RAGFlow API
- Port 80/443: Web interface (via Nginx Proxy Manager)
- Internal ports for service communication

## Installation Steps

### 1. Prepare the Environment

**On QNAP NAS**:
```bash
ssh admin@nas-ip-address
cd /share/docker
mkdir ragflow
cd ragflow
```

**On Standard Linux**:
```bash
mkdir -p ~/docker/ragflow
cd ~/docker/ragflow
```

### 2. Clone or Download RAGFlow

```bash
# Clone the repository (if available)
git clone https://github.com/infiniflow/ragflow.git .

# Or download and extract
wget https://github.com/infiniflow/ragflow/archive/main.zip
unzip main.zip
mv ragflow-main/* .
rm -rf ragflow-main main.zip
```

### 3. Configure Environment

Create `.env` file:
```bash
cat > .env << EOF
# MySQL Configuration
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_DATABASE=ai_lab_ragflow
MYSQL_USER=ragflow
MYSQL_PASSWORD=your_ragflow_password

# Elasticsearch Configuration
ES_JAVA_OPTS=-Xms2g -Xmx2g
ELASTIC_PASSWORD=your_elastic_password

# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_minio_password

# RAGFlow Configuration
RAGFLOW_SERVER_PORT=9380
EOF
```

### 4. Configure Docker Compose

Ensure `docker-compose.yml` includes all necessary services:
- ragflow
- mysql
- elasticsearch
- minio
- redis
- nginx (optional, for reverse proxy)

### 5. Initialize Data Directories

```bash
# Create necessary directories
mkdir -p data logs mysql elasticsearch minio redis tmp

# Set permissions
chmod -R 755 data logs tmp
```

### 6. Deploy Services

```bash
# Pull images
docker compose pull

# Start services
docker compose up -d

# Check status
docker compose ps
```

### 7. Verify Deployment

```bash
# Check service health
docker compose ps

# View logs
docker compose logs -f ragflow

# Test API endpoint
curl http://localhost:9380/api/health
```

## Post-Deployment Configuration

### 1. Access Web Interface

1. Open browser to `http://your-server-ip`
2. Complete initial setup wizard
3. Create admin account
4. Configure knowledge bases

### 2. Configure Nginx Proxy Manager

If using NPM for reverse proxy:

1. Access NPM at `http://your-server-ip:81`
2. Default credentials: `admin@example.com` / `changeme`
3. Add proxy host:
   - Domain: `ragflow.yourdomain.com`
   - Forward to: `ragflow:80`
   - Enable SSL with Let's Encrypt

### 3. Set Up API Access

1. Log into RAGFlow web interface
2. Navigate to Settings > API Keys
3. Generate new API key
4. Save key for MCP configuration

### 4. Configure MCP Server

Update `ragflow-mcp-client.json`:
```json
{
  "mcpServers": {
    "ragflow": {
      "transport": "sse",
      "url": "http://ragflow.yourdomain.com:9380/sse",
      "headers": {
        "api_key": "your-generated-api-key"
      }
    }
  }
}
```

## Production Deployment

### SSL/TLS Configuration

1. **Using Let's Encrypt**:
   ```bash
   # Via Nginx Proxy Manager UI
   # Or using certbot directly
   ```

2. **Custom Certificates**:
   - Place certificates in `/etc/ssl/certs/`
   - Update nginx configuration

### Performance Tuning

1. **Elasticsearch**:
   ```yaml
   environment:
     - ES_JAVA_OPTS=-Xms4g -Xmx4g
     - indices.memory.index_buffer_size=30%
   ```

2. **MySQL**:
   ```yaml
   command: --max_connections=500 --innodb_buffer_pool_size=2G
   ```

3. **Redis**:
   ```yaml
   command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
   ```

### Backup Strategy

1. **Database Backup**:
   ```bash
   # Create backup script
   cat > backup.sh << 'EOF'
   #!/bin/bash
   DATE=$(date +%Y%m%d_%H%M%S)
   docker exec ragflow-mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD ai_lab_ragflow > backups/mysql_$DATE.sql
   docker exec ragflow-minio mc mirror minio/ragflow backups/minio_$DATE/
   EOF
   
   chmod +x backup.sh
   ```

2. **Schedule with cron**:
   ```bash
   crontab -e
   # Add: 0 2 * * * /path/to/backup.sh
   ```

### Monitoring

1. **Resource Monitoring**:
   ```bash
   # Check resource usage
   docker stats
   
   # Monitor specific service
   docker logs -f ragflow --tail 100
   ```

2. **Health Checks**:
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:9380/api/health"]
     interval: 30s
     timeout: 10s
     retries: 3
   ```

## Scaling Considerations

### Horizontal Scaling

1. **Multiple Task Executors**:
   ```yaml
   deploy:
     replicas: 3
   ```

2. **Load Balancing**:
   - Use HAProxy or Nginx for load balancing
   - Configure session affinity if needed

### Vertical Scaling

1. **Increase Resources**:
   ```yaml
   resources:
     limits:
       cpus: '4'
       memory: 8G
     reservations:
       cpus: '2'
       memory: 4G
   ```

## Upgrade Process

### 1. Backup Current Installation
```bash
./backup.sh
docker compose down
cp -r . ../ragflow-backup-$(date +%Y%m%d)
```

### 2. Update Images
```bash
docker compose pull
```

### 3. Apply Updates
```bash
docker compose up -d
```

### 4. Verify Upgrade
```bash
docker compose ps
docker compose logs -f ragflow
```

## Rollback Procedure

If issues occur after upgrade:

```bash
# Stop services
docker compose down

# Restore from backup
cp -r ../ragflow-backup-YYYYMMDD/* .

# Restore database
docker compose up -d mysql
docker exec -i ragflow-mysql mysql -u root -p$MYSQL_ROOT_PASSWORD ai_lab_ragflow < backups/mysql_YYYYMMDD.sql

# Start all services
docker compose up -d
```

## Security Hardening

### 1. Network Security
```yaml
networks:
  ragflow-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 2. Environment Variables
- Use Docker secrets for sensitive data
- Never commit `.env` files to version control

### 3. Access Control
- Implement firewall rules
- Use VPN for remote access
- Enable 2FA where possible

## Troubleshooting Deployment

See `TROUBLESHOOTING.md` for common issues and solutions.

## Support Resources

- RAGFlow Documentation: https://github.com/infiniflow/ragflow
- Docker Documentation: https://docs.docker.com
- Community Forums: [RAGFlow Discussions]