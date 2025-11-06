#!/bin/bash

# =============================================================================
# Resume Website Content Deployment Script
# Syncs website files to S3 and invalidates CloudFront cache
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WEBSITE_DIR="$PROJECT_ROOT/website"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
LOG_FILE="$PROJECT_ROOT/website-deployment.log"
OUTPUTS_FILE="$PROJECT_ROOT/terraform-outputs.json"

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
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI is not installed. Please install AWS CLI"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error_exit "AWS credentials not configured. Please run 'aws configure'"
    fi
    
    # Check if website directory exists
    if [ ! -d "$WEBSITE_DIR" ]; then
        error_exit "Website directory not found: $WEBSITE_DIR"
    fi
    
    # Check if Terraform outputs exist
    if [ ! -f "$OUTPUTS_FILE" ]; then
        warning "Terraform outputs not found. Attempting to retrieve..."
        if [ -d "$TERRAFORM_DIR" ]; then
            cd "$TERRAFORM_DIR"
            terraform output -json > "$OUTPUTS_FILE" 2>/dev/null || error_exit "Could not retrieve Terraform outputs. Please run deploy-infrastructure.sh first."
        else
            error_exit "Terraform directory not found. Please run deploy-infrastructure.sh first."
        fi
    fi
    
    # Check if jq is installed (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        error_exit "jq is required for parsing Terraform outputs. Please install jq"
    fi
    
    success "Prerequisites check completed"
}

# Get deployment configuration from Terraform outputs
get_deployment_config() {
    info "Reading deployment configuration..."
    
    # Extract values from Terraform outputs
    S3_BUCKET=$(jq -r '.s3_bucket_name.value' "$OUTPUTS_FILE")
    CLOUDFRONT_DISTRIBUTION_ID=$(jq -r '.cloudfront_distribution_id.value' "$OUTPUTS_FILE")
    WEBSITE_URL=$(jq -r '.website_url.value' "$OUTPUTS_FILE")
    
    if [ "$S3_BUCKET" = "null" ] || [ "$CLOUDFRONT_DISTRIBUTION_ID" = "null" ]; then
        error_exit "Could not read deployment configuration from Terraform outputs"
    fi
    
    info "S3 Bucket: $S3_BUCKET"
    info "CloudFront Distribution: $CLOUDFRONT_DISTRIBUTION_ID"
    info "Website URL: $WEBSITE_URL"
    
    success "Deployment configuration loaded"
}

# Validate HTML files
validate_html() {
    info "Validating HTML files..."
    
    local html_files
    html_files=$(find "$WEBSITE_DIR" -name "*.html" -type f)
    
    if [ -z "$html_files" ]; then
        warning "No HTML files found to validate"
        return 0
    fi
    
    local validation_errors=0
    
    while IFS= read -r file; do
        info "Validating: $(basename "$file")"
        
        # Basic HTML validation checks
        if ! grep -q "<!DOCTYPE html>" "$file"; then
            warning "Missing DOCTYPE declaration in $(basename "$file")"
            ((validation_errors++))
        fi
        
        if ! grep -q "<html" "$file"; then
            warning "Missing <html> tag in $(basename "$file")"
            ((validation_errors++))
        fi
        
        if ! grep -q "<head>" "$file"; then
            warning "Missing <head> tag in $(basename "$file")"
            ((validation_errors++))
        fi
        
        if ! grep -q "<body>" "$file"; then
            warning "Missing <body> tag in $(basename "$file")"
            ((validation_errors++))
        fi
        
        # Check for unclosed tags (basic check)
        local open_tags closed_tags
        open_tags=$(grep -o '<[^/][^>]*>' "$file" | grep -v '<!' | grep -v '<?' | wc -l)
        closed_tags=$(grep -o '</[^>]*>' "$file" | wc -l)
        
        if [ "$open_tags" -ne "$closed_tags" ]; then
            warning "Potential unclosed tags in $(basename "$file") (Open: $open_tags, Closed: $closed_tags)"
        fi
        
    done <<< "$html_files"
    
    if [ $validation_errors -eq 0 ]; then
        success "HTML validation completed with no errors"
    else
        warning "HTML validation completed with $validation_errors warnings"
    fi
}

