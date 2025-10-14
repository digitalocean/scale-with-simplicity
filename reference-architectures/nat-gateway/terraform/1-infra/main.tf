terraform {
  required_version = ">= 1.6.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
  }
}

provider "digitalocean" {
  token = var.do_token != null ? var.do_token : ""
}

resource "digitalocean_vpc" "this" {
  name     = var.vpc_name
  region   = var.region
  ip_range = "10.20.0.0/16"
}

resource "digitalocean_vpc_nat_gateway" "this" {
  region     = var.region
  vpc_id     = digitalocean_vpc.this.id
  name       = var.nat_gateway_name
  ip_reserve = true
}

resource "digitalocean_kubernetes_cluster" "this" {
  name     = var.cluster_name
  region   = var.region
  version  = var.k8s_version
  vpc_uuid = digitalocean_vpc.this.id

  routing_agent {
    enabled = true
  }

  node_pool {
    name       = "np-default"
    size       = var.node_size
    node_count = var.node_count
  }
}

locals {
  cloud_init = <<-CLOUD
  #cloud-config
  package_update: false
  package_upgrade: false
  runcmd:
    - original_gw=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/gateway || true)
    - if [ -n "$original_gw" ]; then ip route add 169.254.169.254 via $${original_gw} dev eth0 || true; fi
    - ip route replace default via ${digitalocean_vpc_nat_gateway.this.gateway_address}
    - netplan apply || true
  CLOUD
}

resource "digitalocean_droplet" "this" {
  name       = var.droplet_name
  region     = var.region
  size       = var.droplet_size
  image      = var.droplet_image
  vpc_uuid   = digitalocean_vpc.this.id
  user_data  = local.cloud_init
  backups    = false
  ipv6       = false
  monitoring = true
  tags       = ["ra-nat-example"]
}
