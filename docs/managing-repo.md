# Managing the Repository

This guide covers the Git workflow, branching strategy, contribution process, and repository maintenance for the homelab repository.

## Repository Structure

```
homelab/
├── .github/
│   ├── workflows/       # GitHub Actions (CI, renovate)
│   └── renovate.json    # Renovate bot configuration
├── quadlets/
│   ├── system/          # System-level quadlets
│   └── user/            # User-level quadlets
├── docs/                # Documentation
├── scripts/             # Helper scripts
├── renovate.json        # Root renovate config
├── README.md
└── LICENSE
```

## Branching Strategy

### Main Branches

- **`main`** - Production-ready, deployed state
- **`develop`** - Integration branch for upcoming changes (optional)

### Feature Branches

```
feature/<short-description>   # New services, features
fix/<short-description>       # Bug fixes
chore/<short-description>     # Maintenance, updates
docs/<short-description>      # Documentation only
renovate/<dependency-name>    # Automated Renovate PRs
```

### Branch Naming Examples

- `feature/add-prometheus-monitoring`
- `fix/tailscale-auth-key-rotation`
- `chore/update-base-images`
- `docs/quadlet-deployment-guide`
- `renovate/tailscale-1.75.0`

## Git Workflow

### 1. Creating Changes

```bash
# Start from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/add-new-service

# Make changes, commit frequently
git add quadlets/user/newservice.container
git commit -m "feat: add newservice quadlet

- Add container definition with resource limits
- Include environment file template
- Update renovate.json for automated updates"
```

### 2. Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat` - New feature/service
- `fix` - Bug fix
- `chore` - Maintenance, dependency updates
- `docs` - Documentation only
- `refactor` - Code restructuring
- `ci` - CI/CD changes
- `test` - Adding tests

**Examples:**
```
feat: add prometheus quadlet with node-exporter
fix: correct tailscale volume permissions
chore: update tailscale to v1.75.0
docs: add quadlet debugging guide
refactor: reorganize quadlets into system/user dirs
```

### 3. Opening Pull Requests

```bash
# Push branch
git push origin feature/add-new-service

# Open PR via GitHub CLI or web UI
gh pr create --title "feat: add newservice quadlet" \
  --body "Adds newservice with...
  
  - Container config
  - Env template
  - Renovate config"
```

### 4. PR Requirements

- [ ] Descriptive title following conventional commits
- [ ] Clear description of changes and motivation
- [ ] Linked issues (if applicable)
- [ ] Updated documentation (if behavior changes)
- [ ] Renovate config updated for new images
- [ ] CI passes (if configured)

### 5. Review and Merge

- **Self-merge allowed** for personal repo
- **Squash and merge** preferred for clean history
- **Delete branch** after merge

```bash
# Via CLI
gh pr merge --squash --delete-branch
```

## Renovate Bot Integration

Renovate automatically creates PRs for dependency updates:

### How It Works

1. Renovate scans `quadlets/**/*.container` for image references
2. Checks for newer digests/tags upstream
3. Creates PR with updated digest
4. Runs CI checks (if configured)
5. Auto-merges if configured and tests pass

### Handling Renovate PRs

```bash
# Review the PR
gh pr view <pr-number>

# Check what changed
gh pr diff <pr-number>

# Test locally (optional)
git fetch origin pull/<pr-number>/head:renovate-test
git checkout renovate-test
./scripts/deploy-quadlets.sh
systemctl --user daemon-reload
systemctl --user restart <service>

# Merge if satisfied
gh pr merge <pr-number> --squash --delete-branch
```

### Renovate Configuration

See [renovate.md](renovate.md) for detailed configuration.

## Repository Maintenance

### Adding New Services Checklist

- [ ] Create quadlet in `quadlets/user/` or `quadlets/system/`
- [ ] Create `.env.example` with documented variables
- [ ] Add to `renovate.json` `dockerImage` rules
- [ ] Update README services table
- [ ] Test deployment locally
- [ ] Document any special configuration in docs/

### Updating Existing Services

- [ ] Update image digest in quadlet file
- [ ] Update `.env.example` if new variables needed
- [ ] Test deployment
- [ ] Commit with `chore:` or `feat:` prefix

### Cleanup

```bash
# Remove merged branches locally
git branch --merged | grep -v "\*\|main" | xargs -n 1 git branch -d

# Prune remote tracking branches
git remote prune origin
```

## GitHub Configuration

### Required Settings

1. **Branch Protection** (optional for personal repo):
   - Require PR review
   - Require status checks
   - Require linear history

2. **Auto-merge** for Renovate PRs:
   - Settings → General → Auto-merge → Enable

3. **Dependabot alerts** (backup to Renovate):
   - Settings → Security → Dependabot alerts → Enable

### Useful GitHub CLI Commands

```bash
# List open PRs
gh pr list

# View PR checks
gh pr checks <pr-number>

# Run workflow manually
gh workflow run "CI" --ref main

# View workflow runs
gh run list --workflow=CI
```

## Secrets Management

### Repository Secrets (GitHub)

Store in Settings → Secrets → Actions:

| Secret | Purpose |
|--------|---------|
| `TAILSCALE_AUTH_KEY` | For CI testing (if needed) |
| `GH_TOKEN` | For Renovate (auto-configured) |

### Local Secrets

**Never commit secrets to Git.**

```bash
# Local environment files (gitignored)
~/.config/containers/tailscale.env
~/.config/containers/other-service.env
```

Template files (committed):
```
quadlets/user/tailscale.env.example
```

## Disaster Recovery

### Rebootstrap New Machine

```bash
# 1. Enable linger
sudo loginctl enable-linger $(whoami)

# 2. Clone repo
git clone https://github.com/yourusername/homelab.git ~/git/personal/homelab

# 3. Configure secrets
cp ~/git/personal/homelab/quadlets/user/*.env.example ~/.config/containers/
# Edit each .env file

# 4. Deploy all
cd ~/git/personal/homelab
./scripts/deploy-quadlets.sh
systemctl --user daemon-reload

# 5. Start services
systemctl --user enable --now tailscale
# ... other services
```

### Backup Strategy

- **Git repo** = Source of truth (push to GitHub regularly)
- **Secrets** = Store in password manager (1Password, Bitwarden, etc.)
- **Data volumes** = Backup separately (restic, borg, etc.)

## Scripts

### deploy-quadlets.sh

```bash
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
```

Make executable: `chmod +x scripts/deploy-quadlets.sh`

## Quick Reference

| Task | Command |
|------|---------|
| New feature | `git checkout -b feature/name` |
| Quick fix | `git checkout -b fix/name` |
| View changes | `git diff` |
| Stage all | `git add -A` |
| Commit | `git commit -m "type: message"` |
| Push | `git push origin branch-name` |
| Open PR | `gh pr create` |
| Merge PR | `gh pr merge --squash` |
| Sync main | `git checkout main && git pull` |
| Deploy quadlets | `./scripts/deploy-quadlets.sh` |