# Domain configuration
variable "domain_name" {
  description = "The domain name for the resume website"
  type        = string
  default     = "noveycloud"
}

# S3 bucket configuration
variable "bucket_name" {
  description = "Name of the S3 bucket for static website hosting"
  type        = string
  default     = "noveycloud-resume-website"
}

# AWS region configuration
variable "aws_region" {
  description = "AWS region for resources (except ACM certificate)"
  type        = string
  default     = "us-east-1"
}

# Environment configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Tags for resource management
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Resume Website"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

# Deployment user creation
variable "create_deployment_user" {
  description = "Whether to create a dedicated IAM user for deployment"
  type        = bool
  default     = false
}

# Health check configuration
variable "enable_health_check" {
  description = "Whether to enable Route53 health check for the website"
  type        = bool
  default     = false
}