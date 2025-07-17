#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { EventSource } = require('eventsource');
const fetch = require('node-fetch');

const RAGFLOW_URL = process.env.RAGFLOW_URL || 'http://ragflow.leadetic.com:9380';
const API_KEY = process.env.RAGFLOW_API_KEY || 'ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm';

class RAGFlowMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'ragflow-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupTools();
    this.setupErrorHandling();
  }

  setupTools() {
    // Search documents tool
    this.server.setRequestHandler('tools/call', async (request) => {
      if (request.name === 'search_docs') {
        const { query, limit = 5 } = request.arguments;
        
        try {
          const response = await fetch(`${RAGFLOW_URL}/api/search`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'api_key': API_KEY,
            },
            body: JSON.stringify({
              query,
              limit,
            }),
          });

          if (!response.ok) {
            throw new Error(`RAGFlow API error: ${response.status}`);
          }

          const data = await response.json();
          return {
            content: [{
              type: 'text',
              text: JSON.stringify(data, null, 2),
            }],
          };
        } catch (error) {
          return {
            content: [{
              type: 'text',
              text: `Error searching documents: ${error.message}`,
            }],
            isError: true,
          };
        }
      }
      
      throw new Error(`Unknown tool: ${request.name}`);
    });

    // List available tools
    this.server.setRequestHandler('tools/list', async () => {
      return {
        tools: [
          {
            name: 'search_docs',
            description: 'Search documents in RAGFlow',
            inputSchema: {
              type: 'object',
              properties: {
                query: {
                  type: 'string',
                  description: 'Search query',
                },
                limit: {
                  type: 'number',
                  description: 'Maximum number of results',
                  default: 5,
                },
              },
              required: ['query'],
            },
          },
        ],
      };
    });
  }

  setupErrorHandling() {
    this.server.onerror = (error) => {
      console.error('[RAGFlow MCP] Server error:', error);
    };

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    
    console.error('[RAGFlow MCP] Server started');
  }
}

// Initialize and run the server
const server = new RAGFlowMCPServer();
server.run().catch(console.error);