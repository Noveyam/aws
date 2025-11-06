# Design Document

## Overview

The S3 Resume Website is a static web application hosted on AWS using a combination of S3, CloudFront, Route53, and ACM services. The architecture follows AWS best practices for static website hosting while maintaining Free Tier eligibility. Infrastructure is managed using Terraform for reproducible, version-controlled deployments. The system serves a professional resume website through the noveycloud domain with HTTPS security and global content delivery.

## Architecture

### High-Level Architecture

```
Internet → Route53 (noveycloud) → CloudFront Distribution → S3 Bucket (Static Website)
                                        ↑
                                   ACM Certificate
```

### Component Flow

1. **DNS Resolution**: Route53 resolves noveycloud domain to CloudFront distribution
2. **SSL Termination**: CloudFront uses ACM certificate for HTTPS connections
3. **Content Delivery**: CloudFront serves cached content from global edge locations
4. **Origin Fetch**: CloudFront fetches content from S3 bucket when not cached
5. **Static Serving**: S3 serves HTML, CSS, JS, and image files as static website

### AWS Service Integration

- **Primary Origin**: S3 bucket configured for static website hosting
- **CDN Layer**: CloudFront distribution for global content delivery and SSL
- **DNS Management**: Route53 hosted zone for noveycloud domain
- **SSL Security**: ACM certificate for HTTPS encryption
- **Access Control**: 
  - Public read access through CloudFront only
  - Admin write access through AWS credentials/IAM
  - Direct S3 access blocked for security

## Components and Interfaces

### S3 Bucket Component

**Purpose**: Static website hosting and file storage

**Configuration**:
- Bucket name: `noveycloud-resume-website` (globally unique)
- Region: `us-east-1` (required for CloudFront integration)
- Static website hosting enabled
- Index document: `index.html`
- Error document: `error.html`

**Access Control Model**:
- **Public Access**: Anyone can view website content (GET requests only)
- **Admin Access**: Only authenticated AWS user can upload/modify content
- **CloudFront Integration**: Public access routed through CloudFront, not direct S3

