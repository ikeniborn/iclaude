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
    print_info "iwiki installed. Configure IWIKI_LLM_BASE_URL / IWIKI_LLM_KEY / IWIKI_EMBED_MODEL in .claude_config."
}
