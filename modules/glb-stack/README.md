# terraform-digitalocean-glb-stack

A Terraform module that deploys:

* **Regional Load Balancers (LBs)** – one per region you supply.
* A **Global Load Balancer** that fronts the regional LBs and provides worldwide anycast IPs, automatic fail‑over, optional CDN, and HTTPS offload.
* **Optional DNS records** – A‑records that map each region’s two‑letter slug (e.g. `nyc3`) to the LB’s public IP so you can reach a region directly (`nyc3.example.com`).

# Example

```terraform
module "glb_stack" {
  source  = "github.com/digitalocean/terraform-digitalocean-glb-stack"

  name_prefix = "test"

  ## ――― Regional settings ―――
  regions = [
    {
      region   = "nyc3"
      vpc_uuid = "0bcef6a5-c2ed-466d-bedd-000000000000"
    },
    {
      region   = "sfo3"
      vpc_uuid = "b6ef6914-0412-495d-a3db-000000000000"
    },
    {
      region   = "ams3"
      vpc_uuid = "73abe0ad-ded0-4ce4-bb26-000000000000"
    }
  ]

  ## Create one A‑record per regional LB: nyc3.example.com ➜ 203.0.113.10, etc.
  region_dns_records = true

  ## ――― Per‑region load balancer config ―――
  regional_lb_config = {
    redirect_http_to_https = true

    forwarding_rule = {
      entry_port     = 443
      entry_protocol = "https"
      target_port    = 80
      target_protocol = "http"
    }

    healthcheck = {
      port     = 80
      protocol = "http"
      path      = "/"
    }

    droplet_tag = "test"
  }

  ## ――― Global load balancer config ―――
  global_lb_config = {
    redirect_http_to_https = true

    domains = [{
      name       = "test.do.com"   # the public hostname of the GLB
      is_managed = true            # create / manage the DO DNS zone
    }]

    glb_settings = {
      target_protocol = "https"
      target_port     = 443
      cdn = {
        is_enabled = true
      }
    }

    healthcheck = {
      port     = 443
      protocol = "https"
      path      = "/"
    }
  }
}
```

The example spins up three regional LBs (NYC3, SFO3, AMS3), builds a single GLB in front of them, and optionally creates `nyc3.test.do.com`, `sfo3.test.do.com`, and `ams3.test.do.com` DNS records that point at each regional LB.

# Inputs

| Name                 | Description                                                                                                                                                                                     | Type                                                   | Default | Required |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------- | :------: |
| `name_prefix`        | Prefix applied to all load balancer names (e.g. `test-nyc3`).                                                                                                                                   | `string`                                               | n/a     |  **yes** |
| `regions`            | List of regions & VPC UUIDs to deploy to.<br>`[{ region = "nyc3", vpc_uuid = "..." }, …]`                                                                                                       | `list(object({ region = string, vpc_uuid = string }))` | n/a     |  **yes** |
| `region_dns_records` | Create an `A` record for each regional LB using the first domain in `global_lb_config.domains[*].name`.                                                                                         | `bool`                                                 | `false` |    no    |
| `regional_lb_config` | Map of arguments passed to **every** regional load balancer (forwarding rules, health‑checks, tags, etc.). See [DO LB docs](https://docs.digitalocean.com/products/networking/load-balancers/). | `any`                                                  | n/a     |  **yes** |
| `global_lb_config`   | Map of arguments for the GLB (domains, health‑check, GLB settings, etc.). Must include exactly **one** item in `domains`.                                                                       | `any`                                                  | n/a     |  **yes** |

# Support

This Terraform module is provided as a reference implementation and must be fully tested in your own environment before using it in production. The Terraform Provider and its resources are supported, but this module itself is not officially supported.
