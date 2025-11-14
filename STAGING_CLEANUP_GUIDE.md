# Staging Environment Cleanup Guide

## Problem
Staging resources were partially created but not tracked in Terraform state, causing conflicts.

## Resources That Need Cleanup

### 1. S3 Bucket
```bash
aws s3 rb s3://noveycloud-resume-website-staging --force
```

### 2. CloudFront Origin Access Control
```bash
# List OACs
aws cloudfront list-origin-access-controls

# Delete specific OAC (get ID from list)
aws cloudfront delete-origin-access-control --id <OAC_ID> --if-match <ETAG>
```

### 3. CloudFront Function
```bash
# Get function details
aws cloudfront describe-function --name noveycloud-resume-website-staging-security-headers

# Delete function
aws cloudfront delete-function --name noveycloud-resume-website-staging-security-headers --if-match <ETAG>
```

### 4. IAM User
```bash
# Delete access keys first
aws iam list-access-keys --user-name noveycloud-resume-website-staging-deployer
aws iam delete-access-key --user-name noveycloud-resume-website-staging-deployer --access-key-id <KEY_ID>

# Delete user
aws iam delete-user --user-name noveycloud-resume-website-staging-deployer
```

### 5. ACM Certificate
```bash
# List certificates
aws acm list-certificates --region us-east-1

# Delete certificate
aws acm delete-certificate --certificate-arn arn:aws:acm:us-east-1:766158721264:certificate/3f07fea4-9e4a-41cf-8478-c0abd1a74331 --region us-east-1
```

### 6. Route53 Hosted Zone (if created)
```bash
# List hosted zones
aws route53 list-hosted-zones

# Delete records first, then zone
aws route53 delete-hosted-zone --id <ZONE_ID>
```

## Alternative: Skip Staging

For now, you can focus on production deployment since those resources already exist and work.

Update GitHub Actions workflow to only deploy to prod:
- Comment out or remove the `deploy-staging` job
- Only run `deploy-production` job

## Better Approach: Use Subdomain

Instead of creating a separate hosted zone for staging, use a subdomain record in the main zone:
- Change staging domain from `staging.noveycloud.com` to use the main `noveycloud.com` zone
- Create A/AAAA records for `staging.noveycloud.com` pointing to CloudFront
- This avoids the complexity of managing multiple hosted zones
