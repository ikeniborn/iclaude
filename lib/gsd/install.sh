#!/bin/bash
# GSD installation module
# Provides: install_gsd(), update_gsd_if_installed()

#######################################
# Install GSD (Get Shit Done) framework in isolated environment.
# Args: [--force] — remove existing gsd-* skill dirs and version marker
# Returns: 0 on success, 1 on failure
#######################################
install_gsd() {
    local force=false
    [[ "${1:-}" == "--force" ]] && force=true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  GSD: Install Get Shit Done Framework"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    setup_isolated_nvm

    if [[ "$force" == true ]]; then
        print_info "Force reinstall: removing existing GSD skill dirs and version marker..."
        find "${CLAUDE_CONFIG_DIR}/skills" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null \
            | xargs -r rm -rf
        rm -f "${CLAUDE_CONFIG_DIR}/.gsd-version"
    fi

    print_info "Installing GSD via npx..."
    if ! CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" npx get-shit-done-cc@latest --global; then
        print_error "Failed to install GSD"
        return 1
    fi

    # Record installed version from registry (npm cache warm after preceding npx install)
    local ver
    ver=$(npm view get-shit-done-cc version 2>/dev/null || echo "unknown")
    echo "$ver" > "${CLAUDE_CONFIG_DIR}/.gsd-version"
    print_success "GSD installed: version $ver"

    echo ""
    print_info "Next steps:"
    print_info "  Status:  ./iclaude.sh --check-gsd"
    print_info "  Use:     Start a Claude Code session and run /gsd"
    echo ""
    return 0
}

#######################################
# Update GSD if installed. No-op if not installed.
# Returns: 0 always
#######################################
update_gsd_if_installed() {
    if ! detect_gsd; then
        print_info "GSD not installed, skipping update"
        return 0
    fi
    print_info "Updating GSD..."
    install_gsd || print_warning "GSD update failed (non-critical)"
}
