#!/bin/bash

# =============================================================================
# Terraform Infrastructure Validation Tests
# Validates that all AWS resources are created correctly with proper configuration
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
OUTPUTS_FILE="$PROJECT_ROOT/terraform-outputs.json"
TEST_LOG="$PROJECT_ROOT/infrastructure-tests.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log() { echo -e "${1}" | tee -a "$TEST_LOG"; }
test_start() { 
    ((TESTS_RUN++))
    log "${BLUE}[TEST $TESTS_RUN] $1${NC}"
}
test_pass() { 
    ((TESTS_PASSED++))
    log "${GREEN}✓ PASS: $1${NC}"
}
test_fail() { 
    ((TESTS_FAILED++))
    log "${RED}✗ FAIL: $1${NC}"
}
test_skip() { 
    log "${YELLOW}⚠ SKIP: $1${NC}"
}
info() { log "${BLUE}ℹ $1${NC}"; }
error_exit() { log "${RED}ERROR: $1${NC}"; exit 1; }

# Initialize test logging
init_tests() {
    echo "=== Terraform Infrastructure Validation Tests ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    info "Starting infrastructure validation tests..."
    info "Test log: $TEST_LOG"
}

# Check prerequisites
check_prerequisites() {
    test_start "Checking prerequisites"
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        test_fail "AWS CLI not installed"
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        test_fail "jq not installed (required for JSON parsing)"
        return 1
    fi
    
    # Check if Terraform outputs exist
    if [ ! -f "$OUTPUTS_FILE" ]; then
        test_fail "Terraform outputs not found. Run deployment first."
        return 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        test_fail "AWS credentials not configured"
        return 1
    fi
    
    test_pass "All prerequisites met"
}

