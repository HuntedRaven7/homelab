# OpenTofu main configuration for homelab
# Manages Tailscale ACLs, GitHub secrets, and generates k0s join commands

locals {
  common_tags = ["homelab", "k0s"]
}

# Generate k0s join token
resource "random_password" "k0s_join_token" {
  length  = 32
  special = false
  upper   = false
}

# Local file for k0s join command
resource "local_file" "k0s_join_command" {
  filename = "${path.module}/k0s-join.sh"
  content  = <<EOF
#!/bin/bash
# k0s worker join script
# Run this on each worker node to join the cluster

set -e

# Install k0s
curl -sSLf https://get.k0s.sh | sudo sh -s -- "${var.k0s_version}"

# Join the cluster
sudo k0s install worker --single "${var.control_plane_ip}" --token "${random_password.k0s_join_token.result}"

# Start k0s
sudo k0s start

echo "Worker node joined successfully"
EOF
  file_permission = "0755"
}

# Local file for control plane install
resource "local_file" "k0s_control_plane_install" {
  filename = "${path.module}/k0s-control-plane.sh"
  content  = <<EOF
#!/bin/bash
# k0s control plane install script
# Run this on the control plane node

set -e

# Install k0s
curl -sSLf https://get.k0s.sh | sudo sh -s -- "${var.k0s_version}"

# Initialize control plane
sudo k0s install controller --single --token "${random_password.k0s_join_token.result}"

# Start k0s
sudo k0s start

echo "Control plane initialized successfully"
EOF
  file_permission = "0755"
}

# GitHub repository secrets for Argo CD
resource "github_repository_secret" "secrets" {
  for_each = toset([
    "TAILSCALE_API_KEY",
    "TAILSCALE_TAILNET",
    "GITHUB_TOKEN",
  ])
  repository      = var.github_repo
  secret_name     = each.value
  secret_value    = "PLACEHOLDER-SET-VIA-TOFU"
  plaintext_value = "PLACEHOLDER-SET-VIA-TOFU"
}

# Tailscale ACL for the tailnet
resource "tailscale_acl" "homelab" {
  acl = jsonencode({
    groups = {
      admins = ["robin"]
      users = []
    }
    acls = [
      {
        action = "allow"
        users  = ["robin"]
        ports  = ["*:*"]
      }
    ]
    auto_users = {
      inherit = ["admins"]
    }
  })
}

# Tailscale DNS configuration
resource "tailscale_dns_nameservers" "homelab" {
  nameservers = ["1.1.1.1", "8.8.8.8"]
}

# GitHub Actions workflow for k0s validation
resource "github_repository_workflow" "k0s-validate" {
  repository = var.github_repo
  name       = "CI"
  body       = file("${path.module}/templates/ci.yml.tftpl")
}

# GitHub repository settings
resource "github_repository" "homelab" {
  name                        = var.github_repo
  description                 = "Homelab infrastructure - k0s Kubernetes + Argo CD + Tailscale"
  visibility                  = "private"
  has_issues                  = true
  has_projects                = true
  has_wiki                    = true
  has_discussions             = false
  allow_merge_commit          = true
  allow_squash_merge          = true
  allow_rebase_merge          = true
  delete_branch_on_merge      = true
  web_commit_signoff_required = false
  vulnerability_alerts       = true
  secret_scanning_alerts      = true
  dependabot_alerts           = false

  topics = ["kubernetes", "k0s", "argocd", "tailscale", "homelab", "gitops", "podman", "monitoring"]
}