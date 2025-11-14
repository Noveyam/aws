# Import Existing Resources - Instructions

## Problem
Production resources already exist in AWS but aren't in Terraform state, causing "AlreadyExists" errors.

## Solution
Run the import script locally to add existing resources to Terraform state.

## Steps

### 1. Run the Import Script Locally
```bash
cd /path/to/your/project
./scripts/import-existing-resources.sh
```

This will import all existing production resources into your local Terraform state.

### 2. Verify the Import
```bash
cd terraform
terraform plan
```

You should see either:
- "No changes" - Perfect! Resources are in sync
- Minor changes - Review and apply if needed

### 3. Commit the State File (If Using Local State)
```bash
git add terraform/terraform.tfstate
git commit -m "chore: import existing production resources into terraform state"
git push
```

**⚠️ WARNING**: Only commit state files if you're using local state and understand the security implications. State files can contain sensitive data.

## Alternative: Use Remote State

For production deployments, it's better to use remote state (S3 + DynamoDB):

### Setup Remote State Backend
1. Create an S3 bucket for state: `terraform-state-noveycloud`
2. Create a DynamoDB table for locking: `terraform-state-lock`
3. Update `terraform/main.tf` to add backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-noveycloud"
    key            = "resume-website/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

4. Run `terraform init -migrate-state` to move local state to S3
5. Never commit `terraform.tfstate` files again

## Quick Fix for CI/CD

If you can't run the import locally right now, temporarily modify the workflow to skip the apply:

1. Comment out the apply step in `.github/workflows/deploy.yml`
2. Run plan-only to see what would change
3. Import resources locally
4. Re-enable apply

## Resources to Import

The script imports:
- S3 Bucket and all configurations
- CloudFront Distribution, OAC, and Function
- ACM Certificate
- Route53 Hosted Zone and Records
- IAM resources (if any)
