# S3 bucket outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.resume_website.bucket
}

output "s3_bucket_website_endpoint" {
  description = "Website endpoint for the S3 bucket"
  value       = aws_s3_bucket_website_configuration.resume_website.website_endpoint
}

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.resume_website.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.resume_website.domain_name
}

# Route53 outputs
output "route53_zone_id" {
  description = "Zone ID of the Route53 hosted zone"
  value       = local.zone_id
}

output "route53_name_servers" {
  description = "Name servers for the Route53 hosted zone"
  value       = aws_route53_zone.main.name_servers
}

# ACM certificate outputs
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.resume_website.arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.resume_website.status
}

output "acm_certificate_domain_validation_options" {
  description = "Domain validation options for the ACM certificate"
  value       = aws_acm_certificate.resume_website.domain_validation_options
  sensitive   = true
}

# Website URLs
output "website_url" {
  description = "Main website URL"
  value       = "https://${var.domain_name}"
}

output "www_website_url" {
  description = "WWW website URL"
  value       = "https://www.${var.domain_name}"
}

# IAM outputs
output "deployment_policy_arn" {
  description = "ARN of the deployment IAM policy"
  value       = aws_iam_policy.resume_website_deployment.arn
}

output "deployment_user_name" {
  description = "Name of the deployment IAM user (if created)"
  value       = var.create_deployment_user ? aws_iam_user.resume_website_deployer[0].name : null
}

output "deployment_access_key_id" {
  description = "Access key ID for deployment user (if created)"
  value       = var.create_deployment_user ? aws_iam_access_key.resume_website_deployer[0].id : null
  sensitive   = true
}

output "deployment_secret_access_key" {
  description = "Secret access key for deployment user (if created)"
  value       = var.create_deployment_user ? aws_iam_access_key.resume_website_deployer[0].secret : null
  sensitive   = true
}

# Health check outputs
output "health_check_id" {
  description = "ID of the Route53 health check (if enabled)"
  value       = var.enable_health_check ? aws_route53_health_check.resume_website[0].id : null
}