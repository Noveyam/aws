# Complete Cleanup and Deployment Guide

## Current Situation
- Multiple duplicate Route53 zones exist
- Resources exist in AWS but not in Terraform state
- Deployment fails with "AlreadyExists" and "multiple zones matched" errors

## Complete Solution (Step by Step)

### Step 1: Identify Duplicate Zones
```bash
./scripts/cleanup-duplicate-zones.sh
```

This shows you:
- Which zones exist
- How many records each has
- Which ones to keep vs delete

### Step 2: Delete Duplicate Zones

#### A. For staging.noveycloud.com (Delete ALL 3 zones)
```bash
# Zone 1
./scripts/delete-zone-records.sh Z06436973NWN6FRZS2UB0
aws route53 delete-hosted-zone --id Z06436973NWN6FRZS2UB0

# Zone 2
./scripts/delete-zone-records.sh Z04350723AFBQZ97KZBQD
aws route53 delete-hosted-zone --id Z04350723AFBQZ97KZBQD

# Zone 3
./scripts/delete-zone-records.sh Z04420341Q2KMLF9YZQOL
aws route53 delete-hosted-zone --id Z04420341Q2KMLF9YZQOL
```

#### B. For noveycloud.com (Keep 1, Delete 1)
First, check which zone has more records:
```bash
# Check zone 1
aws route53 list-resource-record-sets --hosted-zone-id Z0664040NOJ9Q22FJCWK --query 'length(ResourceRecordSets)'

# Check zone 2
aws route53 list-resource-record-sets --hosted-zone-id Z0756127155MZ0VTLU0BJ --query 'length(ResourceRecordSets)'
```

Keep the one with MORE records, delete the other:
```bash
# Example: If Z0664040NOJ9Q22FJCWK has fewer records, delete it
./scripts/delete-zone-records.sh Z0664040NOJ9Q22FJCWK
aws route53 delete-hosted-zone --id Z0664040NOJ9Q22FJCWK
```

### Step 3: Clean Up Staging Resources
```bash
./scripts/cleanup-staging.sh
```

This removes:
- S3 bucket: noveycloud-resume-website-staging
- CloudFront resources
- IAM users
- ACM certificates

### Step 4: Import Production Resources
```bash
./scripts/import-existing-resources.sh
```

This imports all existing production resources into Terraform state.

### Step 5: Verify Import
```bash
cd terraform
terraform plan
```

You should see either:
- "No changes" ✅ Perfect!
- Minor changes - Review them

### Step 6: Commit State File
```bash
git add terraform/terraform.tfstate
git commit -m "chore: import production resources and clean up duplicates"
git push
```

### Step 7: Deploy!
Push your code and watch CI/CD deploy successfully! 🎉

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `cleanup-duplicate-zones.sh` | Shows duplicate zones |
| `delete-zone-records.sh <zone-id>` | Deletes records from a zone |
| `cleanup-staging.sh` | Removes staging resources |
| `import-existing-resources.sh` | Imports production to Terraform |

## Troubleshooting

### "HostedZoneNotEmpty" Error
- Use `delete-zone-records.sh` first
- Then delete the zone

### "AlreadyExists" Error
- Run `import-existing-resources.sh`
- Commit the state file

### "Multiple zones matched" Error
- Delete duplicate zones
- Keep only one per domain

## After Cleanup

Your infrastructure will be:
- ✅ Single Route53 zone for noveycloud.com
- ✅ No staging zones (using subdomain approach instead)
- ✅ All resources in Terraform state
- ✅ CI/CD working properly

## Time Estimate
- Cleanup: 10-15 minutes
- Import: 2-3 minutes
- Verification: 2 minutes
- **Total: ~20 minutes**

## Need Help?
If you get stuck, check:
1. `DUPLICATE_ZONES_FIX.md` - Zone cleanup details
2. `IMPORT_INSTRUCTIONS.md` - Import process
3. `STAGING_CLEANUP_GUIDE.md` - Manual cleanup steps
