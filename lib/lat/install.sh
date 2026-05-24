#!/bin/bash
# lat.md installation module
# Provides: install_lat()

#######################################
# Install lat.md in isolated environment.
# Uses the currently active nvm node version (no forced Node upgrade).
# Returns: 0 on success, 1 on failure
#######################################
install_lat() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  lat.md: Install Documentation Graph Tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    # Load nvm and activate the isolated environment
    print_info "Loading isolated nvm environment..."
    # shellcheck source=/dev/null
    if ! source "${ISOLATED_NVM_DIR}/nvm.sh" --no-use 2>/dev/null; then
        print_error "Failed to load nvm"
        return 1
    fi

    # Use the highest installed node version in the isolated environment
    setup_isolated_nvm

    # Ensure NPM_CONFIG_PREFIX is set — may not be set if install runs before setup_isolated_nvm
    NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-${ISOLATED_NVM_DIR}/npm-global}"
    export NPM_CONFIG_PREFIX

    # Install lat.md globally
    print_info "Installing lat.md globally (npm install -g lat.md) ..."
    local npm_bin="${NPM_CONFIG_PREFIX}/bin/npm"
    if [[ ! -x "$npm_bin" ]]; then
        npm_bin="$(command -v npm 2>/dev/null)"
    fi

    if [[ -z "$npm_bin" ]]; then
        print_error "npm not found. Ensure Node.js is installed in the isolated environment."
        return 1
    fi

    if ! NPM_CONFIG_PREFIX="$NPM_CONFIG_PREFIX" "$npm_bin" install -g lat.md; then
        print_error "Failed to install lat.md"
        return 1
    fi

    if ! detect_lat; then
        print_error "lat binary not found after install (expected: $NPM_CONFIG_PREFIX/bin/lat)"
        return 1
    fi

    print_success "lat.md installed: $LAT_BIN"

    patch_lat_provider || print_warning "lat provider patch failed — ollama/LAT_LLM_BASE_URL unavailable"

    echo ""
    print_success "lat.md installed successfully!"
    echo ""
    print_info "MCP server wires automatically on each launch when lat.md/ is found."
    print_info "Next steps:"
    print_info "  Status:       ./iclaude.sh --check-lat"
    print_info "  Init project: ./iclaude.sh --lat-init"
    print_info "  Check refs:   ./iclaude.sh --lat-check"
    echo ""
    return 0
}

#######################################
# Patch lat provider.js to add:
#   - ollama / local key support (no auth, OpenAI-compatible API)
#   - LAT_LLM_BASE_URL env override for all providers
#   - LAT_LLM_MODEL env override for all providers
# Idempotent — no-op if patch already applied.
# Returns: 0 on success, 1 on failure
#######################################
patch_lat_provider() {
    local provider_js
    provider_js="${NPM_CONFIG_PREFIX}/lib/node_modules/lat.md/dist/src/search/provider.js"

    if [[ ! -f "$provider_js" ]]; then
        print_warning "lat provider.js not found: $provider_js"
        return 1
    fi

    # Idempotent: already patched
    if grep -q "applyEnvOverrides" "$provider_js" 2>/dev/null; then
        print_info "lat provider.js already patched"
        return 0
    fi

    python3 - "$provider_js" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    src = f.read()

old = """    if (key.startsWith('vck_'))
        return vercel;
    if (key.startsWith('sk-'))
        return openai;
    throw new Error(`Unrecognized LAT_LLM_KEY prefix. Supported: OpenAI (sk-...), Vercel AI Gateway (vck_...).`);
}"""

new = """    if (key.startsWith('vck_'))
        return applyEnvOverrides(vercel, key);
    if (key.startsWith('sk-'))
        return applyEnvOverrides(openai, key);
    // ollama / local OpenAI-compatible: LAT_LLM_KEY=ollama (no auth required)
    if (key === 'ollama' || key === 'local') {
        const baseUrl = process.env.LAT_LLM_BASE_URL || 'http://localhost:11434/v1';
        const model = process.env.LAT_LLM_MODEL || 'nomic-embed-text';
        return {
            name: 'ollama',
            apiBase: baseUrl,
            model,
            dimensions: 768,
            headers: () => ({ 'Content-Type': 'application/json' }),
        };
    }
    throw new Error(`Unrecognized LAT_LLM_KEY prefix. Supported: OpenAI (sk-...), Vercel AI Gateway (vck_...), Ollama (ollama).`);
}
function applyEnvOverrides(provider, key) {
    const baseUrl = process.env.LAT_LLM_BASE_URL;
    const model = process.env.LAT_LLM_MODEL;
    if (!baseUrl && !model) return provider;
    return {
        ...provider,
        ...(baseUrl ? { apiBase: baseUrl } : {}),
        ...(model ? { model } : {}),
    };
}"""

if old not in src:
    print("lat provider.js: pattern not found — may have been updated upstream", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(src.replace(old, new, 1))
PYEOF
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        print_success "lat provider.js patched (ollama + LAT_LLM_BASE_URL/MODEL support)"
    fi
    return $rc
}
