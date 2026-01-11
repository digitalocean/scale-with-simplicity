locals {
  tags = [
    "doks-dbaas-observability",
    var.name_prefix
  ]
}


# Creates a Virtual Private Cloud (VPC) to provide a logically isolated network for the resources.
# All resources within this VPC can communicate with each other over a private network.
resource "digitalocean_vpc" "doks" {
  name     = var.name_prefix
  region   = var.region
  ip_range = var.vpc_cidr
}


# This data source retrieves a list of all available Kubernetes versions on DigitalOcean, so we can use the latest version for our cluster.
data "digitalocean_kubernetes_versions" "all" {}

# This data source finds the most cost-effective Droplet (Virtual Machine) size that meets specific criteria.
# Here, it's looking for a Droplet with 2 vCPUs and 4GB of memory in the specified region.
# The result is sorted by price to ensure the cheapest option is selected. This slug is then used in the Kubernetes node pool.
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

# This is the main resource that creates the DigitalOcean Kubernetes (DOKS) cluster.
resource "digitalocean_kubernetes_cluster" "primary_cluster" {
  name                             = var.name_prefix
  region                           = var.region
  version                          = data.digitalocean_kubernetes_versions.all.latest_version
  vpc_uuid                         = digitalocean_vpc.doks.id
  cluster_subnet                   = var.doks_cluster_subnet
  service_subnet                   = var.doks_service_subnet
  destroy_all_associated_resources = true
  ha                               = var.doks_control_plane_ha
  tags                             = local.tags
  node_pool {
    name       = "${var.name_prefix}-${data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug}"
    size       = data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug
    auto_scale = true
    min_nodes  = var.doks_node_pool_min_nodes
    max_nodes  = var.doks_node_pool_max_nodes
    tags       = local.tags
  }
}

### Managed Databases
# Creates a managed PostgreSQL database cluster for the 'AdService'.
resource "digitalocean_database_cluster" "adservice" {
  name                 = "${var.name_prefix}-adservice-pg"
  engine               = "pg"
  version              = "17"
  size                 = "db-s-1vcpu-1gb"
  region               = var.region
  node_count           = 1
  private_network_uuid = digitalocean_vpc.doks.id
  tags                 = local.tags
}

# Creates a managed Valkey database cluster for the 'CartService'.
# Valkey is an open-source, in-memory data structure store, often used as a database, cache, and message broker.
# It is a fork of Redis and is suitable for high-performance use cases like caching session data.
resource "digitalocean_database_cluster" "cart_service" {
  name                 = "${var.name_prefix}-cartservice-valkey"
  engine               = "valkey"
  version              = "8"
  size                 = "db-s-1vcpu-1gb"
  region               = var.region
  node_count           = 1
  private_network_uuid = digitalocean_vpc.doks.id
  tags                 = local.tags
}

# Bucket used store logs used by Loki
resource "digitalocean_spaces_bucket" "loki_logs" {
  name          = "${var.name_prefix}-loki-logs"
  region        = var.region
  force_destroy = true # Required for clean test teardown when bucket contains Loki data
}

