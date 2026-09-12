#!/usr/bin/env bash
# Deploy quadlets to systemd user directory

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${HOME}/.config/containers/systemd"

mkdir -p "${TARGET_DIR}"

# Deploy user quadlets
for quadlet in "${REPO_ROOT}/quadlets/user/"*; do
    if [[ -f "${quadlet}" ]]; then
        ln -sf "${quadlet}" "${TARGET_DIR}/"
        echo "Linked $(basename "${quadlet}")"
    fi
done

echo "Run: systemctl --user daemon-reload"