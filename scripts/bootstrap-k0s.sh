#!/usr/bin/env bash
# k0s Cluster Bootstrap Script
# Run this on the control plane node to set up the k0s cluster

set -euo pipefail

K0S_VERSION="v1.30.0+k0s.0"
K0S_CONFIG="/var/home/robin/git/personal/homelab/k0s/config/k0s.yaml"

echo "=== k0s Homelab Cluster Bootstrap ==="

# 1. Install k0s if not present
if ! command -v k0s &> /dev/null; then
    echo "Installing k0s ${K0S_VERSION}..."
    curl -sSLf https://get.k0s.sh | sudo sh -s -- "${K0S_VERSION}"
else
    echo "k0s already installed: $(k0s version)"
fi

# 2. Initialize control plane with config
echo "Initializing k0s control plane..."
sudo k0s install controller -c "${K0S_CONFIG}" --single

# 3. Start k0s
echo "Starting k0s..."
sudo k0s start

# 4. Wait for API server to be ready
echo "Waiting for API server..."
until kubectl --kubeconfig /var/lib/k0s/pki/admin.conf get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 5
    echo "  waiting..."
done

# 5. Install Calico CNI (if not using default)
echo "Applying Calico CNI..."
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# 6. Install local-path-provisioner for storage
echo "Installing local-path-provisioner..."
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# 7. Patch local-path as default storage class
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf patch storageclass local-path -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

# 8. Apply Traefik CRDs
echo "Applying Traefik CRDs..."
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf apply -f /var/home/robin/git/personal/homelab/k0s/manifests/traefik-crds.yaml

# 9. Apply Traefik deployment
echo "Applying Traefik deployment..."
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf apply -f /var/home/robin/git/personal/homelab/k0s/manifests/traefik-deployment.yaml

# 10. Apply IngressRoutes
echo "Applying IngressRoutes..."
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf apply -f /var/home/robin/git/personal/homelab/k0s/manifests/traefik-ingressroutes.yaml

# 11. Apply Prometheus ServiceMonitors
echo "Applying Prometheus ServiceMonitors..."
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf apply -f /var/home/robin/git/personal/homelab/k0s/manifests/prometheus-servicemonitors.yaml

# 12. Apply PrometheusRules
echo "Applying PrometheusRules..."
kubectl --kubeconfig /var/lib/k0s/pki/admin.conf apply -f /var/home/robin/git/personal/homelab/k0s/manifests/prometheus-rules.yaml

# 13. Copy kubeconfig for user access
echo "Setting up user kubeconfig..."
mkdir -p ~/.kube
sudo cp /var/lib/k0s/pki/admin.conf ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config

echo ""
echo "=== k0s Cluster Ready ==="
echo "Kubeconfig: ~/.kube/config"
echo ""
echo "Verify cluster:"
echo "  kubectl get nodes -o wide"
echo "  kubectl get pods -A"
echo ""
echo "Access services via Traefik (ports 80/443 on host):"
echo "  https://hermes.tailnet.ts.net"
echo "  https://vault.tailnet.ts.net"
echo "  https://ntfy.tailnet.ts.net"
echo "  https://glance.tailnet.ts.net"
echo "  https://karakeep.tailnet.ts.net"
echo "  https://search.tailnet.ts.net"
echo "  https://prometheus.tailnet.ts.net"
echo "  https://grafana.tailnet.ts.net"