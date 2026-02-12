#!/usr/bin/env bash
# lib/core/remaining.sh
# Remaining utility functions from legacy (Phase 15 extraction)
#
# Contains functions that were not extracted in Phases 0-14:
# - System installation utilities (install_script, etc.)
# - Legacy/deprecated functions (install_nodejs, etc.)
# - Update checking utilities (check_update, etc.)


if ! declare -F install_nodejs &>/dev/null; then
install_nodejs() {
    print_info "Installing Node.js and npm..."
    echo ""

    # Use NodeSource setup script for latest LTS
    if curl -fsSL https://deb.nodesource.com/setup_18.x | bash -; then
        if apt-get install -y nodejs; then
            print_success "Node.js and npm installed successfully"
            echo ""
            node --version
            npm --version
            echo ""
            return 0
        else
            print_error "Failed to install Node.js package"
            return 1
        fi
    else
        print_error "Failed to download Node.js setup script"
        return 1
    fi
}
fi

if ! declare -F install_claude_code &>/dev/null; then
install_claude_code() {
    local using_nvm=false

    # Detect NVM environment
    if detect_nvm; then
        using_nvm=true
        print_info "Detected NVM environment"
        echo ""
    fi

    if [[ "$using_nvm" == true ]]; then
        print_info "Installing Claude Code to NVM environment..."
    else
        print_info "Installing Claude Code globally..."
    fi
    echo ""

    if npm install -g @anthropic-ai/claude-code; then
        print_success "Claude Code installed successfully"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            print_info "Installed to: $(npm prefix -g)/bin/claude"
        fi
        claude --version 2>/dev/null || print_warning "Claude version check failed (may need to restart shell)"
        echo ""
        return 0
    else
        print_error "Failed to install Claude Code"
        return 1
    fi
}
fi

if ! declare -F get_claude_version &>/dev/null; then
get_claude_version() {
    local claude_cmd=""

    # Priority 1: Check NVM environment first
    if detect_nvm; then
        local nvm_claude=$(get_nvm_claude_path)
        if [[ -n "$nvm_claude" ]]; then
            claude_cmd="$nvm_claude"
        fi
    fi

    # Priority 2: Check system locations if NVM not found
    if [[ -z "$claude_cmd" ]]; then
        if command -v claude &> /dev/null; then
            local cmd_path=$(command -v claude)
            # Skip if it's from NVM (already checked)
            if [[ "$cmd_path" != *".nvm"* ]]; then
                claude_cmd="claude"
            fi
        elif [[ -x "/usr/local/bin/claude" ]]; then
            claude_cmd="/usr/local/bin/claude"
        elif [[ -x "/usr/bin/claude" ]]; then
            claude_cmd="/usr/bin/claude"
        else
            local global_npm_prefix=$(npm prefix -g 2>/dev/null)
            if [[ -n "$global_npm_prefix" ]] && [[ -x "$global_npm_prefix/bin/claude" ]]; then
                claude_cmd="$global_npm_prefix/bin/claude"
            fi
        fi
    fi

    if [[ -z "$claude_cmd" ]]; then
        echo "not installed"
        return 1
    fi

    # Get version
    local version=$($claude_cmd --version 2>/dev/null | head -n 1)
    if [[ -z "$version" ]]; then
        echo "unknown"
        return 1
    fi

    echo "$version"
    return 0
}
fi

if ! declare -F check_update &>/dev/null; then
check_update() {
    local skip_isolated="${1:-false}"
    print_info "Checking for Claude Code updates..."
    echo ""

    # Detect NVM environment
    local using_nvm=false
    if detect_nvm "$skip_isolated"; then
        using_nvm=true
    fi

    # Get current version
    local current_version=$(get_claude_version)
    if [[ "$current_version" == "not installed" ]]; then
        print_error "Claude Code is not installed"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            echo "Install with: npm install -g @anthropic-ai/claude-code"
        else
            echo "Install with: sudo iclaude --install"
        fi
        return 1
    fi

    print_info "Current version: $current_version"
    echo ""

    # Get latest version from npm
    print_info "Fetching latest version from npm..."
    local latest_version=$(npm view @anthropic-ai/claude-code version 2>/dev/null)

    if [[ -z "$latest_version" ]]; then
        print_error "Failed to fetch latest version from npm"
        return 1
    fi

    print_info "Latest version:  $latest_version"
    echo ""

    # Compare versions
    if [[ "$current_version" == *"$latest_version"* ]]; then
        print_success "You are running the latest version"
    else
        print_warning "An update is available: $latest_version"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            echo "Run to update: iclaude --update"
            echo "Or directly:   npm install -g @anthropic-ai/claude-code@latest"
        else
            echo "Run to update: sudo iclaude --update"
        fi
    fi

    return 0
}
fi

