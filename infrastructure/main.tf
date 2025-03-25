# Create droplets in each region
resource "digitalocean_droplet" "web" {
  count    = length(var.regions) 
  name     = "web-${var.regions[count.index]}-1"
  size     = var.droplet_size
  image    = var.droplet_image
  region   = var.regions[count.index]
  ssh_keys = [data.digitalocean_ssh_key.default.fingerprint]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx ca-certificates curl gnupg

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker and Docker Compose
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker

    # Configure nginx
    echo "<h1>Welcome to Hivenetes - Region: ${var.regions[count.index]} - Droplet: 1</h1>" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
    systemctl stop nginx
  EOF

  tags = ["web", "region:${var.regions[count.index]}"]
}

# Create regional load balancers
resource "digitalocean_loadbalancer" "regional" {
  count  = length(var.regions)
  name   = "lb-regional-${var.regions[count.index]}"
  region = var.regions[count.index]
  network = "INTERNAL"

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  healthcheck {
    port     = 80
    protocol = "http"
    path     = "/"
  }

  # Select droplet in the current region
  droplet_ids = [digitalocean_droplet.web[count.index].id]
}

# Create domain (changed from resource to data source)
data "digitalocean_domain" "default" {
  name = var.domain
}

resource "digitalocean_loadbalancer" "glb1" {
  name = "hb-glb-tf"
  type = "GLOBAL"
  domains {
    name       = data.digitalocean_domain.default.name
    is_managed = true
  }
  glb_settings {
    target_protocol = "http"
    target_port     = 80
    cdn {
      is_enabled = true
    }
  }
  target_load_balancer_ids = [
    for lb in digitalocean_loadbalancer.regional : lb.id
  ]
}

# Add CNAME records for each region
resource "digitalocean_record" "regional_cname" {
  count  = length(var.regions)
  domain = data.digitalocean_domain.default.name
  type   = "CNAME"
  name   = var.regions[count.index]
  value  = "${var.domain}."
  ttl    = 300
}

# Add all resources to the project
resource "digitalocean_project_resources" "all" {
  project = digitalocean_project.project.id
  resources = concat(
    [for droplet in digitalocean_droplet.web : droplet.urn],
    [for lb in digitalocean_loadbalancer.regional : lb.urn],
    [digitalocean_loadbalancer.glb1.urn],
    [data.digitalocean_domain.default.urn],
    # [for space in digitalocean_spaces_bucket.regional : space.urn],
    [digitalocean_database_cluster.primary.urn]
  )
}

# Add SSH key data source
data "digitalocean_ssh_key" "default" {
  name = "ai" # Make sure this matches your SSH key name in DigitalOcean
}
