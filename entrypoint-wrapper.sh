#!/bin/bash
# Wrapper script to ensure nginx is configured correctly

# Remove default nginx site and any existing ragflow config
rm -f /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-enabled/ragflow

# Create symlink to ragflow config
ln -sf /etc/nginx/sites-available/ragflow /etc/nginx/sites-enabled/ragflow

# Test nginx configuration
nginx -t

# Reload nginx to apply changes
nginx -s reload || true

# Execute the original entrypoint with MCP server enabled
exec /ragflow/entrypoint.sh \
  --enable-mcpserver \
  --mcp-host=0.0.0.0 \
  --mcp-port=9382 \
  --mcp-base-url=http://127.0.0.1:9380 \
  --mcp-script-path=/ragflow/mcp/server/server.py \
  --mcp-mode=self-host \
  --mcp-host-api-key=ragflow-UwYTZlZDI0NTc4NTExZjA4YWYyMDI0Mm