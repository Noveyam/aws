#!/bin/bash

# =============================================================================
# Terraform Configuration Validation Tests
# Validates Terraform configuration files for syntax, best practices, and security
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
TEST_LOG="$PROJECT_ROOT/terraform-config-tests.log"

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
info() { log "${BLUE}ℹ $1${NC}"; }

# Initialize test logging
init_tests() {
    echo "=== Terraform Configuration Validation Tests ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    info "Starting Terraform configuration validation tests..."
    info "Test log: $TEST_LOG"
}

# Check prerequisites
check_prerequisites() {
    test_start "Checking prerequisites"
    
    if ! command -v terraform &> /dev/null; then
        test_fail "Terraform not installed"
        return 1
    fi
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        test_fail "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    
    test_pass "Prerequisites check completed"
}

# Test Terraform syntax validation
test_terraform_syntax() {
    test_start "Validating Terraform syntax"
    
    cd "$TERRAFORM_DIR"
    
    # Run terraform validate
    if terraform validate; then
        test_pass "Terraform configuration syntax is valid"
    else
        test_fail "Terraform configuration has syntax errors"
        return 1
    fi
}

# Test Terraform formatting
test_terraform_formatting() {
    test_start "Checking Terraform formatting"
    
    cd "$TERRAFORM_DIR"
    
    # Check if files are properly formatted
    if terraform fmt -check=true -diff=false; then
        test_pass "Terraform files are properly formatted"
    else
        test_fail "Terraform files are not properly formatted"
        info "Run 'terraform fmt' to fix formatting issues"
        return 1
    fi
}

# Test required files exist
test_required_files() {
    test_start "Checking required Terraform files"
    
    local required_files=("main.tf" "variables.tf" "outputs.tf" "versions.tf" "terraform.tfvars")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$TERRAFORM_DIR/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        test_pass "All required Terraform files exist"
    else
        test_fail "Missing required files: ${missing_files[*]}"
        return 1
    fi
}

# Test provider configuration
test_provider_configuration() {
    test_start "Validating provider configuration"
    
    cd "$TERRAFORM_DIR"
    
    # Check if AWS provider is properly configured
    if grep -q "provider \"aws\"" *.tf; then
        test_pass "AWS provider is configured"
    else
        test_fail "AWS provider not found in configuration"
        return 1
    fi
    
    # Check for provider version constraints
    if grep -q "version.*=.*\"~>" versions.tf; then
        test_pass "Provider version constraints are specified"
    else
        test_fail "Provider version constraints not found"
        return 1
    fi
    
    # Check for required Terraform version
    if grep -q "required_version.*=" versions.tf; then
        test_pass "Required Terraform version is specified"
    else
        test_fail "Required Terraform version not specified"
        return 1
    fi
}

