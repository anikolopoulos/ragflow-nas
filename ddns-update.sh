#!/bin/bash
# DDNS update for both ragflow.leadetic.com and ragflowmcp.leadetic.com

# Configuration
DOMAIN="leadetic.com"
RAGFLOW_RECORD_ID="1784898345"
RAGFLOWMCP_RECORD_ID="1785218694"  # Found from the debug output
LOG_FILE="/share/docker/ragflow/digitalocean-ddns.log"

# Check if DO_API_TOKEN is set
if [ -z "$DO_API_TOKEN" ]; then
    echo "$(date): ERROR - DO_API_TOKEN environment variable not set" >> "$LOG_FILE"
    exit 1
fi

# Get current public IP
CURRENT_IP=$(curl -s https://api.ipify.org)
if [ -z "$CURRENT_IP" ]; then
    echo "$(date): ERROR - Failed to get current public IP" >> "$LOG_FILE"
    exit 1
fi

echo "$(date): Starting DDNS update for ragflow domains" >> "$LOG_FILE"
echo "$(date): Current public IP: $CURRENT_IP" >> "$LOG_FILE"

# Update ragflow.leadetic.com
UPDATE_RESPONSE1=$(curl -s -X PUT \
    -H "Authorization: Bearer $DO_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"data\":\"$CURRENT_IP\"}" \
    "https://api.digitalocean.com/v2/domains/$DOMAIN/records/$RAGFLOW_RECORD_ID")

if echo "$UPDATE_RESPONSE1" | grep -q "\"id\":$RAGFLOW_RECORD_ID"; then
    echo "$(date): Successfully updated ragflow.leadetic.com to $CURRENT_IP" >> "$LOG_FILE"
    echo "SUCCESS: Updated ragflow.leadetic.com to $CURRENT_IP"
else
    echo "$(date): ERROR - Failed to update ragflow.leadetic.com: $UPDATE_RESPONSE1" >> "$LOG_FILE"
    echo "ERROR: Failed to update ragflow.leadetic.com"
fi

# Update ragflowmcp.leadetic.com
UPDATE_RESPONSE2=$(curl -s -X PUT \
    -H "Authorization: Bearer $DO_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"data\":\"$CURRENT_IP\"}" \
    "https://api.digitalocean.com/v2/domains/$DOMAIN/records/$RAGFLOWMCP_RECORD_ID")

if echo "$UPDATE_RESPONSE2" | grep -q "\"id\":$RAGFLOWMCP_RECORD_ID"; then
    echo "$(date): Successfully updated ragflowmcp.leadetic.com to $CURRENT_IP" >> "$LOG_FILE"
    echo "SUCCESS: Updated ragflowmcp.leadetic.com to $CURRENT_IP"
else
    echo "$(date): ERROR - Failed to update ragflowmcp.leadetic.com: $UPDATE_RESPONSE2" >> "$LOG_FILE"
    echo "ERROR: Failed to update ragflowmcp.leadetic.com"
fi