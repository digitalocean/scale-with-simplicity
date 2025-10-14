# Reference Architecture: NAT Gateway for DOKS and Droplet

This example provisions:
- A **VPC** and **NAT Gateway**
- A **DOKS** cluster with the **Routing Agent** enabled
- A **Droplet** that routes egress via the NAT Gateway
- A **Route** CRD that overrides `0.0.0.0/0` to the NAT Gateway **gateway IP** (private VPC IP)

## Prerequisites
- terraform, doctl, kubectl installed
- `export DIGITALOCEAN_ACCESS_TOKEN="YOUR_DO_PAT"`
- `doctl auth init --access-token "$DIGITALOCEAN_ACCESS_TOKEN"`

## Apply (two modules)
```bash
# 1) Infra
terraform -chdir=terraform/1-infra init
terraform -chdir=terraform/1-infra apply -auto-approve

# 2) Route CRD
terraform -chdir=terraform/2-routes init
terraform -chdir=terraform/2-routes apply \
  -var="cluster_id=$(terraform -chdir=../1-infra output -raw cluster_id)" \
  -var="nat_gateway_gateway_ip=$(terraform -chdir=../1-infra output -raw nat_gateway_gateway_ip)" \
  -auto-approve
