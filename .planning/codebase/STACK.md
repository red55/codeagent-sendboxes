# Technology Stack

**Analysis Date:** 2026-04-20

## Overview

This repository is a **Docker-based sandbox environment** for AI coding agents (OpenCode and Qwen Code). It defines base images and language-specific extensions (Go, Ansible) that are built and orchestrated via Make. There is no application source code — the project is purely infrastructure/container definitions.

## Languages

**Primary:**
- **Bash** — Shell scripts and Dockerfile RUN instructions (`base/Dockerfile`, `base/opencode.Dockerfile`, `base/qwencode.Dockerfile`, `golang/Dockerfile`, `ansible/Dockerfile`)
- **YAML** — Ansible playbooks/roles support (LSP configured in `base/.opencode/opencode.json`)

**Secondary:**
- **TypeScript/JavaScript** — Node.js runtime; `get-shit-done` CLI tool dependency (`package.json`)
- **Go** — Language tooling installed (gopls, buf) in `golang/Dockerfile`
- **Python** — Installed via apt (`python3`, `python3-pip`) and pip packages (`pyright`, `uv`) in `base/Dockerfile`

## Runtime

**Environment:**
- **Node.js 25** (Debian Trixie bookworm base) — `base/Dockerfile` line 2: `FROM docker.io/library/node:25-trixie`
- **Docker** (CE + CLI + Compose plugin + Buildx + containerd.io) — installed in `base/Dockerfile` lines 88-112
- **Go 1.26.2** — `golang/Dockerfile` line 4

**Package Manager:**
- **Bun** (latest) — installed globally via `RUN npm i -g bun@latest` in `base/Dockerfile` line 117, added to PATH in line 124
- **npm** — fallback package manager, used for global installs
- **pip3** — Python package manager, used for pyright and uv installation

**Lockfile:**
- `bun.lock` — Bun lockfile present, v1 format, tracks `get-shit-done` and its transitive dependencies

## Frameworks

**AI Coding Agents:**
- **OpenCode** (`opencode-ai@latest`) — Primary AI coding agent, installed via `bun install -g` in `base/opencode.Dockerfile` line 2
- **Qwen Code** (`@qwen-code/qwen-code@latest`) — Alternative AI coding agent, installed via `bun install -g` in `base/qwencode.Dockerfile` line 2

**OpenCode Plugins:**
- `opencode-pty@latest` — PTY (pseudo-terminal) support — `base/opencode.Dockerfile` line 5
- `@franlol/opencode-md-table-formatter@latest` — Markdown table formatter — `base/opencode.Dockerfile` line 6
- `opencode-conductor-plugin@latest` — Agent orchestration — `base/opencode.Dockerfile` line 7
- `opencode-qwencode-auth` — Authentication adapter (npm module, built from source) — `base/opencode.Dockerfile` lines 8-10
- `@tarquinen/opencode-dcp@latest` — Docker container plugin — `base/opencode.Dockerfile` line 11
- `opencode-websearch-cited@latest` — Web search with citations — `base/opencode.Dockerfile` line 14
- `opencode-devcontainers` — DevContainer support (declared in `base/.opencode/opencode.json` line 4)

**CLI Tooling:**
- **get-shit-done** (`get-shit-done@^0.0.2`) — Project-specific CLI automation tool, installed via `bunx get-shit-done-cc` in `base/opencode.Dockerfile` line 12 and `base/qwencode.Dockerfile` line 3

## Key Dependencies

**Critical:**
- **`get-shit-done`** [0.0.2] — Core CLI automation; depends on `chalk`, `commander`, `node-notifier`, `ts-progress` — `package.json` line 3, `bun.lock` line 41
- **`opencode-ai`** (latest) — Primary AI agent runtime — `base/opencode.Dockerfile` line 2
- **`@qwen-code/qwen-code`** (latest) — Qwen AI agent runtime — `base/qwencode.Dockerfile` line 2

