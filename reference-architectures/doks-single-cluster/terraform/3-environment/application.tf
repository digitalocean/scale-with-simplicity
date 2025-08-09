# This resource deploys the microservices demo application using a Helm chart.
# Helm is a package manager for Kubernetes that simplifies the deployment and management of applications.
# The chart is pulled from an OCI (Open Container Initiative) registry, which is a modern way to store Helm charts.
resource "helm_release" "microservices_demo" {
  chart = "oci://ghcr.io/do-solutions/microservices-demo"
  name  = "demo"

  # The `set` block is used to override default values in the Helm chart.
  set = [
    # Disables the development-specific deployment configurations.
    {
      name : "devDeployment"
      value : "false"
    },
    # Sets the fully qualified domain name (FQDN) for the frontend service, used to configure the Ingress resource.
    # externaldns will create a DNS record for this FQDN pointing to the load balancer created by ingress-nginx.
    {
      name : "frontend.fqdn"
      value : var.fqdn
    },
    # Disables an init container that checks for the frontend, as it takes time for the loadbalncer to be created and for externaldns to create the DNS record.
    # Disabling the check ensures the helm release is created even if the DNS record is not yet created.
    {
      name : "loadGenerator.checkFrontendInitContainer"
      value : false
    },
    # Configures the load generator to simulate 100 concurrent users.
    {
      name : "loadGenerator.users"
      value : 100
    },
    # Sets the rate at which the load generator sends requests.
    {
      name : "loadGenerator.rate"
      value : 5
    },
  ]
}