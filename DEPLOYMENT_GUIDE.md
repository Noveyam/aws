# 🚀 Resume Website Deployment Guide

This guide will walk you through deploying your professional resume website to AWS using the automated deployment system.

## 📋 Pre-Deployment Checklist

### 1. Prerequisites Validation
Run the configuration validator to ensure everything is ready:

```bash
./scripts/validate-config.sh
```

This will check:
- ✅ All required files and directories
- ✅ Executable permissions on scripts
- ✅ Required tools (Terraform, AWS CLI, jq, curl)
- ✅ AWS credentials configuration
- ✅ Configuration file validity

### 2. Personalize Your Resume Content

Before deploying, update the placeholder content in `website/index.html`:

**Replace these placeholders with your information:**
- `[Your Name]` - Your full name
- `[your-email]@example.com` - Your email address
- `[Your City, State]` - Your location
- `[your-profile]` - Your LinkedIn profile username
- `[your-username]` - Your GitHub username
- `[Current Company]` - Your current employer
- `[Your University]` - Your educational institution

**Add your content:**
- Professional experience details
- Skills and technologies
- Education information
- Projects and certifications
- Professional photo (`website/images/profile.jpg`)
- Resume PDF (`website/assets/resume.pdf`)

## 🎯 Deployment Options

### Option 1: Interactive Deployment (Recommended for First-Time)

The interactive wizard will guide you through the entire process:

```bash
./scripts/deploy-all.sh interactive
```

This will:
1. Show available environments (dev/staging/prod)
2. Let you select your target environment
3. Validate the configuration
4. Deploy infrastructure and website content
5. Verify the deployment

### Option 2: Direct Production Deployment

If you're ready to deploy directly to production:

```bash
./scripts/deploy-all.sh deploy prod
```

### Option 3: Step-by-Step Deployment

For more control, deploy each component separately:

```bash
# 1. Set environment
./scripts/manage-environment.sh set prod

# 2. Deploy infrastructure
./scripts/deploy-infrastructure.sh deploy

# 3. Deploy website content
./scripts/deploy-website.sh deploy

# 4. Validate deployment
./scripts/deploy-all.sh validate
```

## 🔧 Infrastructure Deployment Details

### What Gets Created:
- **S3 Bucket**: Static website hosting with versioning
- **CloudFront Distribution**: Global CDN with SSL termination
- **Route53 Hosted Zone**: DNS management for your domain
- **ACM Certificate**: SSL/TLS certificate with auto-renewal
- **IAM Policies**: Secure deployment permissions
- **CloudWatch Alarms**: Monitoring and alerting

### Expected Timeline:
- **Terraform Apply**: 2-5 minutes
- **CloudFront Distribution**: 15-20 minutes to fully deploy
- **SSL Certificate Validation**: 2-10 minutes
- **DNS Propagation**: Up to 24 hours (usually much faster)

## 🌐 Domain Configuration

After infrastructure deployment, you'll need to update your domain's name servers:

1. **Get Route53 Name Servers**: The deployment script will display them, or run:
   ```bash
   ./scripts/deploy-infrastructure.sh output
   ```

2. **Update Domain Registrar**: 
   - Log into your domain registrar (where you bought noveycloud)
   - Update the name servers to use the Route53 name servers
   - Save the changes

3. **Wait for Propagation**: DNS changes can take up to 24 hours to propagate globally

## 📊 Monitoring and Validation

### Automated Tests
Run the complete test suite:

```bash
./scripts/run-all-tests.sh
```

This includes:
- Infrastructure validation
- Website functionality tests
- Performance testing
- Accessibility compliance
- Responsive design validation

### Free Tier Monitoring
Monitor your AWS Free Tier usage:

```bash
./scripts/monitor-free-tier.sh
```

### Deployment Status
Check the current deployment status:

```bash
./scripts/deploy-all.sh status
```

## 🔄 Ongoing Maintenance

### Updating Website Content
When you make changes to your resume:

```bash
./scripts/deploy-website.sh deploy
```

This will:
- Validate your HTML/CSS
- Create a backup of current content
- Sync changes to S3
- Invalidate CloudFront cache
- Verify the deployment

### Infrastructure Updates
When you modify Terraform configuration:

```bash
./scripts/deploy-infrastructure.sh plan    # Review changes
./scripts/deploy-infrastructure.sh deploy  # Apply changes
```

### Rollback if Needed
If something goes wrong:

```bash
./scripts/deploy-website.sh rollback      # Rollback website content
./scripts/deploy-infrastructure.sh destroy # Destroy infrastructure (if needed)
```

## 🎉 Success Indicators

Your deployment is successful when:

1. ✅ **Infrastructure Deployed**: Terraform completes without errors
2. ✅ **Website Accessible**: Your site loads at `https://noveycloud`
3. ✅ **SSL Certificate Active**: Browser shows secure connection
4. ✅ **CloudFront Working**: Fast loading from global locations
5. ✅ **DNS Resolving**: Domain points to your CloudFront distribution

## 🆘 Troubleshooting

### Common Issues:

**DNS Not Resolving**
- Check name servers are updated at your domain registrar
- Wait for DNS propagation (up to 24 hours)
- Use `dig noveycloud` to check DNS resolution

**SSL Certificate Issues**
- Ensure DNS is properly configured for validation
- Check certificate status in AWS Certificate Manager
- Wait for validation to complete (usually 2-10 minutes)

**Website Not Loading**
- Check CloudFront distribution status (should be "Deployed")
- Verify S3 bucket has content
- Check browser console for errors

**Free Tier Concerns**
- Monitor usage with `./scripts/monitor-free-tier.sh`
- All services are configured to stay within Free Tier limits
- Set up billing alerts in AWS console for extra safety

## 📞 Support

If you encounter issues:

1. Check the deployment logs in the project root
2. Run `./scripts/validate-config.sh` to verify setup
3. Review AWS console for any service-specific errors
4. Use `./scripts/deploy-all.sh status` to check current state

## 🎯 Next Steps After Deployment

1. **Test Your Website**: Visit `https://noveycloud` and test all functionality
2. **Share Your Resume**: Update your LinkedIn, email signatures, etc.
3. **Monitor Performance**: Use the monitoring scripts to track usage
4. **Keep Content Updated**: Regular updates keep your resume current
5. **Backup Regularly**: The system creates automatic backups, but consider additional backups for important updates

---

**🎉 Congratulations!** You now have a professional, secure, and scalable resume website hosted on AWS!