**Infrastructure:**
- **GitHub CLI (`gh`)** — Installed in `base/Dockerfile` line 103
- **protoc** (v34.1) — Protocol buffer compiler — `golang/Dockerfile` lines 8-10
- **buf** — Protocol buffer build tool — `golang/Dockerfile` line 15
- **gopls** — Go language server — `golang/Dockerfile` line 14

**Python Tooling:**
- **pyright** — Python type checker — `base/Dockerfile` line 116
- **uv** — Python package manager — `base/Dockerfile` line 116

**Ansible (ansible/ directory):**
- **ansible** — Configuration management — `ansible/Dockerfile` line 2
- **ansible-lint** — Linting — `ansible/Dockerfile` line 2
- **mitogen** — Ansible acceleration — `ansible/Dockerfile` line 2
- **netaddr**, **ansible-pylibssh** — Network utilities — `ansible/Dockerfile` line 2

## Build System

**Primary: Make**
- `Makefile` — Orchestrates Docker image builds for all sandbox variants
- Targets: `all`, `base`, `base-opencode`, `base-qwencode`, `opencode`, `qwencode`, `golang-opencode`, `golang-qwencode`, `ansible-opencode`, `ansible-qwencode`, `clean`, `prune`
- Image tagging: `ghcr.io/red55/sandbox` with `latest` version

**Secondary: Docker**
- Multi-stage build via build args (`ARG IMAGE=`)
- Buildx for extended build capabilities — `Makefile` line 49
- Five base images: `oc-sandbox-base`, `qc-sandbox-base`, `opencode-sandbox-base`, `qwencode-sandbox-base`, `golang-sandbox-base`, `ansible-sandbox-base`

## Configuration

**Environment:**
- `base/.opencode/opencode.json` — OpenCode agent configuration (200 lines)
  - LSP servers: ansible-language-server, gopls
  - MCP provider: Context7 (remote URL with Bearer token)
  - AI provider: `qwen-mbp` (OpenAI-compatible at `http://192.168.151.31:8080/v1`)
  - Models: `qwen-next` (262K context, 32K output), `qwen-3.6` (1M context, 65K output)
  - Agent definitions: `build` (primary), `ansible-expert` (subagent), `git-expert` (subagent with nested `gsd-executor` and `gsd-planner`)
  - All permissions set to allow

**Proxy Configuration:**
- `NO_PROXY` / `no_proxy` — `localhost, 127.0.0.1, ::1, 172.17.0.0/16` — `base/Dockerfile` lines 12-13
- Proxy env vars preserved through sudoers — `base/Dockerfile` line 50

**System:**
- Debian package mirror: `mirror.yandex.ru/debian` — `base/Dockerfile` line 7
- Sandbox persistent script hook: `/etc/sandbox-persistent.sh` — `base/Dockerfile` lines 65-73
- Non-root user: `agent` (UID 1000) — `base/Dockerfile` line 41

## Platform Requirements

**Development:**
- Docker (CE + CLI + Compose + Buildx)
- Make
- Bun (for lockfile management)

**Production (Container Registry):**
- **GitHub Container Registry (ghcr.io)** — `Makefile` line 1: `CR := ghcr.io/red55`
- Base images from:
  - `docker.io/docker/sandbox-templates:opencode-docker` (OpenCode) — `Makefile` line 6
  - `ghcr.io/qwenlm/qwen-code:0.14` (Qwen) — `Makefile` line 5

## Container Architecture

```
base/                    # Foundation: Node.js 25, Docker, Go, Python, CLI tools
├── opencode.Dockerfile  # └── OpenCode AI agent + plugins
└── qwencode.Dockerfile  #     Qwen Code AI agent
├── Dockerfile           #     Base image (from OC or QC upstream)
└── .opencode/           #     Agent config (LSP, MCP, providers, agents)
    └── agents/          #     Subagent definitions
golang/                  # Go language tooling (gopls, buf, protoc)
ansible/                 # Ansible + Lint + Mitogen
```

---

*Stack analysis: 2026-04-20*
