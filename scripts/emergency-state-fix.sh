#!/bin/bash

# =============================================================================
# Emergency State Fix - Stop Resource Destruction
# Moves resources from count-based to non-count-based without destroying
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${1}"; }
success() { log "${GREEN}✓ $1${NC}"; }
info() { log "${BLUE}ℹ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

cd "$TERRAFORM_DIR"

info "=== Emergency State Fix ==="
info "Moving resources from [0] to non-indexed..."

# Move Route53 zone
terraform state mv 'aws_route53_zone.main[0]' 'aws_route53_zone.main' 2>/dev/null && success "Route53 zone moved" || info "Already moved"

# Move health check if exists
terraform state mv 'aws_route53_health_check.resume_website[0]' 'aws_route53_health_check.resume_website' 2>/dev/null && success "Health check moved" || info "Not found"

# Move IAM resources if exist
terraform state mv 'aws_iam_user.resume_website_deployer[0]' 'aws_iam_user.resume_website_deployer' 2>/dev/null && success "IAM user moved" || info "Not found"
terraform state mv 'aws_iam_access_key.resume_website_deployer[0]' 'aws_iam_access_key.resume_website_deployer' 2>/dev/null && success "IAM access key moved" || info "Not found"
terraform state mv 'aws_iam_user_policy_attachment.resume_website_deployment[0]' 'aws_iam_user_policy_attachment.resume_website_deployment' 2>/dev/null && success "IAM policy attachment moved" || info "Not found"

success "State fix completed!"
info "Run: terraform plan"
