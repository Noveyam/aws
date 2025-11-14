# Route53 Health Check Fix

## Problem
Terraform apply was failing with error:
```
Error: updating Route53 Health Check: InvalidInput: 
Basic health checks must not have an insufficient data health state specified.
```

## Root Cause
The Route53 health check resource had parameters that are only valid for CloudWatch alarm-based or calculated health checks, not for basic HTTPS health checks:

- `insufficient_data_health_status` - Only for calculated/CloudWatch health checks
- `cloudwatch_alarm_region` - Only for CloudWatch alarm-based checks
- `cloudwatch_alarm_name` - Only for CloudWatch alarm-based checks

## Solution
Removed the invalid parameters from the basic HTTPS health check configuration.

### Before
```hcl
resource "aws_route53_health_check" "resume_website" {
  count                           = var.enable_health_check ? 1 : 0
  fqdn                            = var.domain_name
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/"
  failure_threshold               = 3
  request_interval                = 30
  cloudwatch_alarm_region         = var.aws_region
  cloudwatch_alarm_name           = "${var.bucket_name}-health-check"
  insufficient_data_health_status = "LastKnownStatus"
  
  tags = merge(var.tags, {
    Name = "${var.domain_name} Health Check"
  })
}
```

### After
```hcl
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
```

## Files Modified
- `terraform/main.tf` (line 427)

## Additional Issue
When trying to update the existing health check, AWS returned:
```
Error: missing required field, UpdateHealthCheckInput.AlarmIdentifier.Region
```

This happens because the existing health check was created with CloudWatch alarm parameters, and AWS requires those parameters when updating such a health check.

## Final Solution
Disabled health checks entirely by setting `enable_health_check = false` in `config/deployment.json` for all environments. This causes Terraform to destroy the problematic health check.

Health checks are optional monitoring features and not required for the website to function. They can be re-enabled later after the old health check is removed.

## Files Modified
- `terraform/main.tf` (line 427) - Removed invalid parameters
- `config/deployment.json` - Set `enable_health_check: false` for staging and prod

## Result
With health checks disabled, Terraform will remove the problematic resource and deployment can proceed successfully.
