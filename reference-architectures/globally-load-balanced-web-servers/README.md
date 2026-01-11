# Globally Load Balanced Web Servers

A Terraform composition that bootstraps a **multi-region, highly available web front end** on DigitalOcean. It builds:

1. Peered **VPCs** in each region (fully meshed) so regional resources can talk privately.
2. **Regional Load Balancers (RLBs)** in front of web droplets in each region.
3. A **Global Load Balancer (GLB)** that fronts the regionals, providing anycast IPs, optional HTTPS offload, automatic failover, and a CDN.
4. **DNS records** for direct regional access (e.g., `nyc3.example.com`).
5. **Web droplets** in each region, bootstrapped with nginx + Docker and tagged for targeting by the load balancers.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#0069FF', 'primaryTextColor': '#333', 'primaryBorderColor': '#0069FF', 'lineColor': '#0069FF', 'secondaryColor': '#F3F5F9', 'tertiaryColor': '#fff', 'fontFamily': 'arial'}}}%%
flowchart TB
    subgraph Wrapper[" "]
        direction TB
        DNS(("DNS"))
        User(("User"))

        User --> GLB
        DNS -.-> GLB

        subgraph DO["DigitalOcean Cloud"]
            direction TB

            GLB["Global<br/>Load Balancer"]

            subgraph Region1["Region 1"]
                direction TB
                RLB1["Regional<br/>Load Balancer"]
                subgraph VPC1["VPC"]
                    direction LR
                    Web1A["Web"]
                    Web1B["Web"]
                end
            end

            subgraph Region2["Region 2"]
                direction TB
                RLB2["Regional<br/>Load Balancer"]
                subgraph VPC2["VPC"]
                    direction LR
                    Web2A["Web"]
                    Web2B["Web"]
                end
            end

            subgraph Region3["Region 3"]
                direction TB
                RLB3["Regional<br/>Load Balancer"]
                subgraph VPC3["VPC"]
                    direction LR
                    Web3A["Web"]
                    Web3B["Web"]
                end
            end
        end

        %% GLB to Regional LBs
        GLB --> RLB1
        GLB --> RLB2
        GLB --> RLB3

        %% Regional LBs to Web Droplets
        RLB1 --> Web1A
        RLB1 --> Web1B
        RLB2 --> Web2A
        RLB2 --> Web2B
        RLB3 --> Web3A
        RLB3 --> Web3B

        %% VPC Peering
        VPC1 <-.->|VPC<br/>Peering| VPC2
        VPC2 <-.->|VPC<br/>Peering| VPC3
        VPC1 <-.->|VPC<br/>Peering| VPC3
    end

    %% Styling - Subgraphs
    style Wrapper fill:#FFFFFF,stroke:#FFFFFF
    style DO fill:#E5E4E4,stroke:#0069FF,stroke-width:1px,stroke-dasharray:5
    style Region1 fill:#F3F5F9,stroke:#0069FF,stroke-width:1px
    style Region2 fill:#F3F5F9,stroke:#0069FF,stroke-width:1px
    style Region3 fill:#F3F5F9,stroke:#0069FF,stroke-width:1px
    style VPC1 fill:#C6DDFF,stroke:#0069FF,stroke-width:1px,stroke-dasharray:5
    style VPC2 fill:#C6DDFF,stroke:#0069FF,stroke-width:1px,stroke-dasharray:5
    style VPC3 fill:#C6DDFF,stroke:#0069FF,stroke-width:1px,stroke-dasharray:5

    %% Styling - Components
    style DNS fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style User fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style GLB fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style RLB1 fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style RLB2 fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style RLB3 fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style Web1A fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style Web1B fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style Web2A fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style Web2B fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style Web3A fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
    style Web3B fill:#F3F5F9,stroke:#0069FF,stroke-width:2px
