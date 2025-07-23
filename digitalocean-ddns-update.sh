#!/bin/bash
# DigitalOcean DDNS update script for ragflow.leadetic.com
# This script updates the DNS A record with the current public IP

# Configuration
DOMAIN="ragflow.leadetic.com"
LOG_FILE="/share/docker/ragflow/digitalocean-ddns.log"

# Check if DO_API_TOKEN is set
if [ -z "$DO_API_TOKEN" ]; then
    echo "$(date): ERROR - DO_API_TOKEN environment variable not set" >> "$LOG_FILE"
    exit 1
fi

# Function to log messages
log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Get current public IP from multiple sources for reliability
get_public_ip() {
    local ip=""
    
    # Try multiple services
    for service in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com"; do
        ip=$(curl -s --max-time 5 "$service" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    done
    
    return 1
}

# Main execution
log_message "Starting DDNS update for $DOMAIN"

# Get current public IP
CURRENT_IP=$(get_public_ip)
if [ -z "$CURRENT_IP" ]; then
    log_message "ERROR - Failed to get current public IP"
    exit 1
fi

log_message "Current public IP: $CURRENT_IP"

# Get the domain name without subdomain (e.g., leadetic.com from ragflow.leadetic.com)
BASE_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
SUBDOMAIN=$(echo "$DOMAIN" | sed "s/\.$BASE_DOMAIN//")

# First, get all domains to find our domain ID
DOMAINS_RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer $DO_API_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.digitalocean.com/v2/domains")

# Extract domain name from response
DOMAIN_EXISTS=$(echo "$DOMAINS_RESPONSE" | grep -o "\"name\":\"$BASE_DOMAIN\"")

if [ -z "$DOMAIN_EXISTS" ]; then
    log_message "ERROR - Domain $BASE_DOMAIN not found in DigitalOcean account"
    exit 1
fi

# Get all DNS records for the domain
RECORDS_RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer $DO_API_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.digitalocean.com/v2/domains/$BASE_DOMAIN/records?type=A")

# Parse the response to find our A record
RECORD_ID=$(echo "$RECORDS_RESPONSE" | grep -B2 -A2 "\"name\":\"$SUBDOMAIN\"" | grep -E '"type":"A"' -B3 -A1 | grep -o '"id":[0-9]*' | cut -d: -f2)
CURRENT_DNS_IP=$(echo "$RECORDS_RESPONSE" | grep -B2 -A2 "\"name\":\"$SUBDOMAIN\"" | grep -E '"type":"A"' -B3 -A3 | grep -o '"data":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RECORD_ID" ]; then
    log_message "WARNING - A record not found for $DOMAIN, creating new record"
    
    # Create new A record
    CREATE_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer $DO_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"A\",\"name\":\"$SUBDOMAIN\",\"data\":\"$CURRENT_IP\",\"ttl\":300}" \
        "https://api.digitalocean.com/v2/domains/$BASE_DOMAIN/records")
    
    if echo "$CREATE_RESPONSE" | grep -q '"id"'; then
        log_message "Successfully created new A record for $DOMAIN pointing to $CURRENT_IP"
    else
        log_message "ERROR - Failed to create A record: $CREATE_RESPONSE"
        exit 1
    fi
else
    # Check if update is needed
    if [ "$CURRENT_DNS_IP" = "$CURRENT_IP" ]; then
        log_message "DNS already up to date ($CURRENT_IP), no changes needed"
        exit 0
    fi
    
    log_message "Updating DNS record ID $RECORD_ID from $CURRENT_DNS_IP to $CURRENT_IP"
    
    # Update existing record
    UPDATE_RESPONSE=$(curl -s -X PUT \
        -H "Authorization: Bearer $DO_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\":\"$CURRENT_IP\"}" \
        "https://api.digitalocean.com/v2/domains/$BASE_DOMAIN/records/$RECORD_ID")
    
    if echo "$UPDATE_RESPONSE" | grep -q '"id"'; then
        log_message "Successfully updated $DOMAIN from $CURRENT_DNS_IP to $CURRENT_IP"
    else
        log_message "ERROR - Failed to update DNS record: $UPDATE_RESPONSE"
        exit 1
    fi
fi