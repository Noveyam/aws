#!/bin/bash

# =============================================================================
# Environment Management Script
# Manages different deployment environments and configurations
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/config"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
CONFIG_FILE="$CONFIG_DIR/deployment.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
error_exit() { echo -e "${RED}ERROR: $1${NC}"; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Check prerequisites
check_prerequisites() {
    if ! command -v jq &> /dev/null; then
        error_exit "jq is required for configuration management. Please install jq"
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error_exit "Configuration file not found: $CONFIG_FILE"
    fi
}

# List available environments
list_environments() {
    info "Available environments:"
    jq -r '.environments | keys[]' "$CONFIG_FILE" | while read -r env; do
        local domain
        domain=$(jq -r ".environments.$env.domain_name" "$CONFIG_FILE")
        echo "  - $env ($domain)"
    done
}

# Set environment configuration
set_environment() {
    local env="$1"
    
    if ! jq -e ".environments.$env" "$CONFIG_FILE" >/dev/null; then
        error_exit "Environment '$env' not found in configuration"
    fi
    
    info "Setting up environment: $env"
    
    # Extract environment configuration
    local config
    config=$(jq ".environments.$env" "$CONFIG_FILE")
    
    # Create terraform.tfvars for the environment
    local tfvars_file="$TERRAFORM_DIR/terraform.tfvars"
    
    cat > "$tfvars_file" << EOF
# Generated configuration for environment: $env
# Generated at: $(date)

domain_name = $(echo "$config" | jq -r '.domain_name')
bucket_name = $(echo "$config" | jq -r '.bucket_name')
aws_region = $(echo "$config" | jq -r '.aws_region')
environment = $(echo "$config" | jq -r '.environment')
create_deployment_user = $(echo "$config" | jq -r '.create_deployment_user')
enable_health_check = $(echo "$config" | jq -r '.enable_health_check')

tags = $(echo "$config" | jq '.tags')
EOF
    
    success "Environment configuration set for: $env"
    info "Terraform variables updated: $tfvars_file"
    
    # Save current environment
    echo "$env" > "$PROJECT_ROOT/.current_environment"
}

# Get current environment
get_current_environment() {
    if [ -f "$PROJECT_ROOT/.current_environment" ]; then
        cat "$PROJECT_ROOT/.current_environment"
    else
        echo "none"
    fi
}

# Show environment configuration
show_environment() {
    local env="${1:-$(get_current_environment)}"
    
    if [ "$env" = "none" ]; then
        warning "No environment is currently set"
        list_environments
        return 1
    fi
    
    if ! jq -e ".environments.$env" "$CONFIG_FILE" >/dev/null; then
        error_exit "Environment '$env' not found in configuration"
    fi
    
    info "Configuration for environment: $env"
    echo ""
    jq ".environments.$env" "$CONFIG_FILE"
}

# Validate environment configuration
validate_environment() {
    local env="${1:-$(get_current_environment)}"
    
    if [ "$env" = "none" ]; then
        error_exit "No environment is currently set"
    fi
    
    info "Validating environment configuration: $env"
    
    local config
    config=$(jq ".environments.$env" "$CONFIG_FILE")
    
    # Check required fields
    local required_fields=("domain_name" "bucket_name" "aws_region" "environment")
    local validation_errors=0
    
    for field in "${required_fields[@]}"; do
        local value
        value=$(echo "$config" | jq -r ".$field")
        if [ "$value" = "null" ] || [ -z "$value" ]; then
            warning "Missing required field: $field"
            ((validation_errors++))
        fi
    done
    
    # Validate domain name format
    local domain_name
    domain_name=$(echo "$config" | jq -r '.domain_name')
    if [[ ! "$domain_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
        warning "Invalid domain name format: $domain_name"
        ((validation_errors++))
    fi
    
    # Validate bucket name format
    local bucket_name
    bucket_name=$(echo "$config" | jq -r '.bucket_name')
    if [[ ! "$bucket_name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
        warning "Invalid S3 bucket name format: $bucket_name"
        ((validation_errors++))
    fi
    
    if [ $validation_errors -eq 0 ]; then
        success "Environment configuration is valid"
    else
        error_exit "Environment configuration has $validation_errors errors"
    fi
}

# Create backup configuration
create_backup_config() {
    local env="${1:-$(get_current_environment)}"
    
    if [ "$env" = "none" ]; then
        error_exit "No environment is currently set"
    fi
    
    local backup_file="$CONFIG_DIR/backup-$env-$(date +%Y%m%d_%H%M%S).json"
    
    # Get current Terraform state and outputs
    if [ -d "$TERRAFORM_DIR" ]; then
        cd "$TERRAFORM_DIR"
        
        local backup_data="{}"
        
        # Add environment config
        backup_data=$(echo "$backup_data" | jq --argjson env_config "$(jq ".environments.$env" "$CONFIG_FILE")" '.environment_config = $env_config')
        
        # Add Terraform outputs if available
        if terraform output -json >/dev/null 2>&1; then
            backup_data=$(echo "$backup_data" | jq --argjson tf_outputs "$(terraform output -json)" '.terraform_outputs = $tf_outputs')
        fi
        
        # Add metadata
        backup_data=$(echo "$backup_data" | jq --arg env "$env" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.metadata = {environment: $env, created_at: $date}')
        
        echo "$backup_data" | jq '.' > "$backup_file"
        success "Backup configuration created: $backup_file"
    else
        warning "Terraform directory not found. Creating basic backup..."
        jq --arg env "$env" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{environment_config: .environments[$env], metadata: {environment: $env, created_at: $date}}' "$CONFIG_FILE" > "$backup_file"
        success "Basic backup configuration created: $backup_file"
    fi
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        error_exit "Backup file not found: $backup_file"
    fi
    
    info "Restoring from backup: $backup_file"
    
    # Extract environment from backup
    local env
    env=$(jq -r '.metadata.environment' "$backup_file")
    
    if [ "$env" = "null" ]; then
        error_exit "Invalid backup file: missing environment metadata"
    fi
    
    # Restore environment configuration
    local env_config
    env_config=$(jq '.environment_config' "$backup_file")
    
    # Update main configuration file
    local updated_config
    updated_config=$(jq --argjson env_config "$env_config" --arg env "$env" '.environments[$env] = $env_config' "$CONFIG_FILE")
    echo "$updated_config" > "$CONFIG_FILE"
    
    # Set as current environment
    set_environment "$env"
    
    success "Configuration restored from backup for environment: $env"
}

# Clean old backups
clean_backups() {
    local retention_days
    retention_days=$(jq -r '.deployment_settings.backup_retention_days // 30' "$CONFIG_FILE")
    
    info "Cleaning backups older than $retention_days days..."
    
    find "$CONFIG_DIR" -name "backup-*.json" -type f -mtime +$retention_days -delete 2>/dev/null || true
    
    success "Old backups cleaned"
}

# Main function
main() {
    local command="${1:-help}"
    
    check_prerequisites
    
    case "$command" in
        "list")
            list_environments
            ;;
        "set")
            local env="${2:-}"
            if [ -z "$env" ]; then
                error_exit "Environment name required. Usage: $0 set <environment>"
            fi
            set_environment "$env"
            ;;
        "current")
            local current_env
            current_env=$(get_current_environment)
            if [ "$current_env" = "none" ]; then
                warning "No environment is currently set"
            else
                info "Current environment: $current_env"
            fi
            ;;
        "show")
            show_environment "${2:-}"
            ;;
        "validate")
            validate_environment "${2:-}"
            ;;
        "backup")
            create_backup_config "${2:-}"
            ;;
        "restore")
            local backup_file="${2:-}"
            if [ -z "$backup_file" ]; then
                error_exit "Backup file required. Usage: $0 restore <backup_file>"
            fi
            restore_backup "$backup_file"
            ;;
        "clean")
            clean_backups
            ;;
        "help"|*)
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  list                    - List available environments"
            echo "  set <env>              - Set current environment"
            echo "  current                - Show current environment"
            echo "  show [env]             - Show environment configuration"
            echo "  validate [env]         - Validate environment configuration"
            echo "  backup [env]           - Create backup of environment configuration"
            echo "  restore <backup_file>  - Restore from backup file"
            echo "  clean                  - Clean old backup files"
            echo "  help                   - Show this help message"
            ;;
    esac
}

# Run main function with all arguments
main "$@"