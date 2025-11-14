# Immediate Fix - Run These Commands Now

## The Problem
Terraform state has old entries with `[0]` that are blocking deployment.

## The Solution
Run these commands **right now** in your terminal:

```bash
cd terraform

# Remove old state entries
terraform state rm 'aws_route53_zone.main[0]'
terraform state rm 'aws_route53_health_check.resume_website[0]'
terraform state rm 'aws_iam_user.resume_website_deployer[0]'
terraform state rm 'aws_iam_access_key.resume_website_deployer[0]'
terraform state rm 'aws_iam_user_policy_attachment.resume_website_deployment[0]'

# Import the correct zone (without [0])
terraform import aws_route53_zone.main Z0756127155MZ0VTLU0BJ

# Verify it works
terraform plan
```

## Expected Output
After running these commands, `terraform plan` should show:
- "Plan: 1 to add, 0 to change, 0 to destroy" or similar
- NO errors about "Instance cannot be destroyed"

## Then Commit
```bash
cd ..
git add terraform/terraform.tfstate
git commit -m "fix: remove old state entries and import production zone"
git push
```

## That's It!
Your next CI/CD run will succeed.

---

## Why This Works
- Removes old state entries that use count (`[0]`)
- Imports the production zone without count
- State now matches the current Terraform configuration
- No more conflicts!
