# partner-network-connect-aws

A Terraform module to provision a [DigitalOcean Partner Network Connect](https://www.digitalocean.com/blog/partner-network-connect) between one or more DigitalOcean VPCs with an AWS VPC over Megaport, including:

* A DigitalOcean Partner Attachment connected to one or more VPCs in a specified region
* A Megaport Cloud Router (MCR) in your chosen Megaport location
* Two Megaport Virtual Cross Connects (VXCs): one to DigitalOcean, one to AWS via Hosted VIF
* An AWS Direct Connect Hosted Private Virtual Interface Accepter

## Important Details

* **API Keys**: Since this module configures resources in DigitalOcean, Megaport and AWS you will need API Keys/Tokens from all three providers. It is recommended these API Keys be provided via Environment Variables to minimize the chance of them accidentally being checked into your revision control system (e.g. Github).
* **Megaport Locations**: Determining the values for `mp_do_location`, `mp_aws_location` and `aws_region_full_name` can be a little tricky. To figure out the value for `mp_do_location` your best bet is to visit the [Megaport Enabled Locations](https://www.megaport.com/megaport-enabled-locations/) page, filter for "MCR-Enabled" locations and find a location near the DO region you wish to connect. The text in bold should be the value you are looking for. AWS is a bit trickier, and the suggested method is to use the Megaport Web UI to configure a new MCR and then add a VXC with AWS. When selecting the Hosted VIF the values in bold are used for `aws_region_full_name`. The Data Center name on the line with the city is the value for `mp_aws_location`. Delete the new MCR/VXC config once you have these values and DO NOT purchase it.
* **Megaport Terraform provider**: must be initialized in your root module (see example)
* **BGP IPs**: both `do_local_router_ip` and `do_peer_router_ip` must be valid CIDRs in the `169.254.0.0/16` range. Using subnets smaller than a `/29` can sometimes have issues, so recommended to stick to `/29`
* **Diversity zone mapping**: `"red"` ⇒ `MEGAPORT_RED`, `"blue"` ⇒ `MEGAPORT_BLUE`.


## Usage Example

> **Note:** This is a reference implementation. Copy this module into your project and reference it locally.
> See [Terraform Module Library](../../TERRAFORM-MODULE-LIBRARY.md) for guidance.

```hcl
# Inject the Megaport provider in your root module
provider "megaport" {
  environment           = "production"
  accept_purchase_terms = true
}

module "pnc" {
  source = "./modules/partner-network-connect-aws"  # Path after copying to your project

  name_prefix                = "test"
  do_region                  = "sfo"
  mp_contract_term_months    = 1
  mcr_port_bandwidth_in_mbps = 1000
  vxc_bandwidth_in_mbps      = 1000
  mp_do_location             = "Equinix SV1/10"
  mp_aws_location            = "CoreSite DE1"
  aws_region_full_name       = "US West (Denver) (us-west-2)"
  aws_vgw_id                 = "vgw-test123"
  do_vpc_ids                 = ["test123"]
  bgp_password               = "test123"
  diversity_zone             = "red"
  do_local_router_ip         = "169.254.0.1/29"
  do_peer_router_ip          = "169.254.0.6/29"
}
```

## Inputs

| Name                         | Description                                                                                                                                | Type           | Default  | Required |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|----------------|:--------:|:--------:|
| `name_prefix`                | Name prefix for all resources                                                                                                              | `string`       |   n/a    |   yes    |
| `do_region`                  | DO region slug **without** the trailing digit (e.g. use `sfo` for `sfo3`)                                                                  | `string`       |   n/a    |   yes    |
| `parent_uuid`                | UUID of an existing Partner Network Connect Attachment to configure HA                                                                     | `string`       |   n/a    |    no    |
| `mp_contract_term_months`    | Megaport contract term in months. Valid values: `1`, `12`, `24`, `36`                                                                      | `number`       |   n/a    |   yes    |
| `mcr_port_bandwidth_in_mbps` | Port speed of the Megaport Cloud Router (MCR). To achieve full bidirectional throughput, choose at least twice your desired VXC bandwidth. | `number`       |   n/a    |   yes    |
| `vxc_bandwidth_in_mbps`      | VXC bandwidth for both DO and AWS sides. Must be ≤ `mcr_port_bandwidth_in_mbps`                                                            | `number`       |   n/a    |   yes    |
| `mp_do_location`             | Megaport location name for the DO VXC & MCR (e.g. `"Digital Realty New York JFK12 (NYC1)"`)                                                | `string`       |   n/a    |   yes    |
| `mp_aws_location`            | Megaport location name for the AWS VXC (e.g. `"CoreSite NY1"`)                                                                             | `string`       |   n/a    |   yes    |
| `aws_region_full_name`       | AWS Region string as shown in the Megaport console (e.g. `"US East (N. Virginia) (us-east-1)"`)                                            | `string`       |   n/a    |   yes    |
| `aws_vgw_id`                 | ID of the AWS Virtual Gateway to terminate the DX connection                                                                               | `string`       |   n/a    |   yes    |
| `do_vpc_ids`                 | List of DigitalOcean VPC IDs to attach via the Partner Attachment                                                                          | `list(string)` |   n/a    |   yes    |
| `bgp_password`               | BGP auth password (≤ 25 chars; alphanumeric plus `! @ # . $ % ^ & * + = - _`)                                                              | `string`       |   n/a    |   yes    |
| `diversity_zone`             | Megaport diversity zone: must be either `"red"` or `"blue"`                                                                                | `string`       |   n/a    |   yes    |
| `do_local_router_ip`         | Link-local CIDR for the DO side of the VXC (must be in `169.254.0.0/16`, e.g. `"169.254.0.1/30"`)                                          | `string`       |   n/a    |   yes    |
| `do_peer_router_ip`          | Link-local CIDR for the Megaport side of the VXC (must be in `169.254.0.0/16`, e.g. `"169.254.0.6/30"`)                                    | `string`       |   n/a    |   yes    |
| `aws_asn`                    | AWS ASN (defaults to `64512`)                                                                                                              | `number`       | `64512`  |    no    |
| `do_asn`                     | DO ASN (defaults to `64532`)                                                                                                               | `number`       | `64532`  |    no    |
| `mp_asn`                     | Megaport ASN (defaults to `133937`)                                                                                                        | `number`       | `133937` |    no    |


## Outputs


| Name                      | Description                                                                     |
|---------------------------|---------------------------------------------------------------------------------|
| `partner_attachment_uuid` | The UUID of the Partner Network Connect Attachment. Needed when configuring HA. |

## Testing
This module uses data sources from DigitalOcean, AWS and Megaport, but we do not have an Megaport API Key available to our CI/CD system. This means that the normal `terraform plan` based testing used for testing Pull Requests is skipped. The test will show as passed, but the test is skipped unless both MEGAPORT_ACCESS_KEY and MEGAPORT_SECRET_KEY Env Vars are set. 

Please ensure you test any changes locally prior to create a PR with updates.

# Support

This Terraform module is provided as a reference implementation and must be fully tested in your own environment before using it in production. The Terraform Provider and its resources are supported, but this module itself is not officially supported.
