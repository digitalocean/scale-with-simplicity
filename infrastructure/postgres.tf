# Add random suffix generator
resource "random_id" "db_suffix" {
  byte_length = 4
}

locals {
  database_cluster_name = "${var.database_cluster_name_prefix}-${var.database_cluster_engine}-${join("-", var.regions)}"
}

# Create primary database cluster in the first region
resource "digitalocean_database_cluster" "primary" {
  name       = "${var.database_cluster_name_prefix}-${var.database_cluster_engine}-${var.regions[0]}-${random_id.db_suffix.hex}"
  engine     = var.database_cluster_engine
  version    = var.database_cluster_version
  region     = var.regions[0]
  size       = var.database_cluster_size
  node_count = var.database_cluster_node_count
}

# Create read-only replicas in other regions
resource "digitalocean_database_replica" "cross_region" {
  count      = length(var.regions) - 1
  cluster_id = digitalocean_database_cluster.primary.id
  name       = "${var.database_cluster_name_prefix}-replica-${var.regions[count.index + 1]}"
  size       = var.database_cluster_size
  region     = var.regions[count.index + 1]
}

