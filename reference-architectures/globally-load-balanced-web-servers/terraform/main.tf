module "multi_region_vpc" {
  source      = "git@github.com:digitalocean/terraform-digitalocean-multi-region-vpc.git"
  name_prefix = var.name_prefix
  vpcs = var.vpcs
}

resource "digitalocean_certificate" "cert" {
  count    = var.tls ? 1 : 0
  name    = var.name_prefix
  type    = "lets_encrypt"
  domains = [var.domain, "*.${var.domain}"]
}

module "glb_stack" {
  source = "git@github.com:digitalocean/terraform-digitalocean-glb-stack.git"
  name_prefix = var.name_prefix
  vpcs = [for vpc in values(module.multi_region_vpc.vpc_details) : { region = vpc.region, vpc_uuid = vpc.id }]
  region_dns_records = true
  regional_lb_config = {
    redirect_http_to_https = var.tls
    forwarding_rule = {
      certificate_name = var.tls ? digitalocean_certificate.cert[0].name : null
      entry_port       = var.tls ? 443 : 80
      entry_protocol   = var.tls ? "https" : "http"
      target_port     = 80
      target_protocol = "http"
    }

    healthcheck = {
      port     = 80
      protocol = "http"
      path = "/"
    }

    droplet_tag = var.name_prefix
  }

  global_lb_config = {
    redirect_http_to_https = var.tls
    domains = [{
      name       = var.domain
      is_managed = true
    }]
    glb_settings = {
      target_protocol = var.tls ? "https" : "http"
      target_port     = var.tls ? 443 : 80
      cdn = {
        is_enabled = true
      }
    }
    healthcheck = {
      port     = var.tls ? 443 : 80
      protocol = var.tls ? "https" : "http"
      path = "/"
    }
  }
}

data "digitalocean_ssh_key" "default" {
  name = var.ssh_key
}

locals {
  droplet_instances = {
    for pair in flatten([
      for vpc in values(module.multi_region_vpc.vpc_details) : [
        for i in range(var.droplet_count) : {
          key       = "${vpc.region}-${i + 1}"
          region    = vpc.region
          vpc_uuid  = vpc.id
          droplet   = i
        }
      ]
    ]) : pair.key => {
      region   = pair.region
      vpc_uuid = pair.vpc_uuid
      droplet  = pair.droplet
    }
  }
}

resource "digitalocean_droplet" "web" {
  for_each = local.droplet_instances

  name     = "${var.name_prefix}-${each.value.region}-${each.value.droplet}"
  size     = var.droplet_size
  image    = var.droplet_image
  region   = each.value.region
  vpc_uuid = each.value.vpc_uuid
  ssh_keys = [data.digitalocean_ssh_key.default.fingerprint]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx ca-certificates curl gnupg

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker and Docker Compose
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker

    # Configure nginx
    echo "<h1>Welcome to Hivenetes - Region: ${each.value.region} - Droplet: ${each.value.droplet}</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = [var.name_prefix, "region:${each.value.region}"]
}