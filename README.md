# Homelab

A declarative, GitOps-style homelab infrastructure managed with
**k0s Kubernetes** and **Argo CD**.

## Purpose

This repository serves as the single source of truth for my homelab
infrastructure. It uses a fully Kubernetes-native approach:

- **k0s Kubernetes** for all services (lightweight, single-binary cluster)
- **Argo CD** for GitOps continuous deployment
- **Traefik** as ingress controller with TLS termination
- **Prometheus Stack** for monitoring and alerting
- **Tailscale** for secure mesh VPN connectivity

This enables:

- **Declarative configuration** - All services defined as Kubernetes manifests
- **GitOps workflow** - Changes tracked, reviewed, and deployed via Git
- **Automated sync** - Argo CD continuously reconciles desired state
- **Kubernetes-native** - Leverages k8s scheduling, networking, storage
- **Automated updates** - Renovate bot creates PRs for image/hash updates
- **Tailscale mesh** - All nodes and services communicate via Tailscale VPN
- **Multi-node ready** - Easy to scale from single-node to HA cluster

## Architecture

```text
homelab/
├── k0s/
│   ├── config/k0s.yaml           # k0s cluster configuration
│   └── manifests/                # Kubernetes manifests
│       ├── common.yaml           # Namespaces, StorageClasses, PVs
│       ├── traefik-crds.yaml     # Traefik CRDs (IngressRoute, Middleware)
│       ├── traefik-deployment.yaml  # Traefik DaemonSet + RBAC
│       ├── traefik-ingressroutes.yaml  # IngressRoutes for all services
│       ├── prometheus-servicemonitors.yaml  # ServiceMonitors
│       ├── prometheus-rules.yaml  # PrometheusRules for alerting
│       ├── argocd.yaml           # Argo CD Project and Applications
│       ├── kustomization.yaml    # Kustomize configuration
│       └── apps/                 # Application manifests
│           ├── tailscale.yaml
│           ├── hermes-agent.yaml
│           ├── vaultwarden.yaml
│           ├── ntfy.yaml
│           ├── glance.yaml
│           ├── karakeep.yaml
│           └── searxng.yaml
├── docs/
│   ├── managing-quadlets.md      # Legacy: Podman Quadlet management
│   ├── managing-repo.md          # Git workflow, branching, PR process
│   └── renovate.md               # Renovate bot configuration guide
├── scripts/
│   ├── bootstrap-k0s.sh          # Bootstrap k0s cluster
│   └── bootstrap-argocd.sh       # Bootstrap Argo CD
├── renovate.json                 # Renovate bot configuration
└── README.md                     # This file
```

### Kubernetes Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                  TAILSCALE MESH NETWORK                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    k0s CLUSTER                         │ │
│  │                                                        │ │
│  │  Control Plane:                                        │ │
│  │  - k0s API, Controller, Scheduler                     │ │
│  │                                                        │ │
│  │  Workloads (homelab namespace):                        │ │
│  │  - Tailscale (DaemonSet)                               │ │
│  │  - Hermes Agent, Vaultwarden, Ntfy, Glance            │ │
│  │  - Karakeep, SearXNG                                   │ │
│  │  - Traefik (Ingress, hostPort 80/443)                  │ │
│  │  - Prometheus, Alertmanager, Grafana                   │ │
│  │  - Argo CD                                             │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Ingress: service.bluebuck-rudd.ts.net -> Traefik -> Service│
│  GitOps:   Argo CD watches Git -> Applies manifests        │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Linux server (2GB+ RAM, 2+ CPU cores) - Fedora/CentOS/RHEL/Ubuntu/Debian
- Tailscale account
- GitHub account (for Argo CD GitOps)
- Domain or Tailscale MagicDNS (`*.tailnet.ts.net`)

### Bootstrap a New Cluster

```bash
# 1. Install Tailscale and join tailnet
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --accept-routes --advertise-routes=192.168.1.0/24

# 2. Clone this repository
git clone https://github.com/yourusername/homelab.git ~/git/personal/homelab
cd ~/git/personal/homelab

# 3. Configure secrets (create .env files or use external-secrets)
# See k0s/manifests/apps/*.yaml for required secrets

# 4. Bootstrap k0s cluster
./scripts/bootstrap-k0s.sh

# 5. Verify cluster
kubectl get nodes -o wide
kubectl get pods -A

# 6. Bootstrap Argo CD
./scripts/bootstrap-argocd.sh

# 7. Access Argo CD UI
# URL: https://argocd.tailnet.ts.net
# User: admin
# Password: (shown in bootstrap output)
```

