#!/bin/bash
# Statusline installation module
# Provides functions for installing and configuring statusline script

#######################################
# Configure statusLine in settings.json
# Updates Claude Code settings to enable custom status line script
# Arguments:
#   $1 - absolute path to statusline script
# Returns:
#   0 - success
#   1 - error
#######################################
configure_statusline_in_settings() {
    local script_path="$1"

    # Ensure isolated environment is set up
    setup_isolated_nvm

    # Determine settings file location (always use isolated config for statusline)
    local settings_file="$ISOLATED_CONFIG_DIR/settings.json"

    print_info "Configuring statusLine in settings.json..."
    echo "  Settings file: $settings_file"

    # Ensure settings file exists
    if [[ ! -f "$settings_file" ]]; then
        echo "{}" > "$settings_file"
    fi

    # Check for jq (using core/validation.sh)
    validate_dependency "jq" "Install with: sudo apt install jq (Ubuntu/Debian) or brew install jq (macOS)" || return 1

    # Add statusLine configuration with correct format
    local temp_file="${settings_file}.tmp"
    jq --arg script "$script_path" \
       '. + {
           "statusLine": {
               "type": "command",
               "command": $script,
               "padding": 1
           }
       }' "$settings_file" > "$temp_file"

    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$settings_file"
        chmod 600 "$settings_file"
        print_success "StatusLine configured successfully"
        return 0
    else
        rm -f "$temp_file"
        print_error "Failed to update settings.json"
        return 1
    fi
}

#######################################
# Install statusline script for Claude Code
# Creates claude-statusline.sh and configures settings.json
# Returns:
#   0 - success
#   1 - error
#######################################
install_statusline_script() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Installing Claude Status Line"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Setup isolated environment
    setup_isolated_nvm

    # Create scripts directory
    local scripts_dir="$ISOLATED_CONFIG_DIR/scripts"
    mkdir -p "$scripts_dir"

    local script_path="$scripts_dir/claude-statusline.sh"

    # Check if script already exists
    if [[ -f "$script_path" ]]; then
        print_info "Script already exists: $script_path"
        print_info "Regenerating..."
        echo ""
    fi

    # Get absolute path for settings.json
    local abs_script_path
    if command -v realpath &>/dev/null; then
        abs_script_path=$(realpath "$script_path")
    else
        abs_script_path="$(cd "$(dirname "$script_path")" && pwd)/$(basename "$script_path")"
    fi

    print_info "Installing claude-statusline.sh script..."

    # Script is already created manually, just ensure it's executable
    if [[ ! -f "$script_path" ]]; then
        print_error "Script not found: $script_path"
        echo "  Expected location: $script_path"
        return 1
    fi

    chmod +x "$script_path"
    print_success "Created statusline script: $script_path"

    # Configure settings.json
    if ! configure_statusline_in_settings "$abs_script_path"; then
        return 1
    fi

    # Update lockfile
    save_isolated_lockfile

    echo ""
    echo "✅ StatusLine installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Launch Claude Code: ./iclaude.sh"
    echo "  2. Status line will appear at the bottom of Claude interface"
    echo "  3. Customize the script at: $script_path"
    echo ""
    echo "Check status: ./iclaude.sh --check-statusline"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return 0
}
