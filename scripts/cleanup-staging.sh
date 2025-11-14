#!/bin/bash

# =============================================================================
# Staging Environment Cleanup Script
# Removes partially created staging resources from AWS
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${1}"; }
error() { log "${RED}ERROR: $1${NC}"; }
success() { log "${GREEN}✓ $1${NC}"; }
warning() { log "${YELLOW}⚠ $1${NC}"; }
info() { log "${BLUE}ℹ $1${NC}"; }

# Staging resource names
BUCKET_NAME="noveycloud-resume-website-staging"
OAC_NAME="noveycloud-resume-website-staging-oac"
FUNCTION_NAME="noveycloud-resume-website-staging-security-headers"
IAM_USER="noveycloud-resume-website-staging-deployer"
CERT_ARN="arn:aws:acm:us-east-1:766158721264:certificate/3f07fea4-9e4a-41cf-8478-c0abd1a74331"

info "=== Staging Environment Cleanup ==="
echo ""
warning "This will delete the following staging resources:"
echo "  - S3 Bucket: $BUCKET_NAME"
echo "  - CloudFront OAC: $OAC_NAME"
echo "  - CloudFront Function: $FUNCTION_NAME"
echo "  - IAM User: $IAM_USER"
echo "  - ACM Certificate: $CERT_ARN"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Cleanup cancelled"
    exit 0
fi

# 1. Delete S3 Bucket
info "Deleting S3 bucket..."
if aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null; then
    success "S3 bucket deleted"
else
    warning "S3 bucket not found or already deleted"
fi

# 2. Delete CloudFront Function
info "Deleting CloudFront function..."
FUNCTION_ETAG=$(aws cloudfront describe-function --name "$FUNCTION_NAME" --query 'ETag' --output text 2>/dev/null || echo "")
if [ -n "$FUNCTION_ETAG" ]; then
    aws cloudfront delete-function --name "$FUNCTION_NAME" --if-match "$FUNCTION_ETAG" 2>/dev/null || true
    success "CloudFront function deleted"
else
    warning "CloudFront function not found or already deleted"
fi

# 3. Delete CloudFront Origin Access Control
info "Deleting CloudFront OAC..."
OAC_ID=$(aws cloudfront list-origin-access-controls --query "OriginAccessControlList.Items[?Name=='$OAC_NAME'].Id" --output text 2>/dev/null || echo "")
if [ -n "$OAC_ID" ]; then
    OAC_ETAG=$(aws cloudfront get-origin-access-control --id "$OAC_ID" --query 'ETag' --output text 2>/dev/null || echo "")
    if [ -n "$OAC_ETAG" ]; then
        aws cloudfront delete-origin-access-control --id "$OAC_ID" --if-match "$OAC_ETAG" 2>/dev/null || true
        success "CloudFront OAC deleted"
    fi
else
    warning "CloudFront OAC not found or already deleted"
fi

# 4. Delete IAM User
info "Deleting IAM user..."
# Delete access keys first
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$IAM_USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")
if [ -n "$ACCESS_KEYS" ]; then
    for key in $ACCESS_KEYS; do
        aws iam delete-access-key --user-name "$IAM_USER" --access-key-id "$key" 2>/dev/null || true
    done
fi

# Detach policies
POLICIES=$(aws iam list-attached-user-policies --user-name "$IAM_USER" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
if [ -n "$POLICIES" ]; then
    for policy in $POLICIES; do
        aws iam detach-user-policy --user-name "$IAM_USER" --policy-arn "$policy" 2>/dev/null || true
    done
fi

# Delete user
if aws iam delete-user --user-name "$IAM_USER" 2>/dev/null; then
    success "IAM user deleted"
else
    warning "IAM user not found or already deleted"
fi

# 5. Delete ACM Certificate
info "Deleting ACM certificate..."
if aws acm delete-certificate --certificate-arn "$CERT_ARN" --region us-east-1 2>/dev/null; then
    success "ACM certificate deleted"
else
    warning "ACM certificate not found or already deleted"
fi

echo ""
success "🎉 Staging cleanup completed!"
info "You can now run a fresh staging deployment"
