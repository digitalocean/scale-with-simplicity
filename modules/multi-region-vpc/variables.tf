variable "name_prefix" {
  description = "prefix used for the resources created in this module"
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

