terraform {
  required_version = ">= 1.15"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.99"
    }
  }
}

provider "digitalocean" {
  token = var.digitalocean_token
}

variable "digitalocean_token" {
  description = "DigitalOcean API token."
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Name used for DigitalOcean resources."
  type        = string
  default     = "dosey"
}

resource "digitalocean_ssh_key" "default" {
  name       = var.project_name
  public_key = file("~/.ssh/dosey.pub")
}

resource "digitalocean_droplet" "app" {
  name       = var.project_name
  region     = "fra1"
  size       = "s-1vcpu-1gb"
  image      = "ubuntu-26-04-x64"
  ssh_keys   = [digitalocean_ssh_key.default.fingerprint]
  ipv6       = true
  monitoring = true
  tags       = [var.project_name]
}

resource "digitalocean_firewall" "app" {
  name        = "${var.project_name}-app"
  droplet_ids = [digitalocean_droplet.app.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_domain" "app" {
  name = "dosey.dk"
}

resource "digitalocean_record" "app_a" {
  domain = digitalocean_domain.app.id
  type   = "A"
  name   = "@"
  value  = digitalocean_droplet.app.ipv4_address
}

resource "digitalocean_record" "app_aaaa" {
  domain = digitalocean_domain.app.id
  type   = "AAAA"
  name   = "@"
  value  = digitalocean_droplet.app.ipv6_address
}

resource "digitalocean_record" "www" {
  domain = digitalocean_domain.app.id
  type   = "CNAME"
  name   = "www"
  value  = "dosey.dk."
}
