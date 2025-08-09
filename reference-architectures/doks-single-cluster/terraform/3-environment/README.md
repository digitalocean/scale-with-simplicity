# Terraform Stack 3: Application Environment

This is the final of the three Terraform stacks. Its role is to deploy the demo application and configure the necessary observability components to monitor it effectively. This stack builds upon the infrastructure and cluster services provisioned by the previous two stacks.

This must be seperated from the `2-cluster` stack it utilizes Custom Resource Definitions (CRDs) created by the `2-cluster` stack. We can't create and utilize the CRDs in the same stack.

## Resources Created

This stack deploys the following resources:

- **Microservices Demo Application:** A sample microservices application is deployed using a Helm chart. This represents the actual workload running on the Kubernetes cluster.

- **Application-Specific Monitoring:** This stack configures detailed monitoring for the application and its components:
  - **Database Credentials:** It retrieves credentials for the managed PostgreSQL and Valkey databases provisioned in the first stack and stores them securely in Kubernetes secrets.
  - **Prometheus Exporters:** It deploys `postgres-exporter` and `redis-exporter` via Helm to expose database metrics in a format that Prometheus can scrape.
  - **Prometheus Scrape Configurations:** It creates custom `ScrapeConfig` resources to ensure that Prometheus, which was set up in the second stack, scrapes metrics from the NGINX ingress controller and the newly deployed database exporters.

## Purpose

The goal of this stack is to manage the application layer of the architecture. By keeping the application deployment and its specific monitoring configuration separate from the underlying infrastructure and cluster services, you can iterate on the application independently. This separation of concerns makes the overall architecture more modular and easier to manage.

After applying this stack, the microservices demo application will be running and fully integrated with the monitoring and logging infrastructure. You will be able to view application-specific metrics and dashboards in Grafana.
