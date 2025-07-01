locals {
  aws_connection = try([for conn in megaport_vxc.aws.csp_connections : conn if conn.connect_type == "AWS"][0], null)
}

### DO

resource "digitalocean_partner_attachment" "megaport" {
  name                         = "${var.name_prefix}-${var.redundancy_zone}"
  connection_bandwidth_in_mbps = var.connection_bandwidth_in_mbps
  region                       = substr(var.do_region, 0, 3)
  naas_provider                = "MEGAPORT"
  redundancy_zone              = var.redundancy_zone == "red" ? "MEGAPORT_RED" : var.redundancy_zone == "blue" ? "MEGAPORT_BLUE" : var.redundancy_zone
  vpc_ids                      = var.do_vpc_ids
  bgp {
    local_router_ip = var.do_local_router_ip
    peer_router_asn = var.mp_asn
    peer_router_ip  = var.do_peer_router_ip
    auth_key        = var.bgp_password
  }
}

data "digitalocean_partner_attachment_service_key" "megaport" {
  attachment_id = digitalocean_partner_attachment.megaport.id
}

### MP

data "megaport_location" "do" {
  name = var.mp_do_location
}

data "megaport_location" "aws" {
  name = var.mp_aws_location
}

data "megaport_partner" "aws" {
  connect_type = "AWS"
  company_name = "AWS"
  product_name = var.aws_region_full_name
  location_id = data.megaport_location.aws.id
}

resource "megaport_mcr" "mcr" {
  product_name         = "${var.name_prefix}-${var.redundancy_zone}"
  port_speed           = var.connection_bandwidth_in_mbps
  location_id          = data.megaport_location.do.id
  contract_term_months = var.mp_contract_term_months
  diversity_zone       = var.redundancy_zone
}

resource "megaport_vxc" "do" {
  product_name         = "${var.name_prefix}-do-${var.redundancy_zone}"
  rate_limit           = var.connection_bandwidth_in_mbps
  contract_term_months = var.mp_contract_term_months
  service_key          = data.digitalocean_partner_attachment_service_key.megaport.value
  a_end = {
    requested_product_uid = megaport_mcr.mcr.product_uid
  }
  a_end_partner_config = {
    partner = "vrouter"
    vrouter_config = {
      interfaces = [
        {
          ip_addresses = [digitalocean_partner_attachment.megaport.bgp[0].peer_router_ip]
          bgp_connections = [{
            password         = digitalocean_partner_attachment.megaport.bgp[0].auth_key
            local_asn        = var.mp_asn
            local_ip_address = split("/", digitalocean_partner_attachment.megaport.bgp[0].peer_router_ip)[0]
            peer_asn         = var.do_asn
            peer_ip_address  = split("/", digitalocean_partner_attachment.megaport.bgp[0].local_router_ip)[0]
          }]
        }
      ]
    }
  }
  b_end = {}
}

resource "megaport_vxc" "aws" {
  product_name         = "${var.name_prefix}-aws-${var.redundancy_zone}"
  rate_limit           = var.connection_bandwidth_in_mbps
  contract_term_months = var.mp_contract_term_months

  a_end = {
    requested_product_uid = megaport_mcr.mcr.product_uid
  }

  b_end = {
    requested_product_uid = data.megaport_partner.aws.product_uid
  }

  b_end_partner_config = {
    partner = "aws"
    aws_config = {
      name          = "${var.name_prefix}-${var.redundancy_zone}"
      asn           = var.mp_asn
      amazon_asn    = var.aws_asn
      type          = "private"
      connect_type  = "AWS"
      owner_account = data.aws_caller_identity.current.account_id

    }
  }
}

## AWS
data "aws_caller_identity" "current" {}

resource "aws_dx_hosted_private_virtual_interface_accepter" "mp_vif" {
  virtual_interface_id = local.aws_connection.vif_id
  vpn_gateway_id       = var.aws_vgw_id
}
