#!/bin/bash

# =============================================================================
# Import Existing AWS Resources into Terraform State
# This script imports existing production resources into Terraform state
# =============================================================================

set -euo pipefail

# Colors
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

info "=== Importing Existing Resources into Terraform State ==="
echo ""

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    info "Initializing Terraform..."
    terraform init || error "Terraform init failed"
fi

# Import S3 Bucket
info "Importing S3 bucket..."
terraform import aws_s3_bucket.resume_website noveycloud-resume-website 2>/dev/null || warning "S3 bucket already in state or doesn't exist"

# Import S3 Bucket Versioning
info "Importing S3 bucket versioning..."
terraform import aws_s3_bucket_versioning.resume_website noveycloud-resume-website 2>/dev/null || warning "Already in state"

# Import S3 Bucket Encryption
info "Importing S3 bucket encryption..."
terraform import aws_s3_bucket_server_side_encryption_configuration.resume_website noveycloud-resume-website 2>/dev/null || warning "Already in state"

# Import S3 Bucket Website Configuration
info "Importing S3 bucket website configuration..."
terraform import aws_s3_bucket_website_configuration.resume_website noveycloud-resume-website 2>/dev/null || warning "Already in state"

# Import S3 Bucket Public Access Block
info "Importing S3 bucket public access block..."
terraform import aws_s3_bucket_public_access_block.resume_website noveycloud-resume-website 2>/dev/null || warning "Already in state"

# Import S3 Bucket Lifecycle
info "Importing S3 bucket lifecycle..."
terraform import aws_s3_bucket_lifecycle_configuration.resume_website noveycloud-resume-website 2>/dev/null || warning "Already in state"

# Import S3 Bucket Policy
info "Importing S3 bucket policy..."
terraform import aws_s3_bucket_policy.resume_website noveycloud-resume-website 2>/dev/null || warning "Already in state"

# Import S3 Bucket Notification
info "Importing S3 bucket notification..."
terraform import aws_s3_bucket_notification.resume_website noveycloud-resume-website 2>/dev/null || warning "Already in state"

# Get CloudFront OAC ID
info "Finding CloudFront Origin Access Control..."
OAC_ID=$(aws cloudfront list-origin-access-controls --query "OriginAccessControlList.Items[?Name=='noveycloud-resume-website-oac'].Id" --output text 2>/dev/null || echo "")
if [ -n "$OAC_ID" ]; then
    info "Importing CloudFront OAC: $OAC_ID"
    terraform import aws_cloudfront_origin_access_control.resume_website "$OAC_ID" 2>/dev/null || warning "Already in state"
else
    warning "CloudFront OAC not found"
fi

# Import CloudFront Function
info "Importing CloudFront function..."
terraform import aws_cloudfront_function.security_headers noveycloud-resume-website-security-headers 2>/dev/null || warning "Already in state"

# Get ACM Certificate ARN
info "Finding ACM certificate..."
CERT_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='noveycloud.com'].CertificateArn" --output text 2>/dev/null || echo "")
if [ -n "$CERT_ARN" ]; then
    info "Importing ACM certificate: $CERT_ARN"
    terraform import -provider=aws.us_east_1 aws_acm_certificate.resume_website "$CERT_ARN" 2>/dev/null || warning "Already in state"
else
    warning "ACM certificate not found"
fi

# Get Route53 Zone ID - USE THE PRODUCTION ZONE
info "Importing Route53 hosted zone..."
ZONE_ID="Z0756127155MZ0VTLU0BJ"  # Production zone - DO NOT DELETE
info "Importing production zone: $ZONE_ID"
terraform import aws_route53_zone.main "$ZONE_ID" 2>/dev/null || warning "Already in state"

# Get CloudFront Distribution ID
info "Finding CloudFront distribution..."
DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='Resume website for noveycloud.com'].Id" --output text 2>/dev/null || echo "")
if [ -z "$DIST_ID" ]; then
    # Try finding by alias
    DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, 'noveycloud.com')].Id" --output text 2>/dev/null || echo "")
fi
if [ -n "$DIST_ID" ]; then
    info "Importing CloudFront distribution: $DIST_ID"
    terraform import aws_cloudfront_distribution.resume_website "$DIST_ID" 2>/dev/null || warning "Already in state"
else
    warning "CloudFront distribution not found"
fi

echo ""
success "🎉 Import completed!"
info "Run 'terraform plan' to see if there are any differences"
