# Duplicate Route53 Zones Fix

## Problem
Multiple Route53 hosted zones exist for the same domains, causing Terraform to fail with:
```
Error: multiple Route 53 Hosted Zones matched
```

## Current State
- **2 zones** for `noveycloud.com`
- **3 zones** for `staging.noveycloud.com`

## Solution

### Step 1: Identify Which Zone to Keep
Run the cleanup script to see which zones have records:
```bash
./scripts/cleanup-duplicate-zones.sh
```

This will show you which zone has the most DNS records (that's your active one).

### Step 2: Delete Duplicate Zones

**Important**: Zones with DNS records must have records deleted first!

#### For noveycloud.com
Keep the zone with the most records, delete the others:
```bash
# First, delete all records from the duplicate zone
./scripts/delete-zone-records.sh Z0664040NOJ9Q22FJCWK

# Then delete the empty zone
aws route53 delete-hosted-zone --id Z0664040NOJ9Q22FJCWK
```

#### For staging.noveycloud.com
Delete ALL staging zones (we don't use separate zones for staging):
```bash
# For each staging zone, delete records first, then the zone
./scripts/delete-zone-records.sh Z06436973NWN6FRZS2UB0
aws route53 delete-hosted-zone --id Z06436973NWN6FRZS2UB0

./scripts/delete-zone-records.sh Z04350723AFBQZ97KZBQD
aws route53 delete-hosted-zone --id Z04350723AFBQZ97KZBQD

./scripts/delete-zone-records.sh Z04420341Q2KMLF9YZQOL
aws route53 delete-hosted-zone --id Z04420341Q2KMLF9YZQOL
```

**Note**: The script will show you what records will be deleted and ask for confirmation.

### Step 3: Import the Correct Zone
After cleanup, import the remaining production zone:
```bash
./scripts/import-existing-resources.sh
```

## Terraform Changes Applied

1. **Removed data source** - No longer using `data.aws_route53_zone.main`
2. **Simplified resource** - Single `aws_route53_zone.main` resource
3. **Added prevent_destroy** - Protects zone from accidental deletion

## Why This Happened

Multiple zones were likely created during:
- Failed deployment attempts
- Manual testing
- Different Terraform runs without proper state management

## Prevention

To avoid this in the future:
1. **Use remote state** (S3 + DynamoDB)
2. **Import before creating** - Always check if resources exist first
3. **Clean up failed deployments** - Don't leave partial resources
4. **Use Terraform workspaces** - For multiple environments

## Quick Commands

```bash
# 1. See all zones
aws route53 list-hosted-zones

# 2. See records in a zone
aws route53 list-resource-record-sets --hosted-zone-id Z0756127155MZ0VTLU0BJ

# 3. Delete a zone (must delete all records except NS and SOA first)
aws route53 delete-hosted-zone --id ZONE_ID
```

## After Cleanup

Once you've deleted the duplicate zones:
1. Run `./scripts/import-existing-resources.sh`
2. Run `terraform plan` to verify
3. Commit the state file
4. Push and let CI/CD deploy
