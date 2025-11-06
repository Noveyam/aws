#!/bin/bash

# =============================================================================
# Configuration Validation Script
# Validates deployment configuration and prerequisites
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

main() {
    info "Validating project configuration..."
    echo ""
    
    # Check directory structure
    info "Checking directory structure..."
    local required_dirs=("terraform" "website" "scripts" "config")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            success "$dir/ directory exists"
        else
            error_exit "$dir/ directory missing"
        fi
    done
    
    # Check required files
    info "Checking required files..."
    local required_files=(
        "terraform/main.tf"
        "terraform/variables.tf"
        "terraform/outputs.tf"
        "terraform/versions.tf"
        "website/index.html"
        "website/error.html"
        "website/css/styles.css"
        "website/js/main.js"
        "config/deployment.json"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            success "$file exists"
        else
            error_exit "$file missing"
        fi
    done
    
    # Check executable scripts
    info "Checking executable scripts..."
    local scripts=(
        "scripts/deploy-infrastructure.sh"
        "scripts/deploy-website.sh"
        "scripts/manage-environment.sh"
        "scripts/deploy-all.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -x "$PROJECT_ROOT/$script" ]; then
            success "$script is executable"
        else
            warning "$script is not executable (fixing...)"
            chmod +x "$PROJECT_ROOT/$script"
            success "$script made executable"
        fi
    done
    
    # Check tools
    info "Checking required tools..."
    local tools=("terraform" "aws" "jq" "curl")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            success "$tool is installed"
        else
            if [ "$tool" = "jq" ]; then
                warning "$tool is not installed (recommended for JSON parsing)"
            else
                error_exit "$tool is not installed"
            fi
        fi
    done
    
    # Check AWS credentials
    info "Checking AWS credentials..."
    if aws sts get-caller-identity &> /dev/null; then
        local account_id
        account_id=$(aws sts get-caller-identity --query Account --output text)
        success "AWS credentials configured (Account: $account_id)"
    else
        error_exit "AWS credentials not configured"
    fi
    
    # Validate configuration file
    if command -v jq &> /dev/null; then
        info "Validating configuration file..."
        if jq empty "$PROJECT_ROOT/config/deployment.json" 2>/dev/null; then
            success "deployment.json is valid JSON"
        else
            error_exit "deployment.json is invalid JSON"
        fi
        
        # Check required configuration sections
        local config_sections=("environments" "deployment_settings" "file_settings")
        for section in "${config_sections[@]}"; do
            if jq -e ".$section" "$PROJECT_ROOT/config/deployment.json" >/dev/null; then
                success "Configuration section '$section' exists"
            else
                error_exit "Configuration section '$section' missing"
            fi
        done
    fi
    
    echo ""
    success "🎉 All configuration checks passed!"
    info "Your project is ready for deployment"
}

main "$@"