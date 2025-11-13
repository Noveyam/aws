# Deployment Fix - Terraform Init Order

## 🐛 **Problem**
GitHub Actions deployment was failing with:
```
Error: Missing required provider
This configuration requires provider registry.terraform.io/hashicorp/aws,
but that provider isn't available. You may be able to install it
automatically by running: terraform init
```

## 🔧 **Root Cause**
The deployment script was running commands in the wrong order:
1. ❌ **validate_terraform** (requires providers)
2. ❌ **init_terraform** (downloads providers)
3. ✅ plan_terraform
4. ✅ apply_terraform

**Terraform needs to be initialized BEFORE validation!**

## ✅ **Solution**

### **Fixed Order:**
1. ✅ **init_terraform** (downloads providers first)
2. ✅ **validate_terraform** (now providers are available)
3. ✅ plan_terraform
4. ✅ apply_terraform

### **Changes Made:**

#### **1. Fixed `scripts/deploy-infrastructure.sh`**
Changed the order of operations in both `deploy` and `plan` actions:
```bash
# Before (WRONG):
check_prerequisites
validate_terraform  # ❌ Fails - no providers
init_terraform
plan_terraform

# After (CORRECT):
check_prerequisites
init_terraform      # ✅ Downloads providers first
validate_terraform  # ✅ Now works
plan_terraform
```

#### **2. Enhanced `.github/workflows/deploy.yml`**
Added missing dependencies and fixed script permissions:
```yaml
- name: Install dependencies
  run: |
    sudo apt-get update
    sudo apt-get install -y jq bc

- name: Deploy to staging
  run: |
    chmod +x scripts/*.sh  # Make all scripts executable
    ./scripts/deploy-all.sh deploy staging
```

## 🚀 **How to Apply the Fix**

### **Commit and Push:**
```bash
git add scripts/deploy-infrastructure.sh
git add .github/workflows/deploy.yml
git commit -m "Fix: Terraform init before validate in deployment"
git push
```

### **Test the Fix:**
1. Push to `main` branch (triggers staging deployment)
2. Go to **Actions** tab on GitHub
3. Watch the workflow run - it should now succeed! ✅

## ✅ **Expected Result**

The deployment should now work with this flow:
```
✓ Checkout code
✓ Setup Terraform
✓ Configure AWS credentials
✓ Install dependencies (jq, bc)
✓ Deploy to staging
  ✓ Check prerequisites
  ✓ Initialize Terraform (downloads AWS provider)
  ✓ Validate Terraform configuration
  ✓ Create Terraform plan
  ✓ Apply Terraform changes
  ✓ Deploy website content
✓ Run staging tests
✓ Deployment successful! 🎉
```

## 🔍 **Verification**

After pushing, check that:
1. ✅ GitHub Actions workflow completes successfully
2. ✅ No "Missing required provider" errors
3. ✅ Terraform initializes before validation
4. ✅ Website deploys successfully

## 📝 **Additional Improvements**

The fix also includes:
- ✅ Installing `jq` and `bc` dependencies
- ✅ Making all scripts executable with `chmod +x scripts/*.sh`
- ✅ Consistent dependency installation across all deployment jobs
- ✅ Better error handling and logging

## 🎯 **Next Steps**

1. **Commit the changes** (see above)
2. **Push to main branch**
3. **Monitor the GitHub Actions run**
4. **Verify deployment succeeds**

Your staging deployment should now work perfectly! 🚀
