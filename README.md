# Homelab

A declarative, GitOps-style homelab infrastructure managed with
**Podman Quadlets**, **systemd**, and **k0s Kubernetes**.

## Purpose

This repository serves as the single source of truth for my homelab
infrastructure. It uses a hybrid approach:

- **Podman Quadlets + systemd** for application services (rootless, Tailscale mesh)
- **k0s Kubernetes** for cluster infrastructure (Traefik ingress, Prometheus monitoring)

This enables:
- **Declarative configuration** - All services defined as code
- **GitOps workflow** - Changes tracked, reviewed, and deployed via Git
- **Systemd integration** - Native service management for rootless containers
- **Rootless containers** - Secure, unprivileged service execution
- **Automated updates** - Renovate bot creates PRs for image/hash updates
- **Tailscale mesh** - All services communicate via Tailscale VPN
- **Kubernetes-native ingress & monitoring** - Traefik + Prometheus stack on k0s

## Architecture

```text
homelab/
├── k0s/
│   ├── config/k0s.yaml           # k0s cluster configuration
│   └── manifests/                # Kubernetes manifests
│       ├── traefik-crds.yaml     # Traefik CRDs (IngressRoute, Middleware)
│       ├── traefik-deployment.yaml  # Traefik DaemonSet + RBAC
│       ├── traefik-ingressroutes.yaml  # IngressRoutes for all services
│       ├── prometheus-servicemonitors.yaml  # ServiceMonitors for Tailscale services
│       └── prometheus-rules.yaml  # PrometheusRules for alerting
├── quadlets/
│   ├── system/                   # System-level services (require root)
│   └── user/                     # User-level services (rootless, preferred)
├── docs/
│   ├── managing-quadlets.md      # How to deploy, update, debug quadlets
│   ├── managing-repo.md          # Git workflow, branching, PR process
│   └── renovate.md               # Renovate bot configuration guide
├── scripts/
│   ├── deploy-quadlets.sh        # Deploy Podman Quadlets
│   └── bootstrap-k0s.sh          # Bootstrap k0s cluster
├── renovate.json                 # Renovate bot configuration
└── README.md                     # This file
```

### Hybrid Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                              TAILSCALE MESH                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────┐         ┌─────────────────────────────────┐   │
│   │   Podman Quadlets       │         │          k0s Cluster            │   │
│   │   (Rootless, User)      │         │      (System-level)             │   │
│   ├─────────────────────────┤         ├─────────────────────────────────┤   │
│   │                         │         │                                 │   │
│   │  • Tailscale            │         │  • Traefik (DaemonSet)          │   │
│   │  • Hermes Agent         │         │     - Ingress Controller        │   │
│   │  • Vaultwarden          │         │     - TLS Termination           │   │
│   │  • Ntfy                 │         │     - hostPort 80/443           │   │
│   │  • Glance               │         │                                 │   │
│   │  • Karakeep             │         │  • Prometheus Stack (Helm)      │   │
│   │  • SearXNG              │         │     - Prometheus + Alertmanager │   │
│   │                         │         │     - Grafana                   │   │
│   │                         │         │     - ServiceMonitors + Rules   │   │
│   └──────────────┬──────────┘         └───────────────┬─────────────────┘   │
│                  │                                    │                     │
│                  │        ExternalName Services       │                     │
│                  └────────────────┬───────────────────┘                     │
│                                   │                                         │
│              ┌────────────────────┴────────────────────┐                    │
│              │     Tailscale MagicDNS Resolution       │                    │
│              │  service.tailnet.ts.net → 100.x.y.z     │                    │
│              └─────────────────────────────────────────┘                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Application services** run as rootless Podman containers on the Tailscale network namespace (`Network=container:tailscale`)
- **Traefik** runs as a k0s DaemonSet with `hostPort: 80/443`, acting as the ingress controller
- **Prometheus Stack** runs in k0s via Helm (kube-prometheus-stack), scraping metrics from services via `ExternalName` Services pointing to Tailscale MagicDNS names
- **IngressRoutes** (Traefik CRDs) route traffic from `service.tailnet.ts.net` → k0s Traefik → ExternalName Service → Tailscale → Podman container

## Quick Start

### Prerequisites

- Fedora/CentOS/RHEL or any systemd-based distro with Podman 4.4+
- `podman` and `systemd` user lingering enabled
- Git
- Tailscale account
- For k0s: 2GB+ RAM, 2+ CPU cores

### Bootstrap a New Machine (Podman Quadlets)

```bash
# 1. Enable user lingering (allows user services to start at boot)
sudo loginctl enable-linger $(whoami)

# 2. Clone this repository
git clone https://github.com/yourusername/homelab.git ~/git/personal/homelab
cd ~/git/personal/homelab

# 3. Configure environment files
cp quadlets/user/tailscale.env.example ~/.config/containers/tailscale.env
# Edit ~/.config/containers/tailscale.env with your auth key

# For each service, copy and configure:
cp quadlets/user/hermes-agent.env.example ~/.config/containers/hermes-agent.env
cp quadlets/user/vaultwarden.env.example ~/.config/containers/vaultwarden.env
cp quadlets/user/ntfy.env.example ~/.config/containers/ntfy.env
cp quadlets/user/glance.env.example ~/.config/containers/glance.env
cp quadlets/user/karakeep.env.example ~/.config/containers/karakeep.env
cp quadlets/user/searxng.env.example ~/.config/containers/searxng.env

# 4. Deploy quadlets (symlink to systemd user directory)
./scripts/deploy-quadlets.sh

# 5. Configure Glance
mkdir -p /etc/glance
cp quadlets/user/glance/glance.yml /etc/glance/glance.yml

# 6. Configure SearXNG
mkdir -p /etc/searxng
cp quadlets/user/searxng/settings.yml /etc/searxng/settings.yml

# 7. Start application services
systemctl --user daemon-reload
systemctl --user enable --now tailscale
systemctl --user enable --now hermes-agent
systemctl --user enable --now vaultwarden
systemctl --user enable --now ntfy
systemctl --user enable --now glance
systemctl --user enable --now karakeep
systemctl --user enable --now searxng
```

