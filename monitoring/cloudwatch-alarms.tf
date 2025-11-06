# =============================================================================
# CloudWatch Alarms for Free Tier Monitoring
# Monitors AWS usage to stay within Free Tier limits
# =============================================================================

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# SNS topic for Free Tier alerts
resource "aws_sns_topic" "free_tier_alerts" {
  name = "${var.bucket_name}-free-tier-alerts"
  
  tags = var.tags
}

# SNS topic subscription (email)
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.free_tier_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Alarm for S3 Storage Usage
resource "aws_cloudwatch_metric_alarm" "s3_storage_usage" {
  alarm_name          = "${var.bucket_name}-s3-storage-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400"  # 24 hours
  statistic           = "Average"
  threshold           = "4294967296"  # 4GB (80% of 5GB Free Tier limit)
  alarm_description   = "S3 bucket storage usage approaching Free Tier limit"
  alarm_actions       = [aws_sns_topic.free_tier_alerts.arn]
  ok_actions          = [aws_sns_topic.free_tier_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = var.bucket_name
    StorageType = "StandardStorage"
  }

  tags = var.tags
}

# CloudWatch Alarm for S3 GET Requests
resource "aws_cloudwatch_metric_alarm" "s3_get_requests" {
  alarm_name          = "${var.bucket_name}-s3-get-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "16000"  # 80% of 20,000 Free Tier limit
  alarm_description   = "S3 GET requests approaching Free Tier limit"
  alarm_actions       = [aws_sns_topic.free_tier_alerts.arn]
  ok_actions          = [aws_sns_topic.free_tier_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = var.bucket_name
  }

  tags = var.tags
}

# CloudWatch Alarm for CloudFront Data Transfer
resource "aws_cloudwatch_metric_alarm" "cloudfront_data_transfer" {
  alarm_name          = "${var.bucket_name}-cloudfront-data-transfer"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BytesDownloaded"
  namespace           = "AWS/CloudFront"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "858993459200"  # 800GB (80% of 1TB Free Tier limit)
  alarm_description   = "CloudFront data transfer approaching Free Tier limit"
  alarm_actions       = [aws_sns_topic.free_tier_alerts.arn]
  ok_actions          = [aws_sns_topic.free_tier_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = var.tags
}

# CloudWatch Alarm for Route53 DNS Queries
resource "aws_cloudwatch_metric_alarm" "route53_dns_queries" {
  count               = var.enable_route53_monitoring ? 1 : 0
  alarm_name          = "${var.bucket_name}-route53-dns-queries"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "QueryCount"
  namespace           = "AWS/Route53"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "800000000"  # 800M queries (80% of 1B Free Tier limit)
  alarm_description   = "Route53 DNS queries approaching Free Tier limit"
  alarm_actions       = [aws_sns_topic.free_tier_alerts.arn]
  ok_actions          = [aws_sns_topic.free_tier_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    HostedZoneId = var.route53_zone_id
  }

  tags = var.tags
}

# CloudWatch Dashboard for Free Tier Monitoring
resource "aws_cloudwatch_dashboard" "free_tier_monitoring" {
  dashboard_name = "${var.bucket_name}-free-tier-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.bucket_name, "StorageType", "StandardStorage"],
            [".", "NumberOfObjects", "BucketName", var.bucket_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "S3 Storage Usage"
          period  = 86400
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId", var.cloudfront_distribution_id],
            [".", "Requests", "DistributionId", var.cloudfront_distribution_id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"  # CloudFront metrics are in us-east-1
          title   = "CloudFront Usage"
          period  = 86400
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Route53", "QueryCount", "HostedZoneId", var.route53_zone_id]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Route53 DNS Queries"
          period  = 86400
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })

  tags = var.tags
}

# CloudWatch Log Group for application logs (optional)
resource "aws_cloudwatch_log_group" "application_logs" {
  count             = var.enable_application_logging ? 1 : 0
  name              = "/aws/resume-website/${var.bucket_name}"
  retention_in_days = 7  # Keep logs for 7 days to stay within Free Tier

  tags = var.tags
}

# Budget for cost monitoring
resource "aws_budgets_budget" "free_tier_budget" {
  count        = var.enable_cost_budget ? 1 : 0
  name         = "${var.bucket_name}-free-tier-budget"
  budget_type  = "COST"
  limit_amount = "1"  # $1 budget
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters = {
    Service = [
      "Amazon Simple Storage Service",
      "Amazon CloudFront",
      "Amazon Route 53"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80  # Alert at 80% of budget
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100  # Alert at 100% of budget
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
  }

  tags = var.tags
}

# Variables for monitoring configuration
variable "alert_email" {
  description = "Email address for Free Tier alerts"
  type        = string
  default     = ""
}

variable "enable_route53_monitoring" {
  description = "Enable Route53 DNS query monitoring"
  type        = bool
  default     = true
}

variable "enable_application_logging" {
  description = "Enable CloudWatch application logging"
  type        = bool
  default     = false
}

variable "enable_cost_budget" {
  description = "Enable AWS Budget for cost monitoring"
  type        = bool
  default     = true
}

# Outputs for monitoring resources
output "sns_topic_arn" {
  description = "ARN of the SNS topic for Free Tier alerts"
  value       = aws_sns_topic.free_tier_alerts.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.free_tier_monitoring.dashboard_name}"
}

output "budget_name" {
  description = "Name of the AWS Budget (if enabled)"
  value       = var.enable_cost_budget ? aws_budgets_budget.free_tier_budget[0].name : null
}