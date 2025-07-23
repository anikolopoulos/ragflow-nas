# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RAGFlow is a containerized Retrieval-Augmented Generation (RAG) system deployed using Docker Compose. This is a deployment configuration repository, not the RAGFlow source code itself. The system provides document management, AI-powered Q&A, and MCP integration for Claude Desktop.

## Deployment Environment

- **Server**: QNAP TVS-h874 NAS running QuTS Hero v5.2.5
- **Access**: Project folder accessed via network drive share from MacBook Pro M4 Max running Claude Code
- **Server Management**: SSH access only - provide commands for file changes
- **SSH Path**: Installation located at `/share/docker/ragflow`
- **Network**: Local network with dynamic IP
- **Reverse Proxy**: Nginx Proxy Manager (NPM)
  - **Public URL**: https://ragflow.leadetic.com:8443
  - **NAS IP**: 10.0.0.10

## Network Topology

### External Access Configuration
- **Public Domain**: ragflow.leadetic.com
- **External Port**: 8443 (ISP blocks standard ports 80/443)
- **Traffic Flow**: 
  1. Internet → ragflow.leadetic.com:8443
  2. Router port forward → NPM on 10.0.0.10:8443
  3. NPM proxy → ragflow-nas container:80
- **SSL Termination**: Handled by NPM with Let's Encrypt certificates

### DDNS Configuration
- **Purpose**: Updates DigitalOcean DNS A record with current public IP
- **Script**: `/share/docker/ragflow/digitalocean-ddns-update.sh`
- **Schedule**: Runs every 5 minutes via cron
- **Log**: `/share/docker/ragflow/digitalocean-ddns.log`

#### DDNS Script Details
The DDNS update script (`ddns-update.sh`) performs the following:
1. Gets current public IP from multiple sources (ipify.org as primary)
2. Updates two DNS A records in DigitalOcean:
   - `ragflow.leadetic.com` (record ID: 1784898345)
   - `ragflowmcp.leadetic.com` (record ID: 1785218694)
3. Requires `DO_API_TOKEN` environment variable from `.ddns.env` file
4. Logs all operations to `digitalocean-ddns.log`

#### Crontab Configuration
QNAP may remove custom crontab entries on restart. To restore DDNS updates:

1. **Check if cron entry exists:**
   ```bash
   sudo grep ddns /etc/config/crontab
   ```

2. **If missing, add this line to `/etc/config/crontab`:**
   ```bash
   */5 * * * * source /share/docker/ragflow/.ddns.env && /share/docker/ragflow/ddns-update.sh >/dev/null 2>&1
   ```

3. **Edit crontab:**
   ```bash
   sudo vi /etc/config/crontab
   # Add the line above
   # Save with :wq
   ```

4. **Restart cron service:**
   ```bash
   sudo killall crond
   sudo /usr/sbin/crond -c /etc/config/crontab
   ```

5. **Verify API token exists:**
   ```bash
   cat /share/docker/ragflow/.ddns.env
   # Should contain: DO_API_TOKEN="your_token_here"
   ```

### Domain Configuration

#### External Access Setup
- **Public domains**: 
  - `ragflow.leadetic.com:8443` - Main RAGFlow interface
  - `ragflowmcp.leadetic.com:9382` - MCP service endpoint
- **Router configuration**:
  - External port 8443 → Internal 10.0.0.10:8443 (NPM)
  - External port 9382 → Internal 10.0.0.10:9382 (MCP)
- **NPM (Nginx Proxy Manager)**:
  - Listens on port 8443 for HTTPS traffic
  - Proxies ragflow.leadetic.com → ragflow-nas container port 80
  - SSL termination with Let's Encrypt certificates

#### Fixing Domain Access Issues

1. **If domains stop working, check in order:**
   
   a. **DNS Resolution:**
   ```bash
   dig +short ragflow.leadetic.com
   # Should return your current public IP
   ```
   
   b. **DDNS Updates:**
   ```bash
   tail -20 /share/docker/ragflow/digitalocean-ddns.log
   # Check for recent successful updates
   ```
   
   c. **NPM Port Configuration:**
   ```bash
   docker ps | grep npm
   docker port npm
   # Should show: 443/tcp -> 0.0.0.0:8443
   ```
   
   d. **NPM Container:**
   ```bash
   # If port 8443 is missing, edit /share/docker/npm/docker-compose.yml
   # Ensure this line is uncommented:
   # - "8443:443"    # Alternative HTTPS port
   
   # Then recreate container:
   cd /share/docker/npm
   docker compose down
   docker compose up -d
   ```

