# MCP Server Integration Guide

## Overview

The Model Context Protocol (MCP) server integration allows Claude Desktop and other MCP-compatible clients to interact with your RAGFlow instance. This enables AI assistants to access your document knowledge base and perform RAG operations.

## MCP Server Details

### Connection Information
- **Protocol**: Server-Sent Events (SSE)
- **URL**: `http://ragflow.leadetic.com:9380/sse`
- **Authentication**: API key required

### API Key
Your API key is configured in the MCP client configuration:
```
ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm
```

## Claude Desktop Configuration

### 1. Locate Claude Desktop Config

**macOS**:
```bash
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Windows**:
```
%APPDATA%\Claude\claude_desktop_config.json
```

**Linux**:
```bash
~/.config/claude/claude_desktop_config.json
```

### 2. Add RAGFlow MCP Server

Edit the configuration file to include:

```json
{
  "mcpServers": {
    "ragflow": {
      "transport": "sse",
      "url": "http://ragflow.leadetic.com:9380/sse",
      "headers": {
        "api_key": "ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm"
      }
    }
  }
}
```

### 3. Restart Claude Desktop

After saving the configuration, restart Claude Desktop for the changes to take effect.

## Available MCP Tools

Once connected, the following tools are available in Claude:

### 1. **search_docs**
Search through your RAGFlow knowledge base.

**Parameters**:
- `query`: Search query string
- `kb_id`: (Optional) Specific knowledge base ID
- `limit`: (Optional) Number of results (default: 5)

**Example**:
```
Search for "machine learning algorithms" in my documents
```

### 2. **upload_doc**
Upload a document to RAGFlow.

**Parameters**:
- `file_path`: Path to the document
- `kb_id`: Knowledge base ID

### 3. **list_kbs**
List all available knowledge bases.

### 4. **create_kb**
Create a new knowledge base.

**Parameters**:
- `name`: Knowledge base name
- `description`: (Optional) Description

### 5. **chat**
Have a conversation with RAGFlow using the knowledge base.

**Parameters**:
- `message`: Your question or message
- `kb_id`: Knowledge base ID
- `conversation_id`: (Optional) Continue existing conversation

## Usage Examples

### In Claude Desktop

1. **Search for Information**:
   ```
   Can you search my RAGFlow documents for information about project management?
   ```

2. **Upload a Document**:
   ```
   Please upload the document at /path/to/document.pdf to my RAGFlow knowledge base
   ```

3. **List Knowledge Bases**:
   ```
   Show me all my RAGFlow knowledge bases
   ```

4. **Ask Questions**:
   ```
   Using RAGFlow, what does our documentation say about API authentication?
   ```

## Troubleshooting MCP Connection

### Connection Failed

1. **Verify RAGFlow is Running**:
   ```bash
   curl http://ragflow.leadetic.com:9380/api/health
   ```

2. **Check API Key**:
   - Ensure the API key in your config matches the one in RAGFlow
   - API keys can be managed in RAGFlow's web interface

3. **Network Issues**:
   - Ensure port 9380 is accessible
   - Check firewall rules
   - Verify DNS resolution for ragflow.leadetic.com

### Authentication Errors

1. **Invalid API Key**:
   - Log into RAGFlow web interface
   - Navigate to Settings > API Keys
   - Generate a new key if needed
   - Update claude_desktop_config.json

2. **Header Format**:
   - Ensure the `api_key` header is correctly formatted in the config

### SSE Connection Issues

1. **Timeout Errors**:
   - SSE connections may timeout after periods of inactivity
   - This is normal; the client will reconnect automatically

2. **Proxy Configuration**:
   - If behind a proxy, ensure it supports SSE/EventSource
   - May need to configure proxy settings in Claude Desktop

## Advanced Configuration

### Custom Headers

Add additional headers if required:

```json
{
  "mcpServers": {
    "ragflow": {
      "transport": "sse",
      "url": "http://ragflow.leadetic.com:9380/sse",
      "headers": {
        "api_key": "ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm",
        "X-Custom-Header": "value"
      }
    }
  }
}
```

### Multiple RAGFlow Instances

Connect to multiple RAGFlow instances:

```json
{
  "mcpServers": {
    "ragflow-prod": {
      "transport": "sse",
      "url": "http://ragflow.leadetic.com:9380/sse",
      "headers": {
        "api_key": "prod-api-key"
      }
    },
    "ragflow-dev": {
      "transport": "sse",
      "url": "http://dev.ragflow.local:9380/sse",
      "headers": {
        "api_key": "dev-api-key"
      }
    }
  }
}
```

## Security Best Practices

1. **Use HTTPS in Production**:
   - Configure SSL certificates in Nginx Proxy Manager
   - Update URL to use `https://`

2. **Rotate API Keys Regularly**:
   - Create new API keys periodically
   - Remove old/unused keys

3. **Restrict API Key Permissions**:
   - Use read-only keys when write access isn't needed
   - Create separate keys for different applications

4. **Monitor Access**:
   - Check RAGFlow logs for unauthorized access attempts
   - Monitor API usage patterns

## API Rate Limits

Default rate limits:
- 100 requests per minute per API key
- 1000 requests per hour per API key

Contact your administrator to adjust limits if needed.

## Support

For MCP-specific issues:
- [MCP Documentation](https://github.com/anthropics/model-context-protocol)
- [Claude Desktop Support](https://support.anthropic.com)

For RAGFlow issues:
- Check `TROUBLESHOOTING.md`
- RAGFlow logs in `/logs/mcp_server.log`