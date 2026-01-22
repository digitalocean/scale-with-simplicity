locals {
  tags = [
    "vllm-nfs",
    var.name_prefix
  ]
}

# Creates a Virtual Private Cloud (VPC) to provide a logically isolated network for the resources.
resource "digitalocean_vpc" "vllm" {
  name     = var.name_prefix
  region   = var.region
  ip_range = var.vpc_cidr
}

# Retrieves the latest available Kubernetes version on DigitalOcean.
data "digitalocean_kubernetes_versions" "all" {}

# Finds the most cost-effective Droplet size with 2 vCPUs and 4GB memory for management nodes.
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

# Creates the DigitalOcean Kubernetes (DOKS) cluster with management and GPU node pools.
resource "digitalocean_kubernetes_cluster" "vllm" {
  name                             = var.name_prefix
  region                           = var.region
  version                          = data.digitalocean_kubernetes_versions.all.latest_version
  vpc_uuid                         = digitalocean_vpc.vllm.id
  cluster_subnet                   = var.doks_cluster_subnet
  service_subnet                   = var.doks_service_subnet
  destroy_all_associated_resources = true
  ha                               = var.doks_control_plane_ha
  surge_upgrade                    = var.doks_surge_upgrade
  tags                             = local.tags

  # Management node pool for non-GPU workloads (router, system services)
  node_pool {
    name       = "${var.name_prefix}-mgmt-${data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug}"
    size       = data.digitalocean_sizes.slug_2vcpu_4gb.sizes[0].slug
    auto_scale = true
    min_nodes  = var.management_node_pool_min_nodes
    max_nodes  = var.management_node_pool_max_nodes
    tags       = local.tags
  }
}

# GPU node pool for vLLM workers running on H100 GPUs
resource "digitalocean_kubernetes_node_pool" "gpu" {
  cluster_id = digitalocean_kubernetes_cluster.vllm.id
  name       = "${var.name_prefix}-gpu-h100"
  size       = "gpu-h100x1-80gb"
  node_count = var.gpu_node_count
  tags       = local.tags
}

# NFS share for storing LLM model files.
resource "digitalocean_nfs" "models" {
  region = var.region
  name   = "${var.name_prefix}-models"
  size   = var.nfs_size_gb
  vpc_id = digitalocean_vpc.vllm.id
}
