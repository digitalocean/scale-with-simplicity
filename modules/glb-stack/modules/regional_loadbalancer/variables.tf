variable "name" {
  description = "RLB Name"
  type        = string
}

variable "region" {
  description = "RLB Region"
  type        = string
}

variable "vpc_uuid" {
  description = "UUID of the VPC the RLB will attach to"
  type        = string
}

variable "lb_config" {
  description = "RLB config"
  type        = any
}
