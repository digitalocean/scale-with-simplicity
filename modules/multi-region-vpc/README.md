# multi-region-vpc

This module creates two or more VPCs in a fully meshed peering configuration.

# Example

> **Note:** This is a reference implementation. Copy this module into your project and reference it locally.
> See [Terraform Module Library](../../TERRAFORM-MODULE-LIBRARY.md) for guidance.

```terraform
module "vpc" {
  source      = "./modules/multi-region-vpc"  # Path after copying to your project
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


