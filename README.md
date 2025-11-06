# Noveycloud Resume Website

A professional resume website hosted on AWS S3 with CloudFront CDN, Route53 DNS, and ACM SSL certificate. Built using Terraform for infrastructure as code and optimized for AWS Free Tier usage.

## Architecture

- **S3**: Static website hosting with versioning
- **CloudFront**: Global CDN with SSL termination
- **Route53**: DNS management for noveycloud domain
- **ACM**: SSL/TLS certificate with auto-renewal
- **Terraform**: Infrastructure as code

## Project Structure

```
├── terraform/              # Infrastructure as code
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   ├── terraform.tfvars    # Variable values
│   └── versions.tf         # Provider versions
├── website/                # Website content
│   ├── index.html          # Main resume page
│   ├── error.html          # Custom 404 error page
│   ├── css/                # Stylesheets
│   ├── js/                 # JavaScript files
│   ├── images/             # Images and icons
│   └── assets/             # Downloadable files (PDF resume)
├── scripts/                # Deployment automation
└── README.md               # This file
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Domain name "noveycloud" registered and ready for DNS management

## Quick Start

1. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   ```

2. **Plan Infrastructure**:
   ```bash
   terraform plan
   ```

3. **Deploy Infrastructure**:
   ```bash
   terraform apply
   ```

4. **Upload Website Content**:
   ```bash
   # Use deployment scripts (to be created in later tasks)
   ```

## AWS Free Tier Compliance

This project is designed to stay within AWS Free Tier limits:
- S3: < 5GB storage, < 20,000 GET requests/month
- CloudFront: < 1TB data transfer/month
- Route53: Free DNS queries with domain registration
- ACM: Free SSL certificates for CloudFront

## Domain Configuration

After deploying the infrastructure, you'll need to:
1. Update your domain registrar's name servers to use the Route53 name servers
2. Wait for DNS propagation (up to 24 hours)
3. Verify SSL certificate validation

## Maintenance

- Website content updates: Upload files to S3 and invalidate CloudFront cache
- Infrastructure updates: Modify Terraform files and run `terraform apply`
- Monitoring: Check AWS Free Tier usage in AWS Billing dashboard