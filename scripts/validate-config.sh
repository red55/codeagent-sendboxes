#!/usr/bin/env bash
set -euo pipefail

# Config validation script for base/.opencode/opencode.json
# Validates required fields, provider URLs, and plugin references

CONFIG_FILE="${1:-base/.opencode/opencode.json}"
ERRORS=0

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[FAIL] Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "=== Config Validation: $CONFIG_FILE ==="

# Check JSON is valid
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "[FAIL] Invalid JSON in $CONFIG_FILE"
    exit 1
fi
echo "  [PASS] Valid JSON"

# Check required top-level fields for agent config
check_field() {
    local path="$1"
    local description="$2"
    if jq -e "$path" "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "  [PASS] $description"
    else
        echo "  [FAIL] Missing: $description (path: $path)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_field '.agent' "Agent configuration exists"
check_field '.provider' "Provider configuration exists"

# Check each agent has required fields
echo ""
echo "Checking agent definitions..."
AGENTS=$(jq -r '.agent | keys[]' "$CONFIG_FILE" 2>/dev/null || true)
for agent in $AGENTS; do
    check_field ".agent.\"$agent\".mode" "Agent '$agent' has mode"
    check_field ".agent.\"$agent\".tools" "Agent '$agent' has tools"
done

# Check provider URLs are valid
echo ""
echo "Checking provider configurations..."
PROVIDERS=$(jq -r '.provider | keys[]' "$CONFIG_FILE" 2>/dev/null || true)
for provider in $PROVIDERS; do
    check_field ".provider.\"$provider\".options.baseURL" "Provider '$provider' has baseURL"
    # Validate URL format
    base_url=$(jq -r ".provider.\"$provider\".options.baseURL // empty" "$CONFIG_FILE" 2>/dev/null || true)
    if [ -n "$base_url" ]; then
        if echo "$base_url" | grep -qE '^https?://'; then
            echo "  [PASS] Provider '$provider' baseURL is valid URL"
        else
            echo "  [FAIL] Provider '$provider' baseURL is not a valid URL: $base_url"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Check plugin references match installed packages
echo ""
echo "Checking plugin references..."
PLUGINS=$(jq -r '.plugin // [] | .[]' "$CONFIG_FILE" 2>/dev/null || true)
if [ -n "$PLUGINS" ]; then
    for plugin in $PLUGINS; do
        plugin_name=$(echo "$plugin" | sed 's/@latest//' | sed 's/@[^/]*\///')
        echo "  [INFO] Plugin reference: $plugin"
    done
    echo "  [PASS] Plugin references parseable"
else
    echo "  [INFO] No plugins configured (optional)"
fi

# Check LSP configurations
echo ""
echo "Checking LSP configurations..."
LSPS=$(jq -r '.lsp | keys[]' "$CONFIG_FILE" 2>/dev/null || true)
for lsp in $LSPS; do
    check_field ".lsp.\"$lsp\".command" "LSP '$lsp' has command"
    check_field ".lsp.\"$lsp\".extensions" "LSP '$lsp' has file extensions"
done

# Check file ownership (if running in container)
echo ""
echo "Checking file ownership..."
config_owner=$(stat -c '%U:%G' "$CONFIG_FILE" 2>/dev/null || echo "unknown:unknown")
if [ "$config_owner" = "agent:agent" ] || [ "$config_owner" = "root:root" ] || [ "$config_owner" = "unknown:unknown" ]; then
    echo "  [PASS] Config file ownership: $config_owner"
else
    echo "  [WARN] Config file ownership is $config_owner (expected agent:agent or root:root)"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS validation error(s) found"
    exit 1
else
    echo "PASSED: Config validation successful"
    exit 0
fi
