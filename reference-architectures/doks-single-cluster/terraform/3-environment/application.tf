# microservices-demo app
resource "helm_release" "microservices_demo" {
  chart = "oci://ghcr.io/do-solutions/microservices-demo"
  name  = "demo"
  set = [
    {
      name : "devDeployment"
      value : "false"
    },
    {
      name : "frontend.fqdn"
      value : var.fqdn
    },
    {
      name : "loadGenerator.checkFrontendInitContainer"
      value : false
    },
    {
      name : "loadGenerator.users"
      value : 100
    },
    {
      name : "loadGenerator.rate"
      value : 5
    },
  ]
}