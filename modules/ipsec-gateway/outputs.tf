output "vpn_gateway_id" {
  description = "Id of the created Droplet"
  value       = digitalocean_droplet.vpn_gateway.id
}

output "vpn_gateway_ipv4_address_private" {
  description = "Private IP Address of the VPN Gateway Droplet"
  value       = digitalocean_droplet.vpn_gateway.ipv4_address_private
}