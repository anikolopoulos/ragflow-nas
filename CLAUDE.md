# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RAGFlow is a containerized Retrieval-Augmented Generation (RAG) system deployed using Docker Compose. This is a deployment configuration repository, not the RAGFlow source code itself.

## Deployment Environment

- **Server**: QNAP TVS-h874 NAS running QuTS Hero v5.2.5
- **Access**: Project folder accessed via network drive share from MacBook Pro M4 Max running Claude Code
- **Server Management**: SSH access only - provide commands for file changes
- **SSH Path**: Installation located at `/share/docker/ragflow`
- **Network**: Local network with dynamic IP
- **Reverse Proxy**: Nginx Proxy Manager (NPM)
  - **Public URL**: https://ragflow.leadetic.com:8443
  - **NAS IP**: 10.0.0.10

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
docker exec -it ragflow-server bash
docker exec -it ragflow-mysql mysql -u root -p

# View real-time logs
docker compose logs -f --tail=100

# Test MCP bridge connectivity
curl -X POST http://localhost:9380/mcp/tools -H "Authorization: Bearer YOUR_API_KEY"
```

### Testing MCP Integration

```bash
# Start MCP bridge logs monitoring
docker compose logs -f ragflow

# Test tool listing
curl -X POST http://localhost:9380/mcp/tools \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json"

# Test tool execution (see docs/MCP_BRIDGE_TECHNICAL.md for examples)
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

The MCP (Model Context Protocol) bridge (`mcp-bridge.js`) enables Claude Desktop integration:

- Converts between MCP protocol and RAGFlow REST API
- Handles SSE (Server-Sent Events) for real-time communication
- Manages authentication and request routing
- Implements retry logic and error handling

### Key Configuration Files

- `docker-compose.yml`: Service definitions and orchestration
- `.env`: Environment variables (API keys, ports, resource limits)
- `conf/service_conf.yaml`: RAGFlow application configuration
- `package.json`: Node.js dependencies for MCP bridge

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
