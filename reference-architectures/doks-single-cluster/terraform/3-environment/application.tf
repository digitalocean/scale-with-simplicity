resource "kubernetes_manifest" "cilium_gateway_http" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "demo-http"
      namespace = kubernetes_namespace_v1.demo.metadata[0].name
      annotations = {
        "cert-manager.io/issuer": "demo-letsencrypt-http01"
      }
    }
    spec = {
      gatewayClassName = "cilium"
      # This is used to set the annotations on the service which is then pickup by the DOKS CCM.
      infrastructure = {
      annotations = {
          "service.beta.kubernetes.io/do-loadbalancer-name" = var.name_prefix
        }
      }
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = {
              from     = "Same"
            }
          }
        },
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          hostname = var.fqdn
          tls = {
            certificateRefs = [
              {
                kind = "Secret"
                name = "tls-demo-frontend"
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "Same"
            }
          }
        }
      ]
    }
  }
}

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
        email  = "null@digitalocean.com"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = { name = "letsencrypt-account-key" }
        solvers = [
          {
            http01 = {
              gatewayHTTPRoute = {
                parentRefs = [
                  {
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


resource "kubernetes_manifest" "httproute_frontend" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "demo-frontend"
      namespace = kubernetes_namespace_v1.demo.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name        = kubernetes_manifest.cilium_gateway_http.manifest.metadata.name
          namespace   = kubernetes_namespace_v1.demo.metadata[0].name
          sectionName = "http"
        },
        {
          name        = kubernetes_manifest.cilium_gateway_http.manifest.metadata.name
          namespace   = kubernetes_namespace_v1.demo.metadata[0].name
          sectionName = "https"
        }
      ]
      hostnames = [var.fqdn]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "frontend"
              port = 80
            }
          ]
        }
      ]
    }
  }
}



# This resource deploys the microservices demo application using a Helm chart.
# Helm is a package manager for Kubernetes that simplifies the deployment and management of applications.
# The chart is pulled from an OCI (Open Container Initiative) registry, which is a modern way to store Helm charts.
resource "helm_release" "microservices_demo" {
  chart = "oci://ghcr.io/do-solutions/microservices-demo"
  name  = "demo"
  namespace = kubernetes_namespace_v1.demo.metadata[0].name

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
    # Disables the creation of the Ingress and Issuer resource as these are replaced by the Gateway/HTTPRoute resource and the externally managed Issuer.
    {
      name : "frontend.createIssuer"
      value : "false"
    },
    {
      name : "frontend.createIngress"
      value : "false"
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