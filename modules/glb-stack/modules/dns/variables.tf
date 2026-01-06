variable "domain" {
  description = "Domain used for GLB and RLB records"
  type        = string
}

variable "region_lbs" {
  description = "RLB Configs"
  type = list(object({
    ip     = string
    region = string
  }))
}
