#!/bin/bash
# iwiki installation: ensure uv + sync the engine project under .nvm-isolated.
# Provides: install_iwiki()

# Download the uv binary into the isolated bin/ when neither the isolated nor a
# system uv is available. Outputs the resolved uv path on success; returns 1 on
# failure. Honors HTTPS_PROXY/HTTP_PROXY/PROXY_URL for the bootstrap curl.
_iwiki_bootstrap_uv() {
    local proxy="${HTTPS_PROXY:-${HTTP_PROXY:-${PROXY_URL:-}}}"
    local curl_proxy_args=()
    if [[ -n "$proxy" ]]; then
        curl_proxy_args=(-x "$proxy")
        # HTTPS proxy with an EC cert (P-384) trips OpenSSL 1.1.1 parsing; both
        # flags are required for the bootstrap download.
        [[ "$proxy" == https://* ]] && curl_proxy_args+=(--proxy-insecure -k)
    fi

    print_info "uv not found — downloading to ${ISOLATED_NVM_DIR}/bin/ ..." >&2
    local url="https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-gnu.tar.gz"
    local tmp; tmp=$(mktemp -d)
    if ! curl -fsSL "${curl_proxy_args[@]}" -o "$tmp/uv.tar.gz" "$url"; then
        rm -rf "$tmp"; print_error "Failed to download uv binary (check network/TLS/proxy)"; return 1
    fi
    if ! tar -xzf "$tmp/uv.tar.gz" -C "$tmp" --strip-components=1 --wildcards '*/uv' 2>/dev/null; then
        rm -rf "$tmp"; print_error "Failed to extract uv binary"; return 1
    fi
    mkdir -p "${ISOLATED_NVM_DIR}/bin"
    mv "$tmp/uv" "${ISOLATED_NVM_DIR}/bin/uv"
    chmod +x "${ISOLATED_NVM_DIR}/bin/uv"
    rm -rf "$tmp"
    local uv; uv=$(_iwiki_resolve_uv)
    if [[ -z "$uv" ]]; then
        print_error "uv not found after install — TLS or network issue likely. Check proxy settings."; return 1
    fi
    print_success "uv installed: $uv" >&2
    echo "$uv"
}

install_iwiki() {
    local uv; uv=$(_iwiki_resolve_uv)
    if [[ -z "$uv" ]]; then
        uv=$(_iwiki_bootstrap_uv) || return 1
    fi
    local dir; dir="$(_iwiki_engine_dir)"
    if [[ ! -f "$dir/pyproject.toml" ]]; then
        print_error "iwiki engine project missing at $dir"
        return 1
    fi
    print_info "Syncing iwiki engine (uv) at $dir ..."
    ( cd "$dir" && "$uv" sync ) || { print_error "uv sync failed"; return 1; }

    _iwiki_register_plugin
    print_info "iwiki installed. Configure ICLAUDE_IWIKI_LLM_BASE_URL / ICLAUDE_IWIKI_LLM_KEY / ICLAUDE_IWIKI_EMBED_MODEL in .claude_config."
}

# Invoke the isolated Claude binary, handling both the native binary and the
# legacy "node cli.js" form returned by get_nvm_claude_path().
_iwiki_claude() {
    local cp="$1"; shift
    if [[ "$cp" =~ ^node\  ]]; then ( cd "$SCRIPT_DIR" && node "${cp#node }" "$@" )
    else ( cd "$SCRIPT_DIR" && "$cp" "$@" ); fi
}

# Register the in-repo marketplace + install the iwiki plugin into the isolated
# plugins dir so Claude Code loads it. Non-fatal: the engine works via the CLI
# even if registration fails. Idempotent — skips steps already done.
_iwiki_register_plugin() {
    local cp; cp=$(get_nvm_claude_path 2>/dev/null)
    if [[ -z "$cp" ]]; then
        print_warning "Claude binary not found — skipping plugin registration (engine still usable via the CLI)."
        return 0
    fi
    if [[ -z "${CLAUDE_CONFIG_DIR:-}" ]]; then
        print_warning "CLAUDE_CONFIG_DIR not set — skipping plugin registration."
        return 0
    fi
    # User scope: the plugin is enabled in EVERY project, not just iclaude — the
    # skills run the bundled engine ($CLAUDE_PLUGIN_ROOT/engine) against the
    # current project's own docs/wiki/.
    if ! _iwiki_claude "$cp" plugin marketplace list 2>/dev/null | grep -q "iclaude"; then
        print_info "Registering iclaude marketplace ($SCRIPT_DIR) ..."
        _iwiki_claude "$cp" plugin marketplace add "$SCRIPT_DIR" --scope user \
            || print_warning "marketplace add failed (engine still usable via the CLI)."
    fi
    if _iwiki_claude "$cp" plugin list 2>/dev/null | grep -q "iwiki@iclaude"; then
        # Present already: refresh the marketplace + plugin so a bumped version
        # (e.g. new bundled hooks in hooks/hooks.json) lands in the plugin cache.
        # Restart required to apply. Non-fatal — engine still works via the CLI.
        print_info "iwiki plugin present — refreshing to the marketplace version (bundled hooks) ..."
        _iwiki_claude "$cp" plugin marketplace update iclaude 2>/dev/null \
            || print_warning "marketplace update failed (continuing)."
        _iwiki_claude "$cp" plugin update iwiki@iclaude 2>/dev/null \
            || print_warning "plugin update failed (engine still usable via the CLI)."
    else
        print_info "Installing iwiki plugin (user scope — available in all projects) ..."
        _iwiki_claude "$cp" plugin install iwiki@iclaude --scope user \
            || print_warning "plugin install failed (engine still usable via the CLI)."
    fi
}
