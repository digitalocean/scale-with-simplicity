output "vpc_id" {
  value = digitalocean_vpc.this.id
}

output "nat_gateway_gateway_ip" {
  description = "Private VPC gateway IP; use in Route and Droplet default route."
  value       = digitalocean_vpc_nat_gateway.this.gateway_address
}

output "nat_gateway_public_ip" {
  description = "Static public egress IP for verification."
  value       = digitalocean_vpc_nat_gateway.this.ip_address
}

output "cluster_id"   { value = digitalocean_kubernetes_cluster.this.id }
output "cluster_name" { value = digitalocean_kubernetes_cluster.this.name }
output "droplet_private_ip" { value = digitalocean_droplet.this.ipv4_address_private }
