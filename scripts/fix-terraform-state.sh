#!/bin/bash

# =============================================================================
# Fix Terraform State Issues
# Removes old state entries that are causing conflicts
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
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

cd "$TERRAFORM_DIR" || error "Cannot find terraform directory"

info "=== Fixing Terraform State ==="
echo ""

# Initialize if needed
if [ ! -d ".terraform" ]; then
    info "Initializing Terraform..."
    terraform init || error "Terraform init failed"
fi

# List current state
info "Current state resources:"
terraform state list

echo ""
warning "This script will remove old state entries that use count (e.g., [0])"
echo ""
read -p "Continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Cancelled"
    exit 0
fi

# Move old Route53 zone from [0] to non-indexed
info "Moving Route53 zone from [0] to non-indexed..."
terraform state mv 'aws_route53_zone.main[0]' 'aws_route53_zone.main' 2>/dev/null || info "Already moved or not found"

# Remove old health check with count
info "Removing old health check state (if exists)..."
terraform state rm 'aws_route53_health_check.resume_website[0]' 2>/dev/null || info "Not found in state"

# Remove old IAM user with count
info "Removing old IAM user state (if exists)..."
terraform state rm 'aws_iam_user.resume_website_deployer[0]' 2>/dev/null || info "Not found in state"
terraform state rm 'aws_iam_access_key.resume_website_deployer[0]' 2>/dev/null || info "Not found in state"
terraform state rm 'aws_iam_user_policy_attachment.resume_website_deployment[0]' 2>/dev/null || info "Not found in state"

echo ""
info "Updated state resources:"
terraform state list

echo ""
success "State cleanup completed!"
info "Now run: terraform plan"
