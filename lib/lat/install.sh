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