### Bootstrap k0s Cluster (Traefik + Prometheus)

Run on the control plane node:

```bash
# 1. Run bootstrap script (installs k0s, Traefik, Prometheus stack)
./scripts/bootstrap-k0s.sh

# 2. Verify cluster
kubectl get nodes -o wide
kubectl get pods -A

# 3. Access services via Traefik (host ports 80/443)
# All routes configured in k0s/manifests/traefik-ingressroutes.yaml
```

## Services

### Application Services (Podman Quadlets on Tailscale)

All services run on the Tailscale network (`Network=container:tailscale`) and are accessible via Traefik at `https://<service>.your-tailnet.ts.net`.

| Service | Type | Description | Quadlet | Port | URL |
|---------|------|-------------|---------|------|-----|
| **Tailscale** | User | VPN mesh networking | `tailscale.container` | - | - |
| **Hermes Agent** | User | Local AI inference (Nous) | `hermes-agent.container` | 8000 | `https://hermes.tailnet.ts.net` |
| **Vaultwarden** | User | Password manager | `vaultwarden.container` | 80 | `https://vault.tailnet.ts.net` |
| **Ntfy** | User | Push notifications | `ntfy.container` | 80 | `https://ntfy.tailnet.ts.net` |
| **Glance** | User | Dashboard | `glance.container` | 8080 | `https://glance.tailnet.ts.net` |
| **Karakeep** | User | Bookmark manager | `karakeep.container` | 3000 | `https://karakeep.tailnet.ts.net` |
| **SearXNG** | User | Privacy search engine | `searxng.container` | 8080 | `https://search.tailnet.ts.net` |

### Cluster Services (k0s Kubernetes)

| Service | Type | Description | Deployment | Port | URL |
|---------|------|-------------|------------|------|-----|
| **Traefik** | k0s | Ingress controller | DaemonSet (hostPort 80/443) | 80/443 | `https://traefik.tailnet.ts.net:8080` |
| **Prometheus** | k0s | Metrics collection | StatefulSet (Helm) | 9090 | `https://prometheus.tailnet.ts.net` |
| **Grafana** | k0s | Dashboards | Deployment (Helm) | 80 | `https://grafana.tailnet.ts.net` |
| **Alertmanager** | k0s | Alert routing | StatefulSet (Helm) | 9093 | `https://alertmanager.tailnet.ts.net` |

## Tailscale Integration

Each Podman Quadlet service uses `Network=container:tailscale` to join the Tailscale container's network namespace. This provides:

- **Zero-config networking** - Services auto-discover each other via container names
- **Secure by default** - No ports exposed to host, only via Tailscale
- **Mesh VPN** - Access from any device on your tailnet
- **MagicDNS** - Use `service-name.tailnet.ts.net` for routing

### Tailscale Configuration

The Tailscale quadlet advertises routes for your local subnet and accepts routes from other nodes:

```ini
Environment=TS_EXTRA_ARGS=--accept-routes --advertise-routes=192.168.1.0/24
```

Adjust `--advertise-routes` to match your LAN subnet.

### k0s ↔ Tailscale Bridge

k0s services connect to Tailscale services via `ExternalName` Services:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hermes-agent
  namespace: default
spec:
  type: ExternalName
  externalName: hermes-agent.tailnet.ts.net
  ports:
    - port: 8000
      targetPort: 8000
```

This allows Prometheus (in k0s) to scrape `hermes-agent:8000/metrics` and Traefik to route `hermes.tailnet.ts.net` → `hermes-agent:8000`.

## Management

- [Managing Quadlets](docs/managing-quadlets.md) - Deploy, update, debug, and monitor services
- [Managing Repository](docs/managing-repo.md) - Git workflow, contributing, releases
- [Renovate Bot](docs/renovate.md) - Automated dependency updates

## Adding New Services

### Application Service (Podman Quadlet)

1. Create quadlet in `quadlets/user/` with `Network=container:tailscale`
2. Create `.env.example` with documented variables
3. Add Traefik IngressRoute in `k0s/manifests/traefik-ingressroutes.yaml`
4. Add ServiceMonitor in `k0s/manifests/prometheus-servicemonitors.yaml`
5. Add Glance widget in `quadlets/user/glance/glance.yml`
6. Update `renovate.json` with package rules
7. Update this README services table
8. Test deployment locally

### Cluster Service (k0s Manifest)

1. Create manifest in `k0s/manifests/`
2. Add to `k0s/config/k0s.yaml` if using Helm
3. Update `renovate.json` for image updates
4. Apply with `kubectl apply -f k0s/manifests/`

## Security

- All Podman containers run rootless (no root privileges)
- k0s control plane runs as systemd service (root required for k0s)
- Secrets managed via environment files (not committed to Git)
- Images pinned by digest (SHA256) for supply chain security
- Renovate updates hashes automatically via PR
- Tailscale provides encrypted mesh networking
- No public port exposure required (only via Tailscale)
- Traefik TLS termination at ingress

## License

MIT License - See [LICENSE](LICENSE) for details.
