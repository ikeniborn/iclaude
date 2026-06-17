#!/bin/bash
# iwiki detection + engine runner resolution.
# Provides: detect_iwiki(), _iwiki_resolve_uv(), iwiki_engine_run()

_iwiki_resolve_uv() {
    if [[ -x "$GRAPHIFY_UV_BIN" ]]; then echo "$GRAPHIFY_UV_BIN"
    elif command -v uv &>/dev/null; then command -v uv; fi
}

# Engine project dir (in-repo plugin).
_iwiki_engine_dir() { echo "${SCRIPT_DIR}/plugin/iwiki/engine"; }

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
