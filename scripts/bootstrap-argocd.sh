#!/usr/bin/env bash
# Argo CD Bootstrap Script
# Run this after k0s cluster is up to install Argo CD and bootstrap GitOps

set -euo pipefail

REPO_ROOT="/var/home/robin/git/personal/homelab"
ARGOCD_VERSION="v2.10.0"
REPO_URL="https://github.com/yourusername/homelab.git"

# Decrypt tailnet domain from SOPS
AGE_KEY_FILE="${REPO_ROOT}/.sops/age.key"
TAILNET_DOMAIN=$(SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}" sops --decrypt --extract '["tailnet_domain"]' "${REPO_ROOT}/.sops/tailnet.yaml")

echo "=== Argo CD Bootstrap ==="
echo "Tailnet domain: ${TAILNET_DOMAIN}"

# 1. Install Argo CD
echo "Installing Argo CD ${ARGOCD_VERSION}..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

# 2. Wait for Argo CD to be ready
echo "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-application-controller -n argocd
kubectl wait --for=condition=Available --timeout=300s deployment/argocd-repo-server -n argocd

# 3. Expose Argo CD server via Traefik (IngressRoute)
echo "Creating Argo CD IngressRoute..."
cat <<EOF | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`argocd.${TAILNET_DOMAIN}\`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
      middlewares:
        - name: security-headers
          namespace: kube-system
EOF

# 4. Get initial admin password
echo "Getting Argo CD initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD admin password: ${ARGOCD_PASSWORD}"

# 5. Login to Argo CD CLI (if installed)
if command -v argocd &> /dev/null; then
    echo "Logging into Argo CD..."
    argocd login "argocd.${TAILNET_DOMAIN}" --username admin --password "${ARGOCD_PASSWORD}" --insecure

    # 6. Add repository
    echo "Adding Git repository..."
    argocd repo add "${REPO_URL}" --username yourusername --password YOUR_GITHUB_TOKEN

    # 7. Create Applications
    echo "Creating Argo CD Applications..."
    kubectl apply -f "${REPO_ROOT}/k0s/manifests/argocd.yaml"

    echo ""
    echo "=== Argo CD Bootstrap Complete ==="
    echo "Argo CD URL: https://argocd.${TAILNET_DOMAIN}"
    echo "Username: admin"
    echo "Password: ${ARGOCD_PASSWORD}"
    echo ""
    echo "Next steps:"
    echo "  1. Change admin password: argocd account update-password"
    echo "  2. Configure repository credentials"
    echo "  3. Sync applications: argocd app sync homelab"
else
    echo "Argo CD CLI not installed. Install with: brew install argocd (macOS) or curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
    echo ""
    echo "Manual steps:"
    echo "  1. Access Argo CD at: https://argocd.${TAILNET_DOMAIN}"
    echo "  2. Login with admin / ${ARGOCD_PASSWORD}"
    echo "  3. Add repository: ${REPO_URL}"
    echo "  4. Create applications from k0s/manifests/argocd.yaml"
fi