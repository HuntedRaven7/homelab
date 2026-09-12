# Renovate Bot Configuration

This document explains how Renovate is configured for automated
dependency updates in this homelab repository.

## Overview

Renovate automatically:

1. Scans quadlet files for container images
2. Checks for newer versions on Docker Hub
3. Creates PRs with updated image digests (SHA256)
4. Optionally auto-merges patch/minor updates

## Configuration File

Location: `renovate.json` (repository root)

### Key Settings

| Setting         | Value              | Description                        |
|-----------------|--------------------|------------------------------------|
| `automerge`     | `true`             | Auto-merge PRs when checks pass    |
| `automergeType` | `"pr"`             | Merge via PR (not direct push)     |
| `schedule`      | Nightly/weekend    | Run outside business hours         |
| `timezone`      | `Europe/Stockholm` | Local timezone for scheduling      |
| `pinDigests`    | `true`             | Always pin to SHA256 digest        |

### Regex Managers

Renovate uses custom regex managers to parse quadlet files:

```json
"regexManagers": [
  {
    "fileMatch": ["^quadlets/.*\\.container$"],
    "matchStrings": [
      "Image=(?<depName>[^:]+):(?<currentValue>[^@\\s]+)@sha256:(?<currentDigest>[a-f0-9]+)"
    ],
    ...
  }
]
```

This matches both:

- `Image=docker.io/tailscale/tailscale:v1.74.0@sha256:abc123...`
- `Image=docker.io/tailscale/tailscale:v1.74.0`

## Package Rules

### Tailscale Specific

```json
{
  "matchManagers": ["regex"],
  "matchFileNames": ["**/tailscale.container"],
  "groupName": "tailscale",
  "automerge": true
}
```

- Groups all Tailscale updates
- Auto-merges patch/minor
- Major updates require manual review

### Version Extraction

```json
{
  "matchPackageNames": ["tailscale/tailscale"],
  "extractVersion": "^v(?<version>.+)$"
}
```

Handles Tailscale's `v1.74.0` version format.

### Major Updates

```json
{
  "matchUpdateTypes": ["major"],
  "automerge": false,
  "labels": ["major-update"]
}
```

Major version updates:

- **Not auto-merged**
- Labeled `major-update` for visibility
- Require manual review for breaking changes

## How It Works

### Detection

1. Renovate scans `quadlets/**/*.container` files
2. Finds `Image=` lines
3. Extracts image name and current version/digest
4. Queries Docker Hub for newer versions

### PR Creation

For each update found:

1. Creates branch: `renovate/tailscale-1.75.0`
2. Updates quadlet with new digest
3. Opens PR with conventional commit title
4. Includes changelog (if available)

### PR Content Example

```text
chore(deps): tailscale/tailscale v1.74.0 -> v1.75.0

Updates tailscale/tailscale from v1.74.0 to v1.75.0.

## Changelog
- Bug fix: ...
- Security: ...

## Checklist
- [ ] Test deployment
- [ ] Verify service starts
```

## Auto-Merge Behavior

### Patch/Minor Updates (Auto-Merge)

- Run nightly/weekend
- Merge when CI passes
- No notification unless failure

### Major Updates (Manual)

- PR created but not merged
- Labelled `major-update`
- Requires manual review and merge

## Customizing for New Services

When adding a new service quadlet:

### 1. Add to Regex Manager (if needed)

The default regex matches standard `Image=` lines. No changes
needed for typical cases.

### 2. Add Package Rule (Optional)

```json
{
  "matchManagers": ["regex"],
  "matchFileNames": ["**/myservice.container"],
  "groupName": "myservice",
  "automerge": true
}
```

### 3. Handle Version Format (if non-standard)

```json
{
  "matchPackageNames": ["library/myservice"],
  "extractVersion": "^(?<version>.+)$"
}
```

Common patterns:

- `v1.2.3` → `^v(?<version>.+)$`
- `1.2.3` → `^(?<version>.+)$`
- `latest` → Not recommended (unpinned)

## Testing Renovate Locally

### Dry Run

```bash
# Install renovate CLI
npm install -g renovate

# Run dry run
renovate --dry-run --platform=github --token=<GITHUB_TOKEN> robin/homelab
```

### Local Config Validation

```bash
# Validate config
renovate-config-validator renovate.json
```

## Troubleshooting

### Renovate Not Detecting Images

1. Check quadlet file format matches regex
2. Verify `Image=` line exists and is uncommented
3. Check renovate logs in PR checks

### Digest Not Updating

1. Ensure `pinDigests: true` in packageRules
2. Check Docker Hub has multi-arch manifests
3. Verify image exists at new version

### Auto-Merge Not Working

1. Check branch protection rules allow auto-merge
2. Verify `automerge: true` in config
3. Check PR has required status checks passing
4. Ensure no `major-update` label (blocks auto-merge)

### Rate Limiting

If hitting GitHub API limits:

```json
"prConcurrentLimit": 3,
"prHourlyLimit": 1
```

## Monitoring

### Check Renovate Status

- GitHub: Repository → Insights → Dependency graph
- Renovate Dashboard: <https://app.renovatebot.com/>
- PR labels: `dependencies`, `major-update`

### Audit Log

View all Renovate activity:

```text
Settings → Applications → Renovate → Configure → Audit log
```

## Best Practices

1. **Always pin digests** - Prevents supply chain attacks
2. **Test major updates** - Deploy to staging first
3. **Review changelogs** - Check for breaking changes
4. **Monitor failed PRs** - Fix config issues promptly
5. **Group related updates** - Reduces PR noise

## Disabling for Specific Images

```json
{
  "matchPackageNames": ["tailscale/tailscale"],
  "enabled": false
}
```

Or add to `ignorePaths` for entire files.

## Migration from Dependabot

If migrating from Dependabot:

1. Disable Dependabot in GitHub settings
2. Enable Renovate GitHub App
3. Add `renovate.json`
4. Renovate will detect existing config patterns
