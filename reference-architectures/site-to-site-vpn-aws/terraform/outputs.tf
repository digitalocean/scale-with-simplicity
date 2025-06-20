output "vpn_gateway_ipv4_address_private" {
  description = "Private IP Address of the VPN Gateway Droplet"
  value       = module.do_vpn_droplet.vpn_gateway_ipv4_address_private
}