#!/usr/bin/env bash
# Deploy Script with SOPS Decryption
# Decrypts SOPS encrypted files and substitutes variables before applying

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
K0S_MANIFESTS="${REPO_ROOT}/k0s/manifests"
SOPS_DIR="${REPO_ROOT}/.sops"
AGE_KEY_FILE="${SOPS_DIR}/age.key"

echo "=== Homelab k0s Deploy with SOPS ==="

# Check for age key
if [[ ! -f "${AGE_KEY_FILE}" ]]; then
    echo "ERROR: Age key not found at ${AGE_KEY_FILE}"
    echo "Generate with: age-keygen -o ${AGE_KEY_FILE}"
    exit 1
fi

# Decrypt tailnet domain
echo "Decrypting tailnet domain..."
TAILNET_DOMAIN=$(SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}" sops --decrypt --extract '["tailnet_domain"]' "${SOPS_DIR}/tailnet.yaml")
echo "Tailnet domain: ${TAILNET_DOMAIN}"

# Create temporary directory for processed manifests
TMP_DIR=$(mktemp -d)
trap "rm -rf ${TMP_DIR}" EXIT

# Copy all manifests to temp dir
cp -r "${K0S_MANIFESTS}"/* "${TMP_DIR}/"

# Substitute TAILNET_DOMAIN in all YAML files
echo "Substituting TAILNET_DOMAIN placeholder..."
find "${TMP_DIR}" -name "*.yaml" -type f | while IFS= read -r file; do
    sed -i "s/\${TAILNET_DOMAIN}/${TAILNET_DOMAIN}/g" "${file}"
done

# Also substitute in kustomization.yaml if it has the placeholder
if grep -q "TAILNET_DOMAIN" "${TMP_DIR}/kustomization.yaml"; then
    sed -i "s/TAILNET_DOMAIN=.*/TAILNET_DOMAIN=${TAILNET_DOMAIN}/" "${TMP_DIR}/kustomization.yaml"
fi

# Apply with kustomize
echo "Applying manifests with kustomize..."
kubectl apply -k "${TMP_DIR}"

echo ""
echo "=== Deploy Complete ==="
echo "Tailnet domain: ${TAILNET_DOMAIN}"
echo ""
echo "Services available at:"
echo "  https://hermes.${TAILNET_DOMAIN}"
echo "  https://vault.${TAILNET_DOMAIN}"
echo "  https://ntfy.${TAILNET_DOMAIN}"
echo "  https://glance.${TAILNET_DOMAIN}"
echo "  https://karakeep.${TAILNET_DOMAIN}"
echo "  https://search.${TAILNET_DOMAIN}"
echo "  https://prometheus.${TAILNET_DOMAIN}"
echo "  https://grafana.${TAILNET_DOMAIN}"
echo "  https://alertmanager.${TAILNET_DOMAIN}"
echo "  https://argocd.${TAILNET_DOMAIN}"