#!/bin/bash

# =============================================================================
# Cleanup Duplicate Route53 Hosted Zones
# Removes duplicate zones keeping only the one managed by Terraform
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

info "=== Cleanup Duplicate Route53 Zones ==="
echo ""

# List all zones
info "Current hosted zones:"
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id,ResourceRecordSetCount]' --output table

echo ""
warning "⚠️  This script will help you identify and delete duplicate zones"
warning "⚠️  Make sure you keep the zone that has your DNS records!"
echo ""

# Find noveycloud.com zones
info "Finding noveycloud.com zones..."
PROD_ZONES=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='noveycloud.com.'].Id" --output text)
PROD_ZONE_COUNT=$(echo "$PROD_ZONES" | wc -w)

if [ "$PROD_ZONE_COUNT" -gt 1 ]; then
    warning "Found $PROD_ZONE_COUNT zones for noveycloud.com"
    echo ""
    info "Zones with record counts:"
    for zone_id in $PROD_ZONES; do
        zone_id_clean=$(echo "$zone_id" | cut -d'/' -f3)
        record_count=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id_clean" --query 'length(ResourceRecordSets)' --output text)
        if [ "$zone_id_clean" = "Z0756127155MZ0VTLU0BJ" ]; then
            echo "  Zone: $zone_id_clean - Records: $record_count ⭐ PRODUCTION - KEEP THIS ONE"
        else
            echo "  Zone: $zone_id_clean - Records: $record_count"
        fi
    done
    echo ""
    warning "⚠️  KEEP ZONE: Z0756127155MZ0VTLU0BJ (Production)"
    info "Delete the others manually:"
    echo ""
    for zone_id in $PROD_ZONES; do
        zone_id_clean=$(echo "$zone_id" | cut -d'/' -f3)
        if [ "$zone_id_clean" != "Z0756127155MZ0VTLU0BJ" ]; then
            echo "  aws route53 delete-hosted-zone --id $zone_id_clean"
        fi
    done
else
    success "Only one noveycloud.com zone found - no duplicates"
fi

echo ""

# Find staging.noveycloud.com zones
info "Finding staging.noveycloud.com zones..."
STAGING_ZONES=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='staging.noveycloud.com.'].Id" --output text)
STAGING_ZONE_COUNT=$(echo "$STAGING_ZONES" | wc -w)

if [ "$STAGING_ZONE_COUNT" -gt 0 ]; then
    warning "Found $STAGING_ZONE_COUNT zones for staging.noveycloud.com"
    echo ""
    info "Since we're not using separate staging zones, you can delete all of these:"
    echo ""
    for zone_id in $STAGING_ZONES; do
        zone_id_clean=$(echo "$zone_id" | cut -d'/' -f3)
        echo "  aws route53 delete-hosted-zone --id $zone_id_clean"
    done
fi

echo ""
info "=== Manual Cleanup Required ==="
info "Review the zones above and delete duplicates manually"
info "Keep only ONE zone for noveycloud.com (the one with the most records)"
info "Delete ALL staging.noveycloud.com zones (we don't use them)"
