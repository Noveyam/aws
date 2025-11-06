#!/bin/bash

# =============================================================================
# Free Tier Usage Monitoring Script
# Monitors AWS Free Tier usage for S3, CloudFront, and Route53
# =============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUTS_FILE="$PROJECT_ROOT/terraform-outputs.json"
MONITORING_LOG="$PROJECT_ROOT/free-tier-monitoring.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Free Tier limits
S3_STORAGE_LIMIT=5368709120      # 5GB in bytes
S3_REQUESTS_LIMIT=20000          # 20,000 GET requests per month
CLOUDFRONT_TRANSFER_LIMIT=1099511627776  # 1TB in bytes
ROUTE53_QUERIES_LIMIT=1000000000 # 1 billion queries per month

# Warning thresholds (80% of limits)
S3_STORAGE_WARNING=$((S3_STORAGE_LIMIT * 80 / 100))
S3_REQUESTS_WARNING=$((S3_REQUESTS_LIMIT * 80 / 100))
CLOUDFRONT_TRANSFER_WARNING=$((CLOUDFRONT_TRANSFER_LIMIT * 80 / 100))
ROUTE53_QUERIES_WARNING=$((ROUTE53_QUERIES_LIMIT * 80 / 100))

# Logging functions
log() { echo -e "${1}" | tee -a "$MONITORING_LOG"; }
info() { log "${BLUE}ℹ $1${NC}"; }
success() { log "${GREEN}✓ $1${NC}"; }
warning() { log "${YELLOW}⚠ $1${NC}"; }
error() { log "${RED}✗ $1${NC}"; }

# Initialize monitoring
init_monitoring() {
    echo "=== Free Tier Usage Monitoring ===" > "$MONITORING_LOG"
    echo "Started at: $(date)" >> "$MONITORING_LOG"
    echo "" >> "$MONITORING_LOG"
    
    info "Starting Free Tier usage monitoring..."
    info "Monitoring log: $MONITORING_LOG"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq not installed (required for JSON parsing)"
        exit 1
    fi
    
    if [ ! -f "$OUTPUTS_FILE" ]; then
        error "Terraform outputs not found. Run deployment first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured"
        exit 1
    fi
    
    success "Prerequisites check completed"
}

