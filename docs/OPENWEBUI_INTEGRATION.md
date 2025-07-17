# Integrating RAGFlow MCP with Open WebUI MCPO Server

## Overview

This guide explains how to add RAGFlow MCP support to Open WebUI's MCPO (Model Context Protocol Orchestrator) server, allowing all models in Open WebUI to access your RAGFlow knowledge base.

## Integration Steps

### 1. Update the MCPO Configuration Script

Add the RAGFlow configuration to your MCPO startup script:

```bash
"ragflow": {
  "command": "node",
  "args": ["/app/ragflow-mcp/ragflow-mcp-bridge.js"],
  "env": {
    "RAGFLOW_BASE_URL": "\${RAGFLOW_BASE_URL}",
    "RAGFLOW_API_KEY": "\${RAGFLOW_API_KEY}"
  }
}
```

### 2. Copy the Bridge Script to the Container

The RAGFlow MCP bridge script needs to be available inside the MCPO container. You have several options:

#### Option A: Mount as Volume
```yaml
# In docker-compose.yml
services:
  mcpo:
    volumes:
      - ./ragflow-mcp:/app/ragflow-mcp:ro
```

#### Option B: Build Custom Image
```dockerfile
FROM mcpo:latest
COPY ragflow-mcp-bridge.js /app/ragflow-mcp/
```

#### Option C: Download at Runtime
Add to the startup script before the config generation:
```bash
# Download the bridge script if not present
if [ ! -f /app/ragflow-mcp/ragflow-mcp-bridge.js ]; then
  mkdir -p /app/ragflow-mcp
  wget -O /app/ragflow-mcp/ragflow-mcp-bridge.js \
    https://raw.githubusercontent.com/your-repo/ragflow-mcp-bridge.js
fi
```

### 3. Set Environment Variables

Add these environment variables to your docker-compose.yml:

```yaml
services:
  mcpo:
    environment:
      # Existing variables...
      RAGFLOW_BASE_URL: "http://ragflow.leadetic.com:9380"
      RAGFLOW_API_KEY: "ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm"
```

### 4. Update TOOL_SERVER_CONNECTION

As mentioned in the script comments, update the Docker Compose environment line:

```yaml
TOOL_SERVER_CONNECTION: "time,memory,apify,dataforseo,firecrawl,playwright,brave-search,ragflow"
```

## Complete Docker Compose Example

```yaml
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:latest
    environment:
      TOOL_SERVER_CONNECTION: "http://mcpo:8000"
    depends_on:
      - mcpo

  mcpo:
    image: mcpo:latest
    volumes:
      - ./openwebui-mcpo-config.sh:/app/startup.sh:ro
      - ./ragflow-mcp:/app/ragflow-mcp:ro
    environment:
      # API Keys
      APIFY_TOKEN: "your-apify-token"
      DATAFORSEO_USERNAME: "your-dataforseo-username"
      DATAFORSEO_PASSWORD: "your-dataforseo-password"
      FIRECRAWL_API_KEY: "your-firecrawl-key"
      BRAVE_API_KEY: "your-brave-key"
      
      # RAGFlow Configuration
      RAGFLOW_BASE_URL: "http://ragflow.leadetic.com:9380"
      RAGFLOW_API_KEY: "ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm"
      
      # Tool Server Connection List
      TOOL_SERVER_CONNECTION: "time,memory,apify,dataforseo,firecrawl,playwright,brave-search,ragflow"
    
    entrypoint: ["/bin/sh", "/app/startup.sh"]
    ports:
      - "8000:8000"
```

## Networking Considerations

### If RAGFlow is in the Same Docker Network
```yaml
RAGFLOW_BASE_URL: "http://ragflow:9380"
```

### If RAGFlow is External
```yaml
RAGFLOW_BASE_URL: "http://ragflow.leadetic.com:9380"
```

### If Using Host Network
```yaml
RAGFLOW_BASE_URL: "http://host.docker.internal:9380"
```

## Testing the Integration

1. **Check MCPO Logs**
   ```bash
   docker logs mcpo-container-name
   ```
   
   Look for:
   - `[ragflow-mcp-bridge] RAGFlow MCP Bridge started`
   - `[ragflow-mcp-bridge] Initializing...`

2. **Test in Open WebUI**
   - Create a new chat
   - Ask: "What tools do you have available?"
   - The model should list RAGFlow search_docs tool

3. **Test RAGFlow Search**
   - Ask: "Search my RAGFlow documents for [topic]"
   - The model should attempt to use the search_docs tool

## Troubleshooting

### Bridge Script Not Found
```
Error: Cannot find module '/app/ragflow-mcp/ragflow-mcp-bridge.js'
```
**Solution**: Ensure the script is properly mounted or copied to the container

### Environment Variables Not Set
```
[ragflow-mcp-bridge] Base URL: undefined
```
**Solution**: Check that environment variables are properly escaped with `\$` in the script

### Connection Refused
```
Error: connect ECONNREFUSED
```
**Solution**: Verify RAGFlow is accessible from the MCPO container

### Invalid API Key
```
RAGFlow API error: 401
```
**Solution**: Update RAGFLOW_API_KEY environment variable

## Advanced Configuration

### Custom Bridge Script Location
```bash
"ragflow": {
  "command": "node",
  "args": ["${RAGFLOW_BRIDGE_PATH:-/app/ragflow-mcp/ragflow-mcp-bridge.js}"],
  "env": {
    "RAGFLOW_BASE_URL": "\${RAGFLOW_BASE_URL}",
    "RAGFLOW_API_KEY": "\${RAGFLOW_API_KEY}"
  }
}
```

### Multiple RAGFlow Instances
```bash
"ragflow-prod": {
  "command": "node",
  "args": ["/app/ragflow-mcp/ragflow-mcp-bridge.js"],
  "env": {
    "RAGFLOW_BASE_URL": "\${RAGFLOW_PROD_URL}",
    "RAGFLOW_API_KEY": "\${RAGFLOW_PROD_KEY}"
  }
},
"ragflow-dev": {
  "command": "node",
  "args": ["/app/ragflow-mcp/ragflow-mcp-bridge.js"],
  "env": {
    "RAGFLOW_BASE_URL": "\${RAGFLOW_DEV_URL}",
    "RAGFLOW_API_KEY": "\${RAGFLOW_DEV_KEY}"
  }
}
```

## Security Best Practices

1. **Use Docker Secrets**
   ```yaml
   secrets:
     ragflow_api_key:
       external: true
   
   services:
     mcpo:
       secrets:
         - ragflow_api_key
   ```

2. **Network Isolation**
   ```yaml
   networks:
     mcp-net:
       internal: true
   ```

3. **Read-Only Mounts**
   Always mount scripts as read-only (`:ro`)

## Conclusion

By following this guide, you can successfully integrate RAGFlow MCP with Open WebUI's MCPO server, making your RAGFlow knowledge base available to all AI models in Open WebUI. The key is ensuring:

1. The bridge script is accessible in the container
2. Environment variables are properly configured
3. Network connectivity between services is established
4. The service is listed in TOOL_SERVER_CONNECTION