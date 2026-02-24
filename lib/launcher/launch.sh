#!/bin/bash
# Launcher module
# Provides function for launching Claude Code with router and binary detection

#######################################
# Launch Claude Code
# Detects and launches Claude Code binary (native or via router)
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
#   $@ - Additional arguments passed to Claude Code
# Returns:
#   Does not return (uses exec)
#######################################
launch_claude() {
    local skip_isolated="${1:-false}"
    shift  # Remove first argument, rest are Claude args

    # Auto-repair stale settings.json paths (silent if no change needed)
    repair_settings_paths

    # Check OAuth token expiration before launching
    check_oauth_token "$skip_isolated"

    # NEW: Check if router should be used (only if --router flag is set)
    local use_router=false
    if [[ "$USE_ROUTER_FLAG" == "true" ]] && detect_router "$skip_isolated"; then
        use_router=true
    fi

    echo ""
    if [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code via Router..."
    else
        print_info "Launching Claude Code..."
    fi
    echo ""

    # NEW: Router launch path
    if [[ "$use_router" == "true" ]]; then
        local ccr_cmd=$(get_router_path "$skip_isolated")
        if [[ -z "$ccr_cmd" ]]; then
            print_error "Router enabled but ccr binary not found"
            print_info "Install with: ./iclaude.sh --install-router"
            exit 1
        fi

        # Copy router config to CCR's expected location
        local router_config=""
        if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
            router_config="$ISOLATED_NVM_DIR/.claude-isolated/router.json"
        else
            router_config="$HOME/.claude/router.json"
        fi

        if [[ -f "$router_config" ]]; then
            mkdir -p "$HOME/.claude-code-router"
            cp "$router_config" "$HOME/.claude-code-router/config.json"
            print_info "Using router config: $router_config"
        fi

        print_info "Using Claude Code Router: $ccr_cmd"

        # Show router version
        local router_version=$("$ccr_cmd" --version 2>/dev/null | head -1 || echo "unknown")
        if [[ "$router_version" != "unknown" ]]; then
            print_info "Router version: $router_version"
        fi
        echo ""

        # Signal to statusline that router is active (suppresses RL display)
        export ICLAUDE_ROUTER_ACTIVE=1

        # Launch via ccr code
        exec "$ccr_cmd" code "$@"
    fi

    # EXISTING: Find claude installation (native launch path)
    local claude_cmd=""

    # Priority 1: Check NVM environment first (user's active version)
    if detect_nvm "$skip_isolated"; then
        local nvm_claude=$(get_nvm_claude_path)
        if [[ -n "$nvm_claude" ]]; then
            claude_cmd="$nvm_claude"
            print_info "Using NVM installation"
        fi
    fi

    # Priority 2: Check system global locations if NVM not found
    if [[ -z "$claude_cmd" ]]; then
        if [[ -x "/usr/local/bin/claude" ]]; then
            claude_cmd="/usr/local/bin/claude"
        elif [[ -x "/usr/bin/claude" ]]; then
            claude_cmd="/usr/bin/claude"
        elif command -v claude &> /dev/null; then
            # Fall back to whatever is in PATH, but warn if it's local
            claude_cmd=$(command -v claude)
            local claude_dir=$(dirname "$claude_cmd")
            # Skip if it's from NVM (already checked) or local installation
            if [[ "$claude_cmd" == *".nvm"* ]]; then
                # Already checked in NVM, shouldn't happen but just in case
                :
            elif [[ "$claude_dir" == "." || "$claude_dir" == "$PWD" || "$claude_dir" == "./node_modules/.bin" ]]; then
                print_warning "Found local Claude installation: $claude_cmd"
                print_info "Looking for global installation..."
                claude_cmd=""
            fi
        fi
    fi

    # Priority 3: Try npm global prefix
    if [[ -z "$claude_cmd" ]]; then
        local global_npm_prefix=$(npm prefix -g 2>/dev/null)
        if [[ -n "$global_npm_prefix" ]] && [[ "$global_npm_prefix" != *".nvm"* ]]; then
            # Check for claude in npm global bin
            if [[ -x "$global_npm_prefix/bin/claude" ]]; then
                claude_cmd="$global_npm_prefix/bin/claude"
            # Check for .claude-* temporary files
            elif ls "$global_npm_prefix/bin/.claude-"* &>/dev/null; then
                local temp_claude=$(ls "$global_npm_prefix/bin/.claude-"* 2>/dev/null | head -n 1)
                if [[ -x "$temp_claude" ]]; then
                    claude_cmd="$temp_claude"
                    print_warning "Using temporary Claude binary: $(basename "$temp_claude")"
                fi
            fi
        fi
    fi

    # If still not found, try npx as fallback
    if [[ -z "$claude_cmd" ]]; then
        if command -v npx &> /dev/null; then
            print_info "Using npx to run Claude Code..."
            exec npx @anthropic-ai/claude-code "$@"
        else
            print_error "Claude Code not found"
            echo ""
            echo "Install Claude Code globally:"
            echo "  npm install -g @anthropic-ai/claude-code"
            exit 1
        fi
    fi

    print_info "Using Claude Code: $claude_cmd"

    # Show version of the installation being used
    local used_version=$(get_cli_version "$claude_cmd")
    if [[ "$used_version" != "unknown" ]]; then
        print_info "Version: $used_version"
    fi

    # Debug: Show command that will be executed
    if [[ "${DEBUG_LAUNCH:-0}" == "1" ]]; then
        echo ""
        print_info "Debug: Launching with arguments:"
        printf "  %s\n" "$claude_cmd" "$@"
        print_info "Debug: Environment variables:"
        echo "  CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-not set}"
        echo "  NVM_DIR=${NVM_DIR:-not set}"
        echo "  HTTPS_PROXY=${HTTPS_PROXY:0:50}..."
        echo ""
    fi

    # Pass through any additional arguments
    # Use eval if command contains spaces (e.g., "node /path/to/cli.js")
    if [[ "$claude_cmd" == *" "* ]]; then
        eval exec "$claude_cmd" '"$@"'
    else
        exec "$claude_cmd" "$@"
    fi
}