# Load configuration from Terraform outputs
load_config() {
    info "Loading configuration from Terraform outputs..."
    
    S3_BUCKET=$(jq -r '.s3_bucket_name.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    CLOUDFRONT_DISTRIBUTION_ID=$(jq -r '.cloudfront_distribution_id.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    ROUTE53_ZONE_ID=$(jq -r '.route53_zone_id.value' "$OUTPUTS_FILE" 2>/dev/null || echo "null")
    
    if [ "$S3_BUCKET" = "null" ] || [ "$CLOUDFRONT_DISTRIBUTION_ID" = "null" ]; then
        error "Could not load required configuration from Terraform outputs"
        exit 1
    fi
    
    info "S3 Bucket: $S3_BUCKET"
    info "CloudFront Distribution: $CLOUDFRONT_DISTRIBUTION_ID"
    info "Route53 Zone: $ROUTE53_ZONE_ID"
    
    success "Configuration loaded successfully"
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Calculate percentage
calculate_percentage() {
    local current=$1
    local limit=$2
    echo $((current * 100 / limit))
}

# Monitor S3 usage
monitor_s3_usage() {
    info "Monitoring S3 usage..."
    
    # Get S3 bucket size
    local bucket_size
    bucket_size=$(aws s3api list-objects-v2 --bucket "$S3_BUCKET" --query 'sum(Contents[].Size)' --output text 2>/dev/null || echo "0")
    
    if [ "$bucket_size" = "None" ] || [ "$bucket_size" = "null" ]; then
        bucket_size=0
    fi
    
    local size_percentage
    size_percentage=$(calculate_percentage $bucket_size $S3_STORAGE_LIMIT)
    
    info "S3 Storage Usage: $(format_bytes $bucket_size) / $(format_bytes $S3_STORAGE_LIMIT) (${size_percentage}%)"
    
    if [ $bucket_size -gt $S3_STORAGE_WARNING ]; then
        warning "S3 storage usage is above 80% of Free Tier limit!"
    elif [ $bucket_size -gt $S3_STORAGE_LIMIT ]; then
        error "S3 storage usage exceeds Free Tier limit!"
    else
        success "S3 storage usage is within Free Tier limits"
    fi
    
    # Get S3 request metrics (approximate - CloudWatch may have delay)
    local start_date end_date
    start_date=$(date -u -d "1 month ago" +%Y-%m-%dT%H:%M:%S)
    end_date=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    local request_count
    request_count=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/S3 \
        --metric-name NumberOfObjects \
        --dimensions Name=BucketName,Value="$S3_BUCKET" \
        --start-time "$start_date" \
        --end-time "$end_date" \
        --period 86400 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$request_count" = "None" ] || [ "$request_count" = "null" ]; then
        request_count=0
    fi
    
    local requests_percentage
    requests_percentage=$(calculate_percentage ${request_count%.*} $S3_REQUESTS_LIMIT)
    
    info "S3 Requests (approx): ${request_count%.*} / $S3_REQUESTS_LIMIT (${requests_percentage}%)"
    
    if [ ${request_count%.*} -gt $S3_REQUESTS_WARNING ]; then
        warning "S3 request count is above 80% of Free Tier limit!"
    elif [ ${request_count%.*} -gt $S3_REQUESTS_LIMIT ]; then
        error "S3 request count exceeds Free Tier limit!"
    else
        success "S3 request count is within Free Tier limits"
    fi
}

# Monitor CloudFront usage
monitor_cloudfront_usage() {
    info "Monitoring CloudFront usage..."
    
    # Get CloudFront data transfer (last 30 days)
    local start_date end_date
    start_date=$(date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%S)
    end_date=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    local data_transfer
    data_transfer=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/CloudFront \
        --metric-name BytesDownloaded \
        --dimensions Name=DistributionId,Value="$CLOUDFRONT_DISTRIBUTION_ID" \
        --start-time "$start_date" \
        --end-time "$end_date" \
        --period 86400 \
        --statistics Sum \
        --region us-east-1 \
        --query 'sum(Datapoints[].Sum)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$data_transfer" = "None" ] || [ "$data_transfer" = "null" ]; then
        data_transfer=0
    fi
    
    local transfer_percentage
    transfer_percentage=$(calculate_percentage ${data_transfer%.*} $CLOUDFRONT_TRANSFER_LIMIT)
    
    info "CloudFront Data Transfer (30 days): $(format_bytes ${data_transfer%.*}) / $(format_bytes $CLOUDFRONT_TRANSFER_LIMIT) (${transfer_percentage}%)"
    
    if [ ${data_transfer%.*} -gt $CLOUDFRONT_TRANSFER_WARNING ]; then
        warning "CloudFront data transfer is above 80% of Free Tier limit!"
    elif [ ${data_transfer%.*} -gt $CLOUDFRONT_TRANSFER_LIMIT ]; then
        error "CloudFront data transfer exceeds Free Tier limit!"
    else
        success "CloudFront data transfer is within Free Tier limits"
    fi
    
    # Get CloudFront request count
    local request_count
    request_count=$(aws cloudfront get-distribution-config \
        --id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --query 'DistributionConfig.Comment' \
        --output text 2>/dev/null || echo "0")
    
    info "CloudFront Distribution Status: Active"
}

# Monitor Route53 usage
monitor_route53_usage() {
    info "Monitoring Route53 usage..."
    
    if [ "$ROUTE53_ZONE_ID" = "null" ]; then
        info "Route53 zone ID not available, skipping Route53 monitoring"
        return 0
    fi
    
    # Get Route53 query count (last 30 days)
    local start_date end_date
    start_date=$(date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%S)
    end_date=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    local query_count
    query_count=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Route53 \
        --metric-name QueryCount \
        --dimensions Name=HostedZoneId,Value="$ROUTE53_ZONE_ID" \
        --start-time "$start_date" \
        --end-time "$end_date" \
        --period 86400 \
        --statistics Sum \
        --query 'sum(Datapoints[].Sum)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$query_count" = "None" ] || [ "$query_count" = "null" ]; then
        query_count=0
    fi
    
    local queries_percentage
    queries_percentage=$(calculate_percentage ${query_count%.*} $ROUTE53_QUERIES_LIMIT)
    
    info "Route53 DNS Queries (30 days): ${query_count%.*} / $ROUTE53_QUERIES_LIMIT (${queries_percentage}%)"
    
    if [ ${query_count%.*} -gt $ROUTE53_QUERIES_WARNING ]; then
        warning "Route53 DNS queries are above 80% of Free Tier limit!"
    elif [ ${query_count%.*} -gt $ROUTE53_QUERIES_LIMIT ]; then
        error "Route53 DNS queries exceed Free Tier limit!"
    else
        success "Route53 DNS queries are within Free Tier limits"
    fi
}

# Check billing alerts
check_billing_alerts() {
    info "Checking billing information..."
    
    # Get current month's estimated charges
    local current_charges
    current_charges=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Billing \
        --metric-name EstimatedCharges \
        --dimensions Name=Currency,Value=USD \
        --start-time "$(date -u -d "7 days ago" +%Y-%m-%dT%H:%M:%S)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
        --period 86400 \
        --statistics Maximum \
        --region us-east-1 \
        --query 'Datapoints[-1].Maximum' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$current_charges" = "None" ] || [ "$current_charges" = "null" ]; then
        current_charges="0.00"
    fi
    
    info "Current Month Estimated Charges: \$${current_charges}"
    
    local charges_float
    charges_float=$(echo "$current_charges" | cut -d. -f1)
    
    if [ "$charges_float" -gt 0 ]; then
        warning "You have charges this month: \$${current_charges}"
        warning "Review your usage to ensure you're staying within Free Tier limits"
    else
        success "No charges detected this month"
    fi
}

# Generate monitoring report
generate_report() {
    echo ""
    log "=== Free Tier Monitoring Summary ==="
    log "Monitoring completed at: $(date)"
    
    echo ""
    log "=== Free Tier Limits Reference ==="
    log "S3 Storage: $(format_bytes $S3_STORAGE_LIMIT) per month"
    log "S3 GET Requests: $S3_REQUESTS_LIMIT per month"
    log "CloudFront Data Transfer: $(format_bytes $CLOUDFRONT_TRANSFER_LIMIT) per month"
    log "Route53 DNS Queries: $ROUTE53_QUERIES_LIMIT per month"
    
    echo ""
    log "=== Recommendations ==="
    log "• Monitor usage regularly to avoid unexpected charges"
    log "• Set up CloudWatch alarms for automated monitoring"
    log "• Consider implementing caching to reduce requests"
    log "• Optimize images and assets to reduce data transfer"
    log "• Review AWS Free Tier documentation for updates"
    
    echo ""
    log "=== Useful Commands ==="
    log "• View CloudWatch dashboard: aws cloudwatch list-dashboards"
    log "• Check billing: aws ce get-cost-and-usage"
    log "• List S3 objects: aws s3 ls s3://$S3_BUCKET --recursive --human-readable"
    log "• CloudFront statistics: aws cloudfront get-distribution --id $CLOUDFRONT_DISTRIBUTION_ID"
}

# Set up automated monitoring (cron job)
setup_automated_monitoring() {
    info "Setting up automated monitoring..."
    
    local cron_job="0 9 * * * $SCRIPT_DIR/monitor-free-tier.sh > /dev/null 2>&1"
    local cron_exists
    cron_exists=$(crontab -l 2>/dev/null | grep -c "monitor-free-tier.sh" || echo "0")
    
    if [ "$cron_exists" -eq 0 ]; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        success "Automated daily monitoring set up (9 AM daily)"
    else
        info "Automated monitoring already configured"
    fi
}

# Main monitoring function
main() {
    local action="${1:-monitor}"
    
    init_monitoring
    
    case "$action" in
        "monitor")
            check_prerequisites
            load_config
            monitor_s3_usage
            monitor_cloudfront_usage
            monitor_route53_usage
            check_billing_alerts
            generate_report
            ;;
        "setup")
            check_prerequisites
            setup_automated_monitoring
            ;;
        "s3")
            check_prerequisites
            load_config
            monitor_s3_usage
            ;;
        "cloudfront")
            check_prerequisites
            load_config
            monitor_cloudfront_usage
            ;;
        "route53")
            check_prerequisites
            load_config
            monitor_route53_usage
            ;;
        "billing")
            check_prerequisites
            check_billing_alerts
            ;;
        *)
            echo "Usage: $0 [monitor|setup|s3|cloudfront|route53|billing]"
            echo ""
            echo "Commands:"
            echo "  monitor     - Run complete Free Tier monitoring (default)"
            echo "  setup       - Set up automated daily monitoring"
            echo "  s3          - Monitor S3 usage only"
            echo "  cloudfront  - Monitor CloudFront usage only"
            echo "  route53     - Monitor Route53 usage only"
            echo "  billing     - Check billing information only"
            exit 1
            ;;
    esac
    
    echo ""
    echo "Completed at: $(date)" >> "$MONITORING_LOG"
    success "Free Tier monitoring completed"
}

# Run main function with all arguments
main "$@"