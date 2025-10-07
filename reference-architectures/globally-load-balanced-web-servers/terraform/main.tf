# -------------------------------------------------------------------
# Regional Load Balancers (one per region)
#
# These LBs front the droplets in each region. They select backends
# via the droplet tag (var.name_prefix), and they are placed into the
# same VPC as the droplets (each region has its own VPC).
# -------------------------------------------------------------------

locals {
  # Convert the vpc_details map/object to a keyed map by region for deterministic for_each
  regional_vpcs = {
    for vpc in values(module.multi_region_vpc.vpc_details) :
    vpc.region => vpc
  }
}

resource "digitalocean_loadbalancer" "regional" {
  for_each = local.regional_vpcs

  # Human-friendly name
  name   = "${var.name_prefix}-${each.key}-regional-lb"
  region = each.key

  # Put the LB into the same VPC as the droplets in that region
  vpc_uuid = each.value.id

  # Use droplets by tag so droplets created after LB is provisioned are automatically included
  droplet_tag = var.name_prefix

  # Forwarding rule: entry at 80/443, target to droplet port 80
  forwarding_rule {
    entry_protocol  = var.tls ? "https" : "http"
    entry_port      = var.tls ? 443 : 80
    target_protocol = "http"
    target_port     = 80

    # If TLS is enabled, reference certificate ID (digitalocean_certificate resource created earlier)
    # The provider accepts certificate_id in forwarding_rule; this attaches the cert to the LB.
    certificate_id = var.tls ? digitalocean_certificate.cert[0].id : null
    tls_passthrough = false
  }

  # Basic healthcheck, ensure only healthy droplets get traffic
  healthcheck {
    protocol = var.tls ? "https" : "http"
    port     = var.tls ? 443 : 80
    path     = "/"
    check_interval_seconds   = 10
    response_timeout_seconds = 5
    healthy_threshold        = 3
    unhealthy_threshold      = 3
  }

  # Sticky sessions optional - set to "none" or "cookie"
  sticky_sessions {
    type = "none"
  }

  # Optional: enable proxy protocol or other useful LB features
  enable_proxy_protocol = false

  # Tag the LB for easy identification
  tags = [var.name_prefix, "lb", "region:${each.key}"]
}

# -------------------------------------------------------------------
# Optional per-region DNS records (A) that point to the regional LB
# Creates hostnames like "nyc3.example.com" if you want direct regional hostnames.
# Only create these if region_dns_records = true
# -------------------------------------------------------------------
resource "digitalocean_record" "regional_a" {
  count = var.region_dns_records ? length(keys(local.regional_vpcs)) : 0

  # we need a sorted list of regions to index correctly
  name   = element(sort(keys(local.regional_vpcs)), count.index)
  domain = var.domain

  # fetch the corresponding LB by name/region:
  # compute region variable to find the LB created above
  # NOTE: We do a lookup by region -> lb resource; ensure region names don't have collisions.
  value  = digitalocean_loadbalancer.regional[element(sort(keys(local.regional_vpcs)), count.index)].ipv4
  type   = "A"
  ttl    = 1800
}
