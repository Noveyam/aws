#!/bin/bash

# =============================================================================
# Final Deployment Verification Script
# Comprehensive verification of the complete resume website deployment
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUTS_FILE="$PROJECT_ROOT/terraform-outputs.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}✗ $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    info "Testing: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name"
        ((PASSED_TESTS++))
        return 0
    else
        error "$test_name"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Check if deployment exists
check_deployment_exists() {
    info "=== Checking Deployment Status ==="
    
    if [ ! -f "$OUTPUTS_FILE" ]; then
        error "Terraform outputs not found. Please deploy infrastructure first."
        echo "Run: ./scripts/deploy-infrastructure.sh deploy"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        warning "jq not available. Some tests will be skipped."
        return 1
    fi
    
    success "Deployment outputs found"
    return 0
}

# Extract configuration from outputs
get_config() {
    if command -v jq &> /dev/null && [ -f "$OUTPUTS_FILE" ]; then
        WEBSITE_URL=$(jq -r '.website_url.value' "$OUTPUTS_FILE" 2>/dev/null || echo "")
        WWW_URL=$(jq -r '.www_website_url.value' "$OUTPUTS_FILE" 2>/dev/null || echo "")
        S3_BUCKET=$(jq -r '.s3_bucket_name.value' "$OUTPUTS_FILE" 2>/dev/null || echo "")
        CLOUDFRONT_ID=$(jq -r '.cloudfront_distribution_id.value' "$OUTPUTS_FILE" 2>/dev/null || echo "")
        DOMAIN_NAME=$(echo "$WEBSITE_URL" | sed 's|https://||' 2>/dev/null || echo "")
    else
        WEBSITE_URL=""
        WWW_URL=""
        S3_BUCKET=""
        CLOUDFRONT_ID=""
        DOMAIN_NAME=""
    fi
}

# Test infrastructure components
test_infrastructure() {
    info "=== Testing Infrastructure Components ==="
    
    if [ -z "$S3_BUCKET" ]; then
        error "Cannot determine S3 bucket name"
        return 1
    fi
    
    # Test S3 bucket exists and is accessible
    run_test "S3 bucket exists" "aws s3 ls s3://$S3_BUCKET"
    
    # Test S3 website configuration
    run_test "S3 website configuration" "aws s3api get-bucket-website --bucket $S3_BUCKET"
    
    if [ -n "$CLOUDFRONT_ID" ]; then
        # Test CloudFront distribution
        run_test "CloudFront distribution exists" "aws cloudfront get-distribution --id $CLOUDFRONT_ID"
        
        # Check CloudFront status
        local cf_status
        cf_status=$(aws cloudfront get-distribution --id "$CLOUDFRONT_ID" --query 'Distribution.Status' --output text 2>/dev/null || echo "Unknown")
        if [ "$cf_status" = "Deployed" ]; then
            success "CloudFront distribution is deployed"
            ((PASSED_TESTS++))
        else
            warning "CloudFront distribution status: $cf_status"
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
    fi
}

# Test website accessibility
test_website_accessibility() {
    info "=== Testing Website Accessibility ==="
    
    if [ -z "$WEBSITE_URL" ]; then
        error "Cannot determine website URL"
        return 1
    fi
    
    # Test main website URL
    run_test "Main website accessible" "curl -s -f -L --max-time 30 '$WEBSITE_URL' -o /dev/null"
    
    # Test WWW redirect
    if [ -n "$WWW_URL" ]; then
        run_test "WWW URL accessible" "curl -s -f -L --max-time 30 '$WWW_URL' -o /dev/null"
    fi
    
    # Test HTTPS redirect
    local http_url
    http_url=$(echo "$WEBSITE_URL" | sed 's/https:/http:/')
    run_test "HTTP to HTTPS redirect" "curl -s -L --max-time 30 '$http_url' | grep -q 'https://'"
    
    # Test error page
    run_test "Custom error page" "curl -s --max-time 30 '$WEBSITE_URL/nonexistent-page' | grep -q '404'"
}

# Test website content
test_website_content() {
    info "=== Testing Website Content ==="
    
    if [ -z "$WEBSITE_URL" ]; then
        error "Cannot determine website URL"
        return 1
    fi
    
    local content
    content=$(curl -s --max-time 30 "$WEBSITE_URL" 2>/dev/null || echo "")
    
    if [ -z "$content" ]; then
        error "Could not fetch website content"
        ((TOTAL_TESTS++))
        ((FAILED_TESTS++))
        return 1
    fi
    
    # Test HTML structure
    run_test "HTML DOCTYPE present" "echo '$content' | grep -q '<!DOCTYPE html>'"
    run_test "HTML title present" "echo '$content' | grep -q '<title>'"
    run_test "Meta viewport present" "echo '$content' | grep -q 'viewport'"
    run_test "CSS stylesheet linked" "echo '$content' | grep -q 'styles.css'"
    run_test "JavaScript file linked" "echo '$content' | grep -q 'main.js'"
    
    # Test content sections
    run_test "Header section present" "echo '$content' | grep -q -i 'header'"
    run_test "Navigation present" "echo '$content' | grep -q -i 'nav'"
    run_test "Main content present" "echo '$content' | grep -q -i 'main'"
    run_test "Footer present" "echo '$content' | grep -q -i 'footer'"
}

