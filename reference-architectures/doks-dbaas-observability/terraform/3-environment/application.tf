# cert-manager Issuer for Automatic TLS Certificate Management
#
# This Issuer resource configures cert-manager to automatically obtain and renew
# TLS certificates from Let's Encrypt using the ACME DNS-01 challenge method.
# cert-manager was installed as part of the cluster services in stack 2-cluster.
#
# The DNS-01 challenge works by having cert-manager create a TXT record in your
# domain's DNS to prove ownership.
resource "kubernetes_manifest" "letsencrypt_dns01_issuer" {
  manifest = yamldecode(file("${path.module}/../../k8s/environment/clusterissuer-letsencrypt.yaml"))
}


# Gateway API Resource - Modern Kubernetes Ingress Alternative
#
# The Gateway API is the next-generation ingress solution for Kubernetes that provides
# more expressive, extensible, and role-oriented APIs for managing ingress traffic.
# It's designed to be more powerful and flexible than traditional Ingress resources.
#
# ANNOTATED GATEWAY APPROACH:
# This reference architecture uses the "annotated gateway" pattern where the Gateway
# resource is defined and managed alongside the application resources by the same team.
# This provides an Ingress-like experience where application teams have full control
# over their ingress configuration without requiring platform team involvement.
#
# Alternative approaches include having platform teams manage shared Gateways, but
# the annotated approach offers simplicity and team autonomy - similar to how
# traditional Ingress resources work.
#
# This Gateway uses Cilium as the gateway implementation, which is installed by default in DOKS clusters.
resource "kubernetes_manifest" "cilium_gateway_http" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/environment/gateway-cilium.yaml", {
    namespace   = kubernetes_namespace_v1.demo.metadata[0].name
    name_prefix = var.name_prefix
    fqdn        = var.fqdn
  }))
}

# HTTPRoute Resource - Application Traffic Routing Configuration
#
# HTTPRoute is the Gateway API resource that defines how HTTP traffic should be
# routed to backend services. It binds to a Gateway and defines the routing rules.
# This is equivalent to Ingress resources but provides more flexibility and features.
#
# ANNOTATED GATEWAY PATTERN:
# In this reference architecture, both the Gateway and HTTPRoute are managed together
# by the application team, similar to how Ingress resources work. This "annotated gateway"
# approach means the HTTPRoute binds to a Gateway defined in the same namespace and
# managed by the same team, providing full control over the ingress configuration
# without dependencies on shared infrastructure resources.
resource "kubernetes_manifest" "httproute_frontend_https" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/environment/httproute-frontend.yaml", {
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
    fqdn      = var.fqdn
  }))
}


# HTTPRoute for HTTP to HTTPS redirect
resource "kubernetes_manifest" "httproute_frontend_http_redirect" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/environment/httproute-http-redirect.yaml", {
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
    fqdn      = var.fqdn
  }))
}


# Microservices Demo Application Deployment
#
# This resource deploys the microservices demo application using a Helm chart.
# Helm is a package manager for Kubernetes that simplifies the deployment and management of applications.
# The chart is pulled from an OCI (Open Container Initiative) registry, which is a modern way to store Helm charts.
#
# This demo application showcases a typical microservices architecture with multiple
# services (frontend, cart, catalog, etc.) and demonstrates how they work together
# in a DOKS environment with the Gateway API for ingress.
resource "helm_release" "microservices_demo" {
  chart     = "oci://ghcr.io/do-solutions/microservices-demo"
  name      = "demo"
  namespace = kubernetes_namespace_v1.demo.metadata[0].name

  # The `set` block is used to override default values in the Helm chart.
  # This allows us to customize the deployment for our Gateway API setup.
  set = [
    # Disables the development-specific deployment configurations.
    # In production environments, we want the full production-ready setup.
    {
      name : "devDeployment"
      value : "false"
    },

    # Sets the fully qualified domain name (FQDN) for the frontend service.
    # external-dns (installed in stack 2-cluster) will automatically create a DNS record
    # for this FQDN pointing to the DigitalOcean Load Balancer created by the Gateway.
    {
      name : "frontend.fqdn"
      value : var.fqdn
    },

    # Disables the creation of cert-manager Issuer resource in the Helm chart
    # because we're managing the Issuer externally (defined above in this file).
    # This prevents conflicts and gives us more control over certificate management.
    {
      name : "frontend.createIssuer"
      value : "false"
    },

    # Disables the creation of traditional Ingress resource in the Helm chart
    # because we're using the modern Gateway API with HTTPRoute instead.
    # The HTTPRoute defined above replaces the traditional Ingress functionality.
    {
      name : "frontend.createIngress"
      value : "false"
    },

    # Disables an init container that checks for frontend availability at startup.
    # This is necessary because it takes time for the load balancer to be provisioned
    # and for external-dns to create the DNS record. Without this, the deployment
    # might fail during the initial setup phase.
    {
      name : "loadGenerator.checkFrontendInitContainer"
      value : false
    },

    # Configures the load generator to simulate 100 concurrent users.
    # This creates realistic load patterns for testing and demonstrating
    # the application's performance under load.
    {
      name : "loadGenerator.users"
      value : 100
    },

    # Sets the rate at which the load generator sends requests (requests per second).
    # This creates a steady load pattern that helps validate the monitoring
    # and observability stack deployed in stack 2-cluster.
    {
      name : "loadGenerator.rate"
      value : 5
    },
  ]
}