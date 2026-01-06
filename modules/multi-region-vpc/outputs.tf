output "vpc_details" {
  description = "Details of all created VPCs"
  value = {
    for k, v in digitalocean_vpc.vpc : k => {
      name   = v.name
      id     = v.id
      cidr   = v.ip_range
      region = v.region
    }
  }
}