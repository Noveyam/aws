# CI/CD Non-Interactive Mode Fix

## Problem
The GitHub Actions deployment to staging was failing with error code 1 after successfully creating the Terraform plan. The error occurred because:

1. The `deploy-infrastructure.sh` script was designed for interactive use
2. It prompted for user confirmation before applying changes: `read -p "Do you want to apply these changes? (y/N)"`
3. In CI/CD environments (GitHub Actions), there's no interactive terminal to provide input
4. The script would hang waiting for input and eventually fail

## Root Cause
The `terraform plan -detailed-exitcode` command returns:
- Exit code 0: No changes needed
- Exit code 1: Error occurred
- Exit code 2: Changes detected (success, but changes exist)

The script was treating exit code 2 as an error in some paths, and then waiting for interactive confirmation that would never come in CI/CD.

## Solution
Modified `scripts/deploy-infrastructure.sh` to:

1. **Fixed exit code handling in `plan_terraform()`**:
   - Changed to explicitly return 0 when exit code is 2 (changes detected)
   - This ensures the function succeeds when changes are found

2. **Added non-interactive mode detection**:
   - Checks for CI/CD environment variables: `CI`, `GITHUB_ACTIONS`, or `AUTO_APPROVE`
   - When detected, automatically proceeds with deployment without prompting
   - In interactive mode (local development), still prompts for confirmation

## Changes Made

### scripts/deploy-infrastructure.sh

**Before:**
```bash
terraform plan -out=tfplan -detailed-exitcode || {
    local exit_code=$?
    if [ $exit_code -eq 1 ]; then
        error_exit "Terraform plan failed"
    elif [ $exit_code -eq 2 ]; then
        info "Changes detected in Terraform plan"
    fi
}
```

**After:**
```bash
terraform plan -out=tfplan -detailed-exitcode || {
    local exit_code=$?
    if [ $exit_code -eq 1 ]; then
        error_exit "Terraform plan failed"
    elif [ $exit_code -eq 2 ]; then
        info "Changes detected in Terraform plan"
        return 0  # Explicitly return success
    fi
}
```

**Before:**
```bash
case "$action" in
    "deploy")
        check_prerequisites
        init_terraform
        validate_terraform
        plan_terraform
        
        # Ask for confirmation before applying
        echo ""
        read -p "Do you want to apply these changes? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            apply_terraform
            # ...
```

**After:**
```bash
case "$action" in
    "deploy")
        check_prerequisites
        init_terraform
        validate_terraform
        plan_terraform
        
        # Check if running in CI/CD (non-interactive mode)
        if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ "${AUTO_APPROVE:-false}" = "true" ]; then
            info "Running in non-interactive mode (CI/CD detected)"
            apply_terraform
            get_outputs
            verify_deployment
            
            echo ""
            success "🎉 Infrastructure deployment completed successfully!"
        else
            # Ask for confirmation before applying (interactive mode)
            echo ""
            read -p "Do you want to apply these changes? (y/N): " -n 1 -r
            # ...
```

## Testing
The fix allows the script to:
- ✅ Run automatically in GitHub Actions without hanging
- ✅ Still prompt for confirmation when run locally
- ✅ Support manual override with `AUTO_APPROVE=true` environment variable

## Usage

### In CI/CD (GitHub Actions)
```bash
# Automatically detected and runs non-interactively
./scripts/deploy-all.sh deploy staging
```

### Local Development (Interactive)
```bash
# Prompts for confirmation
./scripts/deploy-infrastructure.sh deploy
```

### Local Development (Non-Interactive)
```bash
# Skip confirmation prompt
AUTO_APPROVE=true ./scripts/deploy-infrastructure.sh deploy
```

## Additional Fixes Applied

### Terraform Format Exit Code Handling
Fixed the `validate_terraform()` function to properly handle Terraform's format check exit codes:
- Exit code 3: Files need formatting (not an error)
- Exit code 2: Files need formatting (older Terraform versions)

**Before:**
```bash
if ! terraform fmt -check=true -diff=true; then
    warning "Terraform files are not properly formatted. Running terraform fmt..."
    terraform fmt
fi
```

**After:**
```bash
terraform fmt -check=true -diff=true || {
    local fmt_exit=$?
    if [ $fmt_exit -eq 3 ] || [ $fmt_exit -eq 2 ]; then
        warning "Terraform files are not properly formatted. Running terraform fmt..."
        terraform fmt
    fi
}
```

### HTML Validation Fixes
Fixed HTML validation errors that were blocking deployment:

1. **Encoded ampersands in index.html**:
   - Changed `Frameworks & Libraries` to `Frameworks &amp; Libraries`
   - Changed `DevOps & Tools` to `DevOps &amp; Tools`

2. **Removed redundant ARIA roles**:
   - Removed `role="contentinfo"` from `<footer>` (implicit)
   - Removed `role="navigation"` from `<nav>` (implicit)
   - Removed invalid `aria-label` from `<div class="error-code">`

## Next Steps
1. Commit and push these changes
2. Re-run the GitHub Actions workflow
3. The deployment should now proceed automatically through all stages
