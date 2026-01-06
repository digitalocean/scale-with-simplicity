variable "name_prefix" {
  type        = string
  description = "Prefix for load balancer names"
}

variable "target_load_balancer_ids" {
  description = "Ids of the RLB which the GLB will point to"
  type        = list(string)
}

variable "glb_config" {
  description = "GLB Config"
  type        = any
}
