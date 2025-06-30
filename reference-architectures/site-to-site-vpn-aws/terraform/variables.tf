variable "name_prefix" {
  description = "Name Prefix to use for the resources created by this module"
  type        = string
}

variable "do_region" {
  description = "DO region slug for the region the droplet will be deployed into"
  type        = string
}

variable "droplet_size" {
  description = "DO size slug used for the droplet"
  type        = string
}

variable "droplet_image" {
  description = "DO image slug to run on the droplet, must be ubuntu based."
  type        = string

  validation {
    condition     = startswith(var.droplet_image, "ubuntu")
    error_message = "The image slug must start with 'ubuntu'."
  }
}

variable "droplet_ssh_keys" {
  description = "A list of SSH key IDs to enable in the format [12345, 123456]"
  type        = list(number)
  default     = []
}

variable "aws_region" {
  description = "AWS Region Id in which the AWS VPC will be created"
  type        = string
}

variable "aws_vpc_cidr" {
  description = "CIDR to use for the AWS VPC"
  type        = string
}

variable "do_vpc_cidr" {
  description = "CIDR to use for the DO VPC"
  type        = string
}

variable "doks_cluster_subnet" {
  description = "CIDR for the DOKS Cluster Subnet"
  type        = string
}

variable "doks_service_subnet" {
  description = "CIDR for the DOKS Service Subnet"
  type        = string
}

variable "vpn_psk" {
  description = "Pre-shared key to use for the AWS Site-to-Site VPN connection. Must be 8 to 64 characters, and contain only alphanumeric characters, dots (.), or underscores (_), as required by AWS."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._]{8,64}$", var.vpn_psk))
    error_message = "The vpn_psk must be 8 to 64 characters and contain only letters, numbers, dots (.), or underscores (_), per AWS Site-to-Site VPN requirements."
  }
}