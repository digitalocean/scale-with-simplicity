locals {
  setup_vpn_script          = file("${path.module}/setup-vpn.sh")
  setup_vpn_script_indented = join("\n", [for line in split("\n", local.setup_vpn_script) : "      ${line}"])
}


resource "digitalocean_droplet" "vpn_gateway" {
  image      = var.image
  name       = var.name
  size       = var.size
  monitoring = var.monitoring
  ssh_keys   = var.ssh_keys
  region     = var.region
  vpc_uuid   = var.vpc_id
  tags       = var.tags
  user_data = templatefile("${path.module}/cloud-init-template.yaml", {
    vpn_psk              = var.vpn_psk
    vpn_tunnel_cidr      = var.vpn_tunnel_cidr_bits
    do_vpn_public_ip     = var.do_vpn_public_ip
    do_vpn_tunnel_ip     = var.do_vpn_tunnel_ip
    remote_vpn_public_ip = var.remote_vpn_public_ip
    remote_vpn_tunnel_ip = var.remote_vpn_tunnel_ip
    remote_vpn_cidr      = var.remote_vpn_cidr
    setup_vpn_script     = local.setup_vpn_script_indented
  })
}

resource "digitalocean_reserved_ip_assignment" "reserved_ip_assignment" {
  ip_address = var.do_vpn_public_ip
  droplet_id = digitalocean_droplet.vpn_gateway.id
}

resource "digitalocean_firewall" "vpn_fw" {
  name        = var.name
  droplet_ids = [digitalocean_droplet.vpn_gateway.id]
  inbound_rule {
    protocol         = "tcp"
    port_range       = "1-65535"
    source_addresses = var.allowed_firewall_cidrs
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "1-65535"
    source_addresses = var.allowed_firewall_cidrs
  }
  inbound_rule {
    protocol         = "icmp"
    source_addresses = var.allowed_firewall_cidrs
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "1-65535"
    source_addresses = [var.remote_vpn_public_ip]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}