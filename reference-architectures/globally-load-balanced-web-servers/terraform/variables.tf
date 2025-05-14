variable "domain" {
  description = "Domain to use for the GLB, plus optional RLB records. This domain must be DO managed."
  type        = string
}

variable "name_prefix" {
  description = "Name to use for the name prefix of the created resources."
  type        = string
}

variable "tls" {
  description = "If set to true will create an LetsEncrypt SSL cert and configure LBs to use TLS"
  type        = bool
  default     = true
}

variable "ssh_key" {
  description = "Name of an existing SSH Key that will be used to access the Droplet."
  type        = string
}

variable "droplet_count" {
  description = "number of droplets in each region"
  type        = number
  default     = 1
}

variable "droplet_size" {
  description = "Size of the droplets"
  type        = string
}

variable "droplet_image" {
  description = "Image used for the droplets"
  type        = string
}

variable "vpcs" {
  type = list(object({
    region   = string
    ip_range = string
  }))
  description = "List of VPC configurations"

  validation {
    condition     = length(var.vpcs) > 1
    error_message = "Please Specify more than one VPC configuration."
  }
}
