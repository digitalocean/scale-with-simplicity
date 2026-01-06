## Terraform-digitalocean-ipsec-gateway

This Terraform module provisions a DigitalOcean Droplet and configures it as an IPSec VPN Gateway using strongSwan and cloud-init. The Droplet is set up to establish a site-to-site VPN tunnel with a remote peer, allowing secure routing of traffic between private networks.

### How It Works

1. **Droplet Provisioning**: The module creates a DigitalOcean Droplet with the specified image, size, region, VPC, SSH keys, and tags.
2. **Cloud-Init Orchestration**: A single `cloud-init` run performs all provisioning and configuration steps:
    * Installs required packages (`iptables-persistent`, `strongswan`, `ifupdown`, `curl`).
    * Generates strongSwan configuration files (`/etc/ipsec.d/vpn.conf`) and PSK secrets (`/etc/ipsec.secrets`).
    * Uploads and executes the VPN setup script (`setup-vpn.sh`), which:
        * Retrieves the Droplet’s Anchor IP and gateway via metadata.
        * Sets the default route through the Anchor IP gateway.
        * Enables IP forwarding and configures NAT for private networks.
        * Adjusts sysctl parameters for proper tunnel operation.
        * Creates the VTI tunnel interface (`Tunnel1`) and routes the remote CIDR.
    * Ensures NAT rules and network interfaces persist across reboots.&#x20;

### Important Details

* **Reserved IP Requirement**: A DigitalOcean Reserved IP must be created and used as the public IP (`do_vpn_public_ip`) for the VPN Droplet. Reserved IPs are managed separately from Droplet resources, allowing you to destroy or recreate the Droplet while retaining the same public IP. This ensures the remote peer configuration remains valid and provides operational flexibility.

* **Routing Configuration**: Other Droplets or DOKS nodes must be configured to route desired CIDRs via this VPN gateway. On DOKS, enable and configure the [DigitalOcean Routing Agent](https://docs.digitalocean.com/products/kubernetes/how-to/use-routing-agent/) to add routes automatically.

* **SSH Access**: You must create a firewall to allow access to allow SSH to the Droplet from outside the VPC.

* **Warning: Cloud-Init Changes**: Because the Droplet is provisioned and configured via `cloud-init`, any modification to the `cloud-init` template or related settings will trigger Droplet recreation. This changes the Droplet's private IP, requiring you to update all routes pointing to the VPN gateway. Examples of such changes include updating the PSK or modifying the remote CIDR.

### Usage Example

```hcl
module "vpn_gateway_droplet" {
  source               = "github.com/digitalocean/terraform-digitalocean-ipsec-gateway"

  # Droplet settings
  name                 = "prod-vgw"
  image                = "ubuntu-20-04-x64"
  size                 = "s-1vcpu-2gb"
  region               = "nyc3"
  vpc_id               = "0bcef6a5-0000-0000-0000-000000000000"
  ssh_keys             = [123456]
  tags                 = ["prod"]

  # VPN configuration
  do_vpn_public_ip     = "1.1.1.1"
  do_vpn_tunnel_ip     = "169.254.104.102"
  remote_vpn_public_ip = "2.2.2.2"
  remote_vpn_tunnel_ip = "169.254.104.101"
  remote_vpn_cidr      = "192.168.100.0/24"
  vpn_psk              = "ThisIsASecret"
}
```

### Inputs

| Name                     | Description                                                                                                              | Type           | Default                                             | Required |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------|----------------|-----------------------------------------------------|----------|
| `name`                   | Name of the Droplet                                                                                                      | `string`       | n/a                                                 | yes      |
| `image`                  | Droplet image slug (e.g., `ubuntu-24-04-x64`)                                                                            | `string`       | `ubuntu-24-04-x64`                                  | no       |
| `size`                   | Droplet size (e.g., `s-1vcpu-2gb`)                                                                                       | `string`       | n/a                                                 | yes      |
| `region`                 | DigitalOcean region (e.g., `nyc3`)                                                                                       | `string`       | n/a                                                 | yes      |
| `vpc_id`                 | VPC UUID to attach the Droplet                                                                                           | `string`       | n/a                                                 | yes      |
| `ssh_keys`               | List of SSH key IDs or fingerprints                                                                                      | `list(string)` | `[]`                                                | no       |
| `tags`                   | List of tags to assign to the Droplet                                                                                    | `list(string)` | `[]`                                                | no       |
| `do_vpn_public_ip`       | Reserved (public) IP for the VPN endpoint on DigitalOcean side.                                                          | `string`       | n/a                                                 | yes      |
| `do_vpn_tunnel_ip`       | Private VTI tunnel IP for the Droplet (e.g., `169.254.104.102`)                                                          | `string`       | n/a                                                 | yes      |
| `vpn_tunnel_cidr`        | CIDR mask bits for the tunnel interface (without slash)                                                                  | `string`       | `"30"`                                              | no       |
| `remote_vpn_public_ip`   | Public IP of the remote VPN endpoint                                                                                     | `string`       | n/a                                                 | yes      |
| `remote_vpn_tunnel_ip`   | Private VTI tunnel IP for the remote peer (e.g., `169.254.104.101`)                                                      | `string`       | n/a                                                 | yes      |
| `remote_vpn_cidr`        | Remote private network CIDR to route through the tunnel                                                                  | `string`       | n/a                                                 | yes      |
| `vpn_psk`                | Pre-shared key for IPSec authentication                                                                                  | `string`       | n/a                                                 | yes      |
| `allowed_firewall_cidrs` | CIDRs to allow through the firewall to the Droplet. Defaults to all private IP address ranges to support any VPC config. | `list(string)` | `["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]` | No       |

### Outputs

| Name                               | Description                                   |
| ---------------------------------- | --------------------------------------------- |
| `vpn_gateway_id`                   | ID of the created Droplet                     |
| `vpn_gateway_ipv4_address_private` | Private IP address of the VPN Gateway Droplet |

# Support

This Terraform module is provided as a reference implementation and must be fully tested in your own environment before using it in production. The Terraform Provider and its resources are supported, but this module itself is not officially supported.
