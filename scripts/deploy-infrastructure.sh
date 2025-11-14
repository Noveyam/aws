#!/bin/bash

# =============================================================================
# Resume Website Infrastructure Deployment Script
# Deploys AWS infrastructure using Terraform with validation and error handling
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Set environment variables for ARM64 compatibility
export TFENV_ARCH=arm64
export GODEBUG=asyncpreemptoff=1

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
LOG_FILE="$PROJECT_ROOT/deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Success message
success() {
    log "${GREEN}✓ $1${NC}"
}

# Warning message
warning() {
    log "${YELLOW}⚠ $1${NC}"
}

# Info message
info() {
    log "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error_exit "Terraform is not installed. Please install Terraform >= 1.0"
    fi
    
    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    info "Terraform version: $TERRAFORM_VERSION"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI is not installed. Please install AWS CLI"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error_exit "AWS credentials not configured. Please run 'aws configure'"
    fi
    
    # Check if jq is installed (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        warning "jq is not installed. Some features may not work properly"
    fi
    
    success "Prerequisites check completed"
}

# Validate Terraform configuration
validate_terraform() {
    info "Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Format files (non-blocking)
    info "Formatting Terraform files..."
    terraform fmt -recursive > /dev/null 2>&1 || true
    
    # Validate configuration
    terraform validate || error_exit "Terraform configuration validation failed"
    
    success "Terraform configuration is valid"
}

# Initialize Terraform
init_terraform() {
    info "Initializing Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize with upgrade to ensure latest providers
    terraform init -upgrade || error_exit "Terraform initialization failed"
    
    success "Terraform initialized successfully"
}

# Plan Terraform deployment
plan_terraform() {
    info "Creating Terraform execution plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Create plan file (exit code 2 means changes detected, which is success)
    set +e
    terraform plan -out=tfplan -detailed-exitcode
    local plan_exit=$?
    set -e
    
    if [ $plan_exit -eq 0 ]; then
        info "No changes detected in Terraform plan"
    elif [ $plan_exit -eq 2 ]; then
        info "Changes detected in Terraform plan"
    else
        error_exit "Terraform plan failed with exit code $plan_exit"
    fi
    
    success "Terraform plan created successfully"
}

# Apply Terraform deployment
apply_terraform() {
    info "Applying Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Apply the plan
    terraform apply tfplan || error_exit "Terraform apply failed"
    
    # Clean up plan file
    rm -f tfplan
    
    success "Infrastructure deployed successfully"
}

# Get Terraform outputs
get_outputs() {
    info "Retrieving deployment outputs..."
    
    cd "$TERRAFORM_DIR" || return 0
    
    # Get outputs in JSON format (non-blocking)
    set +e
    terraform output -json > "$PROJECT_ROOT/terraform-outputs.json" 2>/dev/null
    local output_result=$?
    set -e
    
    if [ $output_result -ne 0 ]; then
        warning "Could not retrieve Terraform outputs (this is normal if resources are still being created)"
        return 0
    fi
    
    # Display key outputs
    echo ""
    info "=== Deployment Summary ==="
    
    if command -v jq &> /dev/null; then
        set +e
        echo "S3 Bucket: $(terraform output -raw s3_bucket_name 2>/dev/null || echo 'N/A')"
        echo "CloudFront Distribution ID: $(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo 'N/A')"
        echo "Website URL: $(terraform output -raw website_url 2>/dev/null || echo 'N/A')"
        echo "WWW URL: $(terraform output -raw www_website_url 2>/dev/null || echo 'N/A')"
        echo ""
        echo "Route53 Name Servers:"
        terraform output -json route53_name_servers 2>/dev/null | jq -r '.[]' 2>/dev/null | sed 's/^/  - /' || echo "  - N/A"
        set -e
        echo ""
        info "Full outputs saved to: terraform-outputs.json"
    else
        set +e
        terraform output 2>/dev/null || echo "Outputs not available yet"
        set -e
    fi
    
    success "Outputs retrieved successfully"
    return 0
}

