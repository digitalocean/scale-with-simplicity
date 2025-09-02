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
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "demo-http"
      namespace = kubernetes_namespace_v1.demo.metadata[0].name
      annotations = {
        # This annotation tells cert-manager which Issuer to use for automatic
        # TLS certificate provisioning. The issuer is defined below in this file.
        "cert-manager.io/issuer": "demo-letsencrypt-http01"
      }
    }
    spec = {
      # Specifies which Gateway Class to use. In DOKS with Cilium, we use "cilium"
      # which was installed by default when the cluster was created.
      gatewayClassName = "cilium"
      
      # Infrastructure configuration allows us to customize the underlying Service
      # that the Gateway creates. These annotations are applied to the Service
      # and picked up by the DigitalOcean Cloud Controller Manager (CCM).
      infrastructure = {
        annotations = {
          # This annotation tells the DigitalOcean CCM to create a load balancer
          # with a specific name, making it easier to identify in the DO console.
          "service.beta.kubernetes.io/do-loadbalancer-name" = var.name_prefix
        }
      }
      
      # Listeners define the network endpoints that this Gateway exposes.
      # Each listener can handle different protocols, ports, and hostnames.
      listeners = [
        {
          # HTTP listener for port 80 - typically used for HTTP-01 ACME challenges
          # and redirecting traffic to HTTPS
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = {
              # Only allow HTTPRoutes from the same namespace to bind to this listener
              from = "Same"
            }
          }
        },
        {
          # HTTPS listener for port 443 - handles secure traffic
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          # Hostname restriction - only accept traffic for this specific FQDN
          hostname = var.fqdn
          tls = {
            # Reference to the TLS certificate Secret that cert-manager will create
            certificateRefs = [
              {
                kind = "Secret"
                name = "tls-demo-frontend"
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              # Only allow HTTPRoutes from the same namespace to bind to this listener
              from = "Same"
            }
          }
        }
      ]
    }
  }
}

# cert-manager Issuer for Automatic TLS Certificate Management
#
# This Issuer resource configures cert-manager to automatically obtain and renew
# TLS certificates from Let's Encrypt using the ACME HTTP-01 challenge method.
# cert-manager was installed as part of the cluster services in stack 2-cluster.
#
# The HTTP-01 challenge works by having Let's Encrypt request a specific file
# from your domain over HTTP. cert-manager automatically creates temporary
# HTTPRoutes to handle these challenges through the Gateway.
resource "kubernetes_manifest" "letsencrypt_http01_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = "demo-letsencrypt-http01"
      namespace = kubernetes_namespace_v1.demo.metadata[0].name
    }
    spec = {
      acme = {
        # Contact email for Let's Encrypt notifications (certificate expiration, etc.)
        # In production, replace with a real email address
        email  = "null@digitalocean.com"
        
        # Let's Encrypt ACME server endpoint for production certificates
        # For testing, you can use: https://acme-staging-v02.api.letsencrypt.org/directory
        server = "https://acme-v02.api.letsencrypt.org/directory"
        
        # Secret where the ACME account private key will be stored
        privateKeySecretRef = { name = "letsencrypt-account-key" }
        
        # Challenge solvers define how cert-manager will prove domain ownership
        solvers = [
          {
            # HTTP-01 challenge solver configuration
            http01 = {
              # Gateway API specific configuration for HTTP-01 challenges
              # This tells cert-manager to use the Gateway for ACME challenges
              # instead of creating traditional Ingress resources
              gatewayHTTPRoute = {
                parentRefs = [
                  {
                    # Reference to the Gateway defined above that will handle
                    # the ACME challenge requests on port 80
                    name      = "demo-http"
                    namespace = kubernetes_namespace_v1.demo.metadata[0].name
                    kind      = "Gateway"
                  }
                ]
              }
            }
          }
        ]
      }
    }
  }
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
resource "kubernetes_manifest" "httproute_frontend" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "demo-frontend"
      namespace = kubernetes_namespace_v1.demo.metadata[0].name
    }
    spec = {
      # parentRefs define which Gateway listeners this HTTPRoute binds to
      # This HTTPRoute will handle traffic from both HTTP (port 80) and HTTPS (port 443)
      parentRefs = [
        {
          # Reference to the Gateway defined above
          name        = kubernetes_manifest.cilium_gateway_http.manifest.metadata.name
          namespace   = kubernetes_namespace_v1.demo.metadata[0].name
          # Bind to the HTTP listener (port 80) - used for ACME challenges and redirects
          sectionName = "http"
        },
        {
          # Reference to the Gateway defined above  
          name        = kubernetes_manifest.cilium_gateway_http.manifest.metadata.name
          namespace   = kubernetes_namespace_v1.demo.metadata[0].name
          # Bind to the HTTPS listener (port 443) - used for secure application traffic
          sectionName = "https"
        }
      ]
      
      # Only accept traffic for this specific hostname
      # This works with the hostname restriction on the HTTPS listener
      hostnames = [var.fqdn]
      
      # Routing rules define how to match incoming requests and where to send them
      rules = [
        {
          # Match conditions - when should this rule apply?
          matches = [
            {
              path = {
                # PathPrefix matching means any path starting with "/" (i.e., all paths)
                # Other options include "Exact" and "RegularExpression"
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          
          # Backend references - where should matching traffic be sent?
          backendRefs = [
            {
              # Send traffic to the "frontend" Service on port 80
              # This Service is created by the microservices-demo Helm chart below
              name = "frontend"
              port = 80
            }
          ]
        }
      ]
    }
  }
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
  chart = "oci://ghcr.io/do-solutions/microservices-demo"
  name  = "demo"
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