if ! declare -F check_dependencies &>/dev/null; then
check_dependencies() {
    local needs_install=false

    echo ""
    print_info "Checking dependencies..."
    echo ""

    # Check npm
    if ! command -v npm &> /dev/null; then
        print_warning "npm not found"
        needs_install=true

        read -p "Install Node.js and npm? (Y/n): " install_node
        if [[ -z "$install_node" ]] || [[ "$install_node" =~ ^[Yy]$ ]]; then
            if ! install_nodejs; then
                print_error "Cannot proceed without npm"
                exit 1
            fi
        else
            print_error "npm is required to run Claude Code"
            echo ""
            echo "Install manually:"
            echo "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
            echo "  sudo apt-get install -y nodejs"
            exit 1
        fi
    else
        print_success "npm found: $(npm --version)"

        # Detect and show NVM info
        if detect_nvm; then
            local npm_prefix=$(npm prefix -g 2>/dev/null)
            print_info "NVM environment detected"
            if [[ -n "$npm_prefix" ]]; then
                print_info "Global packages location: $npm_prefix"
            fi
        fi
    fi

    # Check Claude Code (check multiple locations, prioritize NVM)
    local claude_found=false

    # Check NVM first
    if detect_nvm; then
        local nvm_claude=$(get_nvm_claude_path)
        if [[ -n "$nvm_claude" ]]; then
            claude_found=true
        fi
    fi

    # Check system locations if not found in NVM
    if [[ "$claude_found" == false ]]; then
        if command -v claude &> /dev/null; then
            local cmd_path=$(command -v claude)
            # Don't count NVM paths here (already checked)
            if [[ "$cmd_path" != *".nvm"* ]]; then
                claude_found=true
            fi
        elif [[ -x "/usr/local/bin/claude" || -x "/usr/bin/claude" ]]; then
            claude_found=true
        else
            # Check npm global prefix (non-NVM)
            local global_npm_prefix=$(npm prefix -g 2>/dev/null)
            if [[ -n "$global_npm_prefix" ]] && [[ "$global_npm_prefix" != *".nvm"* ]]; then
                if [[ -x "$global_npm_prefix/bin/claude" ]] || ls "$global_npm_prefix/bin/.claude-"* &>/dev/null; then
                    claude_found=true
                fi
            fi
        fi
    fi

    if [[ "$claude_found" == false ]]; then
        print_warning "Claude Code not found"
        needs_install=true

        echo ""
        read -p "Install Claude Code globally? (Y/n): " install_claude
        if [[ -z "$install_claude" ]] || [[ "$install_claude" =~ ^[Yy]$ ]]; then
            if ! install_claude_code; then
                print_error "Cannot proceed without Claude Code"
                exit 1
            fi
        else
            print_warning "Claude Code is not installed"
            echo ""
            echo "Install manually:"
            echo "  npm install -g @anthropic-ai/claude-code"
            echo ""
            echo "You can still install iclaude, but it won't work until Claude Code is installed."
            read -p "Continue anyway? (y/N): " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_success "Claude Code found"
    fi

    echo ""
}
fi

