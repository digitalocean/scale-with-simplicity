# Globally Load Balanced Web Servers

A Terraform module that bootstraps a complete, multi‑region web infrastructure on DigitalOcean:

1. Peered **VPCs** in each region you choose
2. **Regional Load Balancers** in front of your web droplets (one per region).
3. A **Global Load Balancer** (GLB) in front of your Regional Load Balancers
4. **DNS records** to each regional LB.
5. **Web droplets** in each region, tagged and injected with a simple nginx+Docker user‑data script.

<img src="./globally-load-balanced-web-servers.png" width="700">