### Post-Bootstrap

1. **Login to Argo CD** and sync the `homelab` application
2. **Configure secrets** in Kubernetes (or use External Secrets Operator)
3. **Verify all services** are healthy in Argo CD UI
4. **Access services** via `https://<service>.tailnet.ts.net`

## Services

All services run in the `homelab` namespace (except Traefik, Prometheus Stack, Argo CD).

| Service | Type | Description | Deployment | Port | URL |
| ------- | ---- | ----------- | ---------- | ---- | --- |
| **Tailscale** | k0s | VPN mesh networking | DaemonSet (hostNetwork) | 9091 | - |
| **Traefik** | k0s | Ingress controller | DaemonSet (hostPort 80/443) | 80/443 | `https://traefik.tailnet.ts.net:8080` |
| **Hermes Agent** | k0s | Local AI inference (Nous) | Deployment | 8000 | `https://hermes.tailnet.ts.net` |
| **Vaultwarden** | k0s | Password manager | Deployment | 80 | `https://vault.tailnet.ts.net` |
| **Ntfy** | k0s | Push notifications | Deployment | 80 | `https://ntfy.tailnet.ts.net` |
| **Glance** | k0s | Dashboard | Deployment | 8080 | `https://glance.tailnet.ts.net` |
| **Karakeep** | k0s | Bookmark manager | Deployment | 3000 | `https://karakeep.tailnet.ts.net` |
| **SearXNG** | k0s | Privacy search engine | Deployment | 8080 | `https://search.tailnet.ts.net` |
| **Prometheus** | k0s | Metrics collection | StatefulSet (Helm) | 9090 | `https://prometheus.tailnet.ts.net` |
| **Grafana** | k0s | Dashboards | Deployment (Helm) | 80 | `https://grafana.tailnet.ts.net` |
| **Alertmanager** | k0s | Alert routing | StatefulSet (Helm) | 9093 | `https://alertmanager.tailnet.ts.net` |
| **Argo CD** | k0s | GitOps controller | Deployment (Helm) | 80 | `https://argocd.tailnet.ts.net` |

## Tailscale Integration

Tailscale runs as a **DaemonSet with `hostNetwork: true`** on each node to provide:

- **Mesh VPN** - All pods can communicate via Tailscale IPs
- **MagicDNS** - Services discover each other via `service.namespace.tailnet.ts.net`
- **Subnet routing** - Advertises node's LAN subnet to tailnet
- **Exit node** - Optional: route tailnet traffic through cluster

### Tailscale Configuration

The Tailscale DaemonSet authenticates via Kubernetes Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tailscale-auth
  namespace: homelab
type: Opaque
stringData:
  authkey: "tskey-auth-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

The DaemonSet runs `tailscaled` with userspace networking and configures:

```bash
tailscale up --authkey="${TAILSCALE_AUTH_KEY}" \
  --hostname=$(hostname) \
  --accept-routes \
  --advertise-routes=192.168.1.0/24
```

Adjust `--advertise-routes` to match your LAN subnet.

## GitOps with Argo CD

Argo CD continuously monitors this repository and applies changes:

```yaml
# k0s/manifests/argocd.yaml defines:
# - AppProject: homelab (RBAC, allowed resources)
# - Application: homelab (syncs k0s/manifests to cluster)
```

### Argo CD Applications

| Application | Source Path | Destination Namespace | Sync Policy |
| ----------- | ----------- | --------------------- | ----------- |
| `homelab` | `k0s/manifests` | `homelab` | Auto (prune, self-heal) |
| `monitoring` | `k0s/manifests` | `monitoring` | Auto |
| `ingress` | `k0s/manifests` | `kube-system` | Auto |

### Workflow

1. **Push changes** to Git (new manifests, image updates)
2. **Renovate** creates PRs for dependency updates
3. **Review & merge** PRs
4. **Argo CD detects** changes and syncs automatically
5. **Verify** in Argo CD UI or `kubectl`

## Monitoring

Prometheus Stack (via kube-prometheus-stack Helm chart) provides:

- **Prometheus** - Metrics collection and storage
- **Alertmanager** - Alert deduplication and routing
- **Grafana** - Dashboards and visualization
- **ServiceMonitors** - Auto-discovery of service metrics
- **PrometheusRules** - Predefined alerts for services, nodes, k8s

### ServiceMonitors

