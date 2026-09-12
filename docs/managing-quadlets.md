# Managing Quadlets

This guide covers deploying, updating, debugging, and monitoring Podman Quadlet services.

## Directory Structure

```
quadlets/
├── system/          # System services (installed to /etc/containers/systemd/)
└── user/            # User services (installed to ~/.config/containers/systemd/)
```

- **User quadlets** (preferred): Run rootless, no sudo required, user-scoped
- **System quadlets**: Run as root, system-wide, require sudo

## Deployment

### Automated Deployment (Recommended)

```bash
# Deploy all user quadlets
./scripts/deploy-quadlets.sh

# Deploy specific quadlet
./scripts/deploy-quadlets.sh tailscale
```

### Manual Deployment

```bash
# User quadlets
mkdir -p ~/.config/containers/systemd
ln -sf ~/git/personal/homelab/quadlets/user/*.container ~/.config/containers/systemd/
ln -sf ~/git/personal/homelab/quadlets/user/*.network ~/.config/containers/systemd/
ln -sf ~/git/personal/homelab/quadlets/user/*.volume ~/.config/containers/systemd/
systemctl --user daemon-reload

# System quadlets (requires sudo)
sudo mkdir -p /etc/containers/systemd
sudo ln -sf ~/git/personal/homelab/quadlets/system/*.container /etc/containers/systemd/
sudo ln -sf ~/git/personal/homelab/quadlets/system/*.network /etc/containers/systemd/
sudo ln -sf ~/git/personal/homelab/quadlets/system/*.volume /etc/containers/systemd/
sudo systemctl daemon-reload
```

## Service Management

### Enable and Start

```bash
# User service
systemctl --user enable --now tailscale

# System service
sudo systemctl enable --now tailscale
```

### Check Status

```bash
# User service
systemctl --user status tailscale
systemctl --user list-units '*.service' --state=active

# System service
sudo systemctl status tailscale
```

### View Logs

```bash
# Follow logs (user)
journalctl --user -u tailscale -f

# Last 100 lines (user)
journalctl --user -u tailscale -n 100

# Since boot (user)
journalctl --user -u tailscale -b

# System service logs
sudo journalctl -u tailscale -f
```

### Restart/Stop

```bash
# User service
systemctl --user restart tailscale
systemctl --user stop tailscale

# System service
sudo systemctl restart tailscale
sudo systemctl stop tailscale
```

## Updating Services

### Image Updates (via Renovate PR)

1. Renovate creates PR with updated image digest
2. Review and merge PR
3. Deploy updated quadlet:

```bash
./scripts/deploy-quadlets.sh
systemctl --user daemon-reload
systemctl --user restart tailscale
```

### Manual Image Update

```bash
# Pull new image
podman pull docker.io/tailscale/tailscale:v1.75.0

# Get new digest
podman inspect docker.io/tailscale/tailscale:v1.75.0 --format '{{.Digest}}'

# Update quadlet file with new digest
# Edit quadlets/user/tailscale.container

# Deploy and restart
./scripts/deploy-quadlets.sh
systemctl --user daemon-reload
systemctl --user restart tailscale
```

### Configuration Updates

```bash
# Edit environment file
vim ~/.config/containers/tailscale.env

# Reload and restart
systemctl --user daemon-reload
systemctl --user restart tailscale
```

## Debugging

### Common Issues

**Service fails to start:**
```bash
# Check detailed status
systemctl --user status tailscale --full

# Check journal for errors
journalctl --user -u tailscale -n 50 --no-pager

# Run container manually for debugging
podman run --rm -it --network host --cap-add NET_ADMIN --cap-add SYS_MODULE \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  docker.io/tailscale/tailscale:v1.74.0 /bin/sh
```

**Permission denied on volumes:**
```bash
# Fix volume permissions
mkdir -p /var/lib/tailscale
chmod 700 /var/lib/tailscale
```

**Network issues:**
```bash
# Check if podman network exists
podman network ls

# Inspect container network
podman inspect tailscale --format '{{.NetworkSettings}}'
```

### Debug Commands

```bash
# Show generated systemd unit
systemctl --user cat tailscale

# Show quadlet file
cat ~/.config/containers/systemd/tailscale.container

# Check podman version
podman --version

# Check quadlet generator
podman generate systemd --help
```

## Adding New Services

### 1. Create Quadlet File

```bash
# User service example
cat > quadlets/user/myapp.container << 'EOF'
[Unit]
Description=My Application
After=network-online.target

[Container]
Image=docker.io/library/myapp:v1.0.0@sha256:abc123...
ContainerName=myapp
Network=host
Volume=/path/on/host:/path/in/container:Z
Environment=MY_VAR=value
Restart=always

[Install]
WantedBy=default.target
EOF
```

### 2. Create Environment File (if needed)

```bash
cat > quadlets/user/myapp.env.example << 'EOF'
# My Application Config
MY_VAR=value
SECRET_KEY=changeme
EOF
```

### 3. Deploy and Test

```bash
./scripts/deploy-quadlets.sh myapp
systemctl --user daemon-reload
systemctl --user enable --now myapp
journalctl --user -u myapp -f
```

### 4. Add to Renovate

Update `renovate.json` to include the new image for automated updates.

## Quadlet Types

### Container (`.container`)
Main service definition - most common type.

### Network (`.network`)
Custom podman networks for service communication.

### Volume (`.volume`)
Named volumes for persistent data.

### Kube (`.kube`)
Kubernetes YAML for complex multi-container pods.

## Best Practices

1. **Pin images by digest** - Use `@sha256:...` for reproducibility
2. **Use rootless** - Prefer user quadlets over system quadlets
3. **Environment files** - Keep secrets out of quadlet files
4. **Health checks** - Add `HealthCheck=` for critical services
5. **Resource limits** - Set `MemoryLimit=` and `CPUQuota=` for stability
6. **Dependencies** - Use `After=` and `Requires=` for service ordering

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias qstatus='systemctl --user list-units "*.service" --state=active'
alias qlogs='journalctl --user -f -u'
alias qrestart='systemctl --user restart'
alias qenable='systemctl --user enable --now'
alias qdisable='systemctl --user disable --now'
alias qdeploy='~/git/personal/homelab/scripts/deploy-quadlets.sh'
```