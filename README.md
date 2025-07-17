# RAGFlow Project

## Overview

RAGFlow is a Retrieval-Augmented Generation (RAG) system that provides intelligent document processing and question-answering capabilities. This deployment includes integration with the Model Context Protocol (MCP) for enhanced AI interactions.

## Architecture

The RAGFlow system consists of several interconnected services:

### Core Services
- **RAGFlow Server**: Main application server running on port 9380
- **MySQL**: Database for storing documents, conversations, and metadata
- **Elasticsearch**: Search engine for document indexing and retrieval
- **MinIO**: Object storage for document files
- **Redis**: Caching and session management
- **Nginx Proxy Manager**: Reverse proxy for accessing the system

### Additional Components
- **MCP Server Integration**: Allows Claude Desktop and other MCP clients to interact with RAGFlow
- **Task Executors**: Background workers for document processing

## System Requirements

- Docker and Docker Compose
- QNAP NAS or similar Docker-capable system
- Minimum 8GB RAM (16GB recommended)
- 50GB+ storage space

## Accessing RAGFlow

### Web Interface
- URL: `http://ragflow.leadetic.com`
- Default credentials are set during initial setup

### MCP Server Connection
- Endpoint: `http://ragflow.leadetic.com:9380/sse`
- See `MCP_SERVER.md` for detailed integration instructions

## Configuration Files

### Docker Compose
The main configuration is in `docker-compose.yml` which defines all services and their relationships.

### Service Configuration
- `conf/service_conf.yaml`: Main RAGFlow configuration
- `nginx-ragflow-fixed.conf`: Nginx configuration for the RAGFlow service
- `ragflow-mcp-client.json`: MCP client configuration example

### Environment Variables
Key environment variables include:
- `RAGFLOW_SERVER_PORT`: API server port (default: 9380)
- `MYSQL_PASSWORD`: MySQL root password
- `ES_JAVA_OPTS`: Elasticsearch memory settings

## Directory Structure

```
ragflow/
├── conf/                    # Configuration files
├── data/                    # Application data
├── docker/                  # Docker-related files
├── elasticsearch/           # Elasticsearch data
├── logs/                    # Application logs
├── minio/                   # MinIO object storage
├── mysql/                   # MySQL database files
├── redis/                   # Redis data
├── tmp/                     # Temporary files
├── docker-compose.yml       # Docker Compose configuration
├── entrypoint-wrapper.sh    # Custom entrypoint script
└── ragflow-mcp-client.json  # MCP client configuration
```

## Quick Start

1. **Clone or navigate to the project directory**
   ```bash
   cd /share/docker/ragflow
   ```

2. **Start the services**
   ```bash
   docker compose up -d
   ```

3. **Check service status**
   ```bash
   docker compose ps
   ```

4. **View logs**
   ```bash
   docker compose logs -f
   ```

## Common Operations

### Restart Services
```bash
docker compose restart
```

### Stop Services
```bash
docker compose down
```

### Update Services
```bash
docker compose pull
docker compose up -d
```

### View RAGFlow Logs
```bash
docker compose logs -f ragflow
```

## Maintenance

### Log Rotation
Logs are stored in the `logs/` directory. Implement log rotation to prevent disk space issues:
- `ragflow_server.log`: Main application log
- `mcp_server.log`: MCP server log
- `task_executor_*.log`: Background task logs

### Database Backup
Regular backups of the MySQL database are recommended:
```bash
docker exec ragflow-mysql mysqldump -u root -p ai_lab_ragflow > backup.sql
```

### Storage Cleanup
- Remove old logs from `logs/` directory
- Clean up unused objects in MinIO
- Purge old Elasticsearch indices if needed

## Troubleshooting

See `TROUBLESHOOTING.md` for common issues and solutions.

## API Documentation

RAGFlow provides a REST API for integration:
- Base URL: `http://ragflow.leadetic.com:9380/api`
- Authentication: API key required
- See the official RAGFlow documentation for API details

## Security Considerations

1. **Change default passwords** for all services
2. **Use HTTPS** in production (configure via Nginx Proxy Manager)
3. **Restrict network access** to necessary ports only
4. **Regular security updates** for all containers

## Support and Resources

- Official RAGFlow Documentation: [RAGFlow Docs](https://github.com/infiniflow/ragflow)
- MCP Protocol: [Model Context Protocol](https://github.com/anthropics/model-context-protocol)
- Issues: Create an issue in this repository

## License

This deployment configuration is provided as-is. RAGFlow and its dependencies are subject to their respective licenses.