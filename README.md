# Scale With Simplicity

This repo contains reference architectures developed by DigitalOcean to help users understand how to leverage DigitalOcean Services for specific use cases. Each reference architecture is provided as a Terraform module, allowing you to deploy and test to facilitate learning and rapid development. These reference architecture modules leverage our [Terraform Module Library](./TERRAFORM-MODULE-LIBRARY.md), which contains reusable Terraform modules addressing specific components of the architectures.

**Note**: While these reference architectures are fully functional, they are intended to be used as a reference. Please validate any configuration for your own use case.

---

## Reference Architectures

| Name                                                                                               | Use Case                                                                                                                            | Periodic Validation | YouTube Video |
|----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|---------------------|---------------|
| [DOKS and DBaaS Observability](./reference-architectures/doks-dbaas-observability)                 | Observability for DOKS workloads and managed databases using Prometheus, Grafana, and Loki                         | Yes                 | Coming Soon |
| [Globally Load Balanced Web Servers](./reference-architectures/globally-load-balanced-web-servers) | Load balanced web servers deployed into multiple regions with a global load balancer directing users to the region closest to them. | Yes                 | [Watch Tutorial](https://youtu.be/JRmCjIuOc4o?feature=shared) |
| [NAT Gateway](./reference-architectures/nat-gateway)                                               | Route all egress traffic from DOKS cluster and Droplets through a NAT Gateway, providing a single static IP for outbound connectivity | Yes                 | Coming Soon |
| [Partner Network Connect with AWS](./reference-architectures/partner-network-connect-aws)          | End-to-End connection between DO VPC and AWS VPC using Partner Network Connect with HA support                                      | No                  | Coming Soon |
| [Site to Site VPN with AWS](./reference-architectures/site-to-site-vpn-aws)                        | IPSec VPN Gateway Droplet connecting DO VPC and DOKS cluster with AWS VPC                                                           | No                  | [Watch Tutorial](https://youtu.be/TCELPPiaI20?feature=shared) |

Reference architectures deployed entirely on DigitalOcean are validated periodically (typically daily) to ensure they work as intended. Multi-cloud architectures are not validated via periodic testing but are verified using static analysis and unit testing when updates are made.

---

## Getting Started

This section helps beginners set up Terraform and DigitalOcean access.

1. [Install Terraform](https://developer.hashicorp.com/terraform/downloads)
2. Export your DigitalOcean token:
   ```bash
   export DIGITALOCEAN_ACCESS_TOKEN="your_token_here"
   ```
3. Clone this repo and navigate to the desired reference architecture.
4. Create a `terraform.tfvars` file with required inputs.

Example:
```hcl
region         = "nyc3"
droplet_count  = 3
image          = "ubuntu-20-04-x64"
```

---

## How to Deploy

A typical way to deploy for testing purposes would be to:

- Ensure you have your DigitalOcean [Personal Access Token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) set in the `DIGITALOCEAN_TOKEN` environment variable.
- Clone the repo.
- `cd` into the `terraform` directory within the reference architecture you want to test.
  - **Note**: Some reference architectures use multiple Terraform stacks (e.g., `terraform/1-infra/`, `terraform/2-routes/`) to handle dependencies between resources. These must be deployed sequentially, starting with stack 1. Check the reference architecture's README for specific deployment instructions.
- Create a `tfvars` file with the inputs needed for the reference architecture module.
- Run:
  ```bash
  terraform init
  terraform plan -var-file=<path to tfvars file>
  terraform apply -var-file=<path to tfvars file>
  ```
- Test your deployment.
- When done, destroy the resources in reverse order (for multi-stack architectures, destroy the highest numbered stack first):
  ```bash
  terraform destroy -var-file=<path to tfvars file>
  ```

If you wish to use the reference architecture as a basis for your own deployment, it's recommended to copy the Terraform files to your own repo and customize them for your needs.