**Bucket Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::noveycloud-resume-website/*"
    },
    {
      "Sid": "DenyDirectS3Access",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::noveycloud-resume-website",
        "arn:aws:s3:::noveycloud-resume-website/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalServiceName": "cloudfront.amazonaws.com"
        }
      },
      "NotPrincipal": {
        "AWS": "arn:aws:iam::ACCOUNT-ID:root"
      }
    }
  ]
}
```

**File Structure**:
```
/
├── index.html          # Main resume page
├── error.html          # Custom 404 error page
├── css/
│   └── styles.css      # Resume styling
├── js/
│   └── main.js         # Interactive functionality
├── images/
│   ├── profile.jpg     # Professional photo
│   └── favicon.ico     # Website icon
└── assets/
    └── resume.pdf      # Downloadable PDF version
```

### CloudFront Distribution Component

**Purpose**: Global content delivery and SSL termination

**Configuration**:
- Origin: S3 bucket static website endpoint
- Price class: `PriceClass_100` (US, Canada, Europe - Free Tier friendly)
- Viewer protocol policy: `Redirect HTTP to HTTPS`
- Allowed HTTP methods: `GET, HEAD`
- Compress objects automatically: `Yes`
- Default root object: `index.html`

**Cache Behaviors**:
- Default: Cache HTML files for 24 hours
- Static assets (CSS/JS): Cache for 1 year with versioning
- Images: Cache for 1 month
- PDF files: Cache for 1 week

**Custom Error Pages**:
- 404 errors redirect to `/error.html`
- 403 errors redirect to `/error.html`

### Route53 Hosted Zone Component

**Purpose**: DNS management for noveycloud domain

**DNS Records**:
- A record: `noveycloud` → CloudFront distribution alias
- A record: `www.noveycloud` → CloudFront distribution alias
- CNAME record: `www` → `noveycloud` (if needed)

**Configuration**:
- Hosted zone for `noveycloud` domain
- TTL: 300 seconds for quick updates
- Health checks: Optional monitoring

### ACM Certificate Component

**Purpose**: SSL/TLS certificate for HTTPS connections

**Configuration**:
- Certificate for: `noveycloud` and `*.noveycloud`
- Validation method: DNS validation through Route53
- Region: `us-east-1` (required for CloudFront)
- Auto-renewal: Enabled

## Data Models

### Website Content Structure

```typescript
interface ResumeWebsite {
  metadata: {
    title: string;
    description: string;
    keywords: string[];
    author: string;
  };
  content: {
    header: PersonalInfo;
    sections: ResumeSection[];
  };
  assets: {
    stylesheets: string[];
    scripts: string[];
    images: string[];
  };
}

interface PersonalInfo {
  name: string;
  title: string;
  email: string;
  phone?: string;
  location: string;
  linkedin?: string;
  github?: string;
  website?: string;
}

interface ResumeSection {
  id: string;
  title: string;
  type: 'experience' | 'education' | 'skills' | 'projects' | 'certifications';
  content: any; // Flexible content based on section type
  order: number;
}
```

### Infrastructure as Code (Terraform)

**Purpose**: Manage AWS resources declaratively and ensure reproducible deployments

**Terraform Configuration Structure**:
```
terraform/
├── main.tf              # Main Terraform configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── terraform.tfvars     # Variable values
└── versions.tf          # Provider versions
```

**Key Terraform Resources**:
- `aws_s3_bucket`: S3 bucket for static website hosting
- `aws_s3_bucket_website_configuration`: Static website configuration
- `aws_s3_bucket_public_access_block`: Controlled public access settings
- `aws_s3_bucket_policy`: Bucket policy for CloudFront-only public access
- `aws_cloudfront_origin_access_control`: Secure CloudFront to S3 access
- `aws_cloudfront_distribution`: CDN distribution with OAC
- `aws_acm_certificate`: SSL certificate
- `aws_route53_zone`: DNS hosted zone
- `aws_route53_record`: DNS records for domain
- `aws_iam_policy`: Deployment permissions for admin user

### Deployment Configuration

```typescript
interface DeploymentConfig {
  terraform: {
    workingDirectory: string;
    stateBackend?: 's3' | 'local';
    variables: {
      domain_name: string;
      bucket_name: string;
      aws_region: string;
    };
  };
  aws: {
    region: string;
    profile?: string;
  };
  s3: {
    bucketName: string;
    syncOptions: {
      delete: boolean;
      exclude: string[];
    };
  };
  cloudfront: {
    distributionId: string;
    invalidationPaths: string[];
  };
}
```

## Error Handling

### S3 Error Handling

- **404 Not Found**: Serve custom `error.html` page
- **403 Forbidden**: Redirect to error page with appropriate message
- **500 Server Error**: CloudFront serves cached version if available

### CloudFront Error Handling

- **Origin Unavailable**: Serve cached content with extended TTL
- **SSL Certificate Issues**: Automatic retry with ACM certificate
- **Geographic Restrictions**: None (global access)

### DNS Error Handling

- **Route53 Failures**: Use multiple name servers for redundancy
- **Domain Resolution Issues**: Monitor with Route53 health checks
- **TTL Management**: Balance between performance and update speed

### Deployment Error Handling

- **Upload Failures**: Retry mechanism with exponential backoff
- **Sync Issues**: Validate file checksums before deployment
- **Cache Invalidation**: Automatic invalidation after successful deployment

## Testing Strategy

### Unit Testing

- **HTML Validation**: W3C markup validator for semantic correctness
- **CSS Validation**: CSS validator for syntax and compatibility
- **JavaScript Testing**: Basic functionality tests for interactive elements
- **Accessibility Testing**: WAVE tool for accessibility compliance

### Integration Testing

- **S3 Upload Testing**: Verify file upload and public access
- **CloudFront Testing**: Validate cache behavior and SSL termination
- **DNS Testing**: Confirm domain resolution and redirect behavior
- **Cross-browser Testing**: Chrome, Firefox, Safari, Edge compatibility

### Performance Testing

- **Page Load Speed**: Target under 3 seconds initial load
- **Mobile Performance**: Lighthouse mobile performance score > 90
- **CDN Effectiveness**: Measure response times from different geographic locations
- **Free Tier Monitoring**: Track usage against AWS Free Tier limits

### Security Testing

- **HTTPS Enforcement**: Verify HTTP to HTTPS redirects
- **SSL Certificate Validation**: Confirm proper certificate chain
- **Access Control Testing**: 
  - Verify public can view website through CloudFront
  - Confirm direct S3 access is blocked for unauthorized users
  - Test admin deployment access works correctly
- **Origin Access Control**: Validate CloudFront OAC configuration
- **Header Security**: Implement security headers via CloudFront

### Infrastructure Testing

- **Terraform Validation**: `terraform validate` and `terraform plan` before apply
- **Infrastructure Drift**: Regular `terraform plan` to detect configuration drift
- **Resource Dependencies**: Verify proper resource creation order and dependencies
- **State Management**: Validate Terraform state consistency

### Deployment Testing

- **Staging Environment**: Test deployment process in separate bucket
- **Rollback Testing**: Verify ability to revert to previous version using Terraform
- **Cache Invalidation**: Confirm content updates propagate correctly
- **Monitoring Setup**: CloudWatch alarms for error rates and usage
- **Infrastructure Reproducibility**: Test complete infrastructure recreation from Terraform

### Free Tier Compliance Testing

- **Usage Monitoring**: Track S3 storage, requests, and CloudFront data transfer
- **Cost Alerts**: Set up billing alerts for any unexpected charges
- **Limit Validation**: Ensure all services stay within Free Tier boundaries
- **Resource Optimization**: Monitor and optimize resource usage patterns