# Test resource naming conventions
test_naming_conventions() {
    test_start "Checking resource naming conventions"
    
    cd "$TERRAFORM_DIR"
    
    local naming_issues=0
    
    # Check for consistent resource naming (snake_case)
    while IFS= read -r line; do
        if [[ $line =~ ^resource[[:space:]]+\"[^\"]+\"[[:space:]]+\"([^\"]+)\" ]]; then
            local resource_name="${BASH_REMATCH[1]}"
            if [[ ! $resource_name =~ ^[a-z][a-z0-9_]*$ ]]; then
                log "${YELLOW}⚠ Resource name not following snake_case convention: $resource_name${NC}"
                ((naming_issues++))
            fi
        fi
    done < <(grep -n "^resource " *.tf)
    
    if [ $naming_issues -eq 0 ]; then
        test_pass "Resource naming conventions are followed"
    else
        test_fail "Found $naming_issues naming convention issues"
        return 1
    fi
}

# Test variable definitions
test_variable_definitions() {
    test_start "Validating variable definitions"
    
    cd "$TERRAFORM_DIR"
    
    # Check if all variables have descriptions
    local variables_without_description=0
    
    while IFS= read -r line; do
        if [[ $line =~ ^variable[[:space:]]+\"([^\"]+)\" ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_block_start=$(grep -n "^variable \"$var_name\"" variables.tf | cut -d: -f1)
            local var_block_end=$(tail -n +$((var_block_start + 1)) variables.tf | grep -n "^}" | head -1 | cut -d: -f1)
            var_block_end=$((var_block_start + var_block_end))
            
            if ! sed -n "${var_block_start},${var_block_end}p" variables.tf | grep -q "description"; then
                log "${YELLOW}⚠ Variable without description: $var_name${NC}"
                ((variables_without_description++))
            fi
        fi
    done < <(grep -n "^variable " variables.tf)
    
    if [ $variables_without_description -eq 0 ]; then
        test_pass "All variables have descriptions"
    else
        test_fail "Found $variables_without_description variables without descriptions"
        return 1
    fi
}

# Test output definitions
test_output_definitions() {
    test_start "Validating output definitions"
    
    cd "$TERRAFORM_DIR"
    
    # Check if all outputs have descriptions
    local outputs_without_description=0
    
    while IFS= read -r line; do
        if [[ $line =~ ^output[[:space:]]+\"([^\"]+)\" ]]; then
            local output_name="${BASH_REMATCH[1]}"
            local output_block_start=$(grep -n "^output \"$output_name\"" outputs.tf | cut -d: -f1)
            local output_block_end=$(tail -n +$((output_block_start + 1)) outputs.tf | grep -n "^}" | head -1 | cut -d: -f1)
            output_block_end=$((output_block_start + output_block_end))
            
            if ! sed -n "${output_block_start},${output_block_end}p" outputs.tf | grep -q "description"; then
                log "${YELLOW}⚠ Output without description: $output_name${NC}"
                ((outputs_without_description++))
            fi
        fi
    done < <(grep -n "^output " outputs.tf)
    
    if [ $outputs_without_description -eq 0 ]; then
        test_pass "All outputs have descriptions"
    else
        test_fail "Found $outputs_without_description outputs without descriptions"
        return 1
    fi
}

# Test security best practices
test_security_practices() {
    test_start "Checking security best practices"
    
    cd "$TERRAFORM_DIR"
    
    local security_issues=0
    
    # Check for hardcoded secrets (basic check)
    if grep -i "password\|secret\|key" *.tf | grep -v "aws_secretsmanager\|aws_kms\|description\|variable\|output"; then
        log "${YELLOW}⚠ Potential hardcoded secrets found${NC}"
        ((security_issues++))
    fi
    
    # Check for public access blocks on S3
    if grep -q "aws_s3_bucket_public_access_block" *.tf; then
        test_pass "S3 public access block is configured"
    else
        log "${YELLOW}⚠ S3 public access block not found${NC}"
        ((security_issues++))
    fi
    
    # Check for encryption configuration
    if grep -q "server_side_encryption_configuration\|encryption" *.tf; then
        test_pass "Encryption configuration found"
    else
        log "${YELLOW}⚠ No encryption configuration found${NC}"
        ((security_issues++))
    fi
    
    if [ $security_issues -eq 0 ]; then
        test_pass "Security best practices are followed"
    else
        test_fail "Found $security_issues potential security issues"
        return 1
    fi
}

# Test resource tagging
test_resource_tagging() {
    test_start "Checking resource tagging"
    
    cd "$TERRAFORM_DIR"
    
    # Check if resources have tags
    local resources_without_tags=0
    
    # List of AWS resources that should have tags
    local taggable_resources=("aws_s3_bucket" "aws_cloudfront_distribution" "aws_route53_zone" "aws_acm_certificate")
    
    for resource_type in "${taggable_resources[@]}"; do
        while IFS= read -r line; do
            if [[ $line =~ ^resource[[:space:]]+\"$resource_type\"[[:space:]]+\"([^\"]+)\" ]]; then
                local resource_name="${BASH_REMATCH[1]}"
                local resource_block_start=$(grep -n "^resource \"$resource_type\" \"$resource_name\"" *.tf | cut -d: -f1)
                
                if [ -n "$resource_block_start" ]; then
                    local file_with_resource=$(grep -l "^resource \"$resource_type\" \"$resource_name\"" *.tf)
                    local resource_block_end=$(tail -n +$((resource_block_start + 1)) "$file_with_resource" | grep -n "^}" | head -1 | cut -d: -f1)
                    resource_block_end=$((resource_block_start + resource_block_end))
                    
                    if ! sed -n "${resource_block_start},${resource_block_end}p" "$file_with_resource" | grep -q "tags"; then
                        log "${YELLOW}⚠ Resource without tags: $resource_type.$resource_name${NC}"
                        ((resources_without_tags++))
                    fi
                fi
            fi
        done < <(grep -n "^resource \"$resource_type\"" *.tf)
    done
    
    if [ $resources_without_tags -eq 0 ]; then
        test_pass "All taggable resources have tags"
    else
        test_fail "Found $resources_without_tags resources without tags"
        return 1
    fi
}

# Test Free Tier compliance in configuration
test_free_tier_config() {
    test_start "Checking Free Tier compliance in configuration"
    
    cd "$TERRAFORM_DIR"
    
    # Check CloudFront price class
    if grep -q "PriceClass_100" *.tf; then
        test_pass "CloudFront configured for Free Tier (PriceClass_100)"
    else
        test_fail "CloudFront not configured for Free Tier price class"
        return 1
    fi
    
    # Check for lifecycle rules (cost optimization)
    if grep -q "lifecycle_configuration\|lifecycle_rule" *.tf; then
        test_pass "S3 lifecycle configuration found (cost optimization)"
    else
        log "${YELLOW}⚠ No S3 lifecycle configuration found${NC}"
    fi
}

# Generate test report
generate_report() {
    echo ""
    log "=== Test Results Summary ==="
    log "Tests Run: $TESTS_RUN"
    log "Tests Passed: $TESTS_PASSED"
    log "Tests Failed: $TESTS_FAILED"
    
    local success_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    log "Success Rate: ${success_rate}%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "${GREEN}🎉 All configuration tests passed!${NC}"
        return 0
    else
        log "${RED}❌ Some configuration tests failed. Please review the issues above.${NC}"
        return 1
    fi
}

# Main test execution
main() {
    init_tests
    
    # Run all tests
    check_prerequisites || exit 1
    
    test_terraform_syntax
    test_terraform_formatting
    test_required_files
    test_provider_configuration
    test_naming_conventions
    test_variable_definitions
    test_output_definitions
    test_security_practices
    test_resource_tagging
    test_free_tier_config
    
    # Generate final report
    generate_report
    
    echo ""
    echo "Completed at: $(date)" >> "$TEST_LOG"
    log "Test results saved to: $TEST_LOG"
}

# Run tests
main "$@"