# Validate CSS files
validate_css() {
    info "Validating CSS files..."
    
    local css_files
    css_files=$(find "$WEBSITE_DIR" -name "*.css" -type f)
    
    if [ -z "$css_files" ]; then
        warning "No CSS files found to validate"
        return 0
    fi
    
    local validation_errors=0
    
    while IFS= read -r file; do
        info "Validating: $(basename "$file")"
        
        # Basic CSS validation checks
        # Check for unclosed braces
        local open_braces closed_braces
        open_braces=$(grep -o '{' "$file" | wc -l)
        closed_braces=$(grep -o '}' "$file" | wc -l)
        
        if [ "$open_braces" -ne "$closed_braces" ]; then
            warning "Unclosed braces in $(basename "$file") (Open: $open_braces, Closed: $closed_braces)"
            ((validation_errors++))
        fi
        
        # Check for common syntax errors
        if grep -q ';;' "$file"; then
            warning "Double semicolons found in $(basename "$file")"
        fi
        
    done <<< "$css_files"
    
    if [ $validation_errors -eq 0 ]; then
        success "CSS validation completed with no errors"
    else
        warning "CSS validation completed with $validation_errors warnings"
    fi
}

# Optimize images (if tools are available)
optimize_images() {
    info "Checking for image optimization opportunities..."
    
    local image_files
    image_files=$(find "$WEBSITE_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \))
    
    if [ -z "$image_files" ]; then
        info "No images found to optimize"
        return 0
    fi
    
    local optimized=0
    
    while IFS= read -r file; do
        local file_size
        file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        
        if [ "$file_size" -gt 1048576 ]; then  # 1MB
            warning "Large image file detected: $(basename "$file") ($(($file_size / 1024))KB)"
            warning "Consider optimizing this image for better performance"
        fi
        
    done <<< "$image_files"
    
    info "Image optimization check completed"
}

# Create backup of current S3 content
create_backup() {
    info "Creating backup of current website content..."
    
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Download current S3 content
    if aws s3 sync "s3://$S3_BUCKET" "$backup_dir" --quiet 2>/dev/null; then
        success "Backup created: $backup_dir"
        echo "$backup_dir" > "$PROJECT_ROOT/.last_backup"
    else
        warning "Could not create backup (bucket might be empty)"
    fi
}

# Sync files to S3
sync_to_s3() {
    info "Syncing website files to S3..."
    
    cd "$WEBSITE_DIR"
    
    # Define file type specific settings
    local sync_args=(
        --delete
        --exact-timestamps
        --exclude "*.DS_Store"
        --exclude "*.gitkeep"
        --exclude "Thumbs.db"
        --exclude "*.tmp"
    )
    
    # Sync files with appropriate content types and cache settings
    info "Uploading HTML files..."
    aws s3 sync . "s3://$S3_BUCKET" \
        "${sync_args[@]}" \
        --include "*.html" \
        --content-type "text/html" \
        --cache-control "max-age=86400" \
        --metadata-directive REPLACE
    
    info "Uploading CSS files..."
    aws s3 sync . "s3://$S3_BUCKET" \
        "${sync_args[@]}" \
        --include "*.css" \
        --content-type "text/css" \
        --cache-control "max-age=31536000" \
        --metadata-directive REPLACE
    
    info "Uploading JavaScript files..."
    aws s3 sync . "s3://$S3_BUCKET" \
        "${sync_args[@]}" \
        --include "*.js" \
        --content-type "application/javascript" \
        --cache-control "max-age=31536000" \
        --metadata-directive REPLACE
    
    info "Uploading image files..."
    aws s3 sync . "s3://$S3_BUCKET" \
        "${sync_args[@]}" \
        --exclude "*" \
        --include "*.jpg" --include "*.jpeg" --include "*.png" --include "*.gif" --include "*.ico" --include "*.svg" \
        --cache-control "max-age=2592000" \
        --metadata-directive REPLACE
    
    info "Uploading other files..."
    aws s3 sync . "s3://$S3_BUCKET" \
        "${sync_args[@]}" \
        --exclude "*.html" --exclude "*.css" --exclude "*.js" \
        --exclude "*.jpg" --exclude "*.jpeg" --exclude "*.png" --exclude "*.gif" --exclude "*.ico" --exclude "*.svg" \
        --cache-control "max-age=604800" \
        --metadata-directive REPLACE
    
    success "Website files synced to S3 successfully"
}

# Invalidate CloudFront cache
invalidate_cloudfront() {
    info "Invalidating CloudFront cache..."
    
    # Create invalidation for all files
    local invalidation_id
    invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)
    
    if [ -n "$invalidation_id" ]; then
        info "Invalidation created: $invalidation_id"
        info "Checking invalidation status..."
        
        # Wait for invalidation to complete (with timeout)
        local timeout=300  # 5 minutes
        local elapsed=0
        local interval=10
        
        while [ $elapsed -lt $timeout ]; do
            local status
            status=$(aws cloudfront get-invalidation \
                --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
                --id "$invalidation_id" \
                --query 'Invalidation.Status' \
                --output text)
            
            if [ "$status" = "Completed" ]; then
                success "CloudFront cache invalidation completed"
                return 0
            fi
            
            info "Invalidation status: $status (waiting...)"
            sleep $interval
            elapsed=$((elapsed + interval))
        done
        
        warning "Invalidation is taking longer than expected. It will complete in the background."
    else
        error_exit "Failed to create CloudFront invalidation"
    fi
}

