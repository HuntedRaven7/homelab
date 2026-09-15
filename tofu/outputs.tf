# Output values for the homelab infrastructure

output "control_plane_ip" {
  description = "IP address of the k0s control plane node"
  value       = proxmox_vm.k0s-control-plane[0].ip_address
}

output "worker_ips" {
  description = "IP addresses of the k0s worker nodes"
  value       = [for vm in proxmox_vm.k0s-worker : vm.ip_address]
}

output "k0s_join_command" {
  description = "Command to join worker nodes to the cluster"
  value       = local_file.k0s_join_command.content
  sensitive   = true
}

output "tailscale_dns_names" {
  description = "Tailscale DNS names for services"
  value = {
    for svc in var.service_names : svc => "${svc}.${var.vm_domain}"
  }
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = "${path.module}/kubeconfig"
}