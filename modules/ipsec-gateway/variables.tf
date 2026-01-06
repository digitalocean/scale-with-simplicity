variable "name" {
  description = "Name of the VPN GW Droplet"
  type        = string
}

variable "region" {
  description = "DO region slug for the region the droplet will be deployed into"
  type        = string
}

variable "size" {
  description = "DO size slug used for the droplet"
  type        = string
}

variable "image" {
  description = "DO image slug to run on the droplet, must be ubuntu based. Defaults to ubuntu-24-04"
  type        = string
  default     = "ubuntu-24-04-x64"

  validation {
    condition     = startswith(var.image, "ubuntu")
    error_message = "The image slug must start with 'ubuntu'."
  }
}

variable "monitoring" {
  description = "Whether monitoring agent is installed"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Id of the VPC which the Droplet is connected to"
  type        = string
}

variable "ssh_keys" {
  description = "A list of SSH key IDs to enable in the format [12345, 123456]"
  type        = list(number)
  default     = []
}

variable "tags" {
  description = "A list of the tags to be applied to this Droplet"
  type        = list(string)
  default     = []
}

variable "vpn_psk" {
  description = "pre-shared key used for the VPN tunnel"
  type        = string
  sensitive   = true
}

variable "vpn_tunnel_cidr_bits" {
  description = "Number of CIDR bits used for the tunnel subnet. Defaults to /30"
  type        = string
  default     = "30"
  validation {
    condition     = can(tonumber(var.vpn_tunnel_cidr_bits))
    error_message = "vpn_tunnel_cidr_bits must be a numeric string (e.g. \"30\"); \"/30\" is not allowed."
  }
}

variable "do_vpn_public_ip" {
  description = "The Public Reserved IP address of the IP that will be used as the VPN endpoint on the DO side. This is the 'outside' IP address of the DO side."
  type        = string
  validation {
    condition     = can(cidrnetmask(join("/", [var.do_vpn_public_ip, "32"])))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "do_vpn_tunnel_ip" {
  description = "The IP address of the IP that will be used as the Tunnel interface on the DO side. This is the 'inside' IP address of the DO side."
  type        = string
  validation {
    condition     = can(cidrnetmask(join("/", [var.do_vpn_tunnel_ip, "32"])))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "remote_vpn_public_ip" {
  description = "The Public IP address of the IP that will be used as the VPN endpoint on the remote side.This is the 'outside' IP address of the remote side."
  type        = string
  validation {
    condition     = can(cidrnetmask(join("/", [var.remote_vpn_public_ip, "32"])))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "remote_vpn_tunnel_ip" {
  description = "The IP address of the IP that will be used as the Tunnel interface on the remote side. This is the 'inside' IP address of the remote side."
  type        = string
  validation {
    condition     = can(cidrnetmask(join("/", [var.remote_vpn_tunnel_ip, "32"])))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "remote_vpn_cidr" {
  description = "The CIDR of the remote network reachable via the VPN"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.remote_vpn_cidr))
    error_message = "Must be a valid IPv4 CIDR."
  }
}

variable "allowed_firewall_cidrs" {
  description = "A list of the CIDRs on the DO Side which you which should be allowed by the Cloud Firewall to the VPN GW. Defaults to all RFC1918 CIDRS"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}
