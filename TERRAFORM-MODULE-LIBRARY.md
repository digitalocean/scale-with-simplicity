# Terraform Module Library

Reusable Terraform modules are located in the `modules/` directory. Reference Architectures in this repository use these modules to implement common infrastructure patterns.

See each module's README for detailed usage instructions.

## Available Modules

| Module | Description | Location |
|--------|-------------|----------|
| glb-stack | Create a Global Load Balancer and Regional Load Balancers | [modules/glb-stack](./modules/glb-stack) |
| ipsec-gateway | Creates a Droplet configured as an IPSec VPN Gateway | [modules/ipsec-gateway](./modules/ipsec-gateway) |
| multi-region-vpc | Creates two or more VPCs in a fully-meshed peering configuration | [modules/multi-region-vpc](./modules/multi-region-vpc) |
| partner-network-connect-aws | Connects DO VPCs with AWS VPC using Partner Network Connect via Megaport | [modules/partner-network-connect-aws](./modules/partner-network-connect-aws) |

## Usage

Reference modules using relative paths from your Terraform configuration:

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

## Deprecated

The following external module repositories have been deprecated and consolidated into this repository:

- `terraform-digitalocean-droplet-internet-gateway` - Replaced by the [nat-gateway](./reference-architectures/nat-gateway) reference architecture
