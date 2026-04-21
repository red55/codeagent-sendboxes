# Phase 3: Security Scanning - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 03-security-scanning
**Areas discussed:** Scan scope (PR vs release), Severity thresholds, Token suppression strategy, Cron job structure, PR comment posting, Config scan targets

---

## Scan Scope

| Option | Description | Selected |
|--------|-------------|----------|
| PR + Release | Scan on both PR and release builds. Early feedback on PRs. | ✓ |
| Release only | Only scan on push to main/tags. Faster PR feedback. | |
| You decide | Let the planner choose | |

**User's choice:** PR + Release (Recommended)
**Notes:** PR builds use locally-loaded images (no push). Trivy can scan from Docker daemon directly.

## Severity Thresholds

| Option | Description | Selected |
|--------|-------------|----------|
| CRITICAL + HIGH only | MEDIUM common in base images. Block only critical. | ✓ |
| CRITICAL + HIGH + MEDIUM | Stricter. May cause frequent build failures. | |
| You decide | Let the planner choose | |

**User's choice:** Block CRITICAL + HIGH only (Recommended)
**Notes:** Secrets and misconfigs always warn, never block.

## Context7 Token Suppression

| Option | Description | Selected |
|--------|-------------|----------|
| Suppress by file path | Ignore secrets in opencode.json. Simple, targeted. | ✓ |
| Suppress by pattern | Ignore specific secret pattern. More precise, harder to maintain. | |
| You decide | Let the planner choose | |

**User's choice:** Suppress by file path (Recommended)
**Notes:** The token is in `base/.opencode/opencode.json`. Suppress the entire file path in trivy.yaml.

## Cron Job Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Separate workflow file | `trivy-cron.yml` with schedule trigger. Clean separation. | ✓ |
| Add to release.yml | Schedule trigger on existing workflow. Wasteful (runs full pipeline). | |
| You decide | Let the planner choose | |

**User's choice:** Separate workflow file (Recommended)
**Notes:** Daily at 06:00 UTC. Only downloads/updates Trivy DB cache.

## PR Comment Posting

| Option | Description | Selected |
|--------|-------------|----------|
| Post as PR comments | reviewdog or gh CLI. Author sees issues immediately. | ✓ |
| Workflow logs only | Just log to output. Author must check workflow runs. | |
| You decide | Let the planner choose | |

**User's choice:** Post as PR comments (Recommended)
**Notes:** Matches existing actionlint PR comment pattern in pr.yml.

## Config Scan Targets

| Option | Description | Selected |
|--------|-------------|----------|
| Images + Dockerfiles | Two scan types: image vulns + Dockerfile misconfigs. | ✓ |
| Images only | Only scan built images. Simpler. | |
| You decide | Let the planner choose | |

**User's choice:** Scan both images + Dockerfiles (Recommended)
**Notes:** Image scan catches package vulns. Dockerfile scan catches NOPASSWD sudo, missing HEALTHCHECK, etc.

---

## the agent's Discretion

All gray areas were discussed and decisions were made. No areas were left to agent discretion.

## Deferred Ideas

- Image signing (cosign) — future phase
- SBOM generation — Phase 4
- Provenance attestation — Phase 4
- Slack/email notifications — out of scope
- Automated vulnerability patching — future phase
