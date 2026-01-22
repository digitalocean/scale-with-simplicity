variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "region" {
  type        = string
  description = "DigitalOcean region for deployment (must have H100 GPU Droplets and Managed NFS)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
}

variable "doks_cluster_subnet" {
  type        = string
  description = "CIDR block for DOKS cluster subnet"
}

variable "doks_service_subnet" {
  type        = string
  description = "CIDR block for DOKS service subnet"
}

variable "nfs_size_gb" {
  type        = number
  default     = 200
  description = "Size of NFS share in GB for model storage"
}

variable "gpu_node_count" {
  type        = number
  default     = 0
  description = "Number of H100 GPU nodes in the GPU node pool"
}

variable "doks_control_plane_ha" {
  type        = bool
  default     = false
  description = "Enable high availability for DOKS control plane"
}

variable "doks_surge_upgrade" {
  type = bool
  # When enabled additional nodes are added to a node pool prior to the upgrade. 
  # This is not always desirable or possible when using GPU systems, especially when you have a contracted amount.
  default     = false
  description = "Enable Surge Upgrades"
}

variable "management_node_pool_min_nodes" {
  type        = number
  default     = 1
  description = "Minimum number of nodes in management node pool"
}

variable "management_node_pool_max_nodes" {
  type        = number
  default     = 3
  description = "Maximum number of nodes in management node pool"
}
