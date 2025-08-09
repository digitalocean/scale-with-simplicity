# DOKS Single Cluster Reference Architecture

**Note:** This reference architecture is currently under development. Designs, configurations, and resources are subject to change.

## Overview

This reference architecture deploys a comprehensive and scalable environment on DigitalOcean Kubernetes (DOKS). It is structured into three distinct Terraform stacks, each responsible for a specific layer of the architecture, from core infrastructure to application deployment and observability. This modular approach enhances manageability, promotes separation of concerns, and allows for independent updates to each layer.

The goal is to provide a production-ready foundation that includes:
- A secure and isolated network (VPC).
- A managed Kubernetes cluster with auto-scaling.
- Managed databases for persistent storage (PostgreSQL and Valkey).
- Essential cluster services for ingress, certificate management, DNS, and monitoring.
- A sample microservices application with detailed, application-specific observability.

## Architecture Stacks

The deployment is divided into three sequential Terraform stacks:

### 1. Core Infrastructure (`1-infra`)

This stack provisions the foundational infrastructure components in your DigitalOcean account.

- **Purpose:** To create a stable base layer that changes infrequently.
- **Resources Created:**
    - **Virtual Private Cloud (VPC):** A private network for all resources.
    - **DigitalOcean Kubernetes (DOKS) Cluster:** A managed cluster with an auto-scaling node pool.
    - **Managed PostgreSQL Database:** For relational data storage.
    - **Managed Valkey (Redis-compatible) Database:** For in-memory caching and session storage.

### 2. Cluster Services (`2-cluster`)

This stack installs essential services within the Kubernetes cluster that provide cluster-wide functionality.

- **Purpose:** To equip the cluster with the necessary supporting services for networking, security, and observability.
- **Reason for Separation:** A Kubernetes provider cannot be configured in the same Terraform stack that creates the cluster resource itself.
- **Services Deployed:**
    - **NGINX Ingress Controller:** Manages external access to services.
    - **cert-manager:** Automates TLS certificate management with Let's Encrypt.
    - **kube-prometheus-stack:** Provides a full monitoring solution with Prometheus and Grafana.
    - **Metrics Server:** Enables features like Horizontal Pod Autoscaling (HPA).
    - **ExternalDNS:** Automatically manages DNS records for services and ingresses in DigitalOcean DNS.

### 3. Application Environment (`3-environment`)

This final stack deploys the demo application and its specific monitoring configurations.

- **Purpose:** To manage the application layer, allowing it to be iterated on independently from the underlying infrastructure.
- **Reason for Separation:** This stack depends on Custom Resource Definitions (CRDs) like `ServiceMonitor` and `ScrapeConfig` that are created by the `2-cluster` stack. These CRDs must exist before the resources in this stack can be created.
- **Resources Deployed:**
    - **Microservices Demo Application:** A sample application deployed via a Helm chart.
    - **Application Observability:**
        - Secure handling of database credentials.
        - Prometheus exporters for PostgreSQL and Valkey databases.
        - Custom `ScrapeConfig` resources for Prometheus to gather metrics from the application's databases and the ingress controller.
