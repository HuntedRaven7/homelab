# OpenTofu Provider Configuration
# Configure with: tofu init && tofu apply

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.16.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version  = ">= 3.2.0"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailscale_tailnet
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

provider "local" {}
provider "null" {}