```

## How it fits together

* The [multi-region-vpc](../../modules/multi-region-vpc) module creates two or more VPCs in different regions and peers them in a full mesh so that internal traffic can flow region-to-region securely.
* The [glb-stack](../../modules/glb-stack) module consumes those VPCs and:

    * Provisions one regional load balancer per region/VPC.
    * Exposes optional per-region DNS records for direct regional access.
    * Builds a global load balancer in front of the regionals with optional TLS termination, redirection, health checks, and CDN.
* Web droplets are created, tagged, and placed into each region; the regional load balancers target them via their tag.
* TLS, if enabled, is handled by issuing a Let's Encrypt certificate and wiring it into the forwarding rules for HTTPS.

## Prerequisites

* A DigitalOcean account with API access (e.g., via `DO_TOKEN` environment variable or provider configuration).
* Domain managed by DigitalOcean DNS if you want the module to manage the GLB hostname (`is_managed = true`).
* (Optional) An existing SSH key in DigitalOcean if you want SSH access to the droplets.

## Inputs

| Name            | Description                                                                                                                        | Type                                                   | Default | Required |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------- | -------- |
| `domain`        | Domain to use for the GLB and regional DNS records. Must be managed in DigitalOcean for `is_managed = true` to work.               | `string`                                               | n/a     | yes      |
| `name_prefix`   | Prefix applied to all created resources, used in naming and tagging to wire things together.                                       | `string`                                               | n/a     | yes      |
| `tls`           | If true, obtains a Let's Encrypt certificate and enables HTTPS (redirects and certificate usage) on the regional and global LBs.   | `bool`                                                 | `true`  | no       |
| `ssh_key`       | Name of an existing DigitalOcean SSH key to inject into droplets for access. Usually null in tests.                                | `string`                                               | `null`  | no       |
| `droplet_count` | Number of web droplets to create per region.                                                                                       | `number`                                               | `1`     | no       |
| `droplet_size`  | DigitalOcean droplet size slug (e.g., `s-1vcpu-1gb`).                                                                              | `string`                                               | n/a     | yes      |
| `droplet_image` | Image slug for droplets (e.g., `ubuntu-24-04-x64`).                                                                                | `string`                                               | n/a     | yes      |
| `vpcs`          | List of VPC definitions (region + IP range). At least two are required; they will be fully meshed via the multi-region VPC module. | `list(object({ region = string, ip_range = string }))` | n/a     | yes      |

## Outputs

| Name        | Description                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------ |
| `glb_fqdn`  | Fully qualified domain name of the global load balancer (the main domain).                       |
| `rlb_fqdns` | List of per-region FQDNs (e.g., `nyc3.example.com`) that resolve to each regional load balancer. |

## Submodules and Dependencies

### `multi-region-vpc`

Creates two or more VPCs in distinct regions and peers them together in a full mesh so that private/internal traffic can flow between regions without traversing the public internet. This provides the underlying network fabric for the regional droplets and their load balancers.

### `glb-stack`

Orchestrates the regional and global load balancing tier:

* One **Regional Load Balancer** per region/VPC, with forwarding rules, healthchecks, and droplet targeting via tags.
* A **Global Load Balancer** that fronts the regionals, offering anycast, failover, optional CDN, and TLS termination.
* Optional DNS records for direct regional access.

## Notes

* **TLS behavior**: when `tls = true`, the module requests a Let's Encrypt certificate via `digitalocean_certificate` and configures both regional and global forwarding to use HTTPS with automatic HTTP → HTTPS redirection.
* **Droplet bootstrapping** is done via `user_data`; it installs nginx and Docker to give a minimal working web endpoint.
* **Tagging**: droplets are tagged with `name_prefix` so the load balancers can discover and target them.

## Example variable definition snippet

```hcl
tls           = false
domain        = "test.fakedomain.tld"
name_prefix   = "glb-ws-test"
droplet_size  = "s-1vcpu-2gb"
droplet_image = "ubuntu-24-04-x64"
vpcs = [
  {
    region   = "nyc3",
    ip_range = "10.200.0.0/24"
  },
  {
    region   = "sfo3",
    ip_range = "10.200.1.0/24"
  },
  {
    region   = "ams3",
    ip_range = "10.200.2.0/24"
  }
]
```

## Further reading

* Multi-region VPC module README: [modules/multi-region-vpc](../../modules/multi-region-vpc)
* GLB stack module README: [modules/glb-stack](../../modules/glb-stack)
* DigitalOcean Load Balancer documentation for deeper understanding of forwarding rules, healthchecks, and TLS behavior: [https://docs.digitalocean.com/products/networking/load-balancers/](https://docs.digitalocean.com/products/networking/load-balancers/)
