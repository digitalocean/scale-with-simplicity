output "lb_details" {
  description = "The details of the regional load balancer"
  value = {
    id : digitalocean_loadbalancer.this.id
    ip : digitalocean_loadbalancer.this.ip
    region : digitalocean_loadbalancer.this.region
  }
}