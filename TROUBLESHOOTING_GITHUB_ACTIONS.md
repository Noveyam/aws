# Troubleshooting GitHub Actions Deployment

## 🔍 Common Issues and Solutions

### **Issue 1: "Unable to locate credentials"**

**Symptoms:**
```
Error: Unable to locate credentials
```

**Solutions:**
1. ✅ **Check secrets are added correctly:**
   - Go to: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions`
   - Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` exist
   - Names must be EXACT (case-sensitive)

2. ✅ **Verify secret values:**
   - No extra spaces or newlines
   - Access key should start with `AKIA`
   - Secret key should be 40 characters

3. ✅ **Test locally:**
   ```bash
   aws sts get-caller-identity
   ```

---

### **Issue 2: "Permission denied" or "Access Denied"**

**Symptoms:**
```
Error: Access Denied
An error occurred (AccessDenied) when calling the...
```

**Solutions:**
1. ✅ **Check IAM permissions:**
   - Your IAM user needs permissions for: S3, CloudFront, Route53, ACM
   - Go to AWS Console → IAM → Users → Your User → Permissions

2. ✅ **Verify credentials are active:**
   - AWS Console → IAM → Users → Your User → Security credentials
   - Check access keys are "Active"

---

### **Issue 3: "Terraform state locked"**

**Symptoms:**
```
Error: Error acquiring the state lock
```

**Solutions:**
1. ✅ **Wait for other operations to complete**
2. ✅ **Force unlock (if stuck):**
   ```bash
   cd terraform
   terraform force-unlock LOCK_ID
   ```

---

### **Issue 4: "Script not found" or "Permission denied"**

**Symptoms:**
```
./scripts/deploy-all.sh: Permission denied
./scripts/deploy-all.sh: No such file or directory
```

**Solutions:**
1. ✅ **Make scripts executable:**
   ```bash
   chmod +x scripts/*.sh
   git add scripts/
   git commit -m "Make scripts executable"
   git push
   ```

2. ✅ **Check scripts exist:**
   ```bash
   ls -la scripts/
   ```

---

### **Issue 5: "Environment protection rules"**

**Symptoms:**
```
Waiting for approval...
Deployment blocked by environment protection rules
```

**Solutions:**
1. ✅ **Approve the deployment:**
   - Go to Actions tab → Click the workflow run
   - Click "Review deployments"
   - Select environment and click "Approve and deploy"

2. ✅ **Disable environment protection (for testing):**
   - Go to Settings → Environments → staging
   - Remove protection rules

---

### **Issue 6: "Infrastructure not deployed"**

**Symptoms:**
```
Error: No outputs found
Bucket does not exist
```

**Solutions:**
1. ✅ **Deploy infrastructure first:**
   ```bash
   ./scripts/deploy-infrastructure.sh deploy
   ```

2. ✅ **Check Terraform state:**
   ```bash
   cd terraform
   terraform show
   ```

---

## 🛠️ **Debugging Steps**

### **Step 1: Check GitHub Actions Logs**
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Click on the failed workflow run
4. Click on the failed job
5. Expand the failed step
6. Copy the error message

### **Step 2: Test Locally**
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test scripts
./scripts/validate-config.sh

# Test Terraform
cd terraform
terraform init
terraform plan
```

### **Step 3: Use Simple Workflow**
I've created a simplified workflow: `.github/workflows/deploy-simple.yml`

To use it:
```bash
git add .github/workflows/deploy-simple.yml
git commit -m "Add simple deployment workflow"
git push
```

Then manually trigger it:
1. Go to Actions tab
2. Click "Simple Deploy"
3. Click "Run workflow"
4. Click "Run workflow" button

---

## 📋 **Checklist Before Deployment**

- [ ] AWS credentials added to GitHub Secrets
- [ ] Infrastructure deployed locally first
- [ ] Scripts are executable (`chmod +x scripts/*.sh`)
- [ ] Pushing to correct branch (`main` for staging)
- [ ] No Terraform state locks
- [ ] IAM user has required permissions

---

## 🔧 **Quick Fixes**

### **Fix 1: Reset Everything**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Commit changes
git add .
git commit -m "Fix deployment issues"
git push
```

### **Fix 2: Test Simple Deployment**
Use the new `deploy-simple.yml` workflow which:
- ✅ Only deploys website content (not infrastructure)
- ✅ Has better error messages
- ✅ Tests AWS credentials first
- ✅ Can be manually triggered

### **Fix 3: Deploy Manually First**
```bash
# Deploy infrastructure locally
./scripts/deploy-infrastructure.sh deploy

# Deploy website locally
./scripts/deploy-website.sh deploy

# Then try GitHub Actions
git push
```

---

## 📞 **Still Having Issues?**

### **Get Detailed Error Info:**
1. Copy the full error from GitHub Actions logs
2. Check which step is failing
3. Look for specific error codes

### **Common Error Patterns:**

**"NoSuchBucket"** → Infrastructure not deployed
**"AccessDenied"** → IAM permissions issue
**"InvalidAccessKeyId"** → Wrong credentials
**"SignatureDoesNotMatch"** → Wrong secret key
**"ExpiredToken"** → Credentials expired

---

## ✅ **Success Indicators**

When deployment works, you'll see:
```
✓ AWS credentials are working!
✓ Terraform initialized
✓ Files synced to S3
✓ CloudFront cache invalidated
✓ Website is accessible!
```

---

## 🎯 **Next Steps**

1. **Check the error message** from GitHub Actions
2. **Try the simple workflow** (deploy-simple.yml)
3. **Test locally** to isolate the issue
4. **Verify AWS credentials** are correct

Let me know the specific error message and I can help you fix it! 🚀
