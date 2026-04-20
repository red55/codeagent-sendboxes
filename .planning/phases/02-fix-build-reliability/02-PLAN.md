# Phase 2: Fix Build Reliability

## Goal
Fix critical build issues in Dockerfiles and Makefile so all 4 image variants build successfully with `make all`, passing hadolint strict mode and health checks.

## Requirements
- **REQ-BUILD-005**: Build reproducibility fixes (`.dockerignore`, pin `@latest` tags, remove `sudo`, `SOURCE_DATE_EPOCH`)
- **REQ-TEST-001**: Docker build validation (health checks for key tools)
- **REQ-TEST-002**: Agent config validation (opencode.json schema validation)

## Decisions Implemented
- **D-01**: Go 1.26.2 is valid (current latest stable) — keep as-is
- **D-02**: Remove `golang` from apt-get in `base/Dockerfile`
- **D-03**: Pin ALL `@latest` tags to specific versions
- **D-04**: Remove commented-out plugin line from `base/opencode.Dockerfile`
- **D-05**: Keep Yandex Debian mirror, suppress DL3039 (already configured in Phase 1)
- **D-06**: Create `.dockerignore` at project root
- **D-07**: Set `SOURCE_DATE_EPOCH` in Makefile
- **D-08**: Health checks verify tool presence, config validation, ownership
- **D-09**: Health checks FAIL the build on missing tools, config errors, ownership issues
- **D-10**: Remove `sudo` from `golang/Dockerfile`
- **D-11**: Remove `sudo` from `ansible/Dockerfile`

## Risk Assessment
| Risk | Impact | Mitigation |
|------|--------|------------|
| Wrong version pin breaks build | High | All versions verified against npm/go.dev before implementation |
| Removing `sudo` from golang/ansible Dockerfiles | Low | Dockerfile RUN always runs as root; verified no sudo usage outside RUN |
| `.dockerignore` excludes needed files | Medium | Explicitly tested against Docker build contexts in Makefile |
| Health check script fails on valid images | Medium | Script uses `|| true` for non-critical checks; fails only on missing tools |
| Config validation rejects valid opencode.json | Low | Validation checks only required fields, not optional structure |

## Task Breakdown

### Task 1: Create `.dockerignore` and set `SOURCE_DATE_EPOCH`
**Dependencies:** none
**Description:** Create `.dockerignore` at project root to prevent build context pollution. Exclude `.git/`, `.planning/`, `node_modules/`, `*.md`, `*.txt`, `*.log`, `.opencode/` — but MUST NOT exclude `Dockerfile`, `Makefile`, or `base/` directories (they are build contexts). Add `SOURCE_DATE_EPOCH=1700000000` to Makefile for reproducible build timestamps.

**Files:**
- `NEW: .dockerignore`
- `MODIFY: Makefile`

**Acceptance Criteria:**
- `.dockerignore` exists at project root with correct exclusions
- `make all` still works (build contexts not polluted by `.git/`, `.planning/`, etc.)
- `SOURCE_DATE_EPOCH` variable set in Makefile and exported by `make all`

### Task 2: Fix `base/Dockerfile` — remove redundant `golang`, pin `bun`
**Dependencies:** none (independent of other Dockerfiles)
**Description:** Remove `golang` from the apt-get install list in `base/Dockerfile` (line 106). The golang tarball install in `golang/Dockerfile` is the authoritative source; apt's golang package is redundant and may conflict. Pin `bun@latest` to `bun@1.3.13`.

**Files:**
- `MODIFY: base/Dockerfile`

**Acceptance Criteria:**
- `golang` removed from apt-get install list in base/Dockerfile
- `bun@latest` → `bun@1.3.13`
- `make base` succeeds (base image builds without golang apt package)

### Task 3: Fix agent Dockerfiles — pin packages, remove commented line
**Dependencies:** Task 2 (base/Dockerfile changes; bun version shared)
**Description:** Pin ALL `@latest` tags in agent Dockerfiles. Remove commented-out plugin line from `base/opencode.Dockerfile`.

