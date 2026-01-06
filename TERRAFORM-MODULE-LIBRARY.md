# Terraform Module Library

Reusable Terraform modules are located in the `modules/` directory. Reference Architectures in this repository use these modules to implement common infrastructure patterns.

## How to Use These Modules

These modules are **reference implementations** intended to be copied into your own Terraform project. They are not versioned published modules.

**To use a module:**
1. Copy the module directory (e.g., `modules/glb-stack/`) into your project
2. Reference it with a relative path in your Terraform configuration
3. Customize as needed for your requirements

**Why copy instead of referencing from GitHub?**
- **No version pinning** - Changes to this repository could unexpectedly affect your infrastructure on the next `terraform apply`
- **Large repository** - Referencing from GitHub clones the entire repository including all reference architectures, images, and test files
- **Reference implementations** - These modules are maintained as working examples, not as stable published APIs

See each module's README for detailed configuration options.

## Available Modules

| Module | Description | Location |
|--------|-------------|----------|
| glb-stack | Create a Global Load Balancer and Regional Load Balancers | [modules/glb-stack](./modules/glb-stack) |
| ipsec-gateway | Creates a Droplet configured as an IPSec VPN Gateway | [modules/ipsec-gateway](./modules/ipsec-gateway) |
| multi-region-vpc | Creates two or more VPCs in a fully-meshed peering configuration | [modules/multi-region-vpc](./modules/multi-region-vpc) |
| partner-network-connect-aws | Connects DO VPCs with AWS VPC using Partner Network Connect via Megaport | [modules/partner-network-connect-aws](./modules/partner-network-connect-aws) |

## Usage Within This Repository

Reference Architectures in this repository reference modules using relative paths:

```hcl
module "multi_region_vpc" {
  source      = "../../../modules/multi-region-vpc"
  name_prefix = var.name_prefix
  vpcs        = var.vpcs
}
```

The relative path depends on your Terraform directory depth. For reference architectures at `reference-architectures/<ra-slug>/terraform/`, the path is `../../../modules/<module-name>`.

## Running Module Tests

Each module includes unit tests:

```bash
cd modules/<module-name>
make lint        # Run terraform validate, fmt, tflint
make test-unit   # Run unit tests
```

