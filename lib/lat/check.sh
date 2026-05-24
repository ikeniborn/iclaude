#!/bin/bash
# lat.md check and pre-commit hook module
# Provides: run_lat_check(), install_lat_precommit(), remove_lat_precommit()

_LAT_HOOK_BEGIN="# === LAT-PRECOMMIT-BEGIN ==="
_LAT_HOOK_END="# === LAT-PRECOMMIT-END ==="

#######################################
# Run lat check in project.
# Installs pre-commit hook if not present.
# Returns: 0 if all refs valid, 1 on broken refs or missing project
#######################################
run_lat_check() {
    if ! detect_lat_project; then
        print_error "lat.md/ not found in $LAUNCH_DIR"
        print_info "Initialize with: ./iclaude.sh --lat-init"
        return 1
    fi

    print_info "Running lat check in $LAUNCH_DIR ..."
    if (cd "$LAUNCH_DIR" && "$LAT_BIN" check); then
        print_success "All references valid ✓"
        install_lat_precommit
        return 0
    else
        print_error "Broken references found (see above)"
        install_lat_precommit
        return 1
    fi
}

#######################################
# Install lat check as pre-commit hook.
# Idempotent — no-op if already installed.
# Returns: 0 always
#######################################
install_lat_precommit() {
    local git_dir
    git_dir=$(cd "$LAUNCH_DIR" && git rev-parse --git-dir 2>/dev/null) || {
        print_warning "Not a git repo at $LAUNCH_DIR — skipping pre-commit hook"
        return 0
    }
    local hook_file
    # git_dir may be absolute (worktree) or relative (normal repo)
    if [[ "$git_dir" = /* ]]; then
        hook_file="${git_dir}/hooks/pre-commit"
    else
        hook_file="${LAUNCH_DIR}/${git_dir}/hooks/pre-commit"
    fi
    mkdir -p "$(dirname "$hook_file")"

    # Already installed — skip
    grep -qF "LAT-PRECOMMIT-BEGIN" "$hook_file" 2>/dev/null && return 0

    # Create or append
    if [[ ! -f "$hook_file" ]]; then
        printf '#!/bin/bash\n' > "$hook_file"
        chmod +x "$hook_file"
    fi

    cat >> "$hook_file" << HOOKEOF

${_LAT_HOOK_BEGIN}
# lat.md reference integrity check — installed by iclaude --lat-check
if command -v "${LAT_BIN}" &>/dev/null; then
    "${LAT_BIN}" check || exit 1
fi
${_LAT_HOOK_END}
HOOKEOF

    print_success "lat pre-commit hook installed: $hook_file"
    return 0
}

#######################################
# Remove lat section from pre-commit hook.
# Idempotent — no-op if not present.
# Returns: 0 always
#######################################
remove_lat_precommit() {
    local git_dir
    git_dir=$(cd "$LAUNCH_DIR" && git rev-parse --git-dir 2>/dev/null) || return 0
    local hook_file
    if [[ "$git_dir" = /* ]]; then
        hook_file="${git_dir}/hooks/pre-commit"
    else
        hook_file="${LAUNCH_DIR}/${git_dir}/hooks/pre-commit"
    fi

    [[ -f "$hook_file" ]] || return 0
    grep -qF "LAT-PRECOMMIT-BEGIN" "$hook_file" || return 0

    # Remove lines between markers (inclusive)
    python3 - "$hook_file" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
out, skip = [], False
for line in lines:
    if 'LAT-PRECOMMIT-BEGIN' in line:
        skip = True
    if not skip:
        out.append(line)
    if 'LAT-PRECOMMIT-END' in line:
        skip = False
with open(path, 'w') as f:
    f.writelines(out)
PYEOF

    print_info "lat pre-commit hook removed"
    return 0
}

#######################################
# Display lat.md installation and project status.
# Returns: 0 always
#######################################
check_lat_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  lat.md: Documentation Graph Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # lat CLI
    if detect_lat; then
        local lat_ver
        lat_ver=$("$LAT_BIN" --version 2>/dev/null || echo "unknown")
        print_success "lat CLI: $LAT_BIN ($lat_ver)"
    else
        print_warning "lat CLI: not installed"
        echo "  Run: ./iclaude.sh --install-lat"
        echo ""
        return 0
    fi

    # lat.md/ in project
    if detect_lat_project; then
        print_success "lat.md/: found at $LAT_PROJECT_ROOT"
    else
        print_warning "lat.md/: not found in $LAUNCH_DIR"
        echo "  Run: ./iclaude.sh --lat-init"
    fi

    # MCP config
    local settings_file="${CLAUDE_CONFIG_DIR}/settings.json"
    if python3 -c "
import json, sys
with open('$settings_file') as f:
    s = json.load(f)
sys.exit(0 if 'lat' in s.get('mcpServers', {}) else 1)
" 2>/dev/null; then
        print_success "MCP: configured in settings.json"
    else
        print_warning "MCP: not configured (auto-injects on next launch when lat.md/ present)"
    fi

    echo ""
    return 0
}
