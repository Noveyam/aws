# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Local variables
locals {
  # For staging/dev, use the base domain zone (noveycloud.com)
  # Use the zone we create/manage
  base_domain = var.domain_name
  zone_id     = aws_route53_zone.main.zone_id
}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "resume_website" {
  bucket = var.bucket_name
  tags   = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "resume_website" {
  bucket = aws_s3_bucket.resume_website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "resume_website" {
  bucket = aws_s3_bucket.resume_website.id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# S3 bucket versioning for rollback capability
resource "aws_s3_bucket_versioning" "resume_website" {
  bucket = aws_s3_bucket.resume_website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "resume_website" {
  bucket = aws_s3_bucket.resume_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# S3 bucket public access block configuration
resource "aws_s3_bucket_public_access_block" "resume_website" {
  bucket = aws_s3_bucket.resume_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "resume_website" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${var.domain_name} resume website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront function for security headers
resource "aws_cloudfront_function" "security_headers" {
  name    = "${var.bucket_name}-security-headers"
  runtime = "cloudfront-js-1.0"
  comment = "Add security headers to responses"
  publish = true
  code    = <<-EOT
function handler(event) {
    var response = event.response;
    var headers = response.headers;

    // Add security headers
    headers['strict-transport-security'] = { value: 'max-age=31536000; includeSubDomains; preload' };
    headers['content-type-options'] = { value: 'nosniff' };
    headers['frame-options'] = { value: 'DENY' };
    headers['xss-protection'] = { value: '1; mode=block' };
    headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
    headers['content-security-policy'] = { 
        value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';" 
    };

    return response;
}
EOT
}

# S3 bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "resume_website" {
  bucket     = aws_s3_bucket.resume_website.id
  depends_on = [aws_s3_bucket_public_access_block.resume_website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.resume_website.arn
          }
        }
      }
    ]
  })
}

# S3 bucket notification for monitoring (optional)
resource "aws_s3_bucket_notification" "resume_website" {
  bucket = aws_s3_bucket.resume_website.id

  # This can be extended later to add SNS/SQS notifications for file uploads
  depends_on = [aws_s3_bucket_policy.resume_website]
}

# Route53 hosted zone
# Create or use existing zone
# Zone ID: Z0756127155MZ0VTLU0BJ (Production - DO NOT DELETE)
resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# ACM certificate for SSL/TLS
resource "aws_acm_certificate" "resume_website" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# Route53 records for ACM certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.resume_website.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "resume_website" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.resume_website.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "resume_website" {
  origin {
    domain_name              = aws_s3_bucket.resume_website.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume_website.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  # Cache behavior for default (HTML files)
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }

    min_ttl     = 0
    default_ttl = 86400    # 24 hours
    max_ttl     = 31536000 # 1 year
  }

  # Cache behavior for static assets (CSS, JS)
  ordered_cache_behavior {
    path_pattern           = "/css/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 31536000 # 1 year
    max_ttl     = 31536000 # 1 year
  }

  ordered_cache_behavior {
    path_pattern           = "/js/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 31536000 # 1 year
    max_ttl     = 31536000 # 1 year
  }

  # Cache behavior for images
  ordered_cache_behavior {
    path_pattern           = "/images/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 2592000  # 1 month
    max_ttl     = 31536000 # 1 year
  }

  # Cache behavior for PDF files
  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 604800   # 1 week
    max_ttl     = 31536000 # 1 year
  }

  # Price class for Free Tier optimization
  price_class = "PriceClass_100"

  # Custom error pages
  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 500
    response_code         = 500
    response_page_path    = "/error.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 502
    response_code         = 502
    response_page_path    = "/error.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 503
    response_code         = 503
    response_page_path    = "/error.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 504
    response_code         = 504
    response_page_path    = "/error.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.resume_website.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}

# Route53 A record for apex domain
resource "aws_route53_record" "apex" {
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_website.domain_name
    zone_id                = aws_cloudfront_distribution.resume_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 A record for www subdomain
resource "aws_route53_record" "www" {
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_website.domain_name
    zone_id                = aws_cloudfront_distribution.resume_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA records for IPv6 support
resource "aws_route53_record" "apex_ipv6" {
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.resume_website.domain_name
    zone_id                = aws_cloudfront_distribution.resume_website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_ipv6" {
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.resume_website.domain_name
    zone_id                = aws_cloudfront_distribution.resume_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 health check for monitoring (optional)
# Note: Health check is optional and can be disabled if causing issues
resource "aws_route53_health_check" "resume_website" {
  count             = var.enable_health_check ? 1 : 0
  fqdn              = var.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "${var.domain_name} Health Check"
  })
}

# IAM policy for deployment access
resource "aws_iam_policy" "resume_website_deployment" {
  name        = "${var.bucket_name}-deployment-policy"
  description = "Policy for deploying content to the resume website S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.resume_website.arn,
          "${aws_s3_bucket.resume_website.arn}/*"
        ]
      },
      {
        Sid    = "AllowCloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = aws_cloudfront_distribution.resume_website.arn
      },
      {
        Sid    = "AllowCloudFrontDistributionRead"
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig"
        ]
        Resource = aws_cloudfront_distribution.resume_website.arn
      }
    ]
  })

  tags = var.tags
}

# IAM user for deployment (optional - can be attached to existing user)
resource "aws_iam_user" "resume_website_deployer" {
  count = var.create_deployment_user ? 1 : 0
  name  = "${var.bucket_name}-deployer"
  path  = "/"

  tags = var.tags
}

# Attach deployment policy to user
resource "aws_iam_user_policy_attachment" "resume_website_deployment" {
  count      = var.create_deployment_user ? 1 : 0
  user       = aws_iam_user.resume_website_deployer[0].name
  policy_arn = aws_iam_policy.resume_website_deployment.arn
}

# Access keys for deployment user (use with caution)
resource "aws_iam_access_key" "resume_website_deployer" {
  count = var.create_deployment_user ? 1 : 0
  user  = aws_iam_user.resume_website_deployer[0].name
}