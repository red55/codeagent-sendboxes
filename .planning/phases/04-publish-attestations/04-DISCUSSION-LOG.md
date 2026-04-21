# Phase 4: Publish + Attestations - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 04-publish-attestations
**Areas discussed:** SBOM format, Provenance depth, PR artifacts, Release workflow, Documentation scope

---

## SBOM format

| Option | Description | Selected |
|--------|-------------|----------|
| CycloneDX | Newer, OWASP-favored, better tooling integration | ✓ |
| SPDX | Older standard, broader legacy tool support | |

**User's choice:** CycloneDX
**Notes:** OWASP-favored, better tooling integration. Only generated for release builds (not PR builds).

## Provenance attestation depth

| Option | Description | Selected |
|--------|-------------|----------|
| mode=max (everything) | Full build provenance — build config, source, dependencies | ✓ |
| mode=min (essential only) | Minimal metadata — commit SHA, trigger, timestamp | |

**User's choice:** mode=max
**Notes:** Full build provenance required for supply chain security.

## PR build artifacts

| Option | Description | Selected |
|--------|-------------|----------|
| Docker save tarballs | Save images as .tar artifacts, downloadable from workflow UI | |
| PR tags in registry | Push to ghcr.io with pr-<number> tag | ✓ |
| Fork PRs only (safer) | Restrict push to fork PRs, avoid running on untrusted code | ✓ |

**User's choice:** PR tags in registry, fork PRs only
**Notes:** PR builds push to ghcr.io with `pr-<number>` tags, but only for fork PRs (`github.event.pull_request.head.repo.fork == true`).

## Release workflow

| Option | Description | Selected |
|--------|-------------|----------|
| Include in Phase 4 | Add release workflow with semver tags and release notes | ✓ |
| Defer to future phase | Out of scope — focus on core publishing | |

**User's choice:** Include in Phase 4
**Notes:** Release workflow triggers on `v*` tags, builds all 4 variants, pushes to ghcr.io with semver tags.

## Release notes

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-generated from commits | Use `github/release-actions` to generate notes from PR titles/commits | ✓ |
| Manual curated | Maintainer writes release notes separately | |

**User's choice:** Auto-generated from commits
**Notes:** Use `github/release-actions` for automatic release note generation.

## SBOM scope

| Option | Description | Selected |
|--------|-------------|----------|
| All builds (PR + release) | Generate SBOM for every build — useful for scanning PR images | |
| Release builds only | Generate SBOM only when pushing to registry | ✓ |

**User's choice:** Release builds only
**Notes:** SBOM generation only for release builds to reduce build time and registry usage.

## Documentation scope

| Option | Description | Selected |
|--------|-------------|----------|
| Full CI/CD guide | Document all workflows, triggers, scan results, artifacts, tagging | |
| Minimal usage | Only how to trigger builds and view results | ✓ |

**User's choice:** Minimal usage
**Notes:** README updates kept minimal — only document build triggers and result viewing.

---

## the agent's Discretion

None — all areas discussed and decided.

## Deferred Ideas

- Image signing (cosign) — future phase
- Environment protection rules — not needed for project scale
- Full CI/CD guide documentation — out of scope
- SBOM for PR builds — user chose release builds only
