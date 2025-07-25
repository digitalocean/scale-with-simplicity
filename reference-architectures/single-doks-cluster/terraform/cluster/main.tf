locals {
  tags = [
    "single-doks-cluster",
    var.name_prefix
  ]
}


resource "digitalocean_vpc" "doks" {
  name     = var.name_prefix
  region   = var.region
  ip_range = var.vpc_cidr
}

data "digitalocean_kubernetes_versions" "all" {}

# Retrieves the least expensive 2vCPU 4GB RAM Droplet
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

  sort {
    key       = "price_monthly"
    direction = "asc"
  }
}

resource "digitalocean_kubernetes_cluster" "primary_cluster" {
  name                             = var.name_prefix
  region                           = var.region
  version                          = data.digitalocean_kubernetes_versions.all.latest_version
  vpc_uuid                         = digitalocean_vpc.doks.id
  cluster_subnet                   = var.doks_cluster_subnet
  service_subnet                   = var.doks_service_subnet
  destroy_all_associated_resources = true
  ha                               = var.doks_control_plane_ha
  routing_agent {
    enabled = true
  }
  tags = local.tags
  node_pool {
    name       = "${var.name_prefix}-${data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug}"
    size       = data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug
    auto_scale = true
    min_nodes  = var.doks_node_pool_min_nodes
    max_nodes  = var.doks_node_pool_max_nodes
    tags       = local.tags
  }
}