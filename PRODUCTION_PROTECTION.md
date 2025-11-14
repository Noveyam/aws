# Production Resources Protection

## Protected Resources

The following production resources have `lifecycle { prevent_destroy = true }` and **cannot be deleted** by Terraform:

### 1. Route53 Hosted Zone
- **Zone ID**: Z0756127155MZ0VTLU0BJ
- **Domain**: noveycloud.com
- **Protection**: ✅ Enabled
- **Why**: Contains all your DNS records - critical for website availability

### 2. S3 Bucket
- **Bucket**: noveycloud-resume-website
- **Protection**: ✅ Enabled
- **Why**: Contains your website files and has versioning enabled

## What This Means

### ✅ Safe Operations
These operations will work normally:
- `terraform plan` - Shows what would change
- `terraform apply` - Updates resources
- Updating tags, configurations, settings
- Adding new resources
- Modifying existing resources

### ❌ Blocked Operations
These operations will be **blocked** by Terraform:
- `terraform destroy` - Will fail if it tries to destroy protected resources
- Deleting the Route53 zone
- Deleting the S3 bucket
- Any operation that would destroy these resources

## Error You Might See

If Terraform tries to destroy a protected resource, you'll see:
```
Error: Instance cannot be destroyed

Resource aws_route53_zone.main has lifecycle.prevent_destroy set, 
but the plan calls for this resource to be destroyed.
```

This is **intentional** and **protects your production infrastructure**.

## How to Override (Emergency Only)

If you **really** need to delete these resources:

1. **Remove the lifecycle block** from `terraform/main.tf`:
```hcl
resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = var.tags
  
  # lifecycle {
  #   prevent_destroy = true
  # }
}
```

2. **Run terraform apply**
3. **Then you can destroy** the resource

⚠️ **WARNING**: Only do this if you're absolutely sure! Deleting the Route53 zone will break your website's DNS.

## Best Practices

1. **Never remove `prevent_destroy`** from production resources
2. **Always test in dev/staging** before applying to production
3. **Use `terraform plan`** before every apply
4. **Keep backups** of your Terraform state
5. **Use remote state** (S3 + DynamoDB) for production

## Current Configuration

```hcl
# Route53 Zone - Protected
resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = var.tags

  lifecycle {
    prevent_destroy = true  # ✅ Cannot be deleted
  }
}

# S3 Bucket - Protected
resource "aws_s3_bucket" "resume_website" {
  bucket = var.bucket_name
  tags   = var.tags

  lifecycle {
    prevent_destroy = true  # ✅ Cannot be deleted
  }
}
```

## Summary

Your production infrastructure is protected! Terraform will:
- ✅ Allow updates and modifications
- ✅ Allow adding new resources
- ❌ Block deletion of Route53 zone Z0756127155MZ0VTLU0BJ
- ❌ Block deletion of S3 bucket noveycloud-resume-website

This ensures your website stays online even if someone accidentally runs `terraform destroy`.
