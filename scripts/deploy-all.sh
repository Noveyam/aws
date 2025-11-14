#!/bin/bash

# =============================================================================
# Complete Deployment Orchestration Script
# Orchestrates infrastructure and website deployment with rollback capabilities
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/complete-deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${1}" | tee -a "$LOG_FILE"; }
error_exit() { log "${RED}ERROR: $1${NC}"; exit 1; }
success() { log "${GREEN}✓ $1${NC}"; }
warning() { log "${YELLOW}⚠ $1${NC}"; }
info() { log "${BLUE}ℹ $1${NC}"; }

# Initialize logging
init_logging() {
    echo "=== Complete Resume Website Deployment ===" > "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites for complete deployment..."
    
    # Check if required scripts exist
    local required_scripts=(
        "$SCRIPT_DIR/manage-environment.sh"
        "$SCRIPT_DIR/deploy-infrastructure.sh"
        "$SCRIPT_DIR/deploy-website.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            error_exit "Required script not found: $script"
        fi
        if [ ! -x "$script" ]; then
            chmod +x "$script"
        fi
    done
    
    success "All required scripts are available"
}

# Deploy infrastructure
deploy_infrastructure() {
    local action="${1:-deploy}"
    
    info "Starting infrastructure deployment..."
    
    if ! "$SCRIPT_DIR/deploy-infrastructure.sh" "$action"; then
        error_exit "Infrastructure deployment failed"
    fi
    
    success "Infrastructure deployment completed"
}

# Deploy website content
deploy_website() {
    local action="${1:-deploy}"
    
    info "Starting website content deployment..."
    
    if ! "$SCRIPT_DIR/deploy-website.sh" "$action"; then
        error_exit "Website content deployment failed"
    fi
    
    success "Website content deployment completed"
}

# Validate deployment
validate_deployment() {
    info "Validating complete deployment..."
    
    # Check if terraform outputs exist
    if [ ! -f "$PROJECT_ROOT/terraform-outputs.json" ]; then
        error_exit "Terraform outputs not found. Infrastructure may not be deployed."
    fi
    
    # Extract website URL
    local website_url
    if command -v jq &> /dev/null; then
        website_url=$(jq -r '.website_url.value' "$PROJECT_ROOT/terraform-outputs.json")
    else
        warning "jq not available. Skipping URL validation."
        return 0
    fi
    
    if [ "$website_url" = "null" ] || [ -z "$website_url" ]; then
        error_exit "Could not determine website URL from Terraform outputs"
    fi
    
    info "Testing website accessibility: $website_url"
    
    # Test website with retries
    local max_retries=3
    local retry_delay=10
    local success_count=0
    
    for ((i=1; i<=max_retries; i++)); do
        info "Attempt $i/$max_retries: Testing $website_url"
        
        local http_status
        http_status=$(curl -s -o /dev/null -w "%{http_code}" "$website_url" --max-time 30 || echo "000")
        
        if [ "$http_status" = "200" ]; then
            success "Website is accessible (HTTP $http_status)"
            ((success_count++))
            break
        elif [ "$http_status" = "000" ]; then
            warning "Connection failed (attempt $i/$max_retries)"
        else
            warning "Website returned HTTP $http_status (attempt $i/$max_retries)"
        fi
        
        if [ $i -lt $max_retries ]; then
            info "Waiting $retry_delay seconds before retry..."
            sleep $retry_delay
        fi
    done
    
    if [ $success_count -eq 0 ]; then
        warning "Website accessibility test failed. This might be due to DNS propagation delays."
        warning "Please test manually: $website_url"
    fi
    
    success "Deployment validation completed"
}

# Rollback deployment
rollback_deployment() {
    warning "Starting deployment rollback..."
    
    # Rollback website content first
    info "Rolling back website content..."
    if ! "$SCRIPT_DIR/deploy-website.sh" rollback; then
        error_exit "Website rollback failed"
    fi
    
    # Note: Infrastructure rollback is more complex and should be done manually
    warning "Infrastructure rollback must be done manually using:"
    warning "  $SCRIPT_DIR/deploy-infrastructure.sh destroy"
    
    success "Website rollback completed"
}

# Show deployment status
show_status() {
    info "=== Deployment Status ==="
    
    # Check current environment
    local current_env
    if [ -f "$PROJECT_ROOT/.current_environment" ]; then
        current_env=$(cat "$PROJECT_ROOT/.current_environment")
        info "Current environment: $current_env"
    else
        warning "No environment set"
    fi
    
    # Check if infrastructure is deployed
    if [ -f "$PROJECT_ROOT/terraform-outputs.json" ]; then
        success "Infrastructure: Deployed"
        
        if command -v jq &> /dev/null; then
            local website_url
            website_url=$(jq -r '.website_url.value' "$PROJECT_ROOT/terraform-outputs.json" 2>/dev/null || echo "unknown")
            info "Website URL: $website_url"
            
            local s3_bucket
            s3_bucket=$(jq -r '.s3_bucket_name.value' "$PROJECT_ROOT/terraform-outputs.json" 2>/dev/null || echo "unknown")
            info "S3 Bucket: $s3_bucket"
            
            local cloudfront_id
            cloudfront_id=$(jq -r '.cloudfront_distribution_id.value' "$PROJECT_ROOT/terraform-outputs.json" 2>/dev/null || echo "unknown")
            info "CloudFront Distribution: $cloudfront_id"
        fi
    else
        warning "Infrastructure: Not deployed"
    fi
    
    # Check recent deployments
    if [ -f "$PROJECT_ROOT/website-deployment.log" ]; then
        local last_deployment
        last_deployment=$(tail -1 "$PROJECT_ROOT/website-deployment.log" | grep "Completed at:" || echo "Unknown")
        info "Last website deployment: $last_deployment"
    fi
    
    # Check backups
    local backup_count
    backup_count=$(find "$PROJECT_ROOT/backups" -name "*" -type d 2>/dev/null | wc -l || echo "0")
    info "Available backups: $backup_count"
}

# Interactive deployment
interactive_deployment() {
    info "=== Interactive Deployment Wizard ==="
    
    # Environment selection
    echo ""
    info "Available environments:"
    "$SCRIPT_DIR/manage-environment.sh" list
    
    echo ""
    read -p "Select environment (dev/staging/prod): " -r selected_env
    
    if [ -z "$selected_env" ]; then
        error_exit "Environment selection is required"
    fi
    
    # Set environment
    if ! "$SCRIPT_DIR/manage-environment.sh" set "$selected_env"; then
        error_exit "Failed to set environment: $selected_env"
    fi
    
    # Validate environment
    if ! "$SCRIPT_DIR/manage-environment.sh" validate; then
        error_exit "Environment validation failed"
    fi
    
    # Deployment confirmation
    echo ""
    info "Deployment plan for environment: $selected_env"
    echo "  1. Deploy infrastructure (Terraform)"
    echo "  2. Deploy website content"
    echo "  3. Validate deployment"
    echo ""
    
    read -p "Proceed with deployment? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Deployment cancelled by user"
        exit 0
    fi
    
    # Execute deployment
    deploy_infrastructure
    deploy_website
    validate_deployment
    
    success "🎉 Interactive deployment completed successfully!"
}

# Main function
main() {
    local command="${1:-help}"
    
    init_logging
    check_prerequisites
    
    case "$command" in
        "deploy")
            local env="${2:-}"
            if [ -n "$env" ]; then
                info "Setting environment to: $env"
                if ! "$SCRIPT_DIR/manage-environment.sh" set "$env"; then
                    error_exit "Failed to set environment to $env"
                fi
                success "Environment set to: $env"
            fi
            deploy_infrastructure
            deploy_website
            validate_deployment
            success "🎉 Complete deployment finished successfully!"
            ;;
        "infrastructure")
            local action="${2:-deploy}"
            deploy_infrastructure "$action"
            ;;
        "website")
            local action="${2:-deploy}"
            deploy_website "$action"
            ;;
        "validate")
            validate_deployment
            ;;
        "rollback")
            rollback_deployment
            ;;
        "status")
            show_status
            ;;
        "interactive")
            interactive_deployment
            ;;
        "help"|*)
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  deploy [env]           - Deploy infrastructure and website"
            echo "  infrastructure [action] - Deploy infrastructure only (deploy/plan/destroy)"
            echo "  website [action]       - Deploy website only (deploy/validate/rollback)"
            echo "  validate               - Validate deployment"
            echo "  rollback               - Rollback deployment"
            echo "  status                 - Show deployment status"
            echo "  interactive            - Interactive deployment wizard"
            echo "  help                   - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 deploy prod         - Deploy to production environment"
            echo "  $0 interactive         - Run interactive deployment wizard"
            echo "  $0 infrastructure plan - Show infrastructure plan"
            echo "  $0 website validate    - Validate website files only"
            ;;
    esac
    
    echo ""
    echo "Completed at: $(date)" >> "$LOG_FILE"
    success "Script completed successfully"
}

# Trap to handle interruptions
trap 'echo ""; warning "Deployment interrupted by user"; exit 130' INT

# Run main function with all arguments
main "$@"