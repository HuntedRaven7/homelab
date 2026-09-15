# OpenTofu / Terraform Variables for Homelab
# These values should be set via environment variables or a tfvars file

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "tailscale_api_key" {
  description = "Tailscale API key"
  type        = string
  sensitive   = true
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
}

variable "vm_count" {
  description = "Number of VMs to configure"
  type        = number
  default     = 1
}

variable "vm_ips" {
  description = "List of VM IP addresses"
  type        = list(string)
  default     = []
}

variable "vm_user" {
  description = "SSH user for VMs"
  type        = string
  default     = "robin"
}

variable "k0s_version" {
  description = "k0s version to install"
  type        = string
  default     = "v1.30.0+k0s.0"
}

variable "control_plane_ip" {
  description = "IP address of the control plane"
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

variable "node_ips" {
  description = "List of worker node IPs"
  type        = list(string)
  default     = []
}

variable "tailscale_domain" {
  description = "Tailscale domain name"
  type        = string
  default     = "your-tailnet.ts.net"
}