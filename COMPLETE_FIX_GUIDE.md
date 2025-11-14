# Complete Fix Guide - Step by Step

## Current Issues
1. ✅ Terraform configuration fixed
2. ⚠️ Duplicate Route53 zones exist
3. ⚠️ Old Terraform state with count-based resources
4. ⚠️ Resources exist in AWS but not in state

## Complete Fix Process

### Step 1: Fix Terraform State
Remove old state entries that use count:
```bash
./scripts/fix-terraform-state.sh
```

This removes entries like `aws_route53_zone.main[0]` that are causing conflicts.

### Step 2: Clean Up Duplicate Zones
Identify and delete duplicate Route53 zones:
```bash
./scripts/cleanup-duplicate-zones.sh
```

**Action Required:**
- Keep ONE `noveycloud.com` zone (the one with the most DNS records)
- Delete ALL `staging.noveycloud.com` zones

Example commands (use actual zone IDs from script output):
```bash
# Delete duplicate noveycloud.com zone
aws route53 delete-hosted-zone --id Z0664040NOJ9Q22FJCWK

# Delete all staging zones
aws route53 delete-hosted-zone --id Z06436973NWN6FRZS2UB0
aws route53 delete-hosted-zone --id Z04350723AFBQZ97KZBQD
aws route53 delete-hosted-zone --id Z04420341Q2KMLF9YZQOL
```

### Step 3: Import Existing Resources
Import production resources into Terraform state:
```bash
./scripts/import-existing-resources.sh
```

This imports:
- S3 bucket and configurations
- CloudFront distribution, OAC, and function
- ACM certificate
- Route53 zone and records
- IAM resources

### Step 4: Verify Configuration
Check that everything is in sync:
```bash
cd terraform
terraform plan
```

**Expected output:**
- "No changes" or minimal changes
- No errors about resources already existing

### Step 5: Commit State
```bash
git add terraform/terraform.tfstate
git commit -m "chore: import production resources and fix state"
git push
```

### Step 6: Test CI/CD
Push changes and watch the deployment succeed!

## Quick Reference

### All Scripts
```bash
# 1. Fix state issues
./scripts/fix-terraform-state.sh

# 2. See duplicate zones
./scripts/cleanup-duplicate-zones.sh

# 3. Import resources
./scripts/import-existing-resources.sh

# 4. Clean up staging (optional)
./scripts/cleanup-staging.sh
```

### Verification Commands
```bash
# List all zones
aws route53 list-hosted-zones

# List state resources
cd terraform && terraform state list

# Check for differences
terraform plan

# See what would be imported
terraform import -dry-run aws_s3_bucket.resume_website noveycloud-resume-website
```

## Troubleshooting

### "Resource already exists"
- Run import script: `./scripts/import-existing-resources.sh`

### "Multiple zones matched"
- Delete duplicates: `./scripts/cleanup-duplicate-zones.sh`

### "Instance cannot be destroyed" with [0]
- Fix state: `./scripts/fix-terraform-state.sh`

### "Certificate validation timeout"
- Check DNS records are created in Route53
- Wait up to 30 minutes for validation
- Verify only one zone exists for the domain

## After Everything Works

### Enable Remote State (Recommended)
1. Create S3 bucket: `terraform-state-noveycloud`
2. Create DynamoDB table: `terraform-state-lock`
3. Add backend config to `terraform/main.tf`
4. Run `terraform init -migrate-state`

### Re-enable Staging (Optional)
1. Clean up staging resources
2. Uncomment staging job in `.github/workflows/deploy.yml`
3. Use subdomain approach instead of separate zones

## Summary

**Run these 3 commands:**
```bash
./scripts/fix-terraform-state.sh
./scripts/cleanup-duplicate-zones.sh  # Then manually delete duplicates
./scripts/import-existing-resources.sh
```

Then commit, push, and deploy! 🚀
