tls           = false
domain        = "www.do.jjk3.com"
name_prefix   = "glb-ws-test"
droplet_size  = "s-1vcpu-2gb"
droplet_image = "ubuntu-20-04-x64"
vpcs = [
  {
    region   = "nyc3",
    ip_range = "10.200.0.0/24"
  },
  {
    region   = "sfo3",
    ip_range = "10.200.1.0/24"
  },
  {
    region   = "ams3",
    ip_range = "10.200.2.0/24"
  }
]
