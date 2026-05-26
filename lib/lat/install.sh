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

    # Idempotent: check for the custom-provider block we add (not just applyEnvOverrides,
    # which upstream 0.11.0+ already includes).
    if grep -q "name: \'custom\'" "$provider_js" 2>/dev/null; then
        print_info "lat provider.js already patched"
        return 0
    fi

    python3 - "$provider_js" << 'PYPATCH'
import sys
path = sys.argv[1]
with open(path) as f:
    src = f.read()

# Pattern A: upstream 0.11.0+ (has applyEnvOverrides + ollama, missing custom block)
OLD_A = ("    throw new Error(`Unrecognized LAT_LLM_KEY prefix."
         " Supported: OpenAI (sk-...), Vercel AI Gateway (vck_...),"
         " Ollama (ollama).`);\n}\nfunction applyEnvOverrides")

# Pattern B: older upstream (no applyEnvOverrides, no ollama)
OLD_B = (
    "    if (key.startsWith(\'vck_\'))\n"
    "        return vercel;\n"
    "    if (key.startsWith(\'sk-\'))\n"
    "        return openai;\n"
    "    throw new Error(`Unrecognized LAT_LLM_KEY prefix."
    " Supported: OpenAI (sk-...), Vercel AI Gateway (vck_...).`);\n}"
)

CUSTOM_BLOCK = (
    "    // Custom OpenAI-compatible provider: any key when LAT_LLM_BASE_URL is set\n"
    "    const baseUrl = process.env.LAT_LLM_BASE_URL;\n"
    "    if (baseUrl) {\n"
    "        const model = process.env.LAT_LLM_MODEL || \'text-embedding-3-small\';\n"
    "        const dimensions = parseInt(process.env.LAT_LLM_DIMENSIONS || \'1536\', 10);\n"
    "        return {\n"
    "            name: \'custom\',\n"
    "            apiBase: baseUrl,\n"
    "            model,\n"
    "            dimensions,\n"
    "            headers: (k) => ({\n"
    "                Authorization: `Bearer ${k}`,\n"
    "                \'Content-Type\': \'application/json\',\n"
    "            }),\n"
    "        };\n"
    "    }"
)

NEW_ERR = ("    throw new Error(`Unrecognized LAT_LLM_KEY prefix."
           " Supported: OpenAI (sk-...), Vercel AI Gateway (vck_...),"
           " Ollama (ollama), or set LAT_LLM_BASE_URL for custom providers.`);")

if OLD_A in src:
    new_a = CUSTOM_BLOCK + "\n" + NEW_ERR + "\n}\nfunction applyEnvOverrides"
    out = src.replace(OLD_A, new_a, 1)
elif OLD_B in src:
    new_b = (
        "    if (key.startsWith(\'vck_\'))\n"
        "        return applyEnvOverrides(vercel, key);\n"
        "    if (key.startsWith(\'sk-\'))\n"
        "        return applyEnvOverrides(openai, key);\n"
        "    // ollama / local OpenAI-compatible: LAT_LLM_KEY=ollama (no auth required)\n"
        "    if (key === \'ollama\' || key === \'local\') {\n"
        "        const baseUrl = process.env.LAT_LLM_BASE_URL || \'http://localhost:11434/v1\';\n"
        "        const model = process.env.LAT_LLM_MODEL || \'nomic-embed-text\';\n"
        "        return {\n"
        "            name: \'ollama\',\n"
        "            apiBase: baseUrl,\n"
        "            model,\n"
        "            dimensions: 768,\n"
        "            headers: () => ({ \'Content-Type\': \'application/json\' }),\n"
        "        };\n"
        "    }\n"
        + CUSTOM_BLOCK + "\n"
        + NEW_ERR + "\n"
        "}\n"
        "function applyEnvOverrides(provider, key) {\n"
        "    const baseUrl = process.env.LAT_LLM_BASE_URL;\n"
        "    const model = process.env.LAT_LLM_MODEL;\n"
        "    if (!baseUrl && !model) return provider;\n"
        "    return {\n"
        "        ...provider,\n"
        "        ...(baseUrl ? { apiBase: baseUrl } : {}),\n"
        "        ...(model ? { model } : {}),\n"
        "    };\n"
        "}"
    )
    out = src.replace(OLD_B, new_b, 1)
else:
    print("lat provider.js: no known pattern found — upstream may have changed significantly",
          file=sys.stderr)
    sys.exit(1)

with open(path, "w") as f:
    f.write(out)
PYPATCH
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        print_success "lat provider.js patched (custom LAT_LLM_BASE_URL provider + LAT_LLM_DIMENSIONS)"
    fi
    return $rc
}
