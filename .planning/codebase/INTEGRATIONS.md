# External Integrations

**Analysis Date:** 2026-04-20

## AI Providers

**Qwen-MBP (Primary):**
- Type: OpenAI-compatible API endpoint
- URL: `http://192.168.151.31:8080/v1` (internal network)
- SDK/Client: `@ai-sdk/openai-compatible` (npm package, declared in `base/.opencode/opencode.json` line 174)
- Models:
  - `qwen-next` — 262,144 context window, 32,768 max output
  - `qwen-3.6` — 1,048,576 context window, 65,536 max output
- Auth: Local network (no external auth required)

## MCP (Model Context Protocol) Integrations

**Context7:**
- Type: Remote MCP server
- URL: `https://mcp.context7.com/mcp`
- Auth: Bearer token — `ctx7sk-a1c1beb1-b430-4f63-b8d3-abca285c6733`
- Location: `base/.opencode/opencode.json` lines 37-43
- Purpose: Library documentation lookup for coding agents

## Container Registries

**GitHub Container Registry (ghcr.io):**
- Registry: `ghcr.io/red55`
- Used for: Building and tagging sandbox images
- Images: `sandbox-oc-go`, `sandbox-qc-go`, `sandbox-oc-ansible`, `sandbox-qc-ansible`

**Docker Hub:**
- `docker.io/library/node:25-trixie` — Base image for OpenCode sandbox
- `docker.io/docker/sandbox-templates:opencode-docker` — OpenCode upstream image

**Qwen LM Registry:**
- `ghcr.io/qwenlm/qwen-code:0.14` — Qwen Code upstream image

## External Package Sources

### npm / Bun Registry
- Default Bun registry (bun.sh)
- Global packages installed via `bun install -g` and `npm install -g`:
  - `opencode-ai` — AI coding agent
  - `@qwen-code/qwen-code` — Qwen AI agent
  - `bun` — JavaScript runtime
  - Various OpenCode plugins (listed in `STACK.md` under Frameworks)

### GitHub CLI
- `cli.github.com/packages` — apt repository for `gh` CLI
- GPG key: `/etc/apt/keyrings/githubcli-archive-keyring.gpg`
- Location: `base/Dockerfile` lines 80-84

### Docker
- `download.docker.com/linux/debian` — apt repository for Docker CE
- GPG key: `/etc/apt/keyrings/docker.asc`
- Location: `base/Dockerfile` lines 27-38

### Python (pip)
- `pypi.org` — Standard PyPI for `pyright` and `uv`
- Location: `base/Dockerfile` line 116

### Go Modules
- `go.dev/dl` — Go language distribution
- `github.com/protocolbuffers/protobuf` — protoc binary
- `golang.org/x/tools` — gopls
- `github.com/bufbuild/buf` — buf CLI
- Location: `golang/Dockerfile` lines 8-15

### Debian Packages
- Primary: `mirror.yandex.ru/debian` (configured in `base/Dockerfile` line 7)
- Packages: `docker-ce`, `default-jdk-headless`, `golang`, `python3`, `python3-pip`, `git`, `jq`, `ripgrep`, `sqlite3`, `tshark`, `mc`, etc.

## Authentication & Identity

**GitHub CLI:**
- `gh` CLI installed — relies on `gh auth login` for user-level auth
- No baked-in credentials

**Context7 MCP:**
- Bearer token embedded in `base/.opencode/opencode.json` (lines 41-42): `ctx7sk-a1c1beb1-b430-4f63-b8d3-abca285c6733`
- ⚠️ **Security concern:** Token is committed in plaintext in the repository

**Qwen-MBP Provider:**
- No auth header configured — relies on local network access to `192.168.151.31:8080`

## Network Configuration

**Proxy Support:**
- HTTP proxy env vars supported: `http_proxy`, `https_proxy`, `NO_PROXY`
- `NO_PROXY` includes: `localhost, 127.0.0.1, ::1, 172.17.0.0/16` (Docker bridge network)
- Proxy vars preserved through sudoers: `base/Dockerfile` line 50
- Node.js extra CA certs: `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`

**Internal API:**
- Qwen-MBP API at `http://192.168.151.31:8080/v1` — local network only

## Monitoring & Observability

**Error Tracking:** Not configured
**Logs:** Standard Docker container logging; no external log aggregation
**Metrics:** None detected

## CI/CD & Deployment

**Build Pipeline:**
- Make-based build system (`Makefile`)
- Docker buildx for multi-platform builds
- No CI/CD service detected (no `.github/workflows/`, no Jenkinsfile, no `.gitlab-ci.yml`)

**Hosting:**
- Container images pushed to `ghcr.io/red55/sandbox`
- Images intended for sandbox/development environments (not production hosting)

## Webhooks & Callbacks

**Incoming:** None detected
**Outgoing:** None detected

## Environment Configuration

**Required env vars:**
| Variable | Purpose | Default |
|----------|---------|---------|
| `DEBIAN_FRONTEND` | Non-interactive apt | `noninteractive` |
| `NPM_CONFIG_PREFIX` | Global npm install path | `/usr/local/share/npm-global` |
| `NO_PROXY` / `no_proxy` | Bypass proxy for local/Docker networks | `localhost,127.0.0.1,::1,172.17.0.0/16` |
| `PATH` | Include bun, npm-global, GOPATH bins | Configured in Dockerfiles |
| `BASH_ENV` | Persistent shell config hook | `/etc/sandbox-persistent.sh` |
| `GOPATH` | Go workspace | `/usr/local/go` |
| `DOCKER_BUILDKIT` | (implied) | BuildKit enabled via buildx |

**Secrets location:**
- Context7 MCP token: `base/.opencode/opencode.json` line 41 (⚠️ committed in plaintext)
- No `.env` files detected
- No credential files detected

## Agent Architecture Summary

```
opencode.json
├── provider.qwen-mbp          → http://192.168.151.31:8080/v1 (AI)
├── mcp.context7               → https://mcp.context7.com/mcp (docs)
├── lsp.ansible                → ansible-language-server (local)
├── lsp.golang                 → gopls (local)
├── agent.build                → primary agent (qwen-next, qwen-3.6)
├── agent.ansible-expert       → subagent
└── agent.git-expert           → subagent
    ├── agent.gsd-executor     → nested subagent
    └── agent.gsd-planner      → nested subagent
```

---

*Integration audit: 2026-04-20*