2. **Manual DNS Update (if DDNS fails):**
   ```bash
   source /share/docker/ragflow/.ddns.env
   export DO_API_TOKEN
   /share/docker/ragflow/ddns-update.sh
   ```

3. **Test connectivity:**
   ```bash
   # From NAS:
   curl -k https://10.0.0.10:8443
   curl -k -H "Host: ragflow.leadetic.com" https://10.0.0.10:8443
   
   # From outside:
   curl -k https://ragflow.leadetic.com:8443/api/health
   ```

## Common Development Commands

### Service Management

```bash
# Start all services
docker compose up -d

# View logs for specific service
docker compose logs -f ragflow  # Options: ragflow, mysql, elasticsearch, minio, redis

# Restart services after configuration changes
docker compose restart

# Update to latest versions
docker compose pull && docker compose up -d

# Stop all services
docker compose down

# Stop and remove all data (CAUTION: destroys all data)
docker compose down -v
```

### Development and Debugging

```bash
# Check service status
docker compose ps

# Execute commands in containers
docker exec -it ragflow-nas bash  # Main container
docker exec -it ragflow-mysql mysql -u root -p$MYSQL_ROOT_PASSWORD  # MySQL

# View real-time logs
docker compose logs -f --tail=100

# Monitor resource usage
docker stats

# Health check
curl http://localhost:9380/api/health
```

### Testing MCP Integration

```bash
# Test MCP bridge connectivity
curl -X POST http://localhost:9380/mcp/tools -H "Authorization: Bearer YOUR_API_KEY"

# Test tool listing
curl -X POST http://localhost:9380/mcp/tools \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json"

# Test tool execution (see docs/MCP_BRIDGE_TECHNICAL.md for examples)
```

### Backup and Restore

```bash
# Run comprehensive backup
./scripts/backup.sh

# Verify backup integrity
./scripts/verify_backup.sh /path/to/backup

# Restore from backup
./scripts/restore.sh /path/to/backup

# Setup automated backups
./scripts/setup_backup_cron.sh
```

## Architecture and Key Components

### Service Architecture

The system consists of these Docker services:

- **ragflow**: Main application server (port 9380) with integrated MCP bridge
- **mysql**: Database for application data
- **elasticsearch**: Search engine for document indexing
- **minio**: S3-compatible object storage for files
- **redis**: Caching layer

### MCP Bridge Architecture

The MCP (Model Context Protocol) bridge enables Claude Desktop integration:

- **Main Script**: `ragflow-mcp-wrapper.js` - Node.js bridge between MCP and RAGFlow API
- **Entry Point**: `entrypoint-wrapper.sh` - Custom startup script that launches nginx and MCP server
- **Port**: 9382 (MCP server listens on stdio transport)
- Converts between MCP protocol and RAGFlow REST API
- Implements `search_docs` tool for document retrieval
- Manages authentication and request routing

### Key Configuration Files

- `docker-compose.yml`: Service definitions and orchestration
- `.env`: Environment variables (API keys, ports, resource limits)
- `conf/service_conf.yaml`: RAGFlow application configuration
- `nginx-ragflow-fixed.conf`: Custom nginx configuration
- `package.json`: Node.js dependencies for MCP bridge
- `entrypoint-wrapper.sh`: Custom startup script

### API Authentication

All API requests require Bearer token authentication:

```
Authorization: Bearer YOUR_RAGFLOW_API_KEY
```

## Important Considerations

### When Modifying Configuration

1. Always backup `.env` before changes
2. Run `docker compose restart` after config changes
3. Check logs for startup errors: `docker compose logs -f`

### When Updating Services

1. Create backups first (see DEPLOYMENT.md)
2. Pull latest images: `docker compose pull`
3. Recreate containers: `docker compose up -d`
4. Verify services are healthy: `docker compose ps`

### When Debugging Issues

1. Check service logs: `docker compose logs [service-name]`
2. Verify network connectivity between services
3. Check resource usage (disk space, memory)
4. Review `TROUBLESHOOTING.md` for common issues

### When Working with MCP Integration

1. Ensure API key is correctly set in Claude Desktop config
2. Monitor MCP bridge logs for connection issues
3. Test with simple tools before complex operations
4. Refer to `docs/MCP_BRIDGE_TECHNICAL.md` for protocol details

## Data Locations

