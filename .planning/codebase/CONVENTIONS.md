# Coding Conventions

**Analysis Date:** 2026-04-20

## Overview

This repository is a **Docker-based sandbox environment** for AI coding agents (OpenCode and Qwen Code). There is no application source code — the project consists entirely of infrastructure definitions: Dockerfiles, a Makefile, agent prompt definitions (Markdown), and configuration files. Conventions are defined primarily through agent instructions in `base/agents/` and enforced via tooling (ansible-lint, pyright, gopls).

## Naming Patterns

**Files:**
- Dockerfiles: Named by purpose — `Dockerfile`, `opencode.Dockerfile`, `qwencode.Dockerfile`
- Agent definitions: `*-expert.md` format — `base/agents/ansible-expert.md`, `base/agents/git-expert.md`
- Configuration: JSON with descriptive names — `base/.opencode/opencode.json`
- Makefile: Standard `Makefile` (capitalized, no extension)

**Directories:**
- `base/` — Foundation images and agent definitions
- `golang/` — Go language tooling extension
- `ansible/` — Ansible tooling extension
- `base/.opencode/` — OpenCode agent configuration
- `base/agents/` — Subagent prompt definitions
- `.planning/codebase/` — Codebase analysis documents

## Code Style

### Dockerfiles

**Argument vs. Environment:**
- Use `ARG` for build-time parameters, `ENV` for runtime environment variables
- Pattern: `ARG IMAGE=` at top of multi-stage Dockerfiles (`base/Dockerfile` line 1, `golang/Dockerfile` line 1)
- Shell commands in Dockerfiles use `set -eux -o pipefail` for strict error handling (`base/Dockerfile` line 18)

**User Management:**
- Create non-root user with explicit UID: `useradd --create-home --uid 1000 --shell /bin/bash agent` (`base/Dockerfile` line 41)
- Switch to non-root with `USER agent` before final `WORKDIR` (`base/Dockerfile` lines 122-124)
- Set ownership explicitly: `COPY --chown=agent:agent` (`base/opencode.Dockerfile` lines 16-17)

**Layer Optimization:**
- Combine apt operations: `apt-get update && apt-get install ... && apt-get clean && rm -rf /var/lib/apt/lists/*` in single RUN (`base/Dockerfile` lines 85-115)
- Use heredocs for multi-step setup: `/bin/bash << EOF ... EOF` (`base/Dockerfile` lines 17-77)

**Path Configuration:**
- npm global prefix: `ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global` (`base/Dockerfile` line 10)
- PATH includes custom directories: `ENV PATH=/home/agent/.local/bin:/usr/local/share/npm-global/bin:$PATH` (`base/Dockerfile` line 11)

### Makefile

**Variable Conventions:**
- Use `:=` for immediate assignment: `CR := ghcr.io/red55` (`Makefile` line 1)
- Use spaces (not tabs) for variable definitions; tabs for recipe lines
- Declare all targets as `.PHONY` (`Makefile` line 10)

**Target Naming:**
- Hyphenated, descriptive names: `base-opencode`, `base-qwencode`, `golang-opencode`, `ansible-qwencode`
- Standard targets: `all`, `clean`, `prune`, `pull`

**Image Tagging:**
- Version controlled via `VER := latest` (`Makefile` line 3)
- Tag format: `$(CR)/sandbox` with variant suffixes (`Makefile` lines 2-2)

### Agent Markdown Files (`.md` in `base/agents/`)

**Frontmatter:**
- YAML frontmatter with `name`, `description`, and `tools` keys:
  ```yaml
  ---
  name: ansible-expert
  description: Expert in Ansible playbooks...
  tools:
    read: true
    write: true
    bash: true
  ---
  ```
  (`base/agents/ansible-expert.md` lines 1-8)

**Content Structure:**
- Role definition paragraph
- Expertise list (bullet points with bold categories)
- Task workflow (numbered steps)
- Best practices (bullet points with bold categories)
- Review/debugging checklist

## Import/Dependency Organization

**Dockerfile Layer Order:**
1. Base image declaration (`FROM`)
2. Environment variables (`ENV`)
3. System package installation (`apt-get`)
4. Language-specific tool installation (`pip3`, `npm`, `bun`)
5. Configuration/copy operations (`COPY`)
6. Final user switch and workdir

**Ansible (per agent instructions):**
- YAML preferred over JSON for playbooks (`base/agents/ansible-expert.md` line 34)
- Prefer module usage (`state: present/absent`) over shell commands
- Use `ansible_facts` dictionary instead of `ansible_` named variables (`base/agents/ansible-expert.md` line 41)
- **Mandatory first line** for task/handler files: `# code: language=ansible` (`base/agents/ansible-expert.md` line 42)

## Error Handling

**Dockerfiles:**
- Shell scripts use `set -eux -o pipefail` for strict error propagation (`base/Dockerfile` line 18)
- Non-critical commands use `|| true` to avoid build failure (`base/Dockerfile` line 19: `userdel node || true`)
- Cleanup always follows installs: `apt-get clean && rm -rf /var/lib/apt/lists/*` (`base/Dockerfile` line 114)

**Makefile:**
- `clean` target uses `|| true` to tolerate missing images (`Makefile` lines 42-45)

## Logging and Debugging

**Docker Build Output:**
- `set -x` in Dockerfile RUN blocks enables verbose build logging (`base/Dockerfile` line 18)

**Sandbox Persistent Script:**
- `/etc/sandbox-persistent.sh` sourced on shell init for environment setup (`base/Dockerfile` lines 65-73)
- Written to `/etc/profile.d/sandbox-persistent.sh` and `/home/agent/.bashrc`

## Comments

**Dockerfiles:**
- Inline comments explain non-obvious configuration decisions:
  - `# Create non-root user` (`base/Dockerfile` line 40)
  - `# Pre-create .local directories with correct ownership...` (`base/Dockerfile` lines 55-57)
  - `# Set up npm global package folder...` (`base/Dockerfile` line 62)

**Makefile:**
- Comments separate logical sections: `# OpenCode`, `# QWEN Code` (`Makefile` lines 27, 33)

## Configuration Conventions

**opencode.json:**
- JSON schema reference at top: `"$schema": "https://opencode.ai/config.json"` (`base/.opencode/opencode.json` line 2)
- LSP configuration maps language names to server commands and file extensions (`base/.opencode/opencode.json` lines 10-29)
- Agent definitions follow consistent structure: `mode`, `permission`, `tools` (`base/.opencode/opencode.json` lines 46-169)
- MCP providers use `type: remote` with URL and auth headers (`base/.opencode/opencode.json` lines 36-44)

## Special Directories

**`.planning/codebase/`:**
- Purpose: Codebase analysis documents (ARCHITECTURE.md, STRUCTURE.md, STACK.md, INTEGRATIONS.md, and this file)
- Generated: Yes — produced by GSD codebase mapping command

**`base/.opencode/`:**
- Purpose: OpenCode agent runtime configuration
- Contains: `opencode.json` (LSP, MCP, provider, agent definitions)

**`base/agents/`:**
- Purpose: Subagent prompt definitions
- Contains: `ansible-expert.md`, `git-expert.md`

---

*Convention analysis: 2026-04-20*
