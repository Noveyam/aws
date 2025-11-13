# GitHub Secrets Setup Guide

## 🔐 Setting Up AWS Credentials for GitHub Actions

Your GitHub Actions workflow needs AWS credentials to deploy your resume website. Follow these steps:

## 📋 **Required Secrets**

You need to add these secrets to your GitHub repository:

### **For All Environments (Dev/Staging):**
- `AWS_ACCESS_KEY_ID` - Your AWS Access Key ID
- `AWS_SECRET_ACCESS_KEY` - Your AWS Secret Access Key

### **For Production (Optional - can reuse same credentials):**
- `AWS_ACCESS_KEY_ID_PROD` - Your AWS Access Key ID for production
- `AWS_SECRET_ACCESS_KEY_PROD` - Your AWS Secret Access Key for production

## 🔑 **Step 1: Get Your AWS Credentials**

### **Option A: Check Existing Credentials**
```bash
# View your AWS credentials (be careful not to share these!)
cat ~/.aws/credentials
```

You'll see something like:
```ini
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/...
```

### **Option B: Create New Access Keys**

1. **Go to AWS Console**: https://console.aws.amazon.com/iam/
2. **Click "Users"** in the left sidebar
3. **Click your username** (e.g., "Novey")
4. **Click "Security credentials"** tab
5. **Scroll to "Access keys"** section
6. **Click "Create access key"**
7. **Select "Command Line Interface (CLI)"**
8. **Check the confirmation box**
9. **Click "Create access key"**
10. **Copy both the Access Key ID and Secret Access Key** (you won't see the secret again!)

## 🔧 **Step 2: Add Secrets to GitHub**

### **Navigate to Repository Settings**
1. Go to your GitHub repository: `https://github.com/YOUR_USERNAME/YOUR_REPO`
2. Click **"Settings"** (top menu bar)
3. Click **"Secrets and variables"** → **"Actions"** (left sidebar)
4. Click **"New repository secret"** button

### **Add Each Secret**

#### **Secret 1: AWS_ACCESS_KEY_ID**
- **Name**: `AWS_ACCESS_KEY_ID`
- **Value**: Paste your AWS Access Key ID (starts with `AKIA...`)
- Click **"Add secret"**

#### **Secret 2: AWS_SECRET_ACCESS_KEY**
- **Name**: `AWS_SECRET_ACCESS_KEY`
- **Value**: Paste your AWS Secret Access Key
- Click **"Add secret"**

#### **Secret 3 (Optional): AWS_ACCESS_KEY_ID_PROD**
- **Name**: `AWS_ACCESS_KEY_ID_PROD`
- **Value**: Paste your AWS Access Key ID for production
- Click **"Add secret"**

#### **Secret 4 (Optional): AWS_SECRET_ACCESS_KEY_PROD**
- **Name**: `AWS_SECRET_ACCESS_KEY_PROD`
- **Value**: Paste your AWS Secret Access Key for production
- Click **"Add secret"**

## ✅ **Step 3: Verify Setup**

After adding the secrets, you should see them listed (values will be hidden):
- ✅ AWS_ACCESS_KEY_ID
- ✅ AWS_SECRET_ACCESS_KEY
- ✅ AWS_ACCESS_KEY_ID_PROD (optional)
- ✅ AWS_SECRET_ACCESS_KEY_PROD (optional)

## 🚀 **Step 4: Test the Deployment**

### **Trigger a Deployment**
1. Make a small change to your code
2. Commit and push to the `main` branch:
   ```bash
   git add .
   git commit -m "Test deployment with AWS credentials"
   git push origin main
   ```
3. Go to **"Actions"** tab in GitHub
4. Watch the workflow run - it should now successfully authenticate with AWS!

### **Manual Trigger**
You can also manually trigger a deployment:
1. Go to **"Actions"** tab
2. Click **"Deploy Resume Website"** workflow
3. Click **"Run workflow"**
4. Select environment and click **"Run workflow"**

## 🔒 **Security Best Practices**

### **✅ DO:**
- Use GitHub Secrets for all sensitive credentials
- Create separate IAM users for CI/CD with minimal permissions
- Rotate access keys regularly
- Use different credentials for production

### **❌ DON'T:**
- Never commit AWS credentials to git
- Don't share your secret access keys
- Don't use root account credentials
- Don't give excessive permissions

## 🛡️ **Recommended IAM Policy**

For better security, create a dedicated IAM user for GitHub Actions with this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "cloudfront:*",
        "route53:*",
        "acm:*",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicies"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🆘 **Troubleshooting**

### **Error: "Unable to locate credentials"**
- Make sure secrets are named exactly: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- Check that secrets are added to the correct repository
- Verify secrets don't have extra spaces or newlines

### **Error: "Access Denied"**
- Check that your IAM user has the necessary permissions
- Verify the access keys are active in AWS IAM console
- Make sure the keys haven't expired

### **Error: "Invalid security token"**
- The access keys might be incorrect
- Try creating new access keys
- Verify you're using the correct AWS account

## 📞 **Need Help?**

If you're still having issues:
1. Check the GitHub Actions logs for specific error messages
2. Verify your AWS credentials work locally: `aws sts get-caller-identity`
3. Make sure your IAM user has the required permissions

## 🎉 **Success!**

Once configured, your GitHub Actions workflow will:
- ✅ Automatically deploy to staging when you push to `main`
- ✅ Deploy to development when you push to `develop`
- ✅ Allow manual production deployments
- ✅ Run all tests and validations before deploying

Your resume website will be automatically deployed with every push! 🚀
