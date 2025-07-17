# Technical Deep Dive: RAGFlow MCP Bridge Implementation

## Architecture Overview

```
┌─────────────────┐         stdio          ┌──────────────────┐         HTTP         ┌─────────────┐
│ Claude Desktop  │ ◄─────────────────────► │ MCP Bridge Script│ ◄─────────────────► │   RAGFlow   │
│   (MCP Client)  │      JSON-RPC          │    (Node.js)     │      REST API      │  (SSE/HTTP) │
└─────────────────┘                        └──────────────────┘                     └─────────────┘
```

## Protocol Translation Details

### 1. MCP → RAGFlow Translation

#### MCP Request Format
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "search_docs",
    "arguments": {
      "query": "machine learning",
      "limit": 5
    }
  },
  "id": 123
}
```

#### RAGFlow API Request
```http
POST /api/v1/retrieval
Authorization: Bearer ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm
Content-Type: application/json

{
  "question": "machine learning",
  "kb_ids": [],
  "top_k": 5
}
```

### 2. RAGFlow → MCP Translation

#### RAGFlow Response
```json
{
  "code": 0,
  "data": {
    "results": [
      {
        "content": "Machine learning is...",
        "score": 0.95
      }
    ]
  }
}
```

#### MCP Response Format
```json
{
  "jsonrpc": "2.0",
  "id": 123,
  "result": {
    "content": [{
      "type": "text",
      "text": "Results:\n1. Machine learning is... (score: 0.95)"
    }]
  }
}
```

## Implementation Patterns

### 1. Message Buffering Pattern
```javascript
let buffer = '';

const processData = (data) => {
  buffer += data;
  const lines = buffer.split('\n');
  buffer = lines.pop() || '';  // Keep incomplete line in buffer
  
  for (const line of lines) {
    if (line.trim()) {
      processMessage(line);
    }
  }
};
```
**Why**: stdio might deliver partial messages or multiple messages in one chunk

### 2. Dual Input Handling
```javascript
// Method 1: readline interface
rl.on('line', async (line) => {
  if (line.trim()) {
    processMessage(line);
  }
});

// Method 2: raw data stream
process.stdin.on('data', processData);
```
**Why**: Ensures compatibility with different stdio delivery methods

### 3. Error Response Pattern
```javascript
sendResponse(id, null, {
  code: -32601,  // Method not found
  message: 'Resource reading not implemented'
});
```
**Why**: MCP expects specific error codes for proper error handling

## Critical Success Factors

### 1. Complete Method Implementation
Even if not used, these methods MUST be implemented:
- `resources/list` - Returns empty array
- `resources/read` - Returns error
- `prompts/list` - Returns empty array
- `prompts/get` - Returns error

**Without these**: Claude Desktop shows "Invalid input" errors

### 2. Proper Capability Declaration
```javascript
capabilities: {
  tools: {},      // Even if empty, must be present
  resources: {}   // Even if empty, must be present
}
```

### 3. Logging Strategy
```javascript
const log = (message) => {
  console.error(`[ragflow-mcp-bridge] ${message}`);
};
```
- Use `console.error()` for logs (goes to stderr)
- Use `console.log()` only for protocol messages (stdout)

## State Management

### Current Implementation (Stateless)
- Each request is independent
- No session management
- No caching

### Future Enhancement (Stateful)
```javascript
class RAGFlowSession {
  constructor() {
    this.conversationId = null;
    this.knowledgeBases = new Map();
    this.cache = new Map();
  }
  
  async getOrCreateConversation() {
    if (!this.conversationId) {
      const response = await ragflowAPI.createConversation();
      this.conversationId = response.data.id;
    }
    return this.conversationId;
  }
}
```

## Security Considerations

### 1. API Key Handling
```javascript
const RAGFLOW_API_KEY = process.env.RAGFLOW_API_KEY || 'default-key';
log(`API Key: ${RAGFLOW_API_KEY.substring(0, 20)}...`);  // Only log prefix
```

### 2. Input Validation
```javascript
if (!args.query || typeof args.query !== 'string') {
  throw new Error('Query parameter is required and must be a string');
}
```

### 3. Error Information Disclosure
```javascript
// Don't expose internal errors to client
catch (error) {
  log(`Internal error: ${error.stack}`);  // Full error to logs
  sendResponse(id, null, {
    code: -32000,
    message: 'Internal server error'  // Generic message to client
  });
}
```

## Performance Optimizations

### 1. Connection Pooling (Future)
```javascript
const http = require('http');
const keepAliveAgent = new http.Agent({
  keepAlive: true,
  maxSockets: 10
});
```

### 2. Response Streaming (Future)
```javascript
// For large responses
const streamResponse = async (id, dataStream) => {
  for await (const chunk of dataStream) {
    sendNotification('tools/call/progress', {
      id: id,
      chunk: chunk
    });
  }
};
```

## Testing Strategy

### 1. Manual Testing
```bash
# Test initialize
echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | node ragflow-mcp-bridge.js

# Test tools/list
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | node ragflow-mcp-bridge.js

# Test tool call
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search_docs","arguments":{"query":"test"}},"id":3}' | node ragflow-mcp-bridge.js
```

### 2. Integration Testing
```javascript
// test-mcp-bridge.js
const { spawn } = require('child_process');
const bridge = spawn('node', ['ragflow-mcp-bridge.js']);

bridge.stdin.write(JSON.stringify({
  jsonrpc: '2.0',
  method: 'initialize',
  params: {},
  id: 1
}) + '\n');

bridge.stdout.on('data', (data) => {
  console.log('Response:', data.toString());
});
```

## Deployment Considerations

### 1. Process Management
```json
// pm2.config.js
module.exports = {
  apps: [{
    name: 'ragflow-mcp',
    script: 'ragflow-mcp-bridge.js',
    env: {
      RAGFLOW_BASE_URL: 'http://ragflow.leadetic.com:9380',
      RAGFLOW_API_KEY: 'your-api-key'
    }
  }]
};
```

### 2. Docker Deployment
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY ragflow-mcp-bridge.js .
CMD ["node", "ragflow-mcp-bridge.js"]
```

## Monitoring and Observability

### 1. Metrics Collection
```javascript
const metrics = {
  requests: 0,
  errors: 0,
  latency: []
};

// In handlers
const start = Date.now();
// ... handle request ...
metrics.latency.push(Date.now() - start);
```

### 2. Health Check Endpoint
```javascript
if (method === 'health/check') {
  sendResponse(id, {
    status: 'healthy',
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
}
```

## Conclusion

The bridge pattern proved to be the most reliable solution for connecting RAGFlow to Claude Desktop. By implementing a complete MCP server in Node.js that translates to RAGFlow's REST API, we achieved:

1. **Full protocol compatibility**
2. **Reliable message handling**
3. **Extensible architecture**
4. **Clear debugging capabilities**

This approach can serve as a template for integrating other non-MCP services with Claude Desktop.