if ! declare -F install_script &>/dev/null; then
install_script() {
    local script_path="$SCRIPT_DIR/iclaude.sh"
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Installation requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --install"
        exit 1
    fi

    # Check and install dependencies
    check_dependencies

    # Check if already installed
    if [[ -L "$target_path" ]]; then
        local current_target=$(readlink -f "$target_path")
        local script_realpath=$(readlink -f "$script_path")

        if [[ "$current_target" == "$script_realpath" ]]; then
            print_info "Already installed at: $target_path"
            return 0
        else
            print_warning "Different version found at: $target_path"
            echo "  Current: $current_target"
            echo "  New:     $script_realpath"
            echo ""
            read -p "Replace existing installation? (y/N): " replace

            if [[ ! "$replace" =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                return 1
            fi
        fi
    fi

    # Create symlink
    ln -sf "$(readlink -f "$script_path")" "$target_path"
    chmod +x "$target_path"

    print_success "Installed to: $target_path"
    echo ""
    echo "You can now run: iclaude"
}
fi

if ! declare -F uninstall_script &>/dev/null; then
uninstall_script() {
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Uninstallation requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --uninstall"
        exit 1
    fi

    # Check if installed
    if [[ ! -e "$target_path" ]]; then
        print_info "Not installed (no file at $target_path)"
        return 0
    fi

    # Remove symlink
    rm -f "$target_path"
    print_success "Uninstalled from: $target_path"
}
fi

if ! declare -F create_symlink_only &>/dev/null; then
create_symlink_only() {
    local script_path="$SCRIPT_DIR/iclaude.sh"
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Creating symlink requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --create-symlink"
        exit 1
    fi

    echo ""
    print_info "Checking isolated environment..."
    echo ""

    # Check if isolated environment exists
    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found"
        echo ""
        echo "The isolated environment is required for --create-symlink"
        echo "This allows you to install globally WITHOUT system npm!"
        echo ""
        echo "First, install isolated environment:"
        echo "  ./iclaude.sh --isolated-install"
        echo ""
        echo "Then create symlink:"
        echo "  sudo ./iclaude.sh --create-symlink"
        exit 1
    fi

    # Verify isolated environment is functional
    local claude_cli="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    if [[ ! -f "$claude_cli" ]]; then
        print_error "Claude Code not found in isolated environment"
        echo ""
        echo "Run: ./iclaude.sh --isolated-install"
        exit 1
    fi

    print_success "Isolated environment found and functional"
    echo "  Location: $ISOLATED_NVM_DIR"
    echo "  Claude Code: $claude_cli"
    echo ""

    # Check if already installed
    if [[ -L "$target_path" ]]; then
        local current_target=$(readlink -f "$target_path")
        local script_realpath=$(readlink -f "$script_path")

        if [[ "$current_target" == "$script_realpath" ]]; then
            print_success "Already installed at: $target_path"
            echo ""
            echo "You can now run: iclaude"
            return 0
        else
            print_warning "Different installation found at: $target_path"
            echo "  Current: $current_target"
            echo "  New:     $script_realpath"
            echo ""
            echo "Remove existing installation first:"
            echo "  sudo iclaude --uninstall-symlink"
            return 1
        fi
    fi

    # Create symlink
    ln -sf "$(readlink -f "$script_path")" "$target_path"
    chmod +x "$target_path"

    echo ""
    print_success "Global symlink created successfully!"
    echo ""
    echo "  Symlink: $target_path"
    echo "  Target:  $(readlink -f "$script_path")"
    echo ""
    print_info "Using isolated environment (NO system npm required):"
    echo "  Node.js: $(find "$ISOLATED_NVM_DIR/versions/node" -name node -type f 2>/dev/null | head -1)"
    echo "  Claude Code: $claude_cli"
    echo ""
    echo "You can now run: iclaude"
}
fi

if ! declare -F uninstall_symlink_only &>/dev/null; then
uninstall_symlink_only() {
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Removing symlink requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --uninstall-symlink"
        exit 1
    fi

    echo ""

    # Check if symlink exists
    if [[ ! -e "$target_path" ]]; then
        print_info "Symlink not found at: $target_path"
        echo ""
        echo "Nothing to remove"
        return 0
    fi

    # Show what will be removed
    if [[ -L "$target_path" ]]; then
        local link_target=$(readlink -f "$target_path")
        print_info "Removing symlink:"
        echo "  Symlink: $target_path"
        echo "  Target:  $link_target"
    else
        print_warning "File at $target_path is not a symlink"
        echo ""
        read -p "Remove anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            return 1
        fi
    fi

    # Remove symlink
    rm -f "$target_path"

    echo ""
    print_success "Symlink removed successfully"
    echo ""
    print_info "Note: Isolated environment is preserved"
    echo "  Location: $ISOLATED_NVM_DIR"
    echo "  To use locally: ./iclaude.sh"
    echo "  To recreate symlink: sudo ./iclaude.sh --create-symlink"
}
fi