# Verify deployment
verify_deployment() {
    info "Verifying deployment..."
    
    cd "$TERRAFORM_DIR" || return 0
    
    # Get CloudFront distribution ID (non-blocking)
    set +e
    local distribution_id
    distribution_id=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    set -e
    
    if [ -n "$distribution_id" ] && [ "$distribution_id" != "null" ]; then
        info "Checking CloudFront distribution status..."
        set +e
        local status
        status=$(aws cloudfront get-distribution --id "$distribution_id" --query 'Distribution.Status' --output text 2>/dev/null || echo "Unknown")
        set -e
        info "CloudFront distribution status: $status"
        
        if [ "$status" = "Deployed" ]; then
            success "CloudFront distribution is deployed and ready"
        else
            warning "CloudFront distribution is still deploying. This may take 15-20 minutes."
        fi
    fi
    
    # Check certificate status (non-blocking)
    set +e
    local cert_arn
    cert_arn=$(terraform output -raw acm_certificate_arn 2>/dev/null || echo "")
    set -e
    
    if [ -n "$cert_arn" ] && [ "$cert_arn" != "null" ]; then
        info "Checking SSL certificate status..."
        set +e
        local cert_status
        cert_status=$(aws acm describe-certificate --certificate-arn "$cert_arn" --region us-east-1 --query 'Certificate.Status' --output text 2>/dev/null || echo "Unknown")
        set -e
        info "SSL certificate status: $cert_status"
        
        if [ "$cert_status" = "ISSUED" ]; then
            success "SSL certificate is issued and ready"
        else
            warning "SSL certificate is still being validated. This may take a few minutes."
        fi
    fi
    
    success "Deployment verification completed"
    return 0
}

# Cleanup function
cleanup() {
    cd "$TERRAFORM_DIR"
    rm -f tfplan
}

# Main deployment function
main() {
    local action="${1:-deploy}"
    
    # Set up logging
    echo "=== Resume Website Infrastructure Deployment ===" > "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    info "Starting infrastructure deployment..."
    info "Log file: $LOG_FILE"
    
    case "$action" in
        "deploy")
            check_prerequisites
            init_terraform
            validate_terraform
            plan_terraform
            
            # Check if running in CI/CD (non-interactive mode)
            if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ "${AUTO_APPROVE:-false}" = "true" ]; then
                info "Running in non-interactive mode (CI/CD detected)"
                
                info "Step 1/3: Applying Terraform changes..."
                apply_terraform || error_exit "Terraform apply failed"
                
                info "Step 2/3: Retrieving outputs..."
                get_outputs || warning "Could not retrieve outputs (continuing anyway)"
                
                info "Step 3/3: Verifying deployment..."
                verify_deployment || warning "Verification failed (continuing anyway)"
                
                echo ""
                success "🎉 Infrastructure deployment completed successfully!"
            else
                # Ask for confirmation before applying (interactive mode)
                echo ""
                read -p "Do you want to apply these changes? (y/N): " -n 1 -r
                echo ""
                
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    apply_terraform
                    get_outputs
                    verify_deployment
                    
                    echo ""
                    success "🎉 Infrastructure deployment completed successfully!"
                    info "Next steps:"
                    echo "  1. Update your domain's name servers with the Route53 name servers shown above"
                    echo "  2. Wait for DNS propagation (up to 24 hours)"
                    echo "  3. Run './scripts/deploy-website.sh' to upload your website content"
                else
                    info "Deployment cancelled by user"
                    cleanup
                    exit 0
                fi
            fi
            ;;
        "plan")
            check_prerequisites
            init_terraform
            validate_terraform
            plan_terraform
            info "Plan completed. Run with 'deploy' to apply changes."
            ;;
        "destroy")
            echo ""
            warning "⚠️  WARNING: This will destroy all infrastructure resources!"
            read -p "Are you sure you want to destroy the infrastructure? (y/N): " -n 1 -r
            echo ""
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd "$TERRAFORM_DIR"
                terraform destroy || error_exit "Terraform destroy failed"
                success "Infrastructure destroyed successfully"
            else
                info "Destroy cancelled by user"
            fi
            ;;
        "output")
            cd "$TERRAFORM_DIR"
            get_outputs
            ;;
        *)
            echo "Usage: $0 [deploy|plan|destroy|output]"
            echo ""
            echo "Commands:"
            echo "  deploy   - Deploy the infrastructure (default)"
            echo "  plan     - Show what would be deployed"
            echo "  destroy  - Destroy all infrastructure"
            echo "  output   - Show deployment outputs"
            exit 1
            ;;
    esac
    
    cleanup
    
    echo ""
    echo "Completed at: $(date)" >> "$LOG_FILE"
    success "Script completed successfully"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function with all arguments
main "$@"