**Files:**
- `MODIFY: base/opencode.Dockerfile`
- `MODIFY: base/qwencode.Dockerfile`

**Acceptance Criteria:**
- `base/opencode.Dockerfile`: bun@1.3.13, opencode-ai@1.14.19, opencode-pty@0.3.4, @franlol/opencode-md-table-formatter@0.0.6, opencode-conductor-plugin@1.32.0, @tarquinen/opencode-dcp@3.1.9, opencode-websearch-cited@1.2.0, opencode-qwencode-auth@1.3.0, get-shit-done-cc@1.38.1
- `base/qwencode.Dockerfile`: @qwen-code/qwen-code@0.14.5, get-shit-done-cc@1.38.1
- Commented-out `#RUN opencode plugin oh-my-openagent@latest -g` removed from opencode.Dockerfile

### Task 4: Fix tooling Dockerfiles — remove `sudo`, pin versions
**Dependencies:** none (independent of other Dockerfiles)
**Description:** Remove all `sudo` from `golang/Dockerfile` (lines 7, 9, 11, 14) and `ansible/Dockerfile` (line 1). Dockerfile RUN commands execute as root by default. Pin gopls and buf in `golang/Dockerfile`. Pin ansible, ansible-lint, ansible-pylibssh, and mitogen in `ansible/Dockerfile`.

**Files:**
- `MODIFY: golang/Dockerfile`
- `MODIFY: ansible/Dockerfile`

**Acceptance Criteria:**
- No `sudo` in golang/Dockerfile or ansible/Dockerfile
- gopls pinned to v0.21.1, buf pinned to v1.68.2
- ansible pinned to 13.5.0, ansible-lint to 26.4.0, ansible-pylibssh to 1.4.0, mitogen to 0.3.47

### Task 5: Create health check and config validation scripts
**Dependencies:** none (scripts are independent of Dockerfile changes)
**Description:** Create `scripts/healthcheck.sh` — verifies key tools are installed in each image variant. Create `scripts/validate-config.sh` — validates `base/.opencode/opencode.json` against JSON schema (required fields: name, mode, tools for agents; valid provider URLs; plugin references match Dockerfile). Add `check` target to Makefile.

**Files:**
- `NEW: scripts/healthcheck.sh`
- `NEW: scripts/validate-config.sh`
- `MODIFY: Makefile`

**Acceptance Criteria:**
- `scripts/healthcheck.sh` checks: docker, node, python3, go, ansible, opencode/qwencode, bun, gopls, buf, ansible-lint
- `scripts/validate-config.sh` checks: opencode.json has required fields, provider URLs valid, plugin references match Dockerfiles
- `make check` runs both scripts and fails on errors
- Scripts use `#!/usr/bin/env bash` and `set -euo pipefail`

## Verification

```bash
# Build all variants
make all

# Run health checks
make check

# Verify hadolint passes
hadolint base/Dockerfile .github/lint/.hadolint.yaml
hadolint base/opencode.Dockerfile .github/lint/.hadolint.yaml
hadolint base/qwencode.Dockerfile .github/lint/.hadolint.yaml
hadolint golang/Dockerfile .github/lint/.hadolint.yaml
hadolint ansible/Dockerfile .github/lint/.hadolint.yaml

# Verify .dockerignore excludes .git/
docker build -t test-dockerignore --target test base/ 2>&1 | grep -c ".git/"
# Should be 0 — .git/ not in build context
```

## Success Criteria
- [ ] `.dockerignore` present, `.git/` excluded from build context
- [ ] Go 1.26.2 downloads and installs successfully (verified D-01)
- [ ] All `@latest` tags replaced with specific versions (verified D-03)
- [ ] No `sudo` in `golang/Dockerfile` or `ansible/Dockerfile` (verified D-10, D-11)
- [ ] `golang` removed from base/Dockerfile apt-get list (verified D-02)
- [ ] Commented-out plugin line removed from opencode.Dockerfile (verified D-04)
- [ ] `opencode.json` validates against schema
- [ ] All 4 images pass health check tests
- [ ] `make all` succeeds locally after all fixes
