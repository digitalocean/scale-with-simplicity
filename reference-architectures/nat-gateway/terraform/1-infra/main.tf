locals {
  tags = [
    "nat-gateway",
    var.name_prefix
  ]
}

# VPC
resource "digitalocean_vpc" "main" {
  name     = "${var.name_prefix}-vpc"
  region   = var.region
  ip_range = var.vpc_cidr
}

# NAT Gateway
resource "digitalocean_vpc_nat_gateway" "main" {
  name   = "${var.name_prefix}-nat-gw"
  type   = "PUBLIC"
  region = var.region
  size   = "1"

  vpcs {
    vpc_uuid = digitalocean_vpc.main.id
  }
}

# Data source to find the latest Ubuntu LTS image
data "digitalocean_images" "ubuntu" {
  filter {
    key    = "distribution"
    values = ["Ubuntu"]
  }

  filter {
    key    = "type"
    values = ["base"]
  }

  filter {
    key    = "regions"
    values = [var.region]
  }

  sort {
    key       = "created"
    direction = "desc"
  }
}

# Data source to find the most cost-effective Droplet size with 2 vCPUs and 4GB memory
data "digitalocean_sizes" "slug_2vcpu_4gb" {
  filter {
    key    = "vcpus"
    values = [2]
  }

  filter {
    key    = "memory"
    values = [4096]
  }

  filter {
    key    = "regions"
    values = [var.region]
  }

  filter {
    key    = "available"
    values = ["true"]
  }

  sort {
    key       = "price_monthly"
    direction = "asc"
  }
}


# DOKS Cluster with Routing Agent enabled
# NOTE: Using 1.33.6-do.0 to work around Routing Agent bug in 1.34.x
# TODO: Update to latest version when bug is fixed
resource "digitalocean_kubernetes_cluster" "main" {
  name           = "${var.name_prefix}-cluster"
  region         = var.region
  version        = "1.33.6-do.0"
  vpc_uuid       = digitalocean_vpc.main.id
  cluster_subnet = var.doks_cluster_subnet
  service_subnet = var.doks_service_subnet

  routing_agent {
    enabled = true
  }

  tags = local.tags

  node_pool {
    name       = "${var.name_prefix}-${data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug}"
    size       = data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug
    node_count = var.doks_node_count
    tags       = local.tags
  }
}

# Bastion droplet for SSH access to NAT-routed droplet
resource "digitalocean_droplet" "bastion" {
  image    = data.digitalocean_images.ubuntu.images[0].slug
  name     = "${var.name_prefix}-bastion"
  region   = var.region
  size     = data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = length(var.ssh_key_ids) > 0 ? var.ssh_key_ids : []
  tags     = concat(local.tags, ["bastion"])
}

# Droplet with cloud-init to route traffic through NAT Gateway
resource "digitalocean_droplet" "main" {
  image    = data.digitalocean_images.ubuntu.images[0].slug
  name     = "${var.name_prefix}-droplet"
  region   = var.region
  size     = data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = length(var.ssh_key_ids) > 0 ? var.ssh_key_ids : []
  tags     = concat(local.tags, ["private"])

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    nat_gateway_gateway_ip = one(digitalocean_vpc_nat_gateway.main.vpcs).gateway_ip
  })

  # Ensure NAT Gateway is created first
  depends_on = [digitalocean_vpc_nat_gateway.main]
}

# Firewall for bastion droplet - allows SSH from anywhere
resource "digitalocean_firewall" "bastion" {
  name = "${var.name_prefix}-bastion-fw"

  tags = ["bastion"]

  # Allow SSH from anywhere (public internet)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Firewall for private NAT-routed droplet - allows SSH only from RFC1918 addresses
resource "digitalocean_firewall" "private" {
  name = "${var.name_prefix}-private-fw"

  tags = ["private"]

  # Allow SSH only from RFC1918 private address spaces
  # This allows access from bastion, K8s clusters, and peered networks
  inbound_rule {
    protocol   = "tcp"
    port_range = "22"
    source_addresses = [
      "10.0.0.0/8",     # RFC1918 Class A
      "172.16.0.0/12",  # RFC1918 Class B
      "192.168.0.0/16", # RFC1918 Class C
    ]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
