terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "pablosspot"

    workspaces {
      prefix = "event-driven-system-infrastructure-"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 2.15.0"
    }
  }
}
