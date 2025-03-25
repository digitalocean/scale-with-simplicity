variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "DigitalOcean Project Name"
  type        = string
  default     = "meridian"
}

variable "domain" {
  description = "Domain for the load balancer"
  type        = string
  default     = "hivenetes.com"
}

variable "regions" {
  description = "Regions for deployment"
  type        = list(string)
  default     = ["ams3", "lon1", "nyc3"]
}

variable "droplet_size" {
  description = "Size of the droplets"
  type        = string
  default     = "c2-8vcpu-16gb" # CPU-Optimized 2x SSD
}

variable "droplet_image" {
  description = "Image for the droplets"
  type        = string
  default     = "ubuntu-20-04-x64"
}

# ===================== DigitalOcean Databases CONFIG VARS =======================

variable "database_cluster_name_prefix" {
  type        = string
  default     = "hb-db"
  description = "DigitalOcean Databases cluster name"
}

variable "database_cluster_engine" {
  type        = string
  default     = "pg" #postgres
  description = "DigitalOcean Databases cluster engine"
}

variable "database_cluster_size" {
  type        = string
  default     = "db-s-1vcpu-1gb"
  description = "DigitalOcean Databases cluster size"
}


variable "database_cluster_version" {
  type        = string
  default     = "16"
  description = "DigitalOcean Databases cluster version"
}

variable "database_cluster_node_count" {
  type        = number
  default     = 1
  description = "DigitalOcean Databases cluster node count"
}

# ===================== DigitalOcean Space CONFIG VARS =======================
# variable "spaces_access_id" {
#   type        = string
#   default     = ""
#   description = "DigitalOcean Spaces Access Key"
# }

# variable "spaces_secret_key" {
#   type        = string
#   default     = ""
#   description = "DigitalOcean Spaces Secret Key"
# }

# variable "space_region" {
#   type        = string
#   default     = "ams3"
#   description = "DigitalOcean Space region"
# }

# variable "space_name_prefix" {
#   type        = string
#   default     = "hb-space"
#   description = "Prefix for space names"
# }

# variable "space_regions" {
#   type        = list(string)
#   default     = ["ams3", "lon1", "nyc1"]
#   description = "Regions for spaces deployment"
# }