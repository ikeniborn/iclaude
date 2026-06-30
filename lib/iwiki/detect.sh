#!/bin/bash
# iwiki detection + engine runner resolution.
# Provides: detect_iwiki(), _iwiki_resolve_uv(), iwiki_engine_run()

_iwiki_resolve_uv() {
    if [[ -x "$UV_BIN" ]]; then echo "$UV_BIN"
    elif command -v uv &>/dev/null; then command -v uv; fi
}

# Engine project dir (in-repo plugin).
_iwiki_engine_dir() { echo "${SCRIPT_DIR}/plugin/iwiki/engine"; }

# Resolve the engine project once and export IWIKI_ENGINE_DIR — the canonical
# entrypoint the iwiki skills read. Preference: the in-repo engine (always
# uv-synced by install_iwiki and reachable from any project, since SCRIPT_DIR is
# the iclaude install) -> newest cached plugin engine. No-op if neither exists.
iwiki_export_engine_dir() {
    local dir; dir="$(_iwiki_engine_dir)"
    if [[ ! -f "$dir/pyproject.toml" ]]; then
        dir="$(ls -d "${CLAUDE_CONFIG_DIR:-}"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
    fi
    [[ -f "$dir/pyproject.toml" ]] && export IWIKI_ENGINE_DIR="$dir"
}

detect_iwiki() {
    local uv; uv=$(_iwiki_resolve_uv)
    [[ -n "$uv" && -f "$(_iwiki_engine_dir)/pyproject.toml" ]]
}

# Run the engine: iwiki_engine_run <args...>
# Stays in the caller's CWD (so a relative --wiki-dir like "docs/wiki" resolves
# against the project root); --project points uv at the engine's venv.
iwiki_engine_run() {
    local uv; uv=$(_iwiki_resolve_uv)
    [[ -z "$uv" ]] && { echo "iwiki: uv not found; run ./iclaude.sh --install-iwiki" >&2; return 1; }
    "$uv" run --project "$(_iwiki_engine_dir)" python3 -m iwiki_engine "$@"
}
