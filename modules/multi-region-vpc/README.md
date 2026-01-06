# terraform-digitalocean-multi-region-vpc
This module creates two or more VPCs in a fully meshed peering configuration.

# Example
```terraform
module "vpc" {
  source      = "github.com/digitalocean/terraform-digitalocean-multi-region-vpc"
  name_prefix = "prod"
  vpcs = [
    {
      region     = "nyc3",
      ip_range   = "10.200.0.0/24"
    },
    {
      region     = "sfo3",
      ip_range   = "10.200.1.0/24"
    },
    {
      region     = "ams3",
      ip_range   = "10.200.2.0/24"
    }
  ]
}
```

# Support

This Terraform module is provided as a reference implementation and must be fully tested in your own environment before using it in production. The Terraform Provider and its resources are supported, but this module itself is not officially supported.