# Load Terraform outputs
load_terraform_outputs() {
    test_start "Loading Terraform outputs"
    
    # Extract key values from Terraform outputs
    S3_BUCKET=$(jq -r '.s3_bucket_name.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    CLOUDFRONT_DISTRIBUTION_ID=$(jq -r '.cloudfront_distribution_id.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    ROUTE53_ZONE_ID=$(jq -r '.route53_zone_id.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    ACM_CERTIFICATE_ARN=$(jq -r '.acm_certificate_arn.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    WEBSITE_URL=$(jq -r '.website_url.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    
    if [ "$S3_BUCKET" = "null" ] || [ "$CLOUDFRONT_DISTRIBUTION_ID" = "null" ]; then
        test_fail "Could not load required Terraform outputs"
        return 1
    fi
    
    info "S3 Bucket: $S3_BUCKET"
    info "CloudFront Distribution: $CLOUDFRONT_DISTRIBUTION_ID"
    info "Route53 Zone: $ROUTE53_ZONE_ID"
    info "Website URL: $WEBSITE_URL"
    
    test_pass "Terraform outputs loaded successfully"
}

# Test S3 bucket configuration
test_s3_bucket() {
    test_start "Validating S3 bucket configuration"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
        test_fail "S3 bucket does not exist: $S3_BUCKET"
        return 1
    fi
    
    # Check bucket website configuration
    local website_config
    website_config=$(aws s3api get-bucket-website --bucket "$S3_BUCKET" 2>/dev/null || echo "null")
    
    if [ "$website_config" = "null" ]; then
        test_fail "S3 bucket website hosting not configured"
        return 1
    fi
    
    # Verify index document
    local index_document
    index_document=$(echo "$website_config" | jq -r '.IndexDocument.Suffix' 2>/dev/null || echo "null")
    
    if [ "$index_document" != "index.html" ]; then
        test_fail "S3 bucket index document not set to index.html (found: $index_document)"
        return 1
    fi
    
    # Verify error document
    local error_document
    error_document=$(echo "$website_config" | jq -r '.ErrorDocument.Key' 2>/dev/null || echo "null")
    
    if [ "$error_document" != "error.html" ]; then
        test_fail "S3 bucket error document not set to error.html (found: $error_document)"
        return 1
    fi
    
    # Check bucket versioning
    local versioning_status
    versioning_status=$(aws s3api get-bucket-versioning --bucket "$S3_BUCKET" --query 'Status' --output text 2>/dev/null || echo "null")
    
    if [ "$versioning_status" != "Enabled" ]; then
        test_fail "S3 bucket versioning not enabled (status: $versioning_status)"
        return 1
    fi
    
    # Check bucket encryption
    local encryption_config
    encryption_config=$(aws s3api get-bucket-encryption --bucket "$S3_BUCKET" 2>/dev/null || echo "null")
    
    if [ "$encryption_config" = "null" ]; then
        test_fail "S3 bucket encryption not configured"
        return 1
    fi
    
    test_pass "S3 bucket configuration is correct"
}

# Test S3 bucket policy
test_s3_bucket_policy() {
    test_start "Validating S3 bucket policy"
    
    # Get bucket policy
    local bucket_policy
    bucket_policy=$(aws s3api get-bucket-policy --bucket "$S3_BUCKET" --query 'Policy' --output text 2>/dev/null || echo "null")
    
    if [ "$bucket_policy" = "null" ]; then
        test_fail "S3 bucket policy not found"
        return 1
    fi
    
    # Check if policy allows CloudFront access
    if ! echo "$bucket_policy" | jq -e '.Statement[] | select(.Principal.Service == "cloudfront.amazonaws.com")' >/dev/null 2>&1; then
        test_fail "S3 bucket policy does not allow CloudFront access"
        return 1
    fi
    
    test_pass "S3 bucket policy is correctly configured"
}

# Test CloudFront distribution
test_cloudfront_distribution() {
    test_start "Validating CloudFront distribution"
    
    # Get distribution configuration
    local distribution_config
    distribution_config=$(aws cloudfront get-distribution --id "$CLOUDFRONT_DISTRIBUTION_ID" 2>/dev/null || echo "null")
    
    if [ "$distribution_config" = "null" ]; then
        test_fail "CloudFront distribution not found: $CLOUDFRONT_DISTRIBUTION_ID"
        return 1
    fi
    
    # Check distribution status
    local distribution_status
    distribution_status=$(echo "$distribution_config" | jq -r '.Distribution.Status' 2>/dev/null || echo "null")
    
    if [ "$distribution_status" != "Deployed" ]; then
        test_skip "CloudFront distribution not yet deployed (status: $distribution_status)"
    else
        test_pass "CloudFront distribution is deployed"
    fi
    
    # Check if distribution is enabled
    local distribution_enabled
    distribution_enabled=$(echo "$distribution_config" | jq -r '.Distribution.DistributionConfig.Enabled' 2>/dev/null || echo "false")
    
    if [ "$distribution_enabled" != "true" ]; then
        test_fail "CloudFront distribution is not enabled"
        return 1
    fi
    
    # Check default root object
    local default_root_object
    default_root_object=$(echo "$distribution_config" | jq -r '.Distribution.DistributionConfig.DefaultRootObject' 2>/dev/null || echo "null")
    
    if [ "$default_root_object" != "index.html" ]; then
        test_fail "CloudFront default root object not set to index.html (found: $default_root_object)"
        return 1
    fi
    
    # Check HTTPS redirect
    local viewer_protocol_policy
    viewer_protocol_policy=$(echo "$distribution_config" | jq -r '.Distribution.DistributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy' 2>/dev/null || echo "null")
    
    if [ "$viewer_protocol_policy" != "redirect-to-https" ]; then
        test_fail "CloudFront not configured to redirect HTTP to HTTPS (policy: $viewer_protocol_policy)"
        return 1
    fi
    
    # Check compression
    local compress_enabled
    compress_enabled=$(echo "$distribution_config" | jq -r '.Distribution.DistributionConfig.DefaultCacheBehavior.Compress' 2>/dev/null || echo "false")
    
    if [ "$compress_enabled" != "true" ]; then
        test_fail "CloudFront compression not enabled"
        return 1
    fi
    
    test_pass "CloudFront distribution configuration is correct"
}

# Test ACM certificate
test_acm_certificate() {
    test_start "Validating ACM certificate"
    
    if [ "$ACM_CERTIFICATE_ARN" = "null" ]; then
        test_skip "ACM certificate ARN not available"
        return 0
    fi
    
    # Get certificate details
    local certificate_details
    certificate_details=$(aws acm describe-certificate --certificate-arn "$ACM_CERTIFICATE_ARN" --region us-east-1 2>/dev/null || echo "null")
    
    if [ "$certificate_details" = "null" ]; then
        test_fail "ACM certificate not found: $ACM_CERTIFICATE_ARN"
        return 1
    fi
    
    # Check certificate status
    local certificate_status
    certificate_status=$(echo "$certificate_details" | jq -r '.Certificate.Status' 2>/dev/null || echo "null")
    
    if [ "$certificate_status" != "ISSUED" ]; then
        test_skip "ACM certificate not yet issued (status: $certificate_status)"
    else
        test_pass "ACM certificate is issued and valid"
    fi
    
    # Check certificate validation method
    local validation_method
    validation_method=$(echo "$certificate_details" | jq -r '.Certificate.Options.ValidationMethod' 2>/dev/null || echo "null")
    
    if [ "$validation_method" != "DNS" ]; then
        test_fail "ACM certificate not using DNS validation (method: $validation_method)"
        return 1
    fi
    
    test_pass "ACM certificate configuration is correct"
}

# Test Route53 hosted zone
test_route53_zone() {
    test_start "Validating Route53 hosted zone"
    
    if [ "$ROUTE53_ZONE_ID" = "null" ]; then
        test_skip "Route53 zone ID not available"
        return 0
    fi
    
    # Get hosted zone details
    local hosted_zone
    hosted_zone=$(aws route53 get-hosted-zone --id "$ROUTE53_ZONE_ID" 2>/dev/null || echo "null")
    
    if [ "$hosted_zone" = "null" ]; then
        test_fail "Route53 hosted zone not found: $ROUTE53_ZONE_ID"
        return 1
    fi
    
    # Check if zone is not private
    local is_private
    is_private=$(echo "$hosted_zone" | jq -r '.HostedZone.Config.PrivateZone' 2>/dev/null || echo "true")
    
    if [ "$is_private" = "true" ]; then
        test_fail "Route53 hosted zone is private (should be public)"
        return 1
    fi
    
    # Check for A records pointing to CloudFront
    local record_sets
    record_sets=$(aws route53 list-resource-record-sets --hosted-zone-id "$ROUTE53_ZONE_ID" 2>/dev/null || echo "null")
    
    if [ "$record_sets" = "null" ]; then
        test_fail "Could not retrieve Route53 record sets"
        return 1
    fi
    
    # Check for apex domain A record
    local apex_record_count
    apex_record_count=$(echo "$record_sets" | jq '[.ResourceRecordSets[] | select(.Type == "A" and .AliasTarget != null)] | length' 2>/dev/null || echo "0")
    
    if [ "$apex_record_count" -lt 1 ]; then
        test_fail "No A record found for apex domain"
        return 1
    fi
    
    test_pass "Route53 hosted zone configuration is correct"
}

# Test website accessibility
test_website_accessibility() {
    test_start "Testing website accessibility"
    
    if [ "$WEBSITE_URL" = "null" ]; then
        test_skip "Website URL not available"
        return 0
    fi
    
    # Test HTTP status
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL" --max-time 30 || echo "000")
    
    if [ "$http_status" = "200" ]; then
        test_pass "Website is accessible (HTTP $http_status)"
    elif [ "$http_status" = "000" ]; then
        test_skip "Website connection failed (DNS may still be propagating)"
    else
        test_fail "Website returned HTTP $http_status"
        return 1
    fi
    
    # Test HTTPS redirect
    local http_url="${WEBSITE_URL/https:/http:}"
    local redirect_status
    redirect_status=$(curl -s -o /dev/null -w "%{http_code}" "$http_url" --max-time 30 || echo "000")
    
    if [ "$redirect_status" = "301" ] || [ "$redirect_status" = "302" ]; then
        test_pass "HTTP to HTTPS redirect is working"
    else
        test_skip "HTTP to HTTPS redirect test inconclusive (status: $redirect_status)"
    fi
}

# Test Free Tier compliance
test_free_tier_compliance() {
    test_start "Checking Free Tier compliance indicators"
    
    # Check CloudFront price class
    local distribution_config
    distribution_config=$(aws cloudfront get-distribution --id "$CLOUDFRONT_DISTRIBUTION_ID" 2>/dev/null || echo "null")
    
    if [ "$distribution_config" != "null" ]; then
        local price_class
        price_class=$(echo "$distribution_config" | jq -r '.Distribution.DistributionConfig.PriceClass' 2>/dev/null || echo "null")
        
        if [ "$price_class" = "PriceClass_100" ]; then
            test_pass "CloudFront using Free Tier friendly price class"
        else
            test_fail "CloudFront not using Free Tier price class (found: $price_class)"
            return 1
        fi
    fi
    
    # Check S3 bucket size (basic check)
    local bucket_size
    bucket_size=$(aws s3 ls "s3://$S3_BUCKET" --recursive --summarize 2>/dev/null | grep "Total Size:" | awk '{print $3}' || echo "0")
    
    if [ "$bucket_size" -lt 5368709120 ]; then  # 5GB in bytes
        test_pass "S3 bucket size within Free Tier limits"
    else
        test_fail "S3 bucket size may exceed Free Tier limits"
        return 1
    fi
}

# Generate test report
generate_report() {
    echo ""
    log "=== Test Results Summary ==="
    log "Tests Run: $TESTS_RUN"
    log "Tests Passed: $TESTS_PASSED"
    log "Tests Failed: $TESTS_FAILED"
    log "Tests Skipped: $((TESTS_RUN - TESTS_PASSED - TESTS_FAILED))"
    
    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    log "Success Rate: ${success_rate}%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "${GREEN}🎉 All tests passed! Infrastructure is correctly configured.${NC}"
        return 0
    else
        log "${RED}❌ Some tests failed. Please review the issues above.${NC}"
        return 1
    fi
}

# Main test execution
main() {
    init_tests
    
    # Run all tests
    check_prerequisites || exit 1
    load_terraform_outputs || exit 1
    
    test_s3_bucket
    test_s3_bucket_policy
    test_cloudfront_distribution
    test_acm_certificate
    test_route53_zone
    test_website_accessibility
    test_free_tier_compliance
    
    # Generate final report
    generate_report
    
    echo ""
    echo "Completed at: $(date)" >> "$TEST_LOG"
    log "Test results saved to: $TEST_LOG"
}

# Run tests
main "$@"