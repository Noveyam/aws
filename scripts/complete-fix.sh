#!/bin/bash

# =============================================================================
# Complete Fix - Run All Steps in Order
# This script runs all the necessary fixes to get deployment working
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "=== Complete Deployment Fix ==="
echo ""
warning "This will fix all Terraform state and import issues"
echo ""
read -p "Continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Cancelled"
    exit 0
fi

# Step 1: Fix Terraform State
info "Step 1/3: Fixing Terraform state..."
cd "$SCRIPT_DIR/../terraform"

info "Removing old state entries with [0]..."
terraform state rm 'aws_route53_zone.main[0]' 2>/dev/null || info "Not in state"
terraform state rm 'aws_route53_health_check.resume_website[0]' 2>/dev/null || info "Not in state"
terraform state rm 'aws_iam_user.resume_website_deployer[0]' 2>/dev/null || info "Not in state"
terraform state rm 'aws_iam_access_key.resume_website_deployer[0]' 2>/dev/null || info "Not in state"
terraform state rm 'aws_iam_user_policy_attachment.resume_website_deployment[0]' 2>/dev/null || info "Not in state"

success "State entries removed"
cd "$SCRIPT_DIR"
echo ""

# Step 2: Show duplicate zones
info "Step 2/3: Checking for duplicate zones..."
"$SCRIPT_DIR/cleanup-duplicate-zones.sh"
echo ""
warning "⚠️  IMPORTANT: Delete duplicate zones manually before continuing!"
warning "⚠️  DO NOT DELETE: Z0756127155MZ0VTLU0BJ"
echo ""
read -p "Have you deleted the duplicate zones? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    warning "Please delete duplicate zones first, then run this script again"
    exit 0
fi

# Step 3: Import Resources
info "Step 3/3: Importing production resources..."
"$SCRIPT_DIR/import-existing-resources.sh" || warning "Import completed with warnings"
echo ""

# Verify
info "Verifying configuration..."
cd "$SCRIPT_DIR/../terraform"
terraform plan -detailed-exitcode || {
    exit_code=$?
    if [ $exit_code -eq 2 ]; then
        info "Plan shows changes - review them carefully"
    else
        error "Plan failed - check errors above"
    fi
}

echo ""
success "🎉 Fix completed!"
echo ""
info "Next steps:"
echo "  1. Review the terraform plan output above"
echo "  2. If it looks good, commit the state file:"
echo "     git add terraform/terraform.tfstate"
echo "     git commit -m 'chore: import production resources'"
echo "     git push"
echo "  3. CI/CD will now work!"
