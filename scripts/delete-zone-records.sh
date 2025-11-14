#!/bin/bash

# =============================================================================
# Delete All Records from a Route53 Hosted Zone
# Deletes all records except NS and SOA (which are required)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${1}"; }
error() { log "${RED}ERROR: $1${NC}"; exit 1; }
success() { log "${GREEN}✓ $1${NC}"; }
warning() { log "${YELLOW}⚠ $1${NC}"; }
info() { log "${BLUE}ℹ $1${NC}"; }

if [ $# -eq 0 ]; then
    error "Usage: $0 <hosted-zone-id>"
fi

ZONE_ID="$1"

info "=== Delete Records from Zone $ZONE_ID ==="
echo ""

# Get zone name
ZONE_NAME=$(aws route53 get-hosted-zone --id "$ZONE_ID" --query 'HostedZone.Name' --output text 2>/dev/null || echo "")
if [ -z "$ZONE_NAME" ]; then
    error "Zone $ZONE_ID not found"
fi

info "Zone: $ZONE_NAME"
echo ""

# List all records
info "Fetching records..."
RECORDS=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" --output json)

# Count records
TOTAL_RECORDS=$(echo "$RECORDS" | jq '.ResourceRecordSets | length')
info "Found $TOTAL_RECORDS total records"

# Filter out NS and SOA records (these can't be deleted)
DELETABLE_RECORDS=$(echo "$RECORDS" | jq '[.ResourceRecordSets[] | select(.Type != "NS" and .Type != "SOA")]')
DELETABLE_COUNT=$(echo "$DELETABLE_RECORDS" | jq 'length')

if [ "$DELETABLE_COUNT" -eq 0 ]; then
    success "No records to delete (only NS and SOA remain)"
    exit 0
fi

info "Records to delete: $DELETABLE_COUNT"
echo ""

# Show what will be deleted
info "Records that will be deleted:"
echo "$DELETABLE_RECORDS" | jq -r '.[] | "\(.Name) (\(.Type))"'
echo ""

warning "⚠️  This will delete all DNS records from this zone!"
warning "⚠️  Make sure this is a duplicate zone you want to remove!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Cancelled"
    exit 0
fi

# Create change batch to delete all records
info "Creating delete batch..."
CHANGE_BATCH=$(echo "$DELETABLE_RECORDS" | jq '{
  Changes: [
    .[] | {
      Action: "DELETE",
      ResourceRecordSet: .
    }
  ]
}')

# Apply changes
info "Deleting records..."
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "$CHANGE_BATCH" \
    --query 'ChangeInfo.Id' \
    --output text)

if [ -n "$CHANGE_ID" ]; then
    success "Records deleted successfully"
    info "Change ID: $CHANGE_ID"
    
    # Wait for change to propagate
    info "Waiting for changes to propagate..."
    aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"
    success "Changes propagated"
    
    echo ""
    info "You can now delete the zone:"
    echo "  aws route53 delete-hosted-zone --id $ZONE_ID"
else
    error "Failed to delete records"
fi
