# DOKS and DBaaS Observability Reference Architecture

This reference architecture demonstrates comprehensive observability for DigitalOcean Kubernetes (DOKS) workloads and managed databases (DBaaS). It showcases production-ready monitoring and logging patterns using Prometheus, Grafana, and Loki to provide full visibility into:

- **DOKS Workloads**: Pod and container metrics and logs
- **Cilium Gateway Resources**: L7 HTTP traffic metrics from Envoy proxies
- **Managed Databases**: Metrics and logs from PostgreSQL and Valkey clusters
- **Infrastructure**: Node and system-level monitoring

## Architecture Overview

<!-- TODO: Add architecture diagram -->
<img src="./doks-dbaas-observability.png" width="700">

Key observability features include:

| Feature | Description |
|---------|-------------|
| **Metrics Collection** | Prometheus scraping from DOKS pods, Cilium/Envoy, and managed database endpoints |
| **Log Aggregation** | Loki collecting pod logs, Kubernetes events, and database logs via rsyslog |
| **Visualization** | Pre-configured Grafana dashboards for databases, Cilium, and Gateway metrics |
| **Database Monitoring** | Direct metrics endpoint scraping plus exporters for detailed database observability |
| **Secure Log Sink** | TLS-enabled syslog listener for forwarding managed database logs to Loki |

## Prerequisites

