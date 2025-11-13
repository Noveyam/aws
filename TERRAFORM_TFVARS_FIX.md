# Terraform tfvars Quote Fix

## 🐛 **Issue**
The `manage-environment.sh` script was generating `terraform.tfvars` without quotes around string values, causing Terraform to fail with:
```
Error: Variables not allowed
domain_name = staging.noveycloud.com
```

## ✅ **Fix Applied**

Updated `scripts/manage-environment.sh` to properly quote string values:

### **Before:**
```bash
domain_name = $(echo "$config" | jq -r '.domain_name')
bucket_name = $(echo "$config" | jq -r '.bucket_name')
```

### **After:**
```bash
domain_name = "$(echo "$config" | jq -r '.domain_name')"
bucket_name = "$(echo "$config" | jq -r '.bucket_name')"
```

## 🎯 **Result**

Now generates valid Terraform syntax:
```hcl
domain_name = "staging.noveycloud.com"
bucket_name = "noveycloud-resume-website-staging"
aws_region  = "us-east-1"
environment = "staging"
```

## 🚀 **Deploy**

```bash
git add scripts/manage-environment.sh
git commit -m "Fix terraform.tfvars generation to include quotes"
git push
```

This will fix the Terraform deployment errors in GitHub Actions! ✅