# Test SSL certificate
test_ssl_certificate() {
    info "=== Testing SSL Certificate ==="
    
    if [ -z "$DOMAIN_NAME" ]; then
        error "Cannot determine domain name"
        return 1
    fi
    
    # Test SSL certificate validity
    run_test "SSL certificate valid" "echo | openssl s_client -servername $DOMAIN_NAME -connect $DOMAIN_NAME:443 2>/dev/null | openssl x509 -noout -dates"
    
    # Test SSL grade (if possible)
    if command -v curl &> /dev/null; then
        run_test "SSL connection successful" "curl -s --max-time 10 https://$DOMAIN_NAME -o /dev/null"
    fi
}

# Test performance
test_performance() {
    info "=== Testing Performance ==="
    
    if [ -z "$WEBSITE_URL" ]; then
        error "Cannot determine website URL"
        return 1
    fi
    
    # Test response time
    local response_time
    response_time=$(curl -s -w "%{time_total}" -o /dev/null --max-time 30 "$WEBSITE_URL" 2>/dev/null || echo "999")
    
    if (( $(echo "$response_time < 3.0" | bc -l 2>/dev/null || echo "0") )); then
        success "Response time: ${response_time}s (< 3s)"
        ((PASSED_TESTS++))
    else
        warning "Response time: ${response_time}s (> 3s)"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    # Test compression
    run_test "Gzip compression enabled" "curl -s -H 'Accept-Encoding: gzip' '$WEBSITE_URL' -D - | grep -q 'Content-Encoding: gzip'"
    
    # Test caching headers
    run_test "Cache headers present" "curl -s -I '$WEBSITE_URL' | grep -q -i 'cache-control'"
}

# Test DNS configuration
test_dns() {
    info "=== Testing DNS Configuration ==="
    
    if [ -z "$DOMAIN_NAME" ]; then
        error "Cannot determine domain name"
        return 1
    fi
    
    # Test DNS resolution
    run_test "DNS A record resolves" "dig +short $DOMAIN_NAME A | grep -q '^[0-9]'"
    run_test "DNS AAAA record resolves" "dig +short $DOMAIN_NAME AAAA | grep -q '^[0-9a-f:]'"
    
    # Test WWW subdomain
    run_test "WWW subdomain resolves" "dig +short www.$DOMAIN_NAME A | grep -q '^[0-9]'"
}

# Test monitoring and alerts
test_monitoring() {
    info "=== Testing Monitoring Setup ==="
    
    # Check if CloudWatch alarms exist
    if [ -n "$CLOUDFRONT_ID" ]; then
        local alarm_count
        alarm_count=$(aws cloudwatch describe-alarms --alarm-name-prefix "noveycloud" --query 'MetricAlarms | length(@)' --output text 2>/dev/null || echo "0")
        
        if [ "$alarm_count" -gt 0 ]; then
            success "CloudWatch alarms configured ($alarm_count alarms)"
            ((PASSED_TESTS++))
        else
            warning "No CloudWatch alarms found"
            ((FAILED_TESTS++))
        fi
        ((TOTAL_TESTS++))
    fi
}

# Generate report
generate_report() {
    echo ""
    info "=== Final Verification Report ==="
    echo ""
    
    if [ $TOTAL_TESTS -gt 0 ]; then
        local pass_rate
        pass_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
        
        echo "Total Tests: $TOTAL_TESTS"
        echo "Passed: $PASSED_TESTS"
        echo "Failed: $FAILED_TESTS"
        echo "Pass Rate: ${pass_rate}%"
        echo ""
        
        if [ $pass_rate -ge 90 ]; then
            success "🎉 Excellent! Your resume website is fully deployed and working great!"
        elif [ $pass_rate -ge 75 ]; then
            warning "⚠️  Good! Your website is mostly working, but some issues need attention."
        else
            error "❌ Issues detected. Please review the failed tests and fix them."
        fi
    else
        error "No tests were run. Please check your deployment."
    fi
    
    echo ""
    if [ -n "$WEBSITE_URL" ]; then
        info "🌐 Your resume website: $WEBSITE_URL"
    fi
    
    echo ""
    info "Next steps:"
    echo "  1. If DNS is still propagating, wait up to 24 hours"
    echo "  2. Test your website from different locations/devices"
    echo "  3. Update your LinkedIn and other profiles with your new URL"
    echo "  4. Set up regular monitoring with: ./scripts/monitor-free-tier.sh"
}

# Main function
main() {
    echo "🔍 Resume Website Final Verification"
    echo "===================================="
    echo ""
    
    check_deployment_exists
    get_config
    
    # Run all test suites
    test_infrastructure
    test_website_accessibility
    test_website_content
    test_ssl_certificate
    test_performance
    test_dns
    test_monitoring
    
    # Generate final report
    generate_report
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"