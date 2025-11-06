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
    
    # Format check
    if ! terraform fmt -check=true -diff=true; then
        warning "Terraform files are not properly formatted. Running terraform fmt..."
        terraform fmt
    fi
    
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
    
    # Create plan file
    terraform plan -out=tfplan -detailed-exitcode || {
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            error_exit "Terraform plan failed"
        elif [ $exit_code -eq 2 ]; then
            info "Changes detected in Terraform plan"
        fi
    }
    
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
    
    cd "$TERRAFORM_DIR"
    
    # Get outputs in JSON format
    terraform output -json > "$PROJECT_ROOT/terraform-outputs.json"
    
    # Display key outputs
    echo ""
    info "=== Deployment Summary ==="
    
    if command -v jq &> /dev/null; then
        echo "S3 Bucket: $(terraform output -raw s3_bucket_name)"
        echo "CloudFront Distribution ID: $(terraform output -raw cloudfront_distribution_id)"
        echo "Website URL: $(terraform output -raw website_url)"
        echo "WWW URL: $(terraform output -raw www_website_url)"
        echo ""
        echo "Route53 Name Servers:"
        terraform output -json route53_name_servers | jq -r '.[]' | sed 's/^/  - /'
        echo ""
        info "Full outputs saved to: terraform-outputs.json"
    else
        terraform output
    fi
    
    success "Outputs retrieved successfully"
}

# Verify deployment
verify_deployment() {
    info "Verifying deployment..."
    
    cd "$TERRAFORM_DIR"
    
    # Get CloudFront distribution ID
    local distribution_id
    distribution_id=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    
    if [ -n "$distribution_id" ]; then
        info "Checking CloudFront distribution status..."
        local status
        status=$(aws cloudfront get-distribution --id "$distribution_id" --query 'Distribution.Status' --output text 2>/dev/null || echo "Unknown")
        info "CloudFront distribution status: $status"
        
        if [ "$status" = "Deployed" ]; then
            success "CloudFront distribution is deployed and ready"
        else
            warning "CloudFront distribution is still deploying. This may take 15-20 minutes."
        fi
    fi
    
    # Check certificate status
    local cert_arn
    cert_arn=$(terraform output -raw acm_certificate_arn 2>/dev/null || echo "")
    
    if [ -n "$cert_arn" ]; then
        info "Checking SSL certificate status..."
        local cert_status
        cert_status=$(aws acm describe-certificate --certificate-arn "$cert_arn" --region us-east-1 --query 'Certificate.Status' --output text 2>/dev/null || echo "Unknown")
        info "SSL certificate status: $cert_status"
        
        if [ "$cert_status" = "ISSUED" ]; then
            success "SSL certificate is issued and ready"
        else
            warning "SSL certificate is still being validated. This may take a few minutes."
        fi
    fi
    
    success "Deployment verification completed"
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
            validate_terraform
            init_terraform
            plan_terraform
            
            # Ask for confirmation before applying
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
            ;;
        "plan")
            check_prerequisites
            validate_terraform
            init_terraform
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