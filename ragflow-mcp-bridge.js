#!/usr/bin/env node

const readline = require('readline');
const fetch = require('node-fetch');

// Configuration
const RAGFLOW_BASE_URL = process.env.RAGFLOW_BASE_URL || 'http://ragflow.leadetic.com:9380';
const RAGFLOW_API_KEY = process.env.RAGFLOW_API_KEY || 'ragflow-UwYTZlZDI0NTc4NTExZjA8YWYyMDI0Mm';

// Simple logging to stderr (visible in Claude Desktop logs)
const log = (message) => {
  console.error(`[ragflow-mcp-bridge] ${message}`);
};

// Create interface for stdio communication
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// Send JSON-RPC response
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

// RAGFlow API wrapper functions
const ragflowAPI = {
  // Search documents
  async searchDocs(query, kbId = null, limit = 5) {
    try {
      const url = `${RAGFLOW_BASE_URL}/api/v1/retrieval`;
      const body = {
        question: query,
        kb_ids: kbId ? [kbId] : [],
        top_k: limit
      };
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${RAGFLOW_API_KEY}`
        },
        body: JSON.stringify(body)
      });
      
      if (!response.ok) {
        throw new Error(`RAGFlow API error: ${response.status}`);
      }
      
      const data = await response.json();
      return data;
    } catch (error) {
      log(`Search error: ${error.message}`);
      throw error;
    }
  },
  
  // List knowledge bases
  async listKnowledgeBases() {
    try {
      const url = `${RAGFLOW_BASE_URL}/api/v1/kb/list`;
      
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${RAGFLOW_API_KEY}`
        }
      });
      
      if (!response.ok) {
        throw new Error(`RAGFlow API error: ${response.status}`);
      }
      
      const data = await response.json();
      return data;
    } catch (error) {
      log(`List KB error: ${error.message}`);
      throw error;
    }
  },
  
  // Chat with RAGFlow
  async chat(message, kbId, conversationId = null) {
    try {
      const url = `${RAGFLOW_BASE_URL}/api/v1/conversation/chat`;
      const body = {
        question: message,
        kb_ids: kbId ? [kbId] : [],
        conversation_id: conversationId
      };
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${RAGFLOW_API_KEY}`
        },
        body: JSON.stringify(body)
      });
      
      if (!response.ok) {
        throw new Error(`RAGFlow API error: ${response.status}`);
      }
      
      const data = await response.json();
      return data;
    } catch (error) {
      log(`Chat error: ${error.message}`);
      throw error;
    }
  }
};

// MCP protocol handlers
const handlers = {
  // Initialize handler
  initialize: async (params, id) => {
    log('Initializing...');
    sendResponse(id, {
      protocolVersion: '2024-11-05',
      capabilities: {
        tools: {}
      },
      serverInfo: {
        name: 'ragflow-mcp-bridge',
        version: '1.0.0'
      }
    });
  },
  
  // List available tools
  'tools/list': async (params, id) => {
    const tools = [
      {
        name: 'search_docs',
        description: 'Search documents in RAGFlow knowledge base',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query'
            },
            kb_id: {
              type: 'string',
              description: 'Knowledge base ID (optional)'
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results',
              default: 5
            }
          },
          required: ['query']
        }
      },
      {
        name: 'list_kbs',
        description: 'List all available knowledge bases',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      },
      {
        name: 'chat',
        description: 'Chat with RAGFlow using knowledge base',
        inputSchema: {
          type: 'object',
          properties: {
            message: {
              type: 'string',
              description: 'Your message'
            },
            kb_id: {
              type: 'string',
              description: 'Knowledge base ID'
            },
            conversation_id: {
              type: 'string',
              description: 'Conversation ID to continue (optional)'
            }
          },
          required: ['message']
        }
      }
    ];
    
    sendResponse(id, { tools });
  },
  
  // Call a tool
  'tools/call': async (params, id) => {
    const { name, arguments: args } = params;
    
    try {
      let result;
      
      switch (name) {
        case 'search_docs':
          result = await ragflowAPI.searchDocs(args.query, args.kb_id, args.limit);
          break;
          
        case 'list_kbs':
          result = await ragflowAPI.listKnowledgeBases();
          break;
          
        case 'chat':
          result = await ragflowAPI.chat(args.message, args.kb_id, args.conversation_id);
          break;
          
        default:
          throw new Error(`Unknown tool: ${name}`);
      }
      
      sendResponse(id, {
        content: [{
          type: 'text',
          text: JSON.stringify(result, null, 2)
        }]
      });
    } catch (error) {
      sendResponse(id, null, {
        code: -32000,
        message: error.message
      });
    }
  }
};

// Process incoming messages
rl.on('line', async (line) => {
  try {
    const message = JSON.parse(line);
    const { method, params, id } = message;
    
    log(`Received: ${method}`);
    
    const handler = handlers[method];
    if (handler) {
      await handler(params, id);
    } else {
      sendResponse(id, null, {
        code: -32601,
        message: `Method not found: ${method}`
      });
    }
  } catch (error) {
    log(`Error processing message: ${error.message}`);
  }
});

// Handle process termination
process.on('SIGINT', () => {
  log('Shutting down...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  log('Shutting down...');
  process.exit(0);
});

// Start the bridge
log('RAGFlow MCP Bridge started');