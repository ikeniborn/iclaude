#!/bin/bash
# iwiki installation: ensure uv + sync the engine project under .nvm-isolated.
# Provides: install_iwiki()

install_iwiki() {
    local uv; uv=$(_iwiki_resolve_uv)
    if [[ -z "$uv" ]]; then
        print_error "uv not found. Install graphify first (./iclaude.sh --install-graphify) — it provides uv."
        return 1
    fi
    local dir; dir="$(_iwiki_engine_dir)"
    if [[ ! -f "$dir/pyproject.toml" ]]; then
        print_error "iwiki engine project missing at $dir"
        return 1
    fi
    print_info "Syncing iwiki engine (uv) at $dir ..."
    ( cd "$dir" && "$uv" sync ) || { print_error "uv sync failed"; return 1; }

    _iwiki_register_plugin
    print_info "iwiki installed. Configure IWIKI_LLM_BASE_URL / IWIKI_LLM_KEY / IWIKI_EMBED_MODEL in .claude_config."
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
        print_info "iwiki plugin already registered."
    else
        print_info "Installing iwiki plugin (user scope — available in all projects) ..."
        _iwiki_claude "$cp" plugin install iwiki@iclaude --scope user \
            || print_warning "plugin install failed (engine still usable via the CLI)."
    fi
}
