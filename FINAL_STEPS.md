# Final Steps to Fix Deployment

## ⚠️ IMPORTANT - Production Resources Protected
**Route53 Zone `Z0756127155MZ0VTLU0BJ` is protected**
- Terraform has `prevent_destroy = true` on this zone
- Terraform will **never** delete this zone, even with `terraform destroy`
- Your production DNS is safe!

## Quick Fix (One Command)

Run this script to do everything automatically:
```bash
./scripts/complete-fix.sh
```

This will:
1. Fix Terraform state
2. Show duplicate zones to delete
3. Import production resources
4. Verify everything works

## OR: Step-by-Step Fix (Run Locally)

### Step 1: Fix Terraform State
Remove old state entries that are causing conflicts:
```bash
./scripts/fix-terraform-state.sh
```

**This removes entries like `aws_route53_zone.main[0]` that are blocking deployment.**

### Step 2: Delete ONLY Duplicate Zones
Run the cleanup script to see which zones exist:
```bash
./scripts/cleanup-duplicate-zones.sh
```

**Delete these zones ONLY:**
- Other `noveycloud.com` zone (NOT Z0756127155MZ0VTLU0BJ)
- ALL `staging.noveycloud.com` zones

Example:
```bash
# Delete the OTHER noveycloud.com zone (if it exists)
aws route53 delete-hosted-zone --id Z0664040NOJ9Q22FJCWK

# Delete ALL staging zones
aws route53 delete-hosted-zone --id Z06436973NWN6FRZS2UB0
aws route53 delete-hosted-zone --id Z04350723AFBQZ97KZBQD
aws route53 delete-hosted-zone --id Z04420341Q2KMLF9YZQOL
```

### Step 3: Import Production Resources
The import script is configured to use the correct production zone:
```bash
./scripts/import-existing-resources.sh
```

This will import zone `Z0756127155MZ0VTLU0BJ` and all other production resources.

### Step 4: Verify
```bash
cd terraform
terraform plan
```

Should show minimal or no changes.

### Step 5: Commit and Deploy
```bash
git add terraform/terraform.tfstate
git commit -m "chore: import production resources"
git push
```

## Zone Reference

### ✅ KEEP (Production)
- **Z0756127155MZ0VTLU0BJ** - noveycloud.com (PRODUCTION)

### ❌ DELETE (Duplicates)
- Z0664040NOJ9Q22FJCWK - noveycloud.com (duplicate)
- Z06436973NWN6FRZS2UB0 - staging.noveycloud.com
- Z04350723AFBQZ97KZBQD - staging.noveycloud.com
- Z04420341Q2KMLF9YZQOL - staging.noveycloud.com

## Quick Commands

```bash
# 1. Fix state
./scripts/fix-terraform-state.sh

# 2. Check zones
./scripts/cleanup-duplicate-zones.sh

# 3. Delete duplicates (NOT Z0756127155MZ0VTLU0BJ!)
aws route53 delete-hosted-zone --id Z0664040NOJ9Q22FJCWK
aws route53 delete-hosted-zone --id Z06436973NWN6FRZS2UB0
aws route53 delete-hosted-zone --id Z04350723AFBQZ97KZBQD
aws route53 delete-hosted-zone --id Z04420341Q2KMLF9YZQOL

# 4. Import resources
./scripts/import-existing-resources.sh

# 5. Verify
cd terraform && terraform plan

# 6. Commit
git add terraform/terraform.tfstate
git commit -m "chore: import production resources"
git push
```

## After This

Your CI/CD pipeline will work! The deployment will:
1. ✅ Validate configuration
2. ✅ Deploy to production
3. ✅ Run tests
4. ✅ Create deployment tag

🚀 Ready to deploy!
