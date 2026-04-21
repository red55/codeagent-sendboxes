# CI/CD Pipeline for Docker-Based Sandbox Images — Research Findings

**Date:** 2026-04-20
**Research Scope:** GitHub Actions Docker CI/CD patterns, linting, security scanning, testing, and reproducible builds.

---

## 1. GitHub Actions Docker CI/CD Patterns

### 1.1 Core Action Stack

The modern Docker CI/CD pipeline on GitHub Actions uses these official actions:

| Action | Version | Purpose |
|--------|---------|---------|
| `docker/checkout` | v4+ | Repository checkout (or `actions/checkout@v6`) |
| `docker/setup-buildx-action` | v4 | Creates BuildKit builder instance |
| `docker/setup-qemu-action` | v4 | QEMU emulation for multi-platform builds |
| `docker/login-action` | v4 | Registry authentication |
| `docker/metadata-action` | v6 | Tag/label extraction from Git metadata |
| `docker/build-push-action` | v7 | Build and push Docker images with BuildKit |
| `docker/bake-action` | v7 | High-level multi-target builds via Bake |

### 1.2 Multi-Stage Docker Builds

For multi-stage builds, use the `target` input to build a specific stage, or build the full image and use a separate target stage for testing:

```yaml
- name: Build and push
  uses: docker/build-push-action@v7
  with:
    context: .
    file: ./Dockerfile
    target: builder        # Build only a specific stage
    push: false            # Don't push intermediate stage
    load: true             # Load into local Docker for testing
```

**Recommendation:** For sandbox images, multi-stage builds are ideal — one stage for building dependencies, another for the minimal runtime image. Use `target` to build only the final stage, keeping images lean.

### 1.3 Build Caching Strategies

Three cache backends are available, each with trade-offs:

#### A. Registry Cache (Recommended for multi-branch workflows)

```yaml
- name: Build and push
  uses: docker/build-push-action@v7
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
    cache-from: type=registry,ref=ghcr.io/${{ github.repository }}:buildcache
    cache-to: type=registry,ref=ghcr.io/${{ github.repository }}:buildcache,mode=max
```

- **Pros:** Shared across all branches, persists independently of GitHub Actions cache limits
- **Cons:** Requires pushing image first (cache is stored as a separate manifest)
- **Best for:** Teams with PR-heavy workflows; cache survives branch deletion

#### B. GitHub Actions Cache (Simplest setup)

```yaml
- name: Build and push
  uses: docker/build-push-action@v7
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

- **Pros:** No registry storage needed; works with `load: true` for test-before-push
- **Cons:** Cache is per-repository with 10GB limit; PR branches can only read default branch cache
- **Best for:** Single-branch or small-team workflows

#### C. Local Cache with `actions/cache` (For cache mounts)

BuildKit's `--mount=type=cache` doesn't persist across builds by default. Use `buildkit-cache-dance` to bridge local cache mounts to GitHub Actions cache:

```yaml
- name: Cache Docker layers
  uses: actions/cache@v5
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-

- name: Build and push
  uses: docker/build-push-action@v7
  with:
    cache-from: type=local,src=/tmp/.buildx-cache
    cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max

- name: Move cache
  run: |
    rm -rf /tmp/.buildx-cache
    mv /tmp/.buildx-cache-new /tmp/.buildx-cache
```

#### D. Smart PR Cache with `docker-build-cache-config-action`

For PR-specific cache management, use `int128/docker-build-cache-config-action@v1`:

```yaml
- uses: docker/metadata-action@v6
  id: metadata
  with:
    images: ghcr.io/${{ github.repository }}

- uses: int128/docker-build-cache-config-action@v1
  id: cache
  with:
    image: ghcr.io/${{ github.repository }}/cache
    pull-request-cache: true

- uses: docker/build-push-action@v7
  with:
    push: true
    tags: ${{ steps.metadata.outputs.tags }}
    cache-from: ${{ steps.cache.outputs.cache-from }}
    cache-to: ${{ steps.cache.outputs.cache-to }}
```

This automatically generates cache-from/cache-to pairs that import from `main` and export to a PR-specific tag (`pr-123`), preventing cache pollution.

### 1.4 Registry Authentication (ghcr.io)

```yaml
- name: Login to GHCR
  uses: docker/login-action@v4
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

**Key points:**
- `GITHUB_TOKEN` is auto-created for every workflow run — no secret needed
- Set `permissions: packages: write` at the job level
- Package name inherits repo name: `ghcr.io/${{ github.repository }}`
- For private repos, the package visibility is automatically set to `private`

