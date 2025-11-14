# Staging Environment Redesign

## Problem Solved
Previously, each environment (dev/staging/prod) tried to create its own Route53 hosted zone, causing:
- Conflicts with existing resources
- DNS validation timeouts
- Unnecessary complexity and cost

## New Design

### Route53 Zone Strategy
- **Production**: Creates and manages `noveycloud.com` hosted zone
- **Staging/Dev**: Uses the existing production zone, creates subdomain records

### How It Works

#### For Production (`noveycloud.com`)
1. Creates Route53 hosted zone for `noveycloud.com`
2. Creates all DNS records in that zone
3. Manages the zone lifecycle

#### For Staging (`staging.noveycloud.com`)
1. Looks up the existing `noveycloud.com` zone (data source)
2. Creates DNS records for `staging.noveycloud.com` in the main zone
3. No separate hosted zone needed

#### For Dev (`dev.noveycloud.com`)
1. Same as staging - uses main zone
2. Creates DNS records for `dev.noveycloud.com`

## Benefits

1. **No Conflicts**: Each environment creates unique resources
2. **Faster DNS**: No need to wait for new zone propagation
3. **Cost Savings**: Only one hosted zone ($0.50/month vs $1.50/month)
4. **Simpler Management**: All DNS in one place
5. **Faster Certificate Validation**: DNS records created in existing zone

## Technical Changes

### terraform/main.tf
```hcl
# Added locals for zone management
locals {
  base_domain = var.environment == "prod" ? var.domain_name : replace(var.domain_name, "/^[^.]+\\./", "")
  zone_id     = var.environment == "prod" ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.main.zone_id
}

# Data source to look up existing zone
data "aws_route53_zone" "main" {
  name         = local.base_domain
  private_zone = false
}

# Only create zone for production
resource "aws_route53_zone" "main" {
  count = var.environment == "prod" ? 1 : 0
  name  = var.domain_name
  tags  = var.tags
}
```

### All zone_id references updated
Changed from:
```hcl
zone_id = aws_route53_zone.main.zone_id
```

To:
```hcl
zone_id = local.zone_id
```

## Deployment Flow

### First Time Setup
1. Deploy production first to create the main hosted zone
2. Update domain registrar with Route53 name servers
3. Then deploy staging/dev - they'll use the existing zone

### Subsequent Deployments
- All environments can deploy independently
- No conflicts or resource collisions
- Certificate validation completes in ~5-10 minutes

## Prerequisites

Before deploying staging/dev:
1. Production must be deployed first (creates the main zone)
2. Domain must be pointing to Route53 name servers
3. DNS propagation complete (usually 5-10 minutes)

## Next Steps

1. Clean up any existing staging resources (see STAGING_CLEANUP_GUIDE.md)
2. Deploy production if not already done
3. Deploy staging - it will now work correctly
4. Verify staging.noveycloud.com resolves properly
