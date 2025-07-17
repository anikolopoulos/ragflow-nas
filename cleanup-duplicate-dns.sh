#!/bin/bash
# DigitalOcean DNS cleanup script - removes duplicate A records

# Configuration - EDIT THESE
DO_API_TOKEN="your_digitalocean_api_token_here"
DOMAIN="leadetic.com"
SUBDOMAIN="ragflow"

echo "Fetching all DNS records for $DOMAIN..."

# Get all DNS records
RECORDS=$(curl -s -X GET \
  "https://api.digitalocean.com/v2/domains/$DOMAIN/records" \
  -H "Authorization: Bearer $DO_API_TOKEN" \
  -H "Content-Type: application/json")

# Filter A records for the subdomain
A_RECORDS=$(echo "$RECORDS" | jq -r ".domain_records[] | select(.name == \"$SUBDOMAIN\" and .type == \"A\") | .id")

# Count records
RECORD_COUNT=$(echo "$A_RECORDS" | wc -l | tr -d ' ')

echo "Found $RECORD_COUNT A records for $SUBDOMAIN.$DOMAIN"

if [ "$RECORD_COUNT" -le 1 ]; then
    echo "No duplicates found. Exiting."
    exit 0
fi

echo "Duplicate records found. Keeping the first one and deleting the rest..."

# Keep track of which is first
FIRST_RECORD=true

# Loop through each record ID
echo "$A_RECORDS" | while read -r RECORD_ID; do
    if [ "$FIRST_RECORD" = true ]; then
        echo "Keeping record ID: $RECORD_ID"
        FIRST_RECORD=false
    else
        echo "Deleting duplicate record ID: $RECORD_ID"
        
        # Delete the duplicate record
        DELETE_RESPONSE=$(curl -s -X DELETE \
          "https://api.digitalocean.com/v2/domains/$DOMAIN/records/$RECORD_ID" \
          -H "Authorization: Bearer $DO_API_TOKEN")
        
        if [ $? -eq 0 ]; then
            echo "Successfully deleted record ID: $RECORD_ID"
        else
            echo "Failed to delete record ID: $RECORD_ID"
            echo "Response: $DELETE_RESPONSE"
        fi
        
        # Small delay to avoid rate limiting
        sleep 1
    fi
done

echo "Cleanup complete!"