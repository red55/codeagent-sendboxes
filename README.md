# Sandbox CI/CD Pipeline

AI agent sandbox Docker images with automated linting, building, security scanning, and publishing.

## CI/CD Workflows

### PR Build (`pr.yml`)
- **Triggers:** Pull requests to `main` branch
- **Jobs:** Lint → Build (4 variants) → Trivy Security Scan
- **Fork PRs:** Images pushed to `ghcr.io/red55/sandbox-<variant>:pr-<number>` for review
- **Non-fork PRs:** Images built locally for scanning only (no registry push)

### Release (`release.yml`)
- **Triggers:** Push to `main`, `v*` tags, manual dispatch
- **Jobs:** Lint → Build (4 variants with SBOM + provenance) → Trivy Security Scan
- **Images:** Pushed to `ghcr.io/red55/sandbox-<variant>` with SHA, branch, and semver tags
- **Attestations:** CycloneDX SBOM + build provenance (mode=max) on all release images

### Trivy Cron (`trivy-cron.yml`)
- **Schedule:** Daily at 06:00 UTC
- **Purpose:** Pre-warm Trivy vulnerability database to avoid rate limits

## Viewing Results

- **Lint results:** PR comments (actionlint) and GitHub Security tab (hadolint SARIF)
- **Security scans:** GitHub Security tab → Code scanning alerts (Trivy SARIF uploads)
- **PR comments:** Trivy findings posted as PR review comments
- **Build artifacts:** Fork PR images available at `ghcr.io/red55/sandbox-<variant>:pr-<number>`

## Manual Builds

Trigger any workflow manually via **Actions** tab → select workflow → **Run workflow**.
Or use `workflow_dispatch` — release workflow supports manual triggering.

## Image Variants

| Variant | Base | Tools |
|---------|------|-------|
| `sandbox-oc-go` | OpenCode + Go | Go tooling, OpenCode agent |
| `sandbox-qc-go` | QWEN Code + Go | Go tooling, QWEN Code agent |
| `sandbox-oc-ansible` | OpenCode + Ansible | Ansible tooling, OpenCode agent |
| `sandbox-qc-ansible` | QWEN Code + Ansible | Ansible tooling, QWEN Code agent |
