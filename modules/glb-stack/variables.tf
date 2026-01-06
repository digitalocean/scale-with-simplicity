variable "name_prefix" {
  description = "Prefix used for load balancer names"
  type        = string
}

variable "vpcs" {
  description = "List of vpc config details"
  type = list(object({
    region   = string
    vpc_uuid = string
  }))
  validation {
    condition     = length(var.vpcs) > 0
    error_message = "Please Specify at least one VPC configuration."
  }
}

variable "region_dns_records" {
  description = "If set then a dns record for each region LB will be created"
  type        = bool
  default     = false
}

variable "regional_lb_config" {
  description = "Common load balancer configuration to apply in all regions"
  type        = any

  validation {
    condition = (
      !contains(keys(var.regional_lb_config), "type") ||
      contains(["REGIONAL", "REGIONAL_NETWORK"], lookup(var.regional_lb_config, "type", ""))
    )
    error_message = "If provided, common_config.type must be either \"REGIONAL\" or \"REGIONAL_NETWORK\"."
  }
}

variable "global_lb_config" {
  description = "GLB config"
  type        = any
  validation {
    condition = (
      !contains(keys(var.global_lb_config), "type") ||
      contains(["GLOBAL"], lookup(var.global_lb_config, "type", ""))
    )
    error_message = "If provided, common_config.type must be \"GLOBAL\"."
  }
  validation {
    condition     = !contains(keys(var.global_lb_config), "target_load_balancer_ids")
    error_message = "The key 'target_load_balancer_ids' is not allowed in global_lb_config as it will be set dynamically."
  }
  validation {
    condition = (
      contains(keys(var.global_lb_config), "domains") &&
      length(lookup(var.global_lb_config, "domains", [])) == 1
    )
    error_message = "global_lb_config.domains must contain exactly one domain object."
  }
}
