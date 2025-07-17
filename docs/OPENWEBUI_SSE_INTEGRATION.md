# RAGFlow SSE Integration with Open WebUI MCPO

## Overview

Since MCPO successfully handles SSE connections (as demonstrated by Apify), we should try the direct SSE approach for RAGFlow before implementing a custom bridge script.

## Direct SSE Configuration

### 1. Simple SSE Configuration

```json
"ragflow": {
  "url": "${RAGFLOW_BASE_URL}/sse",
  "type": "sse",
  "headers": {
    "api_key": "${RAGFLOW_API_KEY}"
  }
}
```

This mirrors the Apify configuration pattern:
```json
"apify": {
  "url": "https://mcp.apify.com/sse",
  "type": "sse",
  "headers": {
    "Authorization": "Bearer ${APIFY_TOKEN}"
  }
}
```

### 2. Docker Compose Configuration

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
      - ./openwebui-mcpo-config-sse.sh:/app/startup.sh:ro
    environment:
      # RAGFlow Configuration (SSE)
      RAGFLOW_BASE_URL: "http://ragflow.leadetic.com:9380"
      RAGFLOW_API_KEY: "ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm"
      
      # Other API Keys
      APIFY_TOKEN: "your-apify-token"
      BRAVE_API_KEY: "your-brave-key"
    
    entrypoint: ["/bin/sh", "/app/startup.sh"]
    ports:
      - "8000:8000"
```

## Testing the SSE Approach

### 1. Start with Minimal Configuration

First, test with just RAGFlow and one other service:

```bash
#!/bin/sh
cat > /app/config/runtime-mcp.config.json << EOF
{
  "mcpServers": {
    "ragflow": {
      "url": "${RAGFLOW_BASE_URL}/sse",
      "type": "sse",
      "headers": {
        "api_key": "${RAGFLOW_API_KEY}"
      }
    }
  }
}
EOF

exec mcpo --config /app/config/runtime-mcp.config.json
```

### 2. Check MCPO Logs

```bash
docker logs -f mcpo-container
```

Look for:
- Successful SSE connection establishment
- Any authentication errors
- Protocol negotiation messages

### 3. Test in Open WebUI

Ask the model to list available tools. If RAGFlow appears, the SSE connection is working.

## Potential Issues and Solutions

### Issue 1: 405 Method Not Allowed

If you see this error (like with Claude Desktop), it means the SSE endpoint doesn't accept the HTTP method MCPO is using.

**Solution**: Fall back to the Node.js bridge approach.

### Issue 2: Authentication Headers

Different MCP servers expect different header formats:
- Apify uses: `"Authorization": "Bearer ${TOKEN}"`
- RAGFlow might expect: `"api_key": "${KEY}"` or `"Api-Key": "${KEY}"`

**Try variations**:
```json
"headers": {
  "Authorization": "Bearer ${RAGFLOW_API_KEY}"
}
```

Or:
```json
"headers": {
  "Api-Key": "${RAGFLOW_API_KEY}"
}
```

### Issue 3: CORS or Network Issues

If running in Docker, ensure RAGFlow is accessible:
```bash
# From inside MCPO container
curl -H "api_key: your-key" http://ragflow.leadetic.com:9380/sse
```

## Advantages of SSE Approach

1. **No Additional Scripts**: No need to maintain bridge scripts
2. **Native Protocol**: Uses MCP's built-in SSE support
3. **Simpler Deployment**: No volume mounts or script management
4. **Direct Connection**: Lower latency, fewer moving parts

## When to Use Bridge Script

Only fall back to the Node.js bridge if:
1. SSE endpoint returns persistent 405 errors
2. Protocol incompatibility that can't be resolved
3. Need for request/response transformation
4. Custom authentication logic required

## Debugging SSE Connection

### 1. Enable Debug Logging

Some MCPO implementations support debug flags:
```bash
exec mcpo --debug --config /app/config/runtime-mcp.config.json
```

### 2. Test SSE Endpoint Directly

```bash
# Test SSE stream
curl -N -H "api_key: ${RAGFLOW_API_KEY}" \
  "${RAGFLOW_BASE_URL}/sse"
```

### 3. Inspect Network Traffic

```bash
# Inside container
tcpdump -i any -n host ragflow.leadetic.com
```

## Conclusion

The SSE approach is simpler and more maintainable than a custom bridge script. Since MCPO successfully handles Apify's SSE endpoint, there's a good chance it will work with RAGFlow's SSE endpoint too. Only if this approach fails should you fall back to the Node.js bridge solution.

Key differences from Claude Desktop:
- MCPO is designed to handle multiple transport types
- MCPO has built-in SSE client capabilities
- MCPO might handle protocol negotiation differently

Try the SSE approach first - it could save significant complexity!