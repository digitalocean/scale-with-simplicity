variable "name_prefix" {
  description = "Name Prefix to use for the resources created by this module"
  type        = string
}

variable "do_region" {
  description = "DO region slug without the number that will specify where the Partner Network Connect will be created. For example if you have a VPC in 'sfo3' then this would just be 'sfo'"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z]{3}$", var.do_region))
    error_message = "Value must be exactly 3 alphabetic characters (e.g., 'sfo', 'nyc', 'lon')."
  }
}

variable "parent_uuid" {
  description = "The UUID of an existing Partner Network Connect. If this is specified then the Partner Network Connects will be configured in an HA configuration."
  type        = string
  default     = null
}

variable "mp_contract_term_months" {
  description = "The term of the Megaport contract in months: valid values are 1, 12, 24, and 36. Set to 1 for a month-to-month contract with no minimum term."
  type        = number
  validation {
    condition     = contains([1, 12, 24, 36], var.mp_contract_term_months)
    error_message = "mcr_port_bandwidth_in_mbps must be one of: 1000, 2500, 5000, or 10000."
  }
}

variable "mcr_port_bandwidth_in_mbps" {
  description = "The port speed of the MCR used for this connection. This bandwidth is shared between both VCX used in this connection. If you want to support full bidirectional rate than the port speed needs to be twice the speed of the VXCs"
  type        = number
  validation {
    condition     = contains([1000, 2500, 5000, 10000], var.mcr_port_bandwidth_in_mbps)
    error_message = "mcr_port_bandwidth_in_mbps must be one of: 1000, 2500, 5000, or 10000."
  }
}

variable "vxc_bandwidth_in_mbps" {
  description = "MBps to support for the the VXCs from the MCR to DO and AWS"
  type        = number
  validation {
    condition     = var.vxc_bandwidth_in_mbps <= var.mcr_port_bandwidth_in_mbps
    error_message = "vxc_bandwidth_in_mbps must not exceed mcr_port_bandwidth_in_mbps."
  }
}

variable "mp_do_location" {
  description = "The Megaport location name that is used for the MCR and DO VXC in the Red Redundancy Zone."
  type        = string
}

variable "mp_aws_location" {
  description = "The Megaport location name that is used for AWS VXC in the Red Redundancy Zone"
  type        = string
}

variable "aws_region_full_name" {
  description = "The name of an AWS Region as it appears in the Megaport console such as 'US East (N. Virginia) (us-east-1)'."
  type        = string
}

variable "aws_vgw_id" {
  description = "The Id of the AWS Virtual Gateway that will be used to terminate the AWS side of the connection."
  type        = string
}

variable "do_vpc_ids" {
  description = "A list of VPC Ids within the specified region that will be connected with the Partner Network Connect"
  type        = list(string)
}

variable "bgp_password" {
  description = "Password used for the BGP Password between DO and Megaport"
  type        = string
  validation {
    condition = (
      length(var.bgp_password) <= 25 &&
      can(regex("^[a-zA-Z0-9!@#.$%^&*+=\\-_]*$", var.bgp_password))
    )
    error_message = "bgp_password must be 25 characters or less and contain only alpha-numeric or these special characters: ! @ # . $ % ^ & * + = - _"
  }
}

variable "diversity_zone" {
  description = "The Megaport diversity zone used for this connection."
  type        = string
  validation {
    condition     = contains(["red", "blue"], var.diversity_zone)
    error_message = "diversity_zone must be either red or blue."
  }
}

variable "do_local_router_ip" {
  description = "A link local IP (169.254.0.0/16) address with CIDR to be used on the DO side of the Megaport connection"
  type        = string
  validation {
    condition = (
      can(regex("^169\\.254\\.(\\d{1,3})\\.(\\d{1,3})/([0-9]{1,2})$", var.do_local_router_ip)) &&
      can(cidrhost(var.do_local_router_ip, 0)) # ensures valid CIDR notation
    )
    error_message = "Value must be a valid CIDR in the 169.254.0.0/16 range (e.g., 169.254.100.1/30)."
  }
}

variable "do_peer_router_ip" {
  description = "A link local IP (169.254.0.0/16) address with CIDR to be used on the Megaport side of the Megaport connection"
  type        = string
  validation {
    condition = (
      can(regex("^169\\.254\\.(\\d{1,3})\\.(\\d{1,3})/([0-9]{1,2})$", var.do_peer_router_ip)) &&
      can(cidrhost(var.do_peer_router_ip, 0)) # ensures valid CIDR notation
    )
    error_message = "Value must be a valid CIDR in the 169.254.0.0/16 range (e.g., 169.254.100.1/30)."
  }
}

variable "aws_asn" {
  description = "AWS ASN"
  type        = number
  default     = 64512
}

variable "do_asn" {
  description = "DigitalOcean ASN"
  type        = number
  default     = 64532
}

variable "mp_asn" {
  description = "Megaport ASN"
  type        = number
  default     = 133937
}


