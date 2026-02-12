#!/bin/bash
# Update module for system and NVM installations
# Provides function for updating Claude Code in any environment

#######################################
# Update Claude Code
# Universal update function for system and NVM installations
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   0 - success
#   1 - error
#######################################
update_claude_code() {
    local skip_isolated="${1:-false}"
    local using_nvm=false

    # Detect NVM environment
    if detect_nvm "$skip_isolated"; then
        using_nvm=true
        print_info "Detected NVM environment"
        echo ""
    fi

    # Check if this is isolated environment and source nvm.sh
    local is_isolated=false
    if [[ -d "$ISOLATED_NVM_DIR" ]] && [[ "${NVM_DIR:-}" == "$ISOLATED_NVM_DIR" ]]; then
        is_isolated=true
        # Source NVM for isolated environment (required for correct npm operation)
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            source "$NVM_DIR/nvm.sh"
            print_info "Using isolated NVM environment"
            echo ""
        else
            print_error "NVM not found in isolated environment"
            echo ""
            echo "Directory: $ISOLATED_NVM_DIR"
            echo "Expected: $NVM_DIR/nvm.sh"
            echo ""
            echo "Try reinstalling with: ./iclaude.sh --isolated-install"
            exit 1
        fi
    fi

    # Check if running with sudo (only required for system installations)
    if [[ "$using_nvm" == false ]] && [[ $EUID -ne 0 ]]; then
        print_error "Update requires sudo privileges for system installation"
        echo ""
        echo "Run: sudo $0 --update"
        exit 1
    fi

    # Warn if using sudo with NVM
    if [[ "$using_nvm" == true ]] && [[ $EUID -eq 0 ]]; then
        print_warning "Running with sudo, but NVM installation detected"
        print_warning "This will update the system installation, not NVM"
        echo ""
        read -p "Continue with system update? (y/N): " confirm_sudo
        if [[ ! "$confirm_sudo" =~ ^[Yy]$ ]]; then
            print_info "Update cancelled"
            echo ""
            echo "Run without sudo to update NVM installation:"
            echo "  iclaude --update"
            exit 0
        fi
        using_nvm=false  # Treat as system installation
    fi

    print_info "Updating Claude Code..."
    echo ""

    # Get current version
    local current_version=$(get_claude_version)
    if [[ "$current_version" == "not installed" ]]; then
        print_error "Claude Code is not installed"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            echo "Install first with: npm install -g @anthropic-ai/claude-code"
        else
            echo "Install first with: sudo iclaude --install"
        fi
        exit 1
    fi

    print_info "Current version: $current_version"
    echo ""

    # Get latest version
    local latest_version=$(npm view @anthropic-ai/claude-code version 2>/dev/null)
    if [[ -n "$latest_version" ]]; then
        print_info "Latest version:  $latest_version"
        echo ""
    fi

    # Check if already up to date
    if [[ "$current_version" == *"$latest_version"* ]]; then
        print_success "Already running the latest version"
        echo ""

        # For isolated environment, update lockfile even if version is current
        if [[ "$using_nvm" == true ]] && [[ "$is_isolated" == true ]]; then
            print_info "Updating lockfile to reflect current state..."
            save_isolated_lockfile
        fi

        return 0
    fi

    # Confirm update
    read -p "Proceed with update? (Y/n): " confirm_update
    if [[ -n "$confirm_update" ]] && [[ ! "$confirm_update" =~ ^[Yy]$ ]]; then
        print_info "Update cancelled"
        return 0
    fi

    echo ""

    # Pre-update cleanup: Remove ALL symlinks and temporary installations (NVM only)
    if [[ "$using_nvm" == true ]]; then
        local npm_prefix=$(npm prefix -g 2>/dev/null)
        if [[ -n "$npm_prefix" ]] && [[ "$npm_prefix" == *".nvm"* ]]; then
            local bin_dir="$npm_prefix/bin"
            local lib_dir="$npm_prefix/lib/node_modules/@anthropic-ai"

            print_info "Pre-update cleanup..."

            # Remove ALL Claude symlinks (both broken and working) to avoid EEXIST errors
            if [[ -d "$bin_dir" ]]; then
                rm -f "$bin_dir/claude" "$bin_dir/.claude-"* 2>/dev/null
                print_info "Removed existing symlinks"
            fi

            # Remove ALL temporary .claude-code-* folders to avoid ENOTEMPTY errors
            if [[ -d "$lib_dir" ]]; then
                local temp_folders=$(find "$lib_dir" -maxdepth 1 -type d -name ".claude-code-*" 2>/dev/null)
                if [[ -n "$temp_folders" ]]; then
                    echo "$temp_folders" | while read folder; do
                        [[ -z "$folder" ]] && continue
                        rm -rf "$folder" 2>/dev/null
                        print_info "Removed old temporary installation: $(basename "$folder")"
                    done
                fi
            fi

            # Remove incomplete claude-code installation (without cli.js)
            if [[ -d "$lib_dir/claude-code" ]] && [[ ! -f "$lib_dir/claude-code/cli.js" ]]; then
                print_info "Removing incomplete installation: claude-code"
                rm -rf "$lib_dir/claude-code" 2>/dev/null
            fi

            echo ""
        fi
    fi

    if [[ "$using_nvm" == true ]]; then
        print_info "Installing update to NVM environment..."
    else
        print_info "Installing update to system..."
    fi
    echo ""

    # Update via npm (use install instead of update for npm 10+ compatibility)
    if npm install -g @anthropic-ai/claude-code@latest; then
        echo ""

        # Clear bash command hash cache BEFORE checking version
        hash -r 2>/dev/null || true

        # Verify installation success using universal get_claude_version (works for NVM and system)
        local new_version=$(get_claude_version)
        if [[ "$new_version" == "not installed" ]] || [[ "$new_version" == "unknown" ]]; then
            print_error "Update installed but Claude Code not found"
            echo ""
            echo "The npm install succeeded but Claude Code is not accessible."
            echo "This might be due to temporary installation files."
            echo ""
            echo "Try running cleanup again:"
            echo "  iclaude --update"
            echo ""
            echo "Or manually:"
            echo "  npm uninstall -g @anthropic-ai/claude-code"
            echo "  npm install -g @anthropic-ai/claude-code@latest"
            return 1
        fi

        print_success "Claude Code updated successfully"
        echo ""
        print_info "New version: $new_version"
        echo ""

        # Cleanup old installations after successful update (NVM only)
        if [[ "$using_nvm" == true ]]; then
            # Use is_isolated variable set at the beginning of function
            if [[ "$is_isolated" == true ]]; then
                # Isolated environment: Repair FIRST, then update lockfile
                print_info "Repairing symlinks and permissions..."
                repair_isolated_environment
                echo ""

                print_info "Updating lockfile..."
                save_isolated_lockfile
            else
                # System NVM: Standard cleanup
                cleanup_old_claude_installations
                echo ""

                # Recreate symlinks to point to the newest installation
                recreate_claude_symlinks
                echo ""
            fi
        fi

        # Check if version actually updated
        if [[ "$new_version" != *"$latest_version"* ]]; then
            print_warning "Version still shows: $new_version"
            echo ""
            echo "The update was installed but your shell may be using a cached version."
            echo "Please restart your terminal or run: hash -r"
        fi

        return 0
    else
        echo ""
        print_error "Failed to update Claude Code"
        echo ""

        # Suggest cleanup if it's an NVM installation
        if [[ "$using_nvm" == true ]]; then
            echo "If you see ENOTEMPTY errors, try:"
            echo "  1. Run: iclaude --update (cleanup will run automatically)"
            echo "  2. Or manually remove old installations:"
            echo "     rm -rf ~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/.claude-code-*"
            echo ""
        fi

        echo "Or try manually:"
        echo "  npm install -g @anthropic-ai/claude-code@latest"
        return 1
    fi
}
