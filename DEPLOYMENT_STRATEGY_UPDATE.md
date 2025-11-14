# Deployment Strategy Update

## Changes Applied

### 1. Disabled Staging Deployment in CI/CD
**File**: `.github/workflows/deploy.yml`

- Commented out the entire `deploy-staging` job
- Removed `deploy-staging` from production job dependencies
- Production now deploys directly after validation

**Reason**: Staging environment has conflicting resources that need manual cleanup.

### 2. Created Staging Cleanup Script
**File**: `scripts/cleanup-staging.sh`

A script to remove all partially created staging resources:
- S3 bucket
- CloudFront Origin Access Control
- CloudFront Function
- IAM User and access keys
- ACM Certificate

**Usage**:
```bash
./scripts/cleanup-staging.sh
```

### 3. Current Deployment Flow

```
Push to main branch
  ↓
Validate (HTML, Terraform)
  ↓
Deploy to Production
  ↓
Run Production Tests
  ↓
Create Deployment Tag
```

## Next Steps

### Option A: Clean Up and Re-enable Staging
1. Run the cleanup script: `./scripts/cleanup-staging.sh`
2. Uncomment the staging job in `.github/workflows/deploy.yml`
3. Push changes to trigger deployment

### Option B: Keep Production-Only
- Continue with production-only deployments
- Use feature branches for testing
- Deploy directly to production from main branch

### Option C: Redesign Staging
- Use subdomain approach instead of separate hosted zone
- Modify Terraform to create `staging.noveycloud.com` as A/AAAA records in main zone
- Avoid Route53 hosted zone conflicts

## Production Deployment

Production infrastructure already exists and should deploy successfully:
- Domain: `noveycloud.com`
- S3 Bucket: `noveycloud-resume-website`
- All resources properly configured

## Recommendations

1. **Short term**: Use production-only deployment (current setup)
2. **Medium term**: Clean up staging and re-enable with proper configuration
3. **Long term**: Consider using Terraform workspaces or separate state files per environment

## Files Modified
- `.github/workflows/deploy.yml` - Disabled staging deployment
- `scripts/cleanup-staging.sh` - New cleanup script
- `STAGING_CLEANUP_GUIDE.md` - Manual cleanup instructions
