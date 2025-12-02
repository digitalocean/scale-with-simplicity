output "vpc_id" {
  description = "ID of the VPC"
  value       = digitalocean_vpc.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = digitalocean_vpc_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP for outbound traffic (what external services see)"
  value       = one(one(digitalocean_vpc_nat_gateway.main.egresses).public_gateways).ipv4
}

output "nat_gateway_gateway_ip" {
  description = "VPC gateway IP for routing configuration"
  value       = one(digitalocean_vpc_nat_gateway.main.vpcs).gateway_ip
}

output "cluster_id" {
  description = "ID of the DOKS cluster"
  value       = digitalocean_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Name of the DOKS cluster"
  value       = digitalocean_kubernetes_cluster.main.name
}

output "bastion_public_ip" {
  description = "Public IP of the bastion droplet for SSH access"
  value       = digitalocean_droplet.bastion.ipv4_address
}

output "droplet_private_ip" {
  description = "Private IP of the droplet"
  value       = digitalocean_droplet.main.ipv4_address_private
}

output "droplet_public_ip" {
  description = "Public IP of the droplet"
  value       = digitalocean_droplet.main.ipv4_address
}

output "ubuntu_image" {
  description = "Ubuntu image slug used for droplets"
  value       = data.digitalocean_images.ubuntu.images[0].slug
}
