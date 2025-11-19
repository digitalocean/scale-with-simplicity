# Terraform Stack 2: Cluster Services

This Terraform stack is the second of three, and its purpose is to install and configure essential services within the Kubernetes cluster that was provisioned by the `1-infra` stack. These services provide cluster-wide functionalities like ingress, monitoring, and certificate management, which are required by the applications that will be deployed in the final stack.

This must be seperated from the `1-infra` stack as you can not create a kubernetes provider in the same stack the kubernetes cluster is created in.

## Resources Created

This stack uses the Helm provider to deploy the following services into the `cluster-services` namespace:

- **NGINX Ingress Controller:** Deployed to manage external access to the services in the cluster. It routes incoming traffic to the appropriate backend services based on hostnames and paths.

- **cert-manager:** Automates the management of TLS certificates. It will automatically issue and renew certificates from Let's Encrypt, ensuring that communication with the cluster is always secure.

- **kube-prometheus-stack:** A comprehensive monitoring solution that includes Prometheus for metrics collection and Grafana for visualization. This stack also creates a `ConfigMap` with pre-configured Grafana dashboards for monitoring key services.

- **Metrics Server:** A cluster-wide aggregator of resource usage data. It is essential for Kubernetes features like the Horizontal Pod Autoscaler (HPA), which automatically scales application pods based on metrics like CPU and memory consumption.

- **ExternalDNS:** Synchronizes exposed Kubernetes Services and Ingresses with DigitalOcean DNS. It automatically creates and manages DNS records, making your applications accessible via friendly domain names.

## Purpose

The goal of this stack is to set up the foundational services that your applications will rely on. By managing these with Terraform, you ensure that your cluster is consistently configured with the necessary components for networking, security, and observability. This layer of the architecture is separate from the core infrastructure and the applications themselves, allowing for independent management and updates.

After applying this stack, your Kubernetes cluster will be equipped with all the necessary supporting services, ready for the final stack to deploy the application environment.
