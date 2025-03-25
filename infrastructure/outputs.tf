# ============================== DO Droplets & Networking ==========================
output "droplet_ips" {
  value = {
    for droplet in digitalocean_droplet.web :
    droplet.name => droplet.ipv4_address
  }
}

output "regional_lb_ips" {
  value = {
    for lb in digitalocean_loadbalancer.regional :
    lb.name => lb.ip
  }
}

output "domain" {
  value = data.digitalocean_domain.default
}


# ============================== DO Relational Database ==========================

output "database_clusters" {
  value = merge(
    { (var.regions[0]) = {
      id       = digitalocean_database_cluster.primary.id
      host     = digitalocean_database_cluster.primary.host
      port     = digitalocean_database_cluster.primary.port
      user     = "doadmin"
      password = digitalocean_database_cluster.primary.password
      region   = digitalocean_database_cluster.primary.region
      name     = digitalocean_database_cluster.primary.name
    } },
    { for idx, replica in digitalocean_database_replica.cross_region : var.regions[idx + 1] => {
      id       = replica.id
      host     = replica.host
      port     = replica.port
      user     = "doadmin"
      password = digitalocean_database_cluster.primary.password
      region   = replica.region
      name     = replica.name
    } }
  )
  sensitive = true
}


# ============================== DO Spaces ==========================


# output "spaces" {
#   value = {
#     for space in digitalocean_spaces_bucket.regional :
#     space.name => {
#       name   = space.name
#       region = space.region
#     }
#   }
# }

# output "spaces_by_region" {
#   value = {
#     for idx, space in digitalocean_spaces_bucket.regional : var.regions[idx] => {
#       name     = space.name
#       region   = space.region
#       endpoint = "https://${space.name}.${space.region}.digitaloceanspaces.com"
#     }
#   }
# }

# VPC Outputs
output "vpcs" {
  value = {
    for vpc in digitalocean_vpc.regional :
    vpc.region => {
      id         = vpc.id
      name       = vpc.name
      ip_range   = vpc.ip_range
      region     = vpc.region
      created_at = vpc.created_at
    }
  }
}
