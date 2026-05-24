#!/bin/bash
# lat.md installation module
# Provides: install_lat()

#######################################
# Install lat.md in isolated environment.
# Upgrades Node to 22 via nvm, installs lat.md globally.
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

    # Step 1: Load nvm and upgrade to Node 22
    print_info "Loading nvm from $ISOLATED_NVM_DIR ..."
    # shellcheck source=/dev/null
    if ! source "${ISOLATED_NVM_DIR}/nvm.sh" --no-use 2>/dev/null; then
        print_error "Failed to load nvm"
        return 1
    fi

    print_info "Installing Node.js 22 (required by lat.md) ..."
    if ! NVM_DIR="$ISOLATED_NVM_DIR" nvm install 22; then
        print_error "Failed to install Node 22"
        return 1
    fi

    print_info "Setting Node 22 as default ..."
    if ! NVM_DIR="$ISOLATED_NVM_DIR" nvm alias default 22; then
        print_warning "Failed to set Node 22 as default (non-fatal)"
    fi
    print_success "Node 22 set as default"

    # Reload nvm so npm uses Node 22
    NVM_DIR="$ISOLATED_NVM_DIR" nvm use 22 &>/dev/null || true

    # Step 2: Install lat.md globally
    print_info "Installing lat.md globally (npm install -g lat.md) ..."
    local npm_bin="${NPM_CONFIG_PREFIX}/bin/npm"
    if [[ ! -x "$npm_bin" ]]; then
        npm_bin="$(NVM_DIR="$ISOLATED_NVM_DIR" nvm which current 2>/dev/null | sed 's|/node$|/npm|')"
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