* DigitalOcean account with API token
* Terraform v1.2+ installed
* `kubectl` CLI installed
* `doctl` CLI configured with API token
* A DigitalOcean-managed DNS domain (for ExternalDNS and Let's Encrypt)
* DigitalOcean API Token (`DIGITALOCEAN_ACCESS_TOKEN` environment variable)

## Deployment

This reference architecture uses a three-stack Terraform deployment model to separate concerns and manage dependencies:

- **Stack 1 (`terraform/1-infra`)**: Core infrastructure - VPC, DOKS cluster, managed databases, Spaces bucket
- **Stack 2 (`terraform/2-cluster`)**: Cluster services - observability platform, cert-manager, ExternalDNS
- **Stack 3 (`terraform/3-environment`)**: Application - demo app, Gateway, database observability integration

### Step 1: Deploy Infrastructure (Stack 1)

This stack provisions the foundational infrastructure components. It creates a stable base layer that changes infrequently.

**What This Creates:**

| Resource | Description |
|----------|-------------|
| **VPC** | Private network for all resources |
| **DOKS Cluster** | Managed Kubernetes with Cilium CNI, auto-scaling node pool (2vCPU/4GB nodes, 3-5 nodes) |
| **Managed PostgreSQL** | v17 cluster (1vCPU/1GB) for AdService with metrics endpoint enabled |
| **Managed Valkey** | v8 cluster (1vCPU/1GB) for CartService with metrics endpoint enabled |
| **Spaces Bucket** | Object storage for Loki log retention |

> **Note:** Minimum 3 nodes are required to ensure quorum-based services like Loki can survive node loss.

First, create a `terraform.tfvars` file with your configuration:

```hcl
name_prefix         = "my-observability"
region              = "sfo3"
vpc_cidr            = "10.201.0.0/22"
doks_cluster_subnet = "172.16.64.0/20"
doks_service_subnet = "192.168.12.0/22"
```

Then apply the Terraform configuration:

```bash
cd terraform/1-infra

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file=terraform.tfvars

# Apply the configuration
terraform apply -var-file=terraform.tfvars
```

### Step 2: Configure kubectl

Get credentials for the DOKS cluster:

```bash
doctl kubernetes cluster kubeconfig save $(terraform output -raw cluster_name)
```

### Step 3: Deploy Cluster Services (Stack 2)

This stack installs the core observability platform and essential cluster services. It must be separate from Stack 1 because the Kubernetes provider cannot be configured in the same Terraform stack that creates the cluster.

**What This Creates:**

| Component | Description |
|-----------|-------------|
| **kube-prometheus-stack** | Prometheus (5Gi storage, 7-day retention), Grafana with 5 pre-loaded dashboards, Alertmanager (2 replicas) |
| **Loki** | Log aggregation in SimpleScalable mode with Spaces backend, 7-day retention, TSDB index |
| **Alloy** | DaemonSet for container log collection, Kubernetes event collection, TLS syslog listener (port 6514) with internal LoadBalancer |
| **cert-manager** | TLS certificate automation, Gateway API support |
| **ExternalDNS** | Automatic DNS record management for Services and Gateway API resources |
| **Metrics Server** | Enables HPA and resource-based metrics (2 replicas) |
| **Database Log Sinks** | rsyslog sinks for PostgreSQL and Valkey logs (RFC5424 format, TLS-secured) |

Create a `terraform.tfvars` file:

```hcl
name_prefix      = "my-observability"
grafana_password = "your-secure-password"
log_sink_fqdn    = "logs.your-domain.com"
```

Apply the configuration:

```bash
cd ../2-cluster

# Initialize Terraform
terraform init

# Apply with DO token (required for ExternalDNS and log sinks)
terraform apply -var-file=terraform.tfvars -var="digitalocean_access_token=$DIGITALOCEAN_ACCESS_TOKEN"
```

### Step 4: Deploy Application Environment (Stack 3)

This stack deploys the demo application with Cilium Gateway resources and comprehensive database observability. It must be separate because it depends on Custom Resource Definitions (CRDs) like `ServiceMonitor`, `ScrapeConfig`, and `Certificate` that are created by Stack 2.

**What This Creates:**

| Component | Description |
|-----------|-------------|
| **Cilium Gateway** | HTTPS listener (port 443) with Let's Encrypt DNS-01 certificates, HTTP-to-HTTPS redirect, HTTPRoute for traffic routing |
| **Demo Application** | Microservices e-commerce app with Frontend, AdService (PostgreSQL-backed), CartService (Valkey-backed), and load generator (100 concurrent users, 5 req/sec) |
| **PostgreSQL Observability** | ScrapeConfig for managed database metrics endpoint, postgres-exporter deployment, credential secrets |
| **Valkey Observability** | ScrapeConfig for managed database metrics endpoint, redis-exporter deployment, TLS connection support |
| **Gateway Observability** | PodMonitor for Cilium metrics (CNI, BPF, policy), PodMonitor for Envoy metrics (HTTP rates, latencies, status codes) |

Create a `terraform.tfvars` file:

```hcl
name_prefix = "my-observability"
fqdn        = "demo.your-domain.com"
```

Apply the configuration:

```bash
cd ../3-environment

# Initialize Terraform
terraform init

# Apply the configuration
terraform apply -var-file=terraform.tfvars
```

## Verification

### Check Cluster Services

```bash
kubectl get pods -n cluster-services
```

Expected output shows observability stack running:

```
NAME                                                     READY   STATUS    RESTARTS   AGE
alertmanager-kube-prometheus-stack-alertmanager-0        2/2     Running   0          5m
kube-prometheus-stack-grafana-xxx                        3/3     Running   0          5m
kube-prometheus-stack-operator-xxx                       1/1     Running   0          5m
loki-backend-0                                           2/2     Running   0          5m
loki-read-xxx                                            1/1     Running   0          5m
loki-write-0                                             1/1     Running   0          5m
prometheus-kube-prometheus-stack-prometheus-0            2/2     Running   0          5m
alloy-xxx                                                2/2     Running   0          5m
```

### Check Demo Application

```bash
kubectl get pods -n demo
```

### Check Gateway Status

```bash
kubectl get gateway -n demo
```

The Gateway should show an external IP address once provisioned.

### Access Demo Application

Once the Gateway has an external IP and DNS propagates:

```bash
curl -s https://demo.your-domain.com
```

## Viewing Metrics and Logs

### Access Grafana

Grafana runs as a ClusterIP service. Access it via port-forward:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n cluster-services 3000:80
```

Open http://localhost:3000 in your browser.

**Default credentials:**
- Username: `admin`
- Password: `do-demo` (or value of `grafana_password` variable)

### Pre-configured Dashboards

Navigate to **Dashboards** in the left menu to find:

| Dashboard | Description |
|-----------|-------------|
| **PostgreSQL Exporter** | Database connections, query performance, replication status, table statistics |
| **Redis Exporter** | Memory usage, operations/sec, connected clients, key metrics |
| **Cilium Agent** | CNI operations, BPF map stats, policy enforcement, endpoint health |
| **Envoy Web** | HTTP request rates, response latencies, status code distribution, per-route metrics |
| **Telegraf System Metrics** | CPU, memory, disk, network usage across nodes |

### Viewing Logs

1. In Grafana, click **Explore** in the left menu
2. Select **Loki** as the data source from the dropdown
3. Use LogQL queries to explore logs:

**Pod logs from demo namespace:**
```
{namespace="demo"}
```

**Database logs (PostgreSQL and Valkey):**
```
{job="database-logs"}
```

**Database connection events:**
```
{job="database-logs"} |= "connection"
```

**Kubernetes events:**
```
{job="kubernetes-events"}
```

**Filter by specific pod:**
```
{namespace="demo", pod=~"frontend.*"}
```

**Search for errors:**
```
{namespace="demo"} |= "error"
```

## Inputs

### Stack 1 (1-infra)

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name_prefix` | Prefix for all resource names | `string` | n/a | yes |
| `region` | DigitalOcean region slug | `string` | n/a | yes |
| `vpc_cidr` | CIDR block for VPC | `string` | n/a | yes |
| `doks_cluster_subnet` | CIDR for DOKS cluster subnet | `string` | n/a | yes |
| `doks_service_subnet` | CIDR for DOKS service subnet | `string` | n/a | yes |
| `doks_control_plane_ha` | Enable high availability for DOKS control plane | `bool` | `false` | no |
| `doks_node_pool_min_nodes` | Minimum nodes in node pool (must be >= 3 for Loki quorum) | `number` | `3` | no |
| `doks_node_pool_max_nodes` | Maximum nodes for autoscaling | `number` | `5` | no |

### Stack 2 (2-cluster)

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name_prefix` | Prefix for resources (must match Stack 1) | `string` | n/a | yes |
| `grafana_password` | Password for Grafana admin user | `string` | `"do-demo"` | no |
| `digitalocean_access_token` | DO API token for ExternalDNS and log sinks | `string` | n/a | yes |
| `log_sink_fqdn` | FQDN for the syslog endpoint LoadBalancer | `string` | n/a | yes |

### Stack 3 (3-environment)

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name_prefix` | Prefix for resources (must match Stack 1) | `string` | n/a | yes |
| `fqdn` | FQDN for the demo application (must be DO-managed domain) | `string` | n/a | yes |

## Outputs

Each stack reads outputs from previous stacks via `terraform_remote_state`. Key information accessible after deployment:

| Stack | Output | Description |
|-------|--------|-------------|
| Stack 1 | `cluster_name` | Name of the DOKS cluster for kubectl configuration |
| Stack 1 | `vpc_id` | ID of the created VPC |

## Cleanup

Remove resources in reverse order (Stack 3 -> Stack 2 -> Stack 1):

```bash
# Destroy Stack 3 (Application)
cd terraform/3-environment
terraform destroy -var-file=terraform.tfvars

# Destroy Stack 2 (Cluster Services)
cd ../2-cluster
terraform destroy -var-file=terraform.tfvars -var="digitalocean_access_token=$DIGITALOCEAN_ACCESS_TOKEN"

# Destroy Stack 1 (Infrastructure)
cd ../1-infra
terraform destroy -var-file=terraform.tfvars
```

## Troubleshooting

### Pods Not Scheduling

**Symptom**: Pods stuck in `Pending` state

**Solution**: Check node capacity and pod resource requests:
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl top nodes
```

### Grafana Not Accessible

**Symptom**: Port-forward fails or Grafana shows errors

**Solution**: Verify Grafana pod is running:
```bash
kubectl get pods -n cluster-services -l app.kubernetes.io/name=grafana
kubectl logs -n cluster-services -l app.kubernetes.io/name=grafana
```

### Logs Not Appearing in Loki

**Symptom**: No logs visible in Grafana Explore with Loki data source

**Solution**: Check Alloy and Loki pods:
```bash
kubectl get pods -n cluster-services -l app.kubernetes.io/name=alloy
kubectl logs -n cluster-services -l app.kubernetes.io/name=alloy
kubectl get pods -n cluster-services -l app.kubernetes.io/name=loki
```

### Database Metrics Missing

**Symptom**: PostgreSQL or Redis dashboards show no data

**Solution**: Verify the exporter pods and ScrapeConfig targets:
```bash
kubectl get pods -n demo -l app=postgres-exporter
kubectl get pods -n demo -l app=redis-exporter
kubectl get scrapeconfig -n cluster-services
```

Check Prometheus targets in Grafana (Explore -> Prometheus -> query `up`).

### Gateway Not Getting External IP

**Symptom**: Gateway shows no address

**Solution**: Verify Cilium Gateway API is working:
```bash
kubectl get gatewayclass
kubectl describe gateway -n demo
kubectl get svc -n kube-system -l app.kubernetes.io/name=cilium
```

### Let's Encrypt Certificate Issues

**Symptom**: HTTPS not working, certificate errors

**Solution**: Check cert-manager and certificate status:
```bash
kubectl get certificate -n demo
kubectl describe certificate -n demo
kubectl get certificaterequest -n demo
kubectl logs -n cluster-services -l app.kubernetes.io/name=cert-manager
```

## References

* [Prometheus Documentation](https://prometheus.io/docs/)
* [Grafana Documentation](https://grafana.com/docs/)
* [Loki Documentation](https://grafana.com/docs/loki/latest/)
* [Alloy Documentation](https://grafana.com/docs/alloy/latest/)
* [DigitalOcean Kubernetes](https://docs.digitalocean.com/products/kubernetes/)
* [DigitalOcean Managed Databases](https://docs.digitalocean.com/products/databases/)
* [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
* [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
* [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
