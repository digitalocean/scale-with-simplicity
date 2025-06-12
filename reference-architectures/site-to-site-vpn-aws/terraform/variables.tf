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

variable "vpn_psk" {
  description = "Pre-shared key to use for the VPN connection"
  type        = string
  # Validation 8 to 64 characters, only include . _
}