### 1.5 Matrix Builds for Multiple Image Variants

Use `docker/bake-action` for multi-target builds (preferred over manual matrix):

```hcl
# docker-bake.hcl
variable "DEFAULT_TAG" { default = "latest" }

target "sandbox" {
  dockerfile = "Dockerfile"
  tags       = ["ghcr.io/${{ github.repository }}/sandbox:${DEFAULT_TAG}"]
}

target "sandbox-alpine" {
  dockerfile = "Dockerfile.alpine"
  tags       = ["ghcr.io/${{ github.repository }}/sandbox-alpine:${DEFAULT_TAG}"]
}
```

```yaml
- name: Build all variants
  uses: docker/bake-action@v7
  with:
    files: docker-bake.hcl
    targets: sandbox,sandbox-alpine
    push: true
    set: |
      *.tags=ghcr.io/${{ github.repository }}:${{ github.sha }}
```

Alternatively, use a GitHub Actions matrix with `docker/build-push-action`:

```yaml
jobs:
  build:
    strategy:
      matrix:
        variant: [debian, alpine, slim]
        include:
          - variant: debian
            dockerfile: Dockerfile
          - variant: alpine
            dockerfile: Dockerfile.alpine
          - variant: slim
            dockerfile: Dockerfile.slim
    runs-on: ubuntu-latest
    steps:
      - uses: docker/build-push-action@v7
        with:
          file: ${{ matrix.dockerfile }}
          push: ${{ github.event_name != 'pull_request' }}
          tags: ghcr.io/${{ github.repository }}/${{ matrix.variant }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## 2. Linting Tools

### 2.1 Hadolint — Dockerfile Validation

**Purpose:** Static analysis for Dockerfiles using AST parsing + ShellCheck integration.

#### GitHub Action

```yaml
- name: Lint Dockerfile
  uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: Dockerfile
    config: .hadolint.yaml
    format: sarif
    output-file: hadolint-results.sarif
```

#### Configuration (`.hadolint.yaml`)

```yaml
# Ignore rules that don't apply to your project
ignored:
  - DL3008  # Pin versions in apt-get install
  - DL3042 # Avoid use of cache-http

# Override rule severities
override:
  info:
    - DL3006  # Always tag the version of an image explicitly
  warning:
    - DL3003  # Use WORKDIR to switch to a directory

# Require specific labels
require-labels:
  - maintainer
  - version=semver

# Trusted registries for FROM instructions
trusted-registries:
  - docker.io
  - ghcr.io
```

#### Inline Ignoring in Dockerfiles

```dockerfile
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y curl

