# Homelab

A declarative, GitOps-style homelab infrastructure managed with
**Podman Quadlets** and **systemd**.

## Purpose

This repository serves as the single source of truth for my homelab
infrastructure. It uses Podman Quadlets to define containerized
services as systemd units, enabling:

- **Declarative configuration** - All services defined as code
- **GitOps workflow** - Changes tracked, reviewed, and deployed via Git
- **Systemd integration** - Native service management, logging, and dependencies
- **Rootless containers** - Secure, unprivileged service execution
- **Automated updates** - Renovate bot creates PRs for image/hash updates
- **Tailscale mesh** - All services communicate via Tailscale VPN

## Architecture

```text
homelab/
├── quadlets/
│   ├── system/          # System-level services (require root)
│   └── user/            # User-level services (rootless, preferred)
├── docs/
│   ├── managing-quadlets.md    # How to deploy, update, debug quadlets
│   ├── managing-repo.md        # Git workflow, branching, PR process
│   └── renovate.md             # Renovate bot configuration guide
├── scripts/             # Helper scripts (deploy-quadlets.sh)
├── renovate.json        # Renovate bot configuration
└── README.md            # This file
```

All user services run on the **Tailscale network namespace**
(`Network=container:tailscale`), meaning they're only accessible
via the Tailscale mesh. Traefik acts as the ingress controller,
routing traffic based on hostnames.

## Quick Start

### Prerequisites

- Fedora/CentOS/RHEL or any systemd-based distro with Podman 4.4+
- `podman` and `systemd` user lingering enabled
- Git
- Tailscale account

### Bootstrap a New Machine

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
cp quadlets/user/prometheus.env.example ~/.config/containers/prometheus.env
cp quadlets/user/traefik.env.example ~/.config/containers/traefik.env

# 4. Deploy quadlets (symlink to systemd user directory)
./scripts/deploy-quadlets.sh

# 5. Configure Traefik dynamic config
mkdir -p /etc/traefik
cp quadlets/user/traefik/dynamic.yml /etc/traefik/dynamic.yml
# Edit /etc/traefik/dynamic.yml with your tailnet domain

# 6. Configure Prometheus
mkdir -p /etc/prometheus
cp quadlets/user/prometheus/prometheus.yml /etc/prometheus/prometheus.yml

# 7. Configure Glance
mkdir -p /etc/glance
cp quadlets/user/glance/glance.yml /etc/glance/glance.yml

# 8. Configure SearXNG
mkdir -p /etc/searxng
cp quadlets/user/searxng/settings.yml /etc/searxng/settings.yml

# 9. Start services
systemctl --user daemon-reload
systemctl --user enable --now tailscale
systemctl --user enable --now traefik
systemctl --user enable --now hermes-agent
systemctl --user enable --now vaultwarden
systemctl --user enable --now ntfy
systemctl --user enable --now glance
systemctl --user enable --now karakeep
systemctl --user enable --now searxng
systemctl --user enable --now prometheus
```

## Services

All services run on the Tailscale network
(`Network=container:tailscale`) and are accessible via Traefik at
`https://<service>.your-tailnet.ts.net`.

- **Tailscale** (User) - VPN mesh networking
  - Quadlet: `tailscale.container`
  - Port: -
  - URL: -

- **Traefik** (User) - Reverse proxy
  - Quadlet: `traefik.container`
  - Port: 80/443
  - URL: `traefik:8080`

- **Hermes Agent** (User) - Local AI inference
  - Quadlet: `hermes-agent.container`
  - Port: 8000
  - URL: `hermes`

- **Vaultwarden** (User) - Password manager
  - Quadlet: `vaultwarden.container`
  - Port: 80
  - URL: `vault`

- **Ntfy** (User) - Push notifications
  - Quadlet: `ntfy.container`
  - Port: 80
  - URL: `ntfy`

- **Glance** (User) - Dashboard
  - Quadlet: `glance.container`
  - Port: 8080
  - URL: `glance`

- **Karakeep** (User) - Bookmark manager
  - Quadlet: `karakeep.container`
  - Port: 3000
  - URL: `karakeep`

- **SearXNG** (User) - Privacy search
  - Quadlet: `searxng.container`
  - Port: 8080
  - URL: `search`

- **Prometheus** (User) - Metrics collection
  - Quadlet: `prometheus.container`
  - Port: 9090
  - URL: `prometheus`

## Tailscale Integration

Each service quadlet uses `Network=container:tailscale` to join the
Tailscale container's network namespace. This provides:

- **Zero-config networking** - Services auto-discover each other
  via container names
- **Secure by default** - No ports exposed to host, only via Tailscale
- **Mesh VPN** - Access from any device on your tailnet
- **MagicDNS** - Use `service-name.tailnet.ts.net` for routing

### Tailscale Configuration

The Tailscale quadlet advertises routes for your local subnet and
accepts routes from other nodes:

```ini
Environment=TS_EXTRA_ARGS=--accept-routes --advertise-routes=192.168.1.0/24
```

Adjust `--advertise-routes` to match your LAN subnet.

## Management

- [Managing Quadlets](docs/managing-quadlets.md) - Deploy, update,
  debug, and monitor services
- [Managing Repository](docs/managing-repo.md) - Git workflow,
  contributing, releases
- [Renovate Bot](docs/renovate.md) - Automated dependency updates

## Adding New Services

1. Create quadlet in `quadlets/user/` with `Network=container:tailscale`
2. Create `.env.example` with documented variables
3. Add Traefik route in `quadlets/user/traefik/dynamic.yml`
4. Add Prometheus scrape config in `quadlets/user/prometheus/prometheus.yml`
5. Add Glance widget in `quadlets/user/glance/glance.yml`
6. Update `renovate.json` with package rules
7. Update this README services table
8. Test deployment locally

## Security

- All containers run rootless (no root privileges)
- Secrets managed via environment files (not committed to Git)
- Images pinned by digest (SHA256) for supply chain security
- Renovate updates hashes automatically via PR
- Tailscale provides encrypted mesh networking
- No public port exposure required

## License

MIT License - See [LICENSE](LICENSE) for details.
