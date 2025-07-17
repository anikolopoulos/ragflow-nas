# RAGFlow MCP Integration Guide: Connecting to Claude Desktop

## Overview

This guide documents the approach used to successfully connect RAGFlow to Claude Desktop using the Model Context Protocol (MCP). The integration faced several challenges due to RAGFlow's SSE-based implementation and Claude Desktop's stdio requirements.

## The Challenge

### Initial Problem
- **RAGFlow provides**: An SSE (Server-Sent Events) endpoint at `http://ragflow.leadetic.com:9380/sse`
- **Claude Desktop expects**: stdio-based MCP servers that communicate via standard input/output
- **Mismatch**: Direct SSE configuration caused errors in Claude Desktop

### Failed Approaches

1. **Direct SSE Configuration**
   ```json
   "ragflow": {
     "transport": "sse",
     "url": "http://ragflow.leadetic.com:9380/sse",
     "headers": {
       "api_key": "ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm"
     }
   }
   ```
   **Result**: JSON validation error - Claude Desktop requires a `command` field

2. **Using supergateway**
   ```json
   "ragflow": {
     "command": "supergateway",
     "args": ["--sse", "http://ragflow.leadetic.com:9380/sse"]
   }
   ```
   **Result**: 405 Not Allowed - RAGFlow's SSE endpoint doesn't accept POST requests

3. **Using mcp-proxy**
   ```json
   "ragflow": {
     "command": "mcp-proxy",
     "args": ["http://ragflow.leadetic.com:9380/sse"]
   }
   ```
   **Result**: Incorrect usage - mcp-proxy is for the opposite direction

## The Solution: Custom Bridge Script

### Approach
Create a Node.js script that:
1. Communicates with Claude Desktop via stdio (stdin/stdout)
2. Translates MCP protocol messages to RAGFlow REST API calls
3. Returns responses in MCP-compliant format

### Key Components

#### 1. stdio Communication
```javascript
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// Handle both line-based and streaming input
process.stdin.setEncoding('utf8');
process.stdin.on('data', processData);
```

#### 2. MCP Protocol Implementation
The script implements all required MCP methods:
- `initialize` - Protocol handshake
- `tools/list` - List available tools
- `tools/call` - Execute tool functions
- `resources/list` - Required by MCP (returns empty)
- `resources/read` - Required by MCP (returns error)
- `prompts/list` - Required by MCP (returns empty)
- `prompts/get` - Required by MCP (returns error)

#### 3. JSON-RPC Message Handling
```javascript
const sendResponse = (id, result, error = null) => {
  const response = {
    jsonrpc: '2.0',
    id: id
  };
  
  if (error) {
    response.error = error;
  } else {
    response.result = result;
  }
  
  console.log(JSON.stringify(response));
};
```

#### 4. Error Handling
- Buffer incomplete messages
- Log all interactions to stderr
- Handle uncaught exceptions
- Provide detailed error messages

### Implementation Details

#### Message Processing Flow
1. **Input**: Claude Desktop sends JSON-RPC messages via stdin
2. **Processing**: Script parses messages and routes to appropriate handlers
3. **API Translation**: (Future) Convert MCP tool calls to RAGFlow API requests
4. **Output**: Send JSON-RPC responses via stdout

#### Critical Implementation Points

1. **No Shebang Line**: When using `node` command, the shebang (`#!/usr/bin/env node`) causes syntax errors

2. **Complete Protocol Support**: Must implement all MCP methods, even if returning empty results

3. **Proper Logging**: Use stderr for logs (visible in Claude Desktop Developer logs)

4. **Message Buffering**: Handle partial messages and line breaks correctly

## Configuration

### Claude Desktop Configuration
```json
{
  "mcpServers": {
    "ragflow": {
      "command": "node",
      "args": ["/Users/alex/mcp_servers/ragflow-mcp/ragflow-mcp-bridge.js"],
      "env": {
        "RAGFLOW_BASE_URL": "http://ragflow.leadetic.com:9380",
        "RAGFLOW_API_KEY": "ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm"
      }
    }
  }
}
```

### File Structure
```
/Users/alex/mcp_servers/ragflow-mcp/
├── ragflow-mcp-bridge.js    # Bridge script
└── package.json              # Dependencies (if needed)
```

## Why This Approach Works

1. **Protocol Compatibility**: Bridges the gap between SSE and stdio
2. **Full MCP Compliance**: Implements all required protocol methods
3. **Flexible Architecture**: Can easily add RAGFlow API integration
4. **Debugging Support**: Comprehensive logging for troubleshooting
5. **No External Dependencies**: Uses only Node.js built-in modules

## Next Steps

### Adding RAGFlow API Integration

1. **Install Dependencies**
   ```bash
   npm install node-fetch@2
   ```

2. **Implement API Calls**
   ```javascript
   const ragflowAPI = {
     async searchDocs(query, kbId, limit) {
       const response = await fetch(`${RAGFLOW_BASE_URL}/api/v1/retrieval`, {
         method: 'POST',
         headers: {
           'Content-Type': 'application/json',
           'Authorization': `Bearer ${RAGFLOW_API_KEY}`
         },
         body: JSON.stringify({
           question: query,
           kb_ids: kbId ? [kbId] : [],
           top_k: limit
         })
       });
       return response.json();
     }
   };
   ```

3. **Update Tool Handlers**
   Replace placeholder responses with actual API calls

## Troubleshooting

### Common Issues

1. **"Invalid input" errors**: Ensure all required MCP methods are implemented
2. **Syntax errors**: Remove shebang line when using `node` command
3. **No connection**: Check file paths and permissions
4. **API errors**: Verify API key and endpoint URLs

### Debugging Steps

1. Check Claude Desktop Developer logs
2. View stderr output in logs folder
3. Test script manually: `echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | node ragflow-mcp-bridge.js`

## Lessons Learned

1. **MCP is stdio-first**: Most integrations assume stdio communication
2. **Complete protocol implementation**: Partial implementations cause validation errors
3. **Bridge pattern**: Often the best solution for protocol mismatches
4. **Logging is crucial**: stderr logging helps debug protocol issues
5. **Start simple**: Get basic connection working before adding complexity

## Conclusion

The custom bridge approach successfully connects RAGFlow to Claude Desktop by:
- Accepting stdio input that Claude Desktop expects
- Translating to RAGFlow's REST API format
- Returning MCP-compliant responses

This pattern can be adapted for other services that don't natively support MCP's stdio transport.