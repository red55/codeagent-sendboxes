#!/usr/bin/env bash
set -euo pipefail

# Health check script for sandbox Docker images
# Verifies key tools are installed in each image variant

IMAGE="${1:-}"
VARIANT="${2:-}"
ERRORS=0

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <docker-image> [variant]"
    echo "  variant: base, opencode, qwencode, golang, ansible"
    exit 1
fi

check_tool() {
    local tool="$1"
    local expected="${2:-}"
    if docker run --rm "$IMAGE" which "$tool" >/dev/null 2>&1; then
        echo "  [PASS] $tool found"
    else
        echo "  [FAIL] $tool NOT found"
        ERRORS=$((ERRORS + 1))
    fi
}

check_tool_version() {
    local tool="$1"
    local expected="$2"
    local version
    version=$(docker run --rm "$IMAGE" "$tool" --version 2>&1 | grep -oE "$expected" | head -1 || true)
    if [ -n "$version" ]; then
        echo "  [PASS] $tool version matches ($version)"
    else
        echo "  [FAIL] $tool version check failed (expected pattern: $expected)"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "=== Health Check: $IMAGE (variant: ${VARIANT:-unknown}) ==="

case "$VARIANT" in
    base)
        echo "Checking base image tools..."
        check_tool docker
        check_tool node
        check_tool python3
        check_tool bun
        check_tool jq
        check_tool gh
        check_tool git
        check_tool make
        check_tool curl
        check_tool wget
        ;;
    opencode)
        echo "Checking OpenCode image tools..."
        check_tool docker
        check_tool node
        check_tool python3
        check_tool go
        check_tool bun
        check_tool opencode
        check_tool gopls
        check_tool buf
        ;;
    qwencode)
        echo "Checking QWEN Code image tools..."
        check_tool docker
        check_tool node
        check_tool python3
        check_tool go
        check_tool bun
        check_tool qwencode
        ;;
    golang)
        echo "Checking Go tooling..."
        check_tool go
        check_tool gopls
        check_tool buf
        check_tool_version go "go1\.[0-9]+\.[0-9]+"
        ;;
    ansible)
        echo "Checking Ansible tooling..."
        check_tool ansible
        check_tool ansible-lint
        check_tool python3
        ;;
    *)
        echo "Unknown variant: $VARIANT"
        echo "Expected: base, opencode, qwencode, golang, ansible"
        exit 1
        ;;
esac

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS health check(s) failed"
    exit 1
else
    echo "PASSED: All health checks passed"
    exit 0
fi
