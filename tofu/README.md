# OpenTofu Infrastructure as Code

This directory contains the OpenTofu configuration for managing the
homelab infrastructure as code.

## What It Does

1. **Manages Tailscale ACLs** and DNS configuration
2. **Configures GitHub repository** secrets and workflows
3. **Generates k0s join commands** for worker nodes

## Prerequisites

- OpenTofu installed (`brew install opentofu` or download from opentofu.org)
- Tailscale account with API access
- GitHub personal access token with repo:admin scope

## Quick Start

```bash
# 1. Copy the example variables file
cp tofu.tfvars.example tofu.tfvars

# 2. Edit tofu.tfvars with your values
vim tofu.tfvars

# 3. Initialize OpenTofu
cd tofu
tofu init

# 4. Validate configuration
tofu validate

# 5. Review changes
tofu plan

# 6. Apply
tofu apply
```

## Variables

See `variables.tf` for all available variables. Key variables:

| Variable | Description |
|----------|-------------|
| `github_token` | GitHub personal access token |
| `tailscale_api_key` | Tailscale API key |
| `tailscale_tailnet` | Tailscale tailnet name |
| `ssh_public_key` | SSH public key for VM access |
| `control_plane_ip` | IP address of the control plane |
| `node_ips` | List of worker node IPs |

## Architecture

```
OpenTofu
├── Tailscale ACLs
├── GitHub Secrets
├── GitHub Repository Settings
├── k0s Join Commands
└── CI Workflow
```

## Workflow

1. `tofu apply` configures Tailscale, GitHub, and generates join commands
2. SSH to control plane, run `k0s-control-plane.sh`
3. SSH to workers, run `k0s-join.sh`
4. k0s cluster is ready
5. Run `./scripts/bootstrap-k0s.sh` to deploy manifests
6. Run `./scripts/bootstrap-argocd.sh` to install Argo CD

## State Management

The state backend should be configured for production use. Options:

- **Local file**: Default (not recommended for production)
- **S3-compatible**: AWS S3, MinIO, Ceph

See `providers.tf` for backend configuration examples.

## Secrets

All sensitive values should be provided via `tofu.tfvars` (gitignored) or
environment variables. Never commit secrets to Git.

## Directory Structure

```
tofu/
├── variables.tf          # Input variables
├── providers.tf          # Provider configuration
├── main.tf               # Main infrastructure resources
├── outputs.tf            # Output values
├── templates/
│   ├── cloud-init.yaml.tftpl  # Cloud-init template
│   └── ci.yml.tftpl           # GitHub Actions workflow template
├── tofu.tfvars.example       # Example variables file
└── README.md                 # This file
```

## Post-Deployment

After `tofu apply` completes:

1. **Access control plane**: SSH to the control plane IP
2. **Get k0s kubeconfig**: `sudo cat /var/lib/k0s/pki/admin.conf`
3. **Deploy manifests**: `./scripts/deploy-k0s.sh`
4. **Bootstrap Argo CD**: `./scripts/bootstrap-argocd.sh`
5. **Access services**: Via Tailscale MagicDNS