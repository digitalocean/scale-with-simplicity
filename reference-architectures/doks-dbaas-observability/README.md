# DOKS and DBaaS Observability Reference Architecture

**Note:** This reference architecture is currently under development. Designs, configurations, and resources are subject to change.

## Overview

This reference architecture demonstrates comprehensive observability for DigitalOcean Kubernetes (DOKS) workloads and managed databases (DBaaS). It showcases production-ready monitoring and logging patterns using Prometheus, Grafana, and Loki to provide full visibility into:

- **DOKS Workloads**: Pod and container metrics and logs
- **Cilium Gateway Resources**: L7 HTTP traffic metrics from Envoy proxies
- **Managed Databases**: Metrics and logs from PostgreSQL and Valkey clusters
- **Infrastructure**: Node and system-level monitoring

The deployment is structured into three distinct Terraform stacks, each responsible for a specific layer of the architecture. This modular approach enhances manageability, promotes separation of concerns, and allows for independent updates to each layer.

Key observability features include:
- **Metrics Collection**: Prometheus scraping from DOKS pods, Cilium/Envoy, and managed database endpoints
- **Log Aggregation**: Loki collecting pod logs, Kubernetes events, and database logs via rsyslog
- **Visualization**: Pre-configured Grafana dashboards for databases, Cilium, and Gateway metrics
- **Database Monitoring**: Direct metrics endpoint scraping plus exporters for detailed database observability
- **Secure Log Sink**: TLS-enabled syslog listener for forwarding managed database logs to Loki

## Architecture Stacks

The deployment is divided into three sequential Terraform stacks:

### 1. Core Infrastructure (`1-infra`)

This stack provisions the foundational infrastructure components in your DigitalOcean account.

- **Purpose:** To create a stable base layer that changes infrequently.
- **Resources Created:**
    - **Virtual Private Cloud (VPC):** A private network for all resources.
    - **DigitalOcean Kubernetes (DOKS) Cluster:** A managed cluster with Cilium CNI and auto-scaling node pool.
    - **Managed PostgreSQL Database:** For the AdService with metrics endpoint enabled.
    - **Managed Valkey (Redis-compatible) Database:** For the CartService with metrics endpoint enabled.
    - **Spaces Bucket:** Object storage for Loki log retention.

### 2. Cluster Services (`2-cluster`)

This stack installs the core observability platform and essential cluster services.

- **Purpose:** To deploy the observability stack and supporting services for networking, security, and DNS management.
- **Reason for Separation:** A Kubernetes provider cannot be configured in the same Terraform stack that creates the cluster resource itself.
- **Services Deployed:**
    - **kube-prometheus-stack:** Complete monitoring solution with Prometheus, Grafana, and Alertmanager
        - Configured with persistent storage for metrics retention (7 days)
        - Loki configured as a Grafana data source
        - Pre-loaded Grafana dashboards for PostgreSQL, Redis, Cilium, Envoy, and system metrics
    - **Loki:** Log aggregation system with SimpleScalable deployment mode
        - Uses DigitalOcean Spaces for log storage with 7-day retention
        - Provides centralized logging for pods, Kubernetes events, and database logs
    - **Alloy:** Log collection agent deployed as a DaemonSet
        - Tails container logs from `/var/log/containers`
        - Collects Kubernetes events via API
        - Exposes TLS-secured syslog listener (port 6514) for database logs
        - Internal LoadBalancer for rsyslog forwarding from managed databases
    - **cert-manager:** Automates TLS certificate management
        - Gateway API support enabled for HTTPRoute certificates
        - Generates self-signed CA and certificates for syslog TLS
    - **ExternalDNS:** Automatically manages DNS records
        - Supports Gateway API resources (HTTPRoute, GRPCRoute)
        - Creates DNS entries for services and load balancers
    - **Metrics Server:** Enables Horizontal Pod Autoscaling (HPA) and resource-based metrics.

### 3. Application Environment (`3-environment`)

This final stack deploys the demo application with Cilium Gateway resources and comprehensive database observability.

- **Purpose:** To demonstrate application deployment with Gateway API and complete observability integration for both workloads and databases.
- **Reason for Separation:** This stack depends on Custom Resource Definitions (CRDs) like `ServiceMonitor`, `ScrapeConfig`, and `Certificate` that are created by the `2-cluster` stack.
- **Resources Deployed:**
    - **Cilium Gateway (Gateway API):** Modern ingress implementation using DOKS' default Cilium CNI
        - HTTPS listener with Let's Encrypt TLS certificates via cert-manager DNS-01 challenge
        - HTTP to HTTPS redirect
        - HTTPRoute for application traffic routing
        - Exposes Envoy proxy metrics for L7 observability
    - **Microservices Demo Application:** Sample e-commerce application with load generation
        - Frontend service accessible via Gateway
        - AdService using managed PostgreSQL
        - CartService using managed Valkey
    - **Database Observability:**
        - **PostgreSQL Monitoring:**
            - ScrapeConfig for managed database metrics endpoint
            - PostgreSQL exporter deployment for detailed database metrics
            - Kubernetes secrets for secure credential management
        - **Valkey Monitoring:**
            - ScrapeConfig for managed database metrics endpoint
            - Redis exporter deployment for Valkey metrics
            - TLS-enabled connection to managed Valkey cluster
    - **Gateway Observability:**
        - PodMonitor for Cilium agent metrics (CNI, BPF, policy enforcement)
        - PodMonitor for Envoy proxy metrics (HTTP request rates, latencies, status codes)
        - Pre-configured Grafana dashboards for Gateway traffic analysis
