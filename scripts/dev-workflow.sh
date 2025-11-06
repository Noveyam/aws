#!/bin/bash

# =============================================================================
# Development Workflow Script
# Provides common development tasks and CI/CD simulation
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error_exit() { echo -e "${RED}✗ $1${NC}"; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Simulate CI/CD validation locally
simulate_ci_validation() {
    info "🔍 Simulating CI/CD validation pipeline..."
    echo ""
    
    # Step 1: Configuration validation
    info "Step 1: Validating configuration..."
    if ./scripts/validate-config.sh; then
        success "Configuration validation passed"
    else
        error_exit "Configuration validation failed"
    fi
    echo ""
    
    # Step 2: HTML validation
    info "Step 2: Validating HTML files..."
    local html_errors=0
    find "$PROJECT_ROOT/website" -name "*.html" -type f | while read -r file; do
        info "Checking $(basename "$file")..."
        
        # Basic HTML validation
        if ! grep -q "<!DOCTYPE html>" "$file"; then
            warning "Missing DOCTYPE in $(basename "$file")"
            ((html_errors++))
        fi
        
        if ! grep -q "<html" "$file"; then
            warning "Missing <html> tag in $(basename "$file")"
            ((html_errors++))
        fi
    done
    
    if [ $html_errors -eq 0 ]; then
        success "HTML validation passed"
    else
        warning "HTML validation completed with warnings"
    fi
    echo ""
    
    # Step 3: CSS validation
    info "Step 3: Validating CSS files..."
    local css_errors=0
    find "$PROJECT_ROOT/website" -name "*.css" -type f | while read -r file; do
        info "Checking $(basename "$file")..."
        
        # Check for unclosed braces
        local open_braces closed_braces
        open_braces=$(grep -o '{' "$file" | wc -l)
        closed_braces=$(grep -o '}' "$file" | wc -l)
        
        if [ "$open_braces" -ne "$closed_braces" ]; then
            warning "Unclosed braces in $(basename "$file")"
            ((css_errors++))
        fi
    done
    
    if [ $css_errors -eq 0 ]; then
        success "CSS validation passed"
    else
        warning "CSS validation completed with warnings"
    fi
    echo ""
    
    # Step 4: Terraform validation
    info "Step 4: Validating Terraform configuration..."
    cd "$PROJECT_ROOT/terraform"
    
    if terraform fmt -check=true -diff=true >/dev/null 2>&1; then
        success "Terraform formatting is correct"
    else
        warning "Terraform files need formatting (run: terraform fmt)"
    fi
    
    if terraform init -backend=false >/dev/null 2>&1 && terraform validate >/dev/null 2>&1; then
        success "Terraform validation passed"
    else
        error_exit "Terraform validation failed"
    fi
    
    cd "$PROJECT_ROOT"
    echo ""
    
    success "🎉 All validation checks passed! Ready for CI/CD pipeline"
}

# Run local development server (simple Python server)
run_dev_server() {
    info "🚀 Starting local development server..."
    
    cd "$PROJECT_ROOT/website"
    
    # Check if Python is available
    if command -v python3 &> /dev/null; then
        info "Starting server at http://localhost:8000"
        info "Press Ctrl+C to stop the server"
        python3 -m http.server 8000
    elif command -v python &> /dev/null; then
        info "Starting server at http://localhost:8000"
        info "Press Ctrl+C to stop the server"
        python -m SimpleHTTPServer 8000
    else
        error_exit "Python not found. Please install Python to run the development server"
    fi
}

# Watch for file changes and validate
watch_files() {
    info "👀 Watching files for changes..."
    info "Press Ctrl+C to stop watching"
    
    if ! command -v fswatch &> /dev/null; then
        warning "fswatch not installed. Install with: brew install fswatch (macOS) or apt-get install inotify-tools (Linux)"
        error_exit "File watching requires fswatch or inotify-tools"
    fi
    
    fswatch -o "$PROJECT_ROOT/website" "$PROJECT_ROOT/terraform" | while read -r num; do
        echo ""
        info "Files changed, running validation..."
        simulate_ci_validation
    done
}

# Prepare for deployment
prepare_deployment() {
    local env="${1:-dev}"
    
    info "🎯 Preparing deployment for environment: $env"
    echo ""
    
    # Set environment
    info "Setting environment configuration..."
    ./scripts/manage-environment.sh set "$env"
    
    # Validate configuration
    info "Validating environment configuration..."
    ./scripts/manage-environment.sh validate "$env"
    
    # Run CI validation
    simulate_ci_validation
    
    # Create backup
    info "Creating configuration backup..."
    ./scripts/manage-environment.sh backup "$env"
    
    echo ""
    success "🎉 Ready for deployment to $env environment!"
    info "Next steps:"
    echo "  1. Review the configuration: ./scripts/manage-environment.sh show"
    echo "  2. Deploy infrastructure: ./scripts/deploy-infrastructure.sh plan"
    echo "  3. Deploy website: ./scripts/deploy-website.sh validate"
    echo "  4. Complete deployment: ./scripts/deploy-all.sh deploy $env"
}

# Clean up development artifacts
cleanup() {
    info "🧹 Cleaning up development artifacts..."
    
    # Remove temporary files
    find "$PROJECT_ROOT" -name "*.tmp" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.log" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name ".DS_Store" -delete 2>/dev/null || true
    
    # Clean Terraform artifacts
    if [ -d "$PROJECT_ROOT/terraform" ]; then
        cd "$PROJECT_ROOT/terraform"
        rm -f tfplan* plan-*.txt terraform.tfstate.backup
        cd "$PROJECT_ROOT"
    fi
    
    # Clean old backups (keep last 5)
    if [ -d "$PROJECT_ROOT/backups" ]; then
        find "$PROJECT_ROOT/backups" -type d -name "*" | sort -r | tail -n +6 | xargs rm -rf 2>/dev/null || true
    fi
    
    success "Cleanup completed"
}

# Show project status
show_status() {
    info "📊 Project Status"
    echo ""
    
    # Current environment
    if [ -f "$PROJECT_ROOT/.current_environment" ]; then
        local current_env
        current_env=$(cat "$PROJECT_ROOT/.current_environment")
        info "Current environment: $current_env"
    else
        warning "No environment set"
    fi
    
    # File counts
    local html_count css_count js_count
    html_count=$(find "$PROJECT_ROOT/website" -name "*.html" | wc -l)
    css_count=$(find "$PROJECT_ROOT/website" -name "*.css" | wc -l)
    js_count=$(find "$PROJECT_ROOT/website" -name "*.js" | wc -l)
    
    info "Website files: $html_count HTML, $css_count CSS, $js_count JS"
    
    # Git status
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local branch
        branch=$(git branch --show-current)
        info "Git branch: $branch"
        
        local status
        status=$(git status --porcelain | wc -l)
        if [ "$status" -eq 0 ]; then
            success "Working directory clean"
        else
            warning "$status uncommitted changes"
        fi
    fi
    
    # Deployment status
    if [ -f "$PROJECT_ROOT/terraform-outputs.json" ]; then
        success "Infrastructure deployed"
        if command -v jq &> /dev/null; then
            local website_url
            website_url=$(jq -r '.website_url.value' "$PROJECT_ROOT/terraform-outputs.json" 2>/dev/null || echo "unknown")
            info "Website URL: $website_url"
        fi
    else
        warning "Infrastructure not deployed"
    fi
}

# Main function
main() {
    local command="${1:-help}"
    
    cd "$PROJECT_ROOT"
    
    case "$command" in
        "validate")
            simulate_ci_validation
            ;;
        "serve")
            run_dev_server
            ;;
        "watch")
            watch_files
            ;;
        "prepare")
            local env="${2:-dev}"
            prepare_deployment "$env"
            ;;
        "cleanup")
            cleanup
            ;;
        "status")
            show_status
            ;;
        "help"|*)
            echo "Development Workflow Script"
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  validate           - Run CI/CD validation locally"
            echo "  serve              - Start local development server"
            echo "  watch              - Watch files and validate on changes"
            echo "  prepare [env]      - Prepare for deployment (default: dev)"
            echo "  cleanup            - Clean up development artifacts"
            echo "  status             - Show project status"
            echo "  help               - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 validate        - Validate all files locally"
            echo "  $0 serve           - Start development server"
            echo "  $0 prepare prod    - Prepare for production deployment"
            echo "  $0 watch           - Watch and validate on file changes"
            ;;
    esac
}

# Run main function with all arguments
main "$@"