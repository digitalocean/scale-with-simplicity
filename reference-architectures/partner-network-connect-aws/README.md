# End-to-End DO VPC to AWS VPC Connection with HA Support

This Terraform module provisions a complete, highly available (HA) end-to-end connection between a DigitalOcean VPC and an AWS VPC using the `terraform-digitalocean-partner-network-connect-aws` child module.

## Architecture Overview

<img src="./partner-network-connect-aws.png" width="700">

1. **DigitalOcean Side**
    * A DigitalOcean VPC and Kubernetes cluster (DOKS).
    * Two Partner Network Connect (PNC) attachments (red and optional blue) created via Megaport Cloud Router (MCR) and Virtual Cross Connects (VXCs).

2. **AWS Side**
    * An AWS VPC, subnets, and Virtual Gateway.
    * Two Direct Connect Hosted Private Virtual Interface Accepters, one per PNC attachment for HA.

3. **Test EC2 Instance & DOKS Route**
    * A t4g.nano EC2 instance for connectivity testing.

## Submodules Used

### [terraform-digitalocean-partner-network-connect-aws](https://github.com/digitalocean/terraform-digitalocean-partner-network-connect-aws)
This module provisions private connectivity between DigitalOcean and AWS using Megaport’s global network. It handles:

- Provisioning a **Megaport Cloud Router (MCR)** in a chosen Megaport location
- Creating a **Virtual Cross Connect (VXC)** between the MCR and AWS’s **Virtual Private Gateway (VGW)**
- Configuring **BGP peering** between the DigitalOcean side and AWS side using user-supplied tunnel IPs and a shared BGP secret
- Setting up **redundancy zones** (e.g. red/blue) with optional high availability support
- Linking additional connections to the primary (via `parent_uuid`) for HA topologies
- Tagging and route propagation compatible with both clouds

### [terraform-aws-modules/vpn-gateway](https://registry.terraform.io/modules/terraform-aws-modules/vpn-gateway/aws/latest)
This module automates the creation of a VPN connection on AWS and associates it with:
- A Virtual Private Gateway
- A Customer Gateway pointing to the DigitalOcean VPN public IP
- Static routes between the VPC and remote CIDR

## Prerequisites

* Terraform v1.2+ installed
* DigitalOcean API Token
* AWS IAM credentials for VPC, EC2, and Direct Connect resources
* Megaport API Key with purchase permissions
* `doctl`, and `kubectl` for to perform ping test (optional)

## Inputs

| Name                      | Description                                                                             | Type     | Default | Required |
| ------------------------- | --------------------------------------------------------------------------------------- | -------- | ------- |----------|
| `name_prefix`             | Prefix for all resource names                                                           | `string` | n/a     | yes      |
| `do_region`               | DigitalOcean region slug (no trailing digit, e.g. `sfo`)                                | `string` | n/a     | yes      |
| `doks_cluster_subnet`     | CIDR block for the DOKS cluster subnet                                                  | `string` | n/a     | yes      |
| `doks_service_subnet`     | CIDR block for DOKS service subnet                                                      | `string` | n/a     | yes      |
| `mp_contract_term_months` | Megaport contract term in months (1, 12, 24, 36)                                        | `number` | `1`     | no       |
| `mp_do_location_red`      | Megaport location for DO VXC & MCR in the Red redundancy zone                           | `string` | n/a     | yes      |
| `mp_aws_location_red`     | Megaport location for AWS VXC in the Red redundancy zone                                | `string` | n/a     | yes      |
| `ha_enabled`              | Enable HA (deploy Blue redundancy zone)                                                 | `bool`   | `false` | no       |
| `mp_do_location_blue`     | Megaport location for DO VXC & MCR in the Blue redundancy zone (when HA enabled)        | `string` | n/a     | no       |
| `mp_aws_location_blue`    | Megaport location for AWS VXC in the Blue redundancy zone (when HA enabled)             | `string` | n/a     | no       |
| `aws_region`              | AWS region (e.g. `us-east-1`)                                                           | `string` | n/a     | yes      |
| `aws_vpc_cidr`            | CIDR block for the AWS VPC                                                              | `string` | n/a     | yes      |
| `aws_region_full_name`    | AWS Region name as shown in Megaport console (e.g. `US East (N. Virginia) (us-east-1)`) | `string` | n/a     | yes      |

See the [README](https://github.com/digitalocean/terraform-digitalocean-partner-network-connect-aws/blob/main/README.md) for `terraform-digitalocean-partner-network-connect-aws` module for guidance on how to find the values for the `mp_do_location_red` and `mp_aws_location_red` inputs.

## Outputs

| Name                           | Description                                                         |
| ------------------------------ | ------------------------------------------------------------------- |
| `aws_instance_ip`              | Private IP of the t4g.nano EC2 instance used for testing            |
| `kubeconfig_save_command`      | `doctl` command to configure `kubectl` for the created DOKS cluster |
| `ping_test_command`            | `kubectl` command to run a pod that pings the EC2 instance          |
| `partner_attachment_uuid_red`  | UUID of the Red PNC attachment                                      |
| `partner_attachment_uuid_blue` | UUID of the Blue PNC attachment (null if HA disabled)               |

## Validation

After running `terraform apply`, the module will output three key values that will look like the following. The values here are for example and yours might look a bit different.


```
aws_instance_ip = "192.168.0.108"
kubeconfig_save_command = "doctl kubernetes cluster kubeconfig save pnc-test"
ping_test_command = "kubectl run -it --rm test-pod --image=nicolaka/netshoot -- ping 192.168.0.108"
```

Assuming you have doctl, and kubectl installed you can copy the command output of `kubeconfig_save_command` into your terminal to configure connection to DOKS cluster. Then you can copy and paste the output of the `ping_test_command` into your terminal and it will deploy a pod and run a ping to the EC2 instance.
