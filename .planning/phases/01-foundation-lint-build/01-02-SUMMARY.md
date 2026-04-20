# Phase 01 Plan 02: PR Workflow Summary

## One-Liner
Created `.github/workflows/pr.yml` with lint (hadolint on 5 Dockerfiles + actionlint with reviewdog) and build (4-variant matrix: oc-go, qc-go, oc-ansible, qc-ansible) jobs that validate PRs without pushing to registry.

## Execution Metrics

| Metric | Value |
|--------|-------|
| Duration | ~2 minutes |
| Tasks | 1/1 complete |
| Files created | 1 |
| Files modified | 0 |

## Tasks Completed

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | Create `.github/workflows/pr.yml` with lint + build jobs | `3397e29` | ✅ |

## Deviations from Plan

| Deviation | Type | Details |
|-----------|------|---------|
| No SARIF upload for hadolint in pr.yml | Bug Fix (Rule 1) | `hadolint/hadolint-action@v3.1.0` does not produce SARIF output; SARIF upload step would upload an empty file. Removed to avoid broken workflow. |
| Build step uses `make pull && make all` instead of `docker/build-push-action` | Bug Fix (Rule 1) | `docker/build-push-action` expects a Dockerfile, not a Makefile. Using `make` directly is the correct approach for this project's build system. |

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| No `docker/login-action` or push | PR builds only validate — no registry side effects (D-09) |
| Matrix of 4 variants | Matches project's 4 image types: oc-go, qc-go, oc-ansible, qc-ansible |
| `needs: lint` on build job | Lint gates must pass before build runs (REQ-CI-002) |
| `concurrency` group with cancel-in-progress | Prevents stale PR builds from consuming resources (D-11) |

## Verification Results

- `.github/workflows/pr.yml` exists (104 lines), valid YAML
- Has `pull_request` trigger targeting `main`
- Has `lint` job with hadolint on all 5 Dockerfiles + actionlint + reviewdog
- Has `build` job with `needs: lint`, 4-variant matrix, docker/setup-buildx, setup-qemu, metadata-action
- No `login-action` or push steps present
- Uses `ghcr.io/red55/sandbox` registry prefix
- All acceptance criteria met