Each application ServiceMonitor scrapes metrics from its k8s Service:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hermes-agent
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: hermes-agent
  namespaceSelector:
    matchNames:
      - homelab
  endpoints:
    - port: http
      path: /metrics
```

### Key Alerts

- `ServiceDown` - Any service unavailable > 2min
- `ServiceHighLatency` - p99 latency > 5s
- `ServiceHighErrorRate` - 5xx rate > 5%
- `ContainerHighMemoryUsage` - > 85% memory limit
- `NodeHighMemoryUsage` - > 85% node memory
- `K0sNodeNotReady` - Node NotReady > 5min

## Adding New Services

1. **Create manifest** in `k0s/manifests/apps/<service>.yaml`:
   - Deployment/StatefulSet/DaemonSet
   - Service (ClusterIP)
   - IngressRoute (Traefik CRD)
   - Secret (for sensitive config)
   - ConfigMap (for non-sensitive config)
   - PVC (if persistent storage needed)

2. **Add ServiceMonitor** in `k0s/manifests/prometheus-servicemonitors.yaml`

3. **Add PrometheusRules** in `k0s/manifests/prometheus-rules.yaml` (optional)

4. **Update kustomization.yaml** to include new manifest

5. **Update renovate.json** with package rules for the new image

6. **Update this README** services table

7. **Commit and push** - Argo CD will deploy automatically

## Secrets Management with SOPS

Sensitive configuration (like the Tailscale tailnet domain) is encrypted
using **SOPS with age encryption** and stored in `.sops/`.

### Structure

```text
.sops/
├── age.key              # Age private key (NEVER commit - add to .gitignore)
├── age.key.pub          # Age public key (safe to commit)
├── tailnet.yaml         # Encrypted tailnet domain
└── tailnet.dec.yaml     # Decrypted template (for reference, not committed)
```

### Configuration

- `.sops.yaml` - SOPS configuration file defining encryption rules
- Age public key: `age1e45ke8t9tc9ke0u8ajk2cfnjv4xxh6q3569077q8smpku8gwxusqcpawul`

### Usage

**Encrypt a new value:**

```bash
# Create decrypted YAML
echo 'tailnet_domain: "new-domain.ts.net"' > .sops/tailnet.dec.yaml

# Encrypt
sops --encrypt --age age1e45ke8t9tc9ke0u8ajk2cfnjv4xxh6q3569077q8smpku8gwxusqcpawul \
  .sops/tailnet.dec.yaml > .sops/tailnet.yaml
```

**Decrypt locally:**

```bash
SOPS_AGE_KEY_FILE=.sops/age.key sops --decrypt .sops/tailnet.yaml
```

**Deploy with SOPS (automatic decryption):**

```bash
./scripts/deploy-k0s.sh
```

The deploy script:

1. Decrypts `.sops/tailnet.yaml` using the age key
2. Substitutes `${TAILNET_DOMAIN}` placeholder in all manifests
3. Applies with kustomize

### Key Management

- **Never commit** `.sops/age.key` (private key)
- Store private key in password manager (1Password, Bitwarden, etc.)
- Distribute private key securely to authorized deploy machines
- Rotate keys periodically: generate new key, re-encrypt all files

### GitOps with Encrypted Secrets

For production, consider **External Secrets Operator** which can:

- Fetch secrets from external stores (Vault, AWS Secrets Manager, etc.)
- Sync to Kubernetes Secrets automatically
- Works with Argo CD for full GitOps

## Management

- [Managing Repository](docs/managing-repo.md) - Git workflow, branching, PR process
- [Renovate Bot](docs/renovate.md) - Automated dependency updates

### Useful Commands

```bash
# Check cluster status
kubectl get nodes -o wide
kubectl get pods -A

# Check Argo CD applications
argocd app list
argocd app get homelab

# Force sync
argocd app sync homelab

# View logs
kubectl logs -n homelab -l app=hermes-agent -f

# Port-forward for debugging
kubectl port-forward -n homelab svc/hermes-agent 8000:8000
```

## Security

- **k0s** - Lightweight, secure Kubernetes distribution
- **Tailscale** - Encrypted mesh VPN, no public exposure
- **Traefik** - TLS termination at ingress, security headers middleware
- **Secrets** - Kubernetes Secrets (consider External Secrets Operator for production)
- **Images** - Pinned by digest (SHA256) for supply chain security
- **Renovate** - Automated dependency updates with digest pinning
- **RBAC** - Least-privilege ServiceAccounts for each component
- **Network Policies** - Can be added for pod-to-pod isolation

## License

MIT License - See [LICENSE](LICENSE) for details.
