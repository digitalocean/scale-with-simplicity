# Scale With Simplicty
This repo contains reference architectures developed by DigitalOcean to allow our users to be able to understand how to leverage DigitalOcean Services to support specific use cases.  Each reference architecture is provided as a Terraform module allowing you to deploy and test to facilitate learning and rapid development. These reference architecture modules leverage our [Terraform Module Library](./TERRAFORM-MODULE-LIBRARY.md) which contain reusable Terraform Modules addressing specific components of the architectures.

**Note**: While these reference architectures are fully functional, they are intended to be used as a reference. Please make sure you validate any of the configuration for your own use case.

## Reference Architectures

| Name                                                                                               | Use Case                                                                                                                            | Periodic Validation | YouTube Video |
|----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|---------------------|---------------|
| [Globally Load Balanced Web Servers](./reference-architectures/globally-load-balanced-web-servers) | Load balanced web servers deployed into multiple regions with a global load balancer directing users to the region closest to them. | Yes                 | [Watch Tutorial](https://youtu.be/JRmCjIuOc4o?feature=shared) |
| [Partner Network Connect with AWS](./reference-architectures/partner-network-connect-aws)          | End-to-End connection between DO VPV and AWS VPC using Partner Network Connect with HA support                                      | No                  | Coming Soon |
| [Site to Site VPN with AWS](./reference-architectures/site-to-site-vpn-aws)                        | IPSec VPN Gateway Droplet connecting DO VPC and DOKS cluster with AWS VPC                                                           | No                  | [Watch Tutorial](https://youtu.be/TCELPPiaI20?feature=shared) |

Reference Architectures that are deployed entirely on DigitalOcean are deployed periodically (typically daily) and validated to ensure they work as intended. Multi-cloud architectures are typically not validated via periodic testing, but are still validated using static analysis and unit testing when new updates are made.

## How to Deploy
A typical way to deploy for testing purposes would be to:

- Ensure you have your DigitalOcean [Personal Access Token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) set in the `DIGITALOCEAN_TOKEN` environment variable.
- Clone the repo
- cd into the `terraform` directory within the reference architecture you want to test
- Create a `tfvars` file with the inputs needed for the reference architecture module.
- run `terrafrom init`
- run `terrafrom plan -var-file <path to tfvars file>`
- run `terrafrom apply -var-file <path to tfvars file>`
- Test
- run `terrafrom destroy -var-file <path to tfvars file>`

If you wish to use the reference architecture as a basis for your own deployment, it's recommended to copy the Terraform files to your own repo and customize them for your needs.

