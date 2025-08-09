# Terraform Stack 1: Core Infrastructure

This Terraform stack is the first of three stacks responsible for provisioning the core infrastructure for the single-cluster reference architecture on DigitalOcean. Its primary role is to create the foundational components upon which the application environment will be built.

## Resources Created

This stack will create the following resources in your DigitalOcean account:

- **Virtual Private Cloud (VPC):** A logically isolated network to ensure that your cluster and its resources can communicate securely. All resources created in this stack are placed within this VPC.

- **DigitalOcean Kubernetes (DOKS) Cluster:** A managed Kubernetes cluster. This stack configures the cluster with the latest available Kubernetes version and sets up an auto-scaling node pool. The node pool automatically adjusts the number of nodes based on workload demands, ensuring both performance and cost-efficiency.

- **Managed PostgreSQL Database:** A managed database instance for services that require a relational database. By using a managed service, you offload the operational overhead of database maintenance, backups, and scaling.

- **Managed Valkey Database:** A managed, in-memory Valkey (a fork of Redis) database cluster. This is ideal for high-performance use cases like caching, session management, or real-time applications.

## Purpose

The goal of this stack is to separate the core, slower-moving infrastructure from the in-cluster and application-level configurations. By provisioning the VPC, DOKS cluster, and managed databases here, you create a stable foundation that will not change as frequently as the applications and services running on top of it.

After applying this stack, you will have a running Kubernetes cluster and the necessary databases, ready for the next stack to configure the in-cluster services.
