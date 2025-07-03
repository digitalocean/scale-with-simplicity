# Terraform Module Library
The Reference Architectures included in this repo leverage the reusable Terraform Modules published as part of our Terraform Module Library.

See README in each repo for how to use the module.

| Name                                               | Description                                                                | Repo URL                                                                           |                                                                                                                                                               
|----------------------------------------------------|----------------------------------------------------------------------------|------------------------------------------------------------------------------------| 
| terraform-digitalocean-droplet-internet-gateway    | Create IGW droplets and optional configure DOKS cluster with default route | https://github.com/digitalocean/terraform-digitalocean-droplet-internet-gateway    |
| terraform-digitalocean-glb-stack                   | Create a GLB and one or more RLBs                                          | https://github.com/digitalocean/terraform-digitalocean-glb-stack                   |
| terraform-digitalocean-ipsec-gateway               | Creates a Droplet and configures it as an IPSec VPN Gateway                | https://github.com/digitalocean/terraform-digitalocean-ipsec-gateway               |
| terraform-digitalocean-multi-region-vpc            | Creates two or more VPCs in a fully-meshed peering configuration           | https://github.com/digitalocean/terraform-digitalocean-multi-region-vpc            |
| terraform-digitalocean-partner-network-connect-aws | Connects one or more DO VPCs with an AWS VPC using Partner Network Connect | https://github.com/digitalocean/terraform-digitalocean-partner-network-connect-aws |