# Verify deployment
verify_deployment() {
    info "Verifying deployment..."
    
    # Check if website is accessible
    info "Testing website accessibility..."
    
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL" || echo "000")
    
    if [ "$http_status" = "200" ]; then
        success "Website is accessible at $WEBSITE_URL"
    elif [ "$http_status" = "000" ]; then
        warning "Could not connect to website. DNS might still be propagating."
    else
        warning "Website returned HTTP status: $http_status"
    fi
    
    # Check S3 bucket contents
    info "Verifying S3 bucket contents..."
    local file_count
    file_count=$(aws s3 ls "s3://$S3_BUCKET" --recursive | wc -l)
    info "Files in S3 bucket: $file_count"
    
    success "Deployment verification completed"
}

# Rollback function
rollback() {
    if [ ! -f "$PROJECT_ROOT/.last_backup" ]; then
        error_exit "No backup found for rollback"
    fi
    
    local backup_dir
    backup_dir=$(cat "$PROJECT_ROOT/.last_backup")
    
    if [ ! -d "$backup_dir" ]; then
        error_exit "Backup directory not found: $backup_dir"
    fi
    
    warning "Rolling back to backup: $backup_dir"
    
    # Restore from backup
    aws s3 sync "$backup_dir" "s3://$S3_BUCKET" --delete
    
    # Invalidate CloudFront cache
    invalidate_cloudfront
    
    success "Rollback completed"
}

# Main deployment function
main() {
    local action="${1:-deploy}"
    
    # Set up logging
    echo "=== Resume Website Content Deployment ===" > "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    info "Starting website content deployment..."
    info "Log file: $LOG_FILE"
    
    case "$action" in
        "deploy")
            check_prerequisites
            get_deployment_config
            validate_html
            validate_css
            optimize_images
            create_backup
            sync_to_s3
            invalidate_cloudfront
            verify_deployment
            
            echo ""
            success "🎉 Website deployment completed successfully!"
            info "Your website is now live at: $WEBSITE_URL"
            info "Note: If using a custom domain, ensure DNS is properly configured"
            ;;
        "validate")
            check_prerequisites
            validate_html
            validate_css
            optimize_images
            info "Validation completed. Run with 'deploy' to upload changes."
            ;;
        "rollback")
            check_prerequisites
            get_deployment_config
            rollback
            ;;
        "invalidate")
            check_prerequisites
            get_deployment_config
            invalidate_cloudfront
            ;;
        *)
            echo "Usage: $0 [deploy|validate|rollback|invalidate]"
            echo ""
            echo "Commands:"
            echo "  deploy     - Deploy website content (default)"
            echo "  validate   - Validate HTML/CSS files only"
            echo "  rollback   - Rollback to previous version"
            echo "  invalidate - Invalidate CloudFront cache only"
            exit 1
            ;;
    esac
    
    echo ""
    echo "Completed at: $(date)" >> "$LOG_FILE"
    success "Script completed successfully"
}

# Run main function with all arguments
main "$@"