# Global ignore for entire file
# hadolint global ignore=DL3006,DL3008
```

#### Key Rules to Enforce

| Rule | Severity | Why |
|------|----------|-----|
| DL3006 | Error | Always tag images explicitly (`FROM alpine:3.19`, not `FROM alpine`) |
| DL3008 | Warning | Pin apt-get versions (`apt-get install -y package=version`) |
| DL3015 | Warning | Avoid unnecessary RUN steps (use `&&` chaining) |
| DL3018 | Warning | Pin apk versions (`apk add package=version`) |
| SC2086 | Info | ShellCheck: quote variables in RUN instructions |

### 2.2 Actionlint — GitHub Actions Workflow Validation

**Purpose:** Static analysis for `.github/workflows/*.yml` files.

#### GitHub Action (via reviewdog)

```yaml
- name: Lint workflows
  uses: reviewdog/action-actionlint@v1
  with:
    reporter: github-pr-review  # Posts as PR comments
    fail_level: error           # Fails on error-level issues only
    level: error
```

#### Local/CI-only mode (no reviewdog)

```yaml
- name: Lint workflows
  run: |
    docker run --rm -v "${PWD}/.github/workflows:/workflows" rhysd/actionlint:latest
```

#### Configuration (`.github/actionlint.yaml`)

```yaml
# Custom runner labels
self-hosted-runner:
  labels:
    - ubuntu-24.04-selfhosted

# Ignore specific errors on specific lines
ignore:
  - "use of run-on with self-hosted"
```

#### Key Checks

- **YAML syntax:** Missing keys, unexpected keys, type mismatches
- **Expression type checking:** `${{ }}` expressions validate property access
- **Action I/O validation:** `with:` inputs and `steps.{id}.outputs` references
- **Security:** Untrusted `${{ github.event.* }}` inputs in `run:` commands
- **Permissions:** Validates `permissions:` block against available scopes
- **Runner labels:** Checks against available runners

### 2.3 ShellCheck — Bash Script Validation

**Purpose:** Static analysis for shell scripts, including those embedded in Dockerfile `RUN` instructions (via hadolint's SC* rules).

#### In Dockerfiles (via hadolint)

Hadolint natively integrates ShellCheck for `RUN` instructions:

```dockerfile
# This will trigger SC2086 (unquoted variable)
RUN echo $PATH

# This passes ShellCheck
RUN echo "$PATH"
```

#### Standalone ShellCheck Action

For linting separate shell scripts (entrypoints, setup scripts):

```yaml
- name: Lint shell scripts
  uses: ludeeus/action-shellcheck@master
  with:
    ignore_paths: >-
      .github
    severity: warning
```

#### Key ShellCheck Rules for Dockerfiles

| Rule | Description |
|------|-------------|
| SC2086 | Double-quote to prevent globbing and word splitting |
| SC2034 | Variables appear unused (common in Docker ENTRYPOINT) |
| SC1091 | Don't use `source` for missing files (use `|| true`) |
| SC2002 | Useless cat (pipe directly) |

---

## 3. Security Scanning

### 3.1 Trivy Integration in GitHub Actions

#### Basic Vulnerability Scan

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@v0.35.0
  with:
    image-ref: 'ghcr.io/${{ github.repository }}:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    exit-code: '1'
    ignore-unfixed: true
    vuln-type: 'os,library'
    severity: 'CRITICAL,HIGH'
```

#### Scan Without Pushing (fs mode)

```yaml
- name: Build image (don't push)
  uses: docker/build-push-action@v7
  with:
    load: true
    tags: myimage:test

- name: Scan built image
  uses: aquasecurity/trivy-action@v0.35.0
  with:
    image-ref: 'myimage:test'
    format: 'table'
    exit-code: '1'
    severity: 'CRITICAL,HIGH'
```

#### Secret Scanning in Images

```yaml
- name: Scan for secrets
  uses: aquasecurity/trivy-action@v0.35.0
  with:
    image-ref: 'ghcr.io/${{ github.repository }}:${{ github.sha }}'
    format: 'json'
    output: 'trivy-secrets.json'
    severity: 'CRITICAL,HIGH,MEDIUM'
    scanners: 'secret'
```

#### IaC / Misconfiguration Scanning

```yaml
- name: Scan for misconfigurations
  uses: aquasecurity/trivy-action@v0.35.0
  with:
    scan-type: 'config'
    scan-ref: '.'
    format: 'sarif'
    output: 'trivy-misconfig.sarif'
    severity: 'CRITICAL,HIGH'
```

#### GitHub Code Scanning Integration

```yaml
- name: Run Trivy
  uses: aquasecurity/trivy-action@v0.35.0
  with:
    image-ref: 'ghcr.io/${{ github.repository }}:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'

- name: Upload Trivy scan results to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v4
  with:
    sarif_file: 'trivy-results.sarif'
```

### 3.2 Trivy Configuration File

Store scan configuration in `trivy.yaml`:

```yaml
# trivy.yaml
scan:
  security-checks: vuln,secret,misconfig
  scanners:
    - vuln
    - secret
    - misconfig

severity:
  - CRITICAL
  - HIGH

ignore-unfixed: true

vuln:
  type:
    - os
    - library

exit-code: 1

format: sarif
output: trivy-results.sarif

secret:
  config: trivy-secret.yaml
```

### 3.3 Best Practices for Scanning Docker Layers

1. **Scan after build, before push** — Use `load: true` to build locally, scan, then push only if clean
2. **Use `ignore-unfixed: true`** — Don't fail on unfixed vulnerabilities in base images you can't control
3. **Cache the Trivy DB** — Built-in caching in `trivy-action` stores DB at `$GITHUB_WORKSPACE/.cache/trivy`
4. **Pre-populate DB via cron** — Avoid rate limiting by updating cache daily:

```yaml
# Cron job to pre-warm Trivy cache
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight UTC
  workflow_dispatch:

jobs:
  update-cache:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/setup-trivy@v0.2.0
        with:
          cache: true
          version: v0.69.3
```

5. **Scan for secrets in Docker layers** — Trivy's `secret` scanner detects API keys, tokens, and credentials baked into image layers
6. **Use `scanners: vuln,secret,misconfig`** for comprehensive coverage

---

## 4. Testing Docker Images

### 4.1 Test-Before-Push Pattern

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: docker/setup-buildx-action@v4

      - name: Build and load to local Docker
        uses: docker/build-push-action@v7
        with:
          load: true
          tags: ${{ github.repository }}:test-${{ github.sha }}
          cache-from: type=gha

      - name: Run image tests
        run: |
          docker run --rm ${{ github.repository }}:test-${{ github.sha }} ./test.sh

      - name: Run integration tests
        run: |
          docker run --rm -p 8080:8080 ${{ github.repository }}:test-${{ github.sha }} &
          sleep 5
          curl -f http://localhost:8080/health || exit 1

      - name: Build and push (only on main/tag push)
        if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/')
        uses: docker/build-push-action@v7
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.sha }}
            ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### 4.2 Build Validation Without Push

```yaml
- name: Validate build configuration
  uses: docker/build-push-action@v7
  with:
    call: check    # Validates Dockerfile without building

- name: Build (dry run)
  uses: docker/build-push-action@v7
  with:
    push: false
    load: true
    tags: sandbox:test
```

### 4.3 Docker Build Testing Patterns

| Pattern | Use Case | Action |
|---------|----------|--------|
| `load: true` | Build and test locally, skip push | `docker/build-push-action` |
| `call: check` | Validate Dockerfile syntax only | `docker/build-push-action` |
| `outputs: type=docker,dest=...` | Export image as tar for artifact sharing | `docker/build-push-action` |
| `push: false` on PR | Build without pushing to registry | `docker/build-push-action` |

### 4.4 JSON Schema Validation for Config Files

For validating `opencode.json` or similar configuration files inside the image:

```yaml
- name: Validate opencode.json schema
  run: |
    # Use ajv or python-jsonschema
    npx ajv-cli validate -s schema.json -d opencode.json
```

```bash
# Python approach
pip install jsonschema
python -c "
import json, jsonschema
with open('opencode.json') as f:
    config = json.load(f)
jsonschema.validate(config, schema={'type': 'object', 'required': ['key']})
"
```

---

## 5. Reproducible Builds

### 5.1 Version Pinning Strategies

#### Dockerfile Level

```dockerfile
# Pin base image by digest (most reproducible)
FROM ubuntu@sha256:abc123...

# Or pin by exact tag
FROM ubuntu:24.04

# Pin package versions
RUN apt-get update && apt-get install -y \
    curl=7.88.1-10+deb12u5 \
    ca-certificates=20230311 \
    && rm -rf /var/lib/apt/lists/*
```

#### GitHub Actions Level

```yaml
# Pin all actions to specific versions (NOT tags for security)
- uses: actions/checkout@v5        # OK: major version tag
- uses: docker/build-push-action@3b5e8027fcad23fda98b2e3ac259d8d67585f671  # SHA pin
```

#### Build Metadata Tags

```yaml
- uses: docker/metadata-action@v6
  with:
    tags: |
      type=sha,prefix=
      type=semver,pattern={{version}}
      type=ref,event=branch
      type=ref,event=pr
      type=raw,value=latest,enable={{is_default_branch}}
```

### 5.2 Build Provenance (SLSA)

`docker/build-push-action` automatically generates SLSA provenance attestations:

```yaml
- uses: docker/build-push-action@v7
  with:
    push: true
    provenance: mode=max   # Full provenance (public repos) or mode=min (private)
    sbom: true             # SBOM attestation
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

**Provenance levels:**
- `mode=max` — Includes full build details (recommended for public repos)
- `mode=min` — Minimal provenance with digest and build date (default for private repos)
- `off` — No provenance

**Security note:** With `mode=max` on public repos, build arguments are included in provenance. Never pass secrets as build args — use `secret` mounts instead:

```yaml
with:
  secrets: |
    GIT_AUTH_TOKEN=${{ secrets.GITHUB_TOKEN }}
```

### 5.3 SBOM Generation

#### Via Build Push Action (built-in)

```yaml
- uses: docker/build-push-action@v7
  with:
    push: true
    sbom: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

#### Via Trivy (alternative)

```yaml
- name: Generate SBOM with Trivy
  uses: aquasecurity/trivy-action@v0.35.0
  with:
    image-ref: 'ghcr.io/${{ github.repository }}:${{ github.sha }}'
    format: 'spdx-json'
    output: 'sbom.spdx.json'
    scan-type: 'image'
    scanners: 'vuln'
```

#### Reproducible Builds with `SOURCE_DATE_EPOCH`

```yaml
- name: Build reproducible image
  uses: docker/build-push-action@v7
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
  env:
    SOURCE_DATE_EPOCH: ${{ github.event.repository.updated_at }}
```

### 5.4 Artifact Attestation

```yaml
- name: Generate artifact attestation
  uses: actions/attest@v4
  with:
    subject-name: ghcr.io/${{ github.repository }}
    subject-digest: ${{ steps.push.outputs.digest }}
    push-to-registry: true
```

---

## 6. Complete Reference Workflow

A comprehensive workflow combining all patterns:

```yaml
name: CI/CD — Docker Sandbox Images

on:
  push:
    branches: [main, 'release/**']
    tags: ['v*']
  pull_request:
    branches: [main]

permissions:
  contents: read
  packages: write
  security-events: write

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # ── Lint Phase ──
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Lint Dockerfile
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile
          format: sarif
          output-file: hadolint-results.sarif

      - name: Lint workflows
        uses: reviewdog/action-actionlint@v1
        with:
          reporter: github-pr-review
          fail_level: error

  # ── Build + Test Phase ──
  build:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Login to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v4
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and load (test)
        uses: docker/build-push-action@v7
        with:
          load: true
          tags: sandbox:test
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Test image
        run: |
          docker run --rm sandbox:test ./test.sh

      - name: Build and push
        if: github.event_name != 'pull_request'
        uses: docker/build-push-action@v7
        with:
          push: true
          provenance: mode=max
          sbom: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Generate attestation
        if: github.event_name != 'pull_request'
        uses: actions/attest@v4
        with:
          subject-name: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME}}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true

  # ── Security Scan Phase ──
  security:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run Trivy vulnerability scan
        uses: aquasecurity/trivy-action@v0.35.0
        with:
          image-ref: '${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          exit-code: '1'
          ignore-unfixed: true
          vuln-type: 'os,library'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: 'trivy-results.sarif'
```

---

## 7. Key Recommendations Summary

1. **Use `docker/build-push-action@v7` with BuildKit** — Full access to modern features (cache, attestations, checks)
2. **Cache via `type=gha`** for simplicity, or `type=registry` with `docker-build-cache-config-action` for PR workflows
3. **Pin action versions by SHA** in production (`@3b5e8027fcad23fda98b2e3ac259d8d67585f671`) or by major version (`@v7`)
4. **Run hadolint + actionlint as gate checks** before building images
5. **Scan with Trivy before push** using `load: true` + `image-ref` pattern
6. **Generate SBOM + provenance attestations** on every push for supply chain security
7. **Use `SOURCE_DATE_EPOCH`** for reproducible builds
8. **Never pass secrets as build args** — use `secrets:` input with BuildKit secret mounts
9. **Test before push** — build with `load: true`, run tests, then push only if clean
10. **Use `docker/metadata-action`** for automatic tag management based on Git events

---

## 8. Research Sources

1. **Docker Build & Push Action** — https://github.com/docker/build-push-action
2. **Docker GitHub Actions Documentation** — https://docs.docker.com/build/ci/github-actions/
3. **Docker Metadata Action** — https://github.com/docker/metadata-action
4. **Docker Build Cache Config Action** — https://github.com/int128/docker-build-cache-config-action
5. **Hadolint** — https://github.com/hadolint/hadolint
6. **Actionlint** — https://github.com/rhysd/actionlint
7. **Trivy** — https://github.com/aquasecurity/trivy
8. **Trivy Action** — https://github.com/aquasecurity/trivy-action
9. **Docker Bake Action** — https://github.com/docker/bake-action
10. **GitHub Actions Cache** — https://github.com/actions/cache
11. **GitHub Actions Docker Tutorial** — https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images
12. **GitHub Actions Attest** — https://github.com/actions/attest
13. **Reproducible Builds (SOURCE_DATE_EPOCH)** — https://reproducible-builds.org/docs/source-date-epoch/
14. **BuildKit Cache Management** — https://docs.docker.com/build/cache/backends/
15. **Reviewdog Actionlint** — https://github.com/reviewdog/action-actionlint
16. **Ludeeus ShellCheck Action** — https://github.com/ludeeus/action-shellcheck
17. **Buildkit Cache Dance** — https://github.com/reproducible-containers/buildkit-cache-dance
