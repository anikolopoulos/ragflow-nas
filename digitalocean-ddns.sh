#!/bin/bash
# DigitalOcean DDNS update script

# Configuration - EDIT THESE
DO_API_TOKEN="your_digitalocean_api_token_here"
DOMAIN="leadetic.com"
SUBDOMAIN="ragflow"
LOG_FILE="/share/docker/ragflow/digitalocean-ddns.log"

# Log start
echo "$(date): Starting DDNS update for $SUBDOMAIN.$DOMAIN" >> "$LOG_FILE"

# Get current public IP
CURRENT_IP=$(curl -s -4 ifconfig.me)
if [ -z "$CURRENT_IP" ]; then
    echo "$(date): ERROR - Could not determine current IP" >> "$LOG_FILE"
    exit 1
fi

echo "$(date): Current public IP: $CURRENT_IP" >> "$LOG_FILE"

# Get current DNS record
RECORD_INFO=$(curl -s -X GET \
  "https://api.digitalocean.com/v2/domains/$DOMAIN/records" \
  -H "Authorization: Bearer $DO_API_TOKEN" \
  -H "Content-Type: application/json" | \
  jq -r ".domain_records[] | select(.name == \"$SUBDOMAIN\" and .type == \"A\")")

if [ -z "$RECORD_INFO" ]; then
    echo "$(date): ERROR - DNS record not found for $SUBDOMAIN.$DOMAIN" >> "$LOG_FILE"
    exit 1
fi

# Extract record ID and current IP
RECORD_ID=$(echo "$RECORD_INFO" | jq -r '.id')
DNS_IP=$(echo "$RECORD_INFO" | jq -r '.data')

echo "$(date): DNS record ID: $RECORD_ID, Current DNS IP: $DNS_IP" >> "$LOG_FILE"

# Check if update is needed
if [ "$CURRENT_IP" = "$DNS_IP" ]; then
    echo "$(date): No update needed - IPs match" >> "$LOG_FILE"
    exit 0
fi

# Update DNS record
echo "$(date): Updating DNS record from $DNS_IP to $CURRENT_IP" >> "$LOG_FILE"

UPDATE_RESPONSE=$(curl -s -X PUT \
  "https://api.digitalocean.com/v2/domains/$DOMAIN/records/$RECORD_ID" \
  -H "Authorization: Bearer $DO_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"data\":\"$CURRENT_IP\"}")

if echo "$UPDATE_RESPONSE" | jq -e '.domain_record.data' > /dev/null 2>&1; then
    UPDATED_IP=$(echo "$UPDATE_RESPONSE" | jq -r '.domain_record.data')
    echo "$(date): SUCCESS - DNS updated to $UPDATED_IP" >> "$LOG_FILE"
else
    echo "$(date): ERROR - Failed to update DNS: $UPDATE_RESPONSE" >> "$LOG_FILE"
    exit 1
fi