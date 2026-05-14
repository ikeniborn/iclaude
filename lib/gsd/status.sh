#!/bin/bash
# GSD status module
# Provides: check_gsd_status()

#######################################
# Display GSD installation status.
# Shows installed/not-installed, version from marker, skill dirs.
# Returns: 0 always
#######################################
check_gsd_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  GSD: Get Shit Done Framework Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if ! detect_gsd; then
        print_warning "GSD: not installed"
        echo "  Run: ./iclaude.sh --install-gsd"
        echo ""
        return 0
    fi

    print_success "GSD: installed"

    local marker="${CLAUDE_CONFIG_DIR}/.gsd-version"
    if [[ -f "$marker" ]]; then
        local ver
        ver=$(cat "$marker" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
        print_info "Version: $ver"
    else
        print_info "Version: unknown (marker absent)"
    fi

    echo ""
    print_info "Installed skills:"
    find "${CLAUDE_CONFIG_DIR}/skills" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null \
        | sort \
        | while IFS= read -r dir; do
            echo "  $(basename "$dir")"
        done

    echo ""
    return 0
}
