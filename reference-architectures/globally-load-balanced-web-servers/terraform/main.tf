# -------------------------------------------------------------------
# Multi-region VPC mesh
# This module creates VPCs in multiple regions and peers them together
# so resources in different regions can communicate privately. The
# name_prefix is used to tag/namesake things consistently; "vpcs" is the
# list of region+CIDR pairs. See the multi-region VPC module README for more details
# https://github.com/digitalocean/terraform-digitalocean-multi-region-vpc
# -------------------------------------------------------------------
module "multi_region_vpc" {
  source      = "github.com/digitalocean/terraform-digitalocean-multi-region-vpc?ref=v1.0.0"
  name_prefix = var.name_prefix
  vpcs        = var.vpcs
}

# -------------------------------------------------------------------
# TLS certificate (optional)
# If TLS is enabled, obtain a Let's Encrypt certificate for the primary
# domain and its wildcard. count is used so the resource only exists when
# var.tls is true.
# -------------------------------------------------------------------
resource "digitalocean_certificate" "cert" {
  count   = var.tls ? 1 : 0
  name    = var.name_prefix
  type    = "lets_encrypt"
  domains = [var.domain, "*.${var.domain}"]
}

# -------------------------------------------------------------------
# Global + regional load balancing stack
# This module sets up:
#   * Regional Load Balancers (one per region/VPC) in front of droplets
#   * A Global Load Balancer that fronts the regionals with anycast IPs,
#     optional CDN, and HTTPS handling.
#   * Optional DNS records to reach each region directly.
#
# See the GLB Stack README for more details:
# https://github.com/digitalocean/terraform-digitalocean-glb-stack/blob/main/README.md
# -------------------------------------------------------------------
module "glb_stack" {
  source      = "github.com/digitalocean/terraform-digitalocean-glb-stack?ref=v1.0.0"
  name_prefix = var.name_prefix

  # Supply the list of region/VPC pairs the GLB stack should target.
  # We extract region + vpc_uuid from the multi-region VPC module output.
  vpcs = [for vpc in values(module.multi_region_vpc.vpc_details) : { region = vpc.region, vpc_uuid = vpc.id }]

  # Create DNS A records for each regional LB so regional hostnames like
  # nyc3.example.com resolve directly.
  region_dns_records = true

  # Configuration that applies to each regional load balancer.
  regional_lb_config = {
    redirect_http_to_https = var.tls

    forwarding_rule = {
      certificate_name = var.tls ? digitalocean_certificate.cert[0].name : null
      entry_port       = var.tls ? 443 : 80
      entry_protocol   = var.tls ? "https" : "http"
      target_port      = 80
      target_protocol  = "http"
    }

    # Basic healthcheck to ensure the regional LB only sends traffic to healthy droplets.
    healthcheck = {
      port     = 80
      protocol = "http"
      path     = "/"
    }

    # Tag used to associate droplets with the regional load balancers.
    droplet_tag = var.name_prefix
  }

  # Global load balancer sitting in front of the regionals, with its own
  # healthcheck, optional HTTPS redirection, and CDN.
  global_lb_config = {
    redirect_http_to_https = var.tls

    domains = [{
      name       = var.domain
      is_managed = true # Let the module create/manage the DNS zone for the GLB host.
    }]

    glb_settings = {
      target_protocol = var.tls ? "https" : "http"
      target_port     = var.tls ? 443 : 80

      # Enable CDN in front of the GLB for caching and performance.
      cdn = {
        is_enabled = true
      }
    }

    # Healthcheck from the global LB into the regional layers.
    healthcheck = {
      port     = var.tls ? 443 : 80
      protocol = var.tls ? "https" : "http"
      path     = "/"
    }
  }
}

# -------------------------------------------------------------------
# Optional SSH key lookup (for testing or operator access)
# Looks up an existing SSH key by name so its ID can be injected into droplets.
# Only does this when var.ssh_key is provided. This uses a data source,
# which does not create anything; it just reads existing state.
# -------------------------------------------------------------------
data "digitalocean_ssh_key" "default" {
  count = var.ssh_key != null ? 1 : 0
  name  = var.ssh_key
}

# -------------------------------------------------------------------
# Build a map of all droplet instances we intend to create across regions.
# Each entry's key encodes region and ordinal so we can use Terraform's
# for_each to create one droplet per region/index. This flatten/for loop
# logic constructs the metadata needed per droplet. Newcomers: this is a
# purely local computation—no API calls happen here.
# -------------------------------------------------------------------
locals {
  droplet_instances = {
    for pair in flatten([
      for vpc in values(module.multi_region_vpc.vpc_details) : [
        for i in range(var.droplet_count) : {
          key      = "${vpc.region}-${i + 1}"
          region   = vpc.region
          vpc_uuid = vpc.id
          droplet  = i
        }
      ]
      ]) : pair.key => {
      region   = pair.region
      vpc_uuid = pair.vpc_uuid
      droplet  = pair.droplet
    }
  }
}

# -------------------------------------------------------------------
# Web droplets
# One droplet per region+index. Tagged so the GLB/regional LBs can target
# them (via the droplet_tag) and optionally provision with an SSH key.
# user_data bootstraps nginx and Docker to give a visible landing page.
# -------------------------------------------------------------------
resource "digitalocean_droplet" "web" {
  for_each = local.droplet_instances

  name     = "${var.name_prefix}-${each.value.region}-${each.value.droplet}"
  size     = var.droplet_size
  image    = var.droplet_image
  region   = each.value.region
  vpc_uuid = each.value.vpc_uuid

  # Inject SSH key for access if provided. Using the data source above to
  # resolve the key's ID. Empty list if no key specified. :contentReference[oaicite:7]{index=7}
  ssh_keys = var.ssh_key != null ? [data.digitalocean_ssh_key.default[0].id] : []

  # user_data is executed at first boot to install and start nginx + Docker.
  # It's a simple way to get a working web page and container runtime without
  # external configuration management. Newcomers: this is cloud-init-like shell
  # scripting; you can inspect its output on the droplet under system logs.
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx ca-certificates curl gnupg

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \"$(
      . /etc/os-release && echo \"$VERSION_CODENAME\"
    )\" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker and Docker Compose
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker

    # Configure nginx with a simple region-aware welcome page
    echo "<h1>Welcome to Hivenetes - Region: ${each.value.region} - Droplet: ${each.value.droplet}</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF

  # Tags are used by the GLB stack to identify which droplets to include
  # behind regional load balancers. The region tag is informational/diagnostic.
  tags = [var.name_prefix, "region:${each.value.region}"]
}
