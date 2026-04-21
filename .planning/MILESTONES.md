# Milestones

## v0.35.0 — Sandbox CI/CD Pipeline

**Shipped:** 2026-04-21
**Phases:** 4 | **Plans:** 11 | **Tasks:** ~20

**Delivered:** Complete CI/CD pipeline for AI agent sandbox Docker images with lint gates, 4-variant builds, Trivy security scanning, SBOM/provenance attestations, and fork PR support.

**Accomplishments:**
1. GitHub Actions workflows (pr.yml + release.yml) with lint, build, and security jobs
2. 16 dependency version pins, .dockerignore, SOURCE_DATE_EPOCH for reproducibility
3. Trivy vulnerability/secret/misconfiguration scanning integrated into CI
4. CycloneDX SBOM + mode=max provenance attestations on release images
5. Fork PR-gated registry push with pr-<number> tags
6. README.md with CI/CD documentation

**Known gaps:** healthcheck.sh not in `make check` (requires pre-built images); multi-platform support deferred; cosign signing deferred.

<details>
<summary>Full details</summary>

See `.planning/milestones/v0.35.0-ROADMAP.md` for phase-level details.
See `.planning/milestones/v0.35.0-REQUIREMENTS.md` for requirements traceability.

</details>