- MySQL data: `./mysql/`
- Elasticsearch indices: `./elasticsearch/`
- MinIO objects: `./minio/`
- Application logs: `./logs/`
- Temporary files: `./tmp/`
- Backup files: `/share/docker/backups/ragflow/`

## File Permissions Note

When editing files from macOS via network share, files may need proper permissions on the NAS. Use SSH to fix permissions if containers fail to read modified files:

```bash
ssh admin@10.0.0.10
cd /share/docker/ragflow
chmod 644 filename  # For config files
chmod 755 script.sh # For executable scripts
```

## Nginx Proxy Manager (NPM) Configuration

### Main Proxy Host Settings
- **Domain**: ragflow.leadetic.com
- **Scheme**: http
- **Forward Hostname**: ragflow-nas (container name)
- **Forward Port**: 80
- **Cache Assets**: Off
- **Block Common Exploits**: On
- **Websockets Support**: On

### SSL Settings
- **SSL Certificate**: Let's Encrypt
- **Force SSL**: On
- **HTTP/2 Support**: On
- **HSTS Enabled**: On
- **HSTS Subdomains**: Off

### Custom Location: /sse (Server-Sent Events)
- **Location**: /sse
- **Scheme**: http
- **Forward Hostname**: ragflow-nas
- **Forward Port**: 80
- **Advanced Configuration**:
```nginx
proxy_pass http://ragflow-nas:80/sse;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Connection '';
proxy_http_version 1.1;
chunked_transfer_encoding off;
proxy_buffering off;
proxy_cache off;
proxy_read_timeout 86400s;
proxy_send_timeout 86400s;
```

### Custom Location: /mcp (Model Context Protocol)
- **Location**: /mcp
- **Scheme**: http
- **Forward Hostname**: ragflow-nas
- **Forward Port**: 80
- **Advanced Configuration**:
```nginx
proxy_pass http://ragflow-nas:80/mcp;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_buffering off;
proxy_read_timeout 300s;
proxy_send_timeout 300s;
```

### Important NPM Notes
- NPM container name: `npm`
- NPM generates duplicate `proxy_pass` directives when custom locations have advanced config (known bug)
- If NPM fails to start after SSL changes, manually edit `/data/nginx/proxy_host/4.conf` to remove duplicate `proxy_pass` lines
- Let's Encrypt rate limit: 5 certificates per domain per week

## Lessons Learned from Configuration Issues

### Model Configuration in RAGFlow v0.19.1

1. **Required Model Variables**: RAGFlow v0.19.1 requires these model configuration keys in `service_conf.yaml.template`:
   - `chat_mdl`
   - `embedding_mdl`
   - `rerank_mdl`
   - `asr_mdl`
   - `image2text_mdl`

2. **Empty String Handling**: Never use empty strings (`""`) for model values in the template. The template processor strips quotes, causing YAML to interpret them as `None`, which leads to TypeError. Always provide actual model names.

3. **Factory Name Detection**: RAGFlow extracts factory names from model names:
   - Models containing "BAAI" → BAAI factory
   - Models containing "e5" → Youdao factory
   - The `factory` field in configuration is largely ignored for display purposes

4. **Model Name Format**: When specifying models:
   - For OpenAI models via LiteLLM: `"model-name@OpenAI"`
   - For local models: Use the actual model name without special suffixes
   - The `___OpenAI-API` suffix doesn't work as expected

### Configuration Best Practices

1. **Template Processing**: Let RAGFlow's entrypoint process the template. Don't mount a static `service_conf.yaml` as it causes conflicts.

2. **Environment Variables**: Ensure all required variables are set in `.env`:
   - Database credentials
   - Service passwords
   - API keys

3. **Model Selection**: Even if models appear under wrong factories in the UI, they'll use the correct endpoints specified in `base_url`.

### Troubleshooting Tips

1. **TypeError: 'NoneType' is not iterable**: This means a model configuration value is None. Check that all `*_mdl` keys have non-empty values.

2. **Container Restart Loop**: Check for:
   - File permission issues with mounted volumes
   - Conflicts between mounted files and entrypoint expectations
   - nginx PID file errors

3. **502 Bad Gateway**: Usually means the RAGFlow server process isn't running. Check logs for Python exceptions.

### Current Working Configuration

The system is now configured with:
- Chat models via OpenAI/LiteLLM
- Local embedding service at 10.0.0.132:8030
- Local reranking service at 10.0.0.132:8030
- All required model variables properly set

Even though some models appear under BAAI/Youdao factories in the UI, they correctly use the configured OpenAI-API-Compatible endpoints.
