#!/bin/bash

#######################################
# iclaude.sh - Fully Modular Entry Point
# Version: 4.0 (100% Modular Architecture)
# Description: Fully modular Claude Code wrapper - no legacy dependencies
#######################################

set -euo pipefail

#######################################
# Determine library directory
#######################################
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

#######################################
# Load core modules (Phase 0)
#######################################
if [[ ! -d "$LIB_DIR/core" ]]; then
    echo "ERROR: Core modules not found at $LIB_DIR/core"
    echo "Please ensure lib/ directory structure exists."
    exit 1
fi

# Load core modules in order
source "${LIB_DIR}/core/init.sh"
source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/core/validation.sh"
source "${LIB_DIR}/core/json.sh"
source "${LIB_DIR}/core/remaining.sh"

#######################################
# Initialize environment
#######################################
init_environment

#######################################
# Load proxy modules (Phase 2)
#######################################
if [[ -d "$LIB_DIR/proxy" ]]; then
    source "${LIB_DIR}/proxy/validate.sh"
    source "${LIB_DIR}/proxy/credentials.sh"
    source "${LIB_DIR}/proxy/configure.sh"
    source "${LIB_DIR}/proxy/git.sh"
fi

#######################################
# Load NVM modules (Phase 3)
#######################################
if [[ -d "$LIB_DIR/nvm" ]]; then
    source "${LIB_DIR}/nvm/detect.sh"
    source "${LIB_DIR}/nvm/setup.sh"
    source "${LIB_DIR}/nvm/install.sh"
    source "${LIB_DIR}/nvm/claude.sh"
    source "${LIB_DIR}/nvm/repair.sh"
    source "${LIB_DIR}/nvm/cleanup.sh"
fi

#######################################
# Load lockfile modules (Phase 4)
#######################################
if [[ -d "$LIB_DIR/lockfile" ]]; then
    source "${LIB_DIR}/lockfile/save.sh"
    source "${LIB_DIR}/lockfile/install.sh"
fi

#######################################
# Load config modules (Phase 5)
#######################################
if [[ -d "$LIB_DIR/config" ]]; then
    source "${LIB_DIR}/config/isolated.sh"
    source "${LIB_DIR}/config/export.sh"
    source "${LIB_DIR}/config/status.sh"
fi

#######################################
# Load OAuth modules (Phase 6)
#######################################
if [[ -d "$LIB_DIR/oauth" ]]; then
    source "${LIB_DIR}/oauth/token.sh"
fi

#######################################
# Load router modules (Phase 7)
#######################################
if [[ -d "$LIB_DIR/router" ]]; then
    source "${LIB_DIR}/router/detect.sh"
    source "${LIB_DIR}/router/install.sh"
    source "${LIB_DIR}/router/status.sh"
fi

#######################################
# Load PII proxy modules
#######################################
if [[ -d "$LIB_DIR/pii-proxy" ]]; then
    source "${LIB_DIR}/pii-proxy/detect.sh"
    source "${LIB_DIR}/pii-proxy/install.sh"
    source "${LIB_DIR}/pii-proxy/status.sh"
fi

#######################################
# Load Graphify modules
#######################################
if [[ -d "$LIB_DIR/graphify" ]]; then
    source "${LIB_DIR}/graphify/detect.sh"
    source "${LIB_DIR}/graphify/install.sh"
    source "${LIB_DIR}/graphify/status.sh"
fi

#######################################
# Load LSP modules (Phase 8.1)
#######################################
if [[ -d "$LIB_DIR/lsp" ]]; then
    source "${LIB_DIR}/lsp/install.sh"
    source "${LIB_DIR}/lsp/repair.sh"
    source "${LIB_DIR}/lsp/status.sh"
fi

#######################################
# Load statusline modules (Phase 8.2)
#######################################
if [[ -d "$LIB_DIR/statusline" ]]; then
    source "${LIB_DIR}/statusline/detect.sh"
    source "${LIB_DIR}/statusline/install.sh"
    source "${LIB_DIR}/statusline/status.sh"
fi

#######################################
# Load Oh-My-Posh modules (Phase 8.3)
#######################################
if [[ -d "$LIB_DIR/ohmyposh" ]]; then
    source "${LIB_DIR}/ohmyposh/detect.sh"
    source "${LIB_DIR}/ohmyposh/install.sh"
    source "${LIB_DIR}/ohmyposh/status.sh"
fi

#######################################
# Load Caveman modules (Phase 8.4)
#######################################
if [[ -d "$LIB_DIR/caveman" ]]; then
    source "${LIB_DIR}/caveman/install.sh"
fi

#######################################
# Load Sandbox modules (Phase 9.1)
#######################################
if [[ -d "$LIB_DIR/sandbox" ]]; then
    source "${LIB_DIR}/sandbox/detect.sh"
    source "${LIB_DIR}/sandbox/install.sh"
    source "${LIB_DIR}/sandbox/status.sh"
    source "${LIB_DIR}/sandbox/microvm.sh"
fi

#######################################
# Load Update modules (Phase 9.5)
#######################################
if [[ -d "$LIB_DIR/update" ]]; then
    source "${LIB_DIR}/update/isolated.sh"
    source "${LIB_DIR}/update/cleanup.sh"
    source "${LIB_DIR}/update/update.sh"
fi

#######################################
# Load Launcher modules (Phase 9.6)
#######################################
if [[ -d "$LIB_DIR/launcher" ]]; then
    source "${LIB_DIR}/launcher/launch.sh"
fi

#######################################
# Load Command Handling modules (Phase 14)
#######################################
if [[ -d "$LIB_DIR/command" ]]; then
    source "${LIB_DIR}/command/usage.sh"
    source "${LIB_DIR}/command/parse.sh"
    source "${LIB_DIR}/command/dispatch.sh"
fi

#######################################
# Load Chrome Integration modules
#######################################
if [[ -d "$LIB_DIR/chrome" ]]; then
    source "${LIB_DIR}/chrome/detection.sh"
fi

#######################################
# Main execution (Phase 15: inline from legacy main())
# All business logic functions loaded from modules above
#######################################

# Main execution starts here (previously main() function)

    test_mode=false
    skip_test=false
    show_password=false
    proxy_url=""
    skip_permissions=false  # По умолчанию безопасный режим (БЕЗ --dangerously-skip-permissions)
    no_proxy=false
    use_system=false
    use_isolated_config=false
    use_shared_config=false
    claude_args=()
    USE_ROUTER_FLAG=false
    USE_PII_PROXY_FLAG=false
    USE_MICRO_VM_FLAG=false
    USE_GRAPHIFY_FLAG=false
    USE_CHROME=false  # Chrome integration disabled by default (enable with --chrome)
    NO_ATTRIBUTION_HEADER=false  # Disable x-anthropic-billing-header (also auto-disabled when --router is active)
    posh_insecure=false
    model_value=""  # Model selection (empty = use Claude Code default)

    # Apply persistent settings from config file (before argument parsing so CLI can override)
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        # Match: USE_PII_PROXY=true  USE_PII_PROXY="true"  USE_PII_PROXY='true'  export USE_PII_PROXY=true
        _cfg_pii=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?USE_PII_PROXY[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
            "$CREDENTIALS_FILE" 2>/dev/null || true)
        [[ -n "$_cfg_pii" ]] && USE_PII_PROXY_FLAG=true
        unset _cfg_pii

        # Match: MICRO_VM_ENABLED=true  MICRO_VM_ENABLED="true"  export MICRO_VM_ENABLED=true
        _cfg_microvm=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?MICRO_VM_ENABLED[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
            "$CREDENTIALS_FILE" 2>/dev/null || true)
        [[ -n "$_cfg_microvm" ]] && USE_MICRO_VM_FLAG=true
        unset _cfg_microvm

        # Match: GRAPHIFY_OUTPUT_DIR=/some/path
        _cfg_graphify_out=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?GRAPHIFY_OUTPUT_DIR[[:space:]]*=[[:space:]]*['\"]?[^'\"[:space:]]" \
            "$CREDENTIALS_FILE" 2>/dev/null | head -1 || true)
        if [[ -n "$_cfg_graphify_out" ]]; then
            GRAPHIFY_OUTPUT_DIR=$(echo "$_cfg_graphify_out" | \
                sed 's/.*GRAPHIFY_OUTPUT_DIR[[:space:]]*=[[:space:]]*//' | tr -d "\"'")
            export GRAPHIFY_OUTPUT_DIR
        fi
        unset _cfg_graphify_out

        # Match: GRAPHIFY_EXTRA_ARGS="--no-video"
        _cfg_graphify_args=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?GRAPHIFY_EXTRA_ARGS[[:space:]]*=" \
            "$CREDENTIALS_FILE" 2>/dev/null | head -1 || true)
        if [[ -n "$_cfg_graphify_args" ]]; then
            GRAPHIFY_EXTRA_ARGS=$(echo "$_cfg_graphify_args" | \
                sed 's/.*GRAPHIFY_EXTRA_ARGS[[:space:]]*=[[:space:]]*//' | tr -d "\"'")
            export GRAPHIFY_EXTRA_ARGS
        fi
        unset _cfg_graphify_args

        # Match: NO_ATTRIBUTION_HEADER=true  NO_ATTRIBUTION_HEADER="true"  export NO_ATTRIBUTION_HEADER=true
        _cfg_no_attr=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?NO_ATTRIBUTION_HEADER[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
            "$CREDENTIALS_FILE" 2>/dev/null || true)
        [[ -n "$_cfg_no_attr" ]] && NO_ATTRIBUTION_HEADER=true
        unset _cfg_no_attr

        # Match: USE_CHROME=true  USE_CHROME="true"  export USE_CHROME=true
        _cfg_chrome=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?USE_CHROME[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
            "$CREDENTIALS_FILE" 2>/dev/null || true)
        [[ -n "$_cfg_chrome" ]] && USE_CHROME=true
        unset _cfg_chrome

        # Match: CLAUDE_CODE_SKIP_PERMISSIONS=true  CLAUDE_CODE_SKIP_PERMISSIONS="true"  export CLAUDE_CODE_SKIP_PERMISSIONS=true
        _cfg_skip_perm=$(grep -E \
            "^[[:space:]]*(export[[:space:]]+)?CLAUDE_CODE_SKIP_PERMISSIONS[[:space:]]*=[[:space:]]*[\"']?true[\"']?" \
            "$CREDENTIALS_FILE" 2>/dev/null || true)
        [[ -n "$_cfg_skip_perm" ]] && skip_permissions=true
        unset _cfg_skip_perm
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--proxy)
                if [[ -z "${2:-}" ]]; then
                    print_error "--proxy requires a URL argument"
                    echo "Usage: iclaude --proxy http://user:pass@host:port"
                    exit 1
                fi
                proxy_url="$2"
                shift 2
                ;;
            --proxy-ca)
                if [[ -z "${2:-}" ]]; then
                    print_error "--proxy-ca requires a certificate file path"
                    echo "Usage: iclaude --proxy-ca /path/to/proxy-cert.pem"
                    exit 1
                fi
                if [[ ! -f "$2" ]]; then
                    print_error "Certificate file not found: $2"
                    exit 1
                fi
                export PROXY_CA="$2"
                export PROXY_INSECURE=false
                shift 2
                ;;
            --proxy-insecure)
                export PROXY_INSECURE=true
                unset PROXY_CA
                shift
                ;;
            --insecure)
                posh_insecure=true
                shift
                ;;
            -t|--test)
                test_mode=true
                shift
                ;;
            -c|--clear)
                clear_credentials
                exit 0
                ;;
            --restore-git-proxy)
                restore_git_proxy
                exit 0
                ;;
            --no-proxy)
                no_proxy=true
                shift
                ;;
            --install)
                install_script
                exit $?
                ;;
            --uninstall)
                uninstall_script
                exit $?
                ;;
            --create-symlink)
                create_symlink_only
                exit $?
                ;;
            --uninstall-symlink)
                uninstall_symlink_only
                exit $?
                ;;
            --update)
                update_claude_code "$use_system"
                exit $?
                ;;
            --check-update)
                check_update "$use_system"
                exit $?
                ;;
            --isolated-install)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --isolated-install"
                    echo ""
                    echo "The --system flag skips isolated environment, but --isolated-install"
                    echo "is specifically for installing isolated environment."
                    exit 1
                fi
                install_isolated_nvm
                install_isolated_nodejs
                install_isolated_claude
                exit $?
                ;;
            --install-from-lockfile)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-from-lockfile"
                    echo ""
                    echo "The --system flag skips isolated environment, but --install-from-lockfile"
                    echo "is specifically for installing isolated environment from lockfile."
                    exit 1
                fi
                install_from_lockfile
                exit $?
                ;;
            --cleanup-isolated)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --cleanup-isolated"
                    echo ""
                    echo "The --system flag skips isolated environment, but --cleanup-isolated"
                    echo "is specifically for cleaning isolated environment."
                    exit 1
                fi
                cleanup_isolated_nvm
                exit $?
                ;;
            --repair-isolated)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --repair-isolated"
                    echo ""
                    echo "The --system flag skips isolated environment, but --repair-isolated"
                    echo "is specifically for repairing isolated environment."
                    exit 1
                fi
                repair_isolated_environment
                exit $?
                ;;
            --repair-plugins)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --repair-plugins"
                    echo ""
                    echo "The --system flag skips isolated environment, but --repair-plugins"
                    echo "is specifically for repairing plugin paths in isolated environment."
                    exit 1
                fi
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "  Repairing Plugin Paths"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                repair_plugin_paths
                echo ""
                exit $?
                ;;
            --check-isolated)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --check-isolated"
                    echo ""
                    echo "The --system flag skips isolated environment, but --check-isolated"
                    echo "is specifically for checking isolated environment status."
                    exit 1
                fi
                check_isolated_status
                exit 0
                ;;
            --isolated-update)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --isolated-update"
                    echo ""
                    echo "The --system flag skips isolated environment, but --isolated-update"
                    echo "is specifically for updating Claude Code in isolated environment."
                    exit 1
                fi
                update_isolated_claude
                exit $?
                ;;
            --install-router)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-router"
                    echo ""
                    echo "Router is only available in isolated environment"
                    exit 1
                fi
                install_isolated_router
                exit $?
                ;;
            --check-router)
                check_router_status
                exit 0
                ;;
            --install-lsp)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-lsp"
                    echo ""
                    echo "LSP servers are only available in isolated environment"
                    exit 1
                fi
                # Collect all following non-flag arguments as LSP languages
                shift
                lsp_languages=()
                while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                    lsp_languages+=("$1")
                    shift
                done
                install_isolated_lsp_servers "${lsp_languages[@]}"
                exit $?
                ;;
            --check-lsp)
                check_lsp_status
                exit 0
                ;;
            --install-statusline)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-statusline"
                    echo ""
                    echo "Status line is only available in isolated environment"
                    exit 1
                fi
                install_statusline_script
                exit $?
                ;;
            --check-statusline)
                check_statusline_status
                exit 0
                ;;
            --regenerate-statusline)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --regenerate-statusline"
                    echo ""
                    echo "Status line is only available in isolated environment"
                    exit 1
                fi
                install_statusline_script
                exit $?
                ;;
            --install-posh|--install-ohmyposh)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-posh"
                    echo ""
                    echo "Oh My Posh is only available in isolated environment"
                    exit 1
                fi
                install_isolated_ohmyposh ${posh_insecure:+--insecure}
                exit $?
                ;;
            --check-posh|--check-ohmyposh)
                check_ohmyposh_status
                exit 0
                ;;
            --router)
                USE_ROUTER_FLAG=true
                shift
                ;;
            --graphify)
                USE_GRAPHIFY_FLAG=true
                shift
                ;;
            --install-graphify)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-graphify"
                    echo ""
                    echo "Graphify is only available in isolated environment"
                    exit 1
                fi
                _gfy_install_force=""
                [[ "${2:-}" == "--force" ]] && { _gfy_install_force="--force"; shift; }
                [[ -f "$CREDENTIALS_FILE" ]] && source "$CREDENTIALS_FILE"
                install_graphify "$_gfy_install_force"
                exit $?
                ;;
            --check-graphify)
                check_graphify_status
                exit 0
                ;;
            --pii-proxy)
                USE_PII_PROXY_FLAG=true
                shift
                ;;
            --install-pii-proxy)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-pii-proxy"
                    echo ""
                    echo "PII proxy is only available in isolated environment"
                    exit 1
                fi
                _pii_install_force=""
                [[ "${2:-}" == "--force" ]] && { _pii_install_force="--force"; shift; }
                install_isolated_pii_proxy "$_pii_install_force"
                exit $?
                ;;
            --check-pii-proxy)
                check_pii_proxy_status
                exit 0
                ;;
            --install-microvm)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-microvm"
                    echo ""
                    echo "microVM is only available in isolated environment"
                    exit 1
                fi
                # Load saved proxy settings from .claude_config (sets PROXY_URL/PROXY_CA/PROXY_INSECURE)
                [[ -f "$CREDENTIALS_FILE" ]] && source "$CREDENTIALS_FILE"
                install_microvm
                exit $?
                ;;
            --check-microvm)
                check_microvm_status
                exit 0
                ;;
            --caveman-install)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --caveman-install"
                    echo ""
                    echo "caveman is only available in isolated environment"
                    exit 1
                fi
                install_caveman
                exit $?
                ;;
            --caveman-remove)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --caveman-remove"
                    exit 1
                fi
                remove_caveman
                exit $?
                ;;
            --check-caveman)
                check_caveman
                exit 0
                ;;
            --sandbox-microvm)
                USE_MICRO_VM_FLAG=true
                shift
                ;;
            --no-attribution-header)
                NO_ATTRIBUTION_HEADER=true
                shift
                ;;
            --chrome)
                USE_CHROME=true
                shift
                ;;
            --no-chrome)
                USE_CHROME=false
                shift
                ;;
            --model)
                if [[ -z "${2:-}" ]]; then
                    print_error "--model requires a model name argument"
                    echo "Usage: iclaude --model claude-opus-4-6"
                    echo "Available models: claude-opus-4-6, claude-sonnet-4-6, claude-haiku-3-5"
                    exit 1
                fi
                model_value="$2"
                shift 2
                ;;
            --no-test)
                skip_test=true
                shift
                ;;
            --show-password)
                show_password=true
                shift
                ;;
            --no-save)
                skip_permissions=true  # Включаем --dangerously-skip-permissions (небезопасный режим)
                shift
                ;;
            --save)
                # Backward compatibility: --save now does nothing (safe mode is default)
                print_warning "--save is deprecated (safe mode is now default). Use --no-save for unsafe mode."
                shift
                ;;
            --system)
                use_system=true
                shift
                ;;
            --isolated-config)
                use_isolated_config=true
                shift
                ;;
            --shared-config)
                use_shared_config=true
                shift
                ;;
            --check-config)
                check_config_status
                exit 0
                ;;
            --refresh-token)
                # Setup isolated environment if needed for refresh
                if [[ "$use_system" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
                    setup_isolated_nvm
                fi
                refresh_oauth_token "$use_system"
                exit $?
                ;;
            --export-config)
                export_config "$2"
                exit $?
                ;;
            --import-config)
                import_config "$2"
                exit $?
                ;;
            --)
                shift
                claude_args=("$@")
                break
                ;;
            *)
                claude_args+=("$1")
                shift
                ;;
        esac
    done

    # Combined mode: PII proxy + CCR router — show informational message
    # Both flags can now be combined; chain: claude → PII proxy(:9000) → CCR(:3456) → providers
    # No mutual exclusion — combined mode is handled in launch_claude() via start_ccr_server()
    if [[ "$USE_PII_PROXY_FLAG" == "true" ]] && [[ "$USE_ROUTER_FLAG" == "true" ]]; then
        print_info "Combined mode detected: PII proxy + CCR router chain will be activated"
        print_info "Traffic chain: claude → PII proxy(:${PII_PROXY_PORT:-9000}) → CCR(:${CCR_PORT:-3456}) → providers"
        echo ""
    fi

    # Rebuild graphify knowledge graph if --graphify flag is set
    if [[ "$USE_GRAPHIFY_FLAG" == true ]]; then
        _graphify_rebuild_graph || print_warning "Graph rebuild failed — continuing without updated graph"
    fi

    # Configure isolated config if needed
    # Priority:
    # 1. If --isolated-config is set, use isolated config
    # 2. If --shared-config is set, use shared config (default)
    # 3. If isolated environment exists and is default, use isolated config (unless --shared-config)
    if [[ "$use_isolated_config" == true ]]; then
        setup_isolated_config
        disable_auto_updates "$CLAUDE_CONFIG_DIR"
        print_info "Using isolated configuration: $CLAUDE_CONFIG_DIR"
        echo ""
    elif [[ "$use_shared_config" == false ]] && [[ "$use_system" == false ]] && [[ -d "$ISOLATED_NVM_DIR" ]] && [[ "$USE_ISOLATED_BY_DEFAULT" == true ]]; then
        # Auto-enable isolated config for isolated installations (unless --shared-config)
        setup_isolated_config
        disable_auto_updates "$CLAUDE_CONFIG_DIR"
        print_info "Using isolated configuration (automatic): $CLAUDE_CONFIG_DIR"
        echo ""
    else
        # Use shared config (default)
        if [[ "$use_shared_config" == true ]]; then
            print_info "Using shared configuration: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
            echo ""
        fi
        # Disable auto-updates for shared config too
        disable_auto_updates
    fi

    echo ""
    echo "═══════════════════════════════════════"
    echo "  Claude Code Proxy Initializer v2.0"
    echo "═══════════════════════════════════════"
    echo ""

    # Check if --no-proxy flag is set
    if [[ "$no_proxy" == true ]]; then
        print_info "Running without proxy"
        echo ""

        # Ensure proxy variables are unset
        unset HTTPS_PROXY
        unset HTTP_PROXY
        unset NO_PROXY

        # Restore git proxy settings if backup exists
        if [[ -f "$GIT_BACKUP_FILE" ]]; then
            restore_git_proxy
        fi

        # Save model selection to config if specified
        if [[ -n "$model_value" ]]; then
            save_model_to_config "$model_value"
        fi

        # Check OAuth token expiration
        check_token_expiration

        # Check if lockfile has changed since last environment update
        check_lockfile_changes

        # Add --dangerously-skip-permissions only when --no-save is used
        if [[ "$skip_permissions" == true ]]; then
            claude_args+=("--dangerously-skip-permissions")
        fi

        # Add --chrome flag if explicitly enabled via --chrome and Chrome extension available
        if [[ "$USE_CHROME" == true ]]; then
            if warn_chrome_integration 2>/dev/null; then
                claude_args+=("--chrome")
            else
                print_info "Chrome integration disabled (extension not detected)"
                print_info "Launching without browser automation..."
                echo ""
            fi
        fi

        # Add --model flag if specified
        if [[ -n "$model_value" ]]; then
            claude_args+=("--model" "$model_value")
            export CLAUDE_CODE_MODEL="$model_value"
            print_info "Using model: $model_value"
        fi

        # Launch Claude Code without proxy
        launch_claude "$use_system" "${claude_args[@]}"
        exit 0
    fi

    # Get proxy URL (from argument, saved file, or prompt)
    proxy_no_proxy=""
    if [[ -z "$proxy_url" ]]; then
        proxy_credentials=$(prompt_proxy_url)
        # Parse pipe-separated output: URL|NO_PROXY
        proxy_url=$(echo "$proxy_credentials" | cut -d'|' -f1)
        proxy_no_proxy=$(echo "$proxy_credentials" | cut -d'|' -f2)
    else
        # Validate provided URL (allow domains for now)
        validation_result=0
        validate_proxy_url "$proxy_url" || validation_result=$?

        if [[ $validation_result -eq 1 ]]; then
            print_error "Invalid proxy URL: $proxy_url"
            echo "Expected format: protocol://[user:pass@]IP:port"
            exit 1
        elif [[ $validation_result -eq 2 ]]; then
            print_warning "Proxy URL contains domain name instead of IP address"
            print_info "Consider using IP address for better reliability"
        fi

        # Use default NO_PROXY if not loaded from saved credentials
        proxy_no_proxy="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    # Configure proxy
    print_info "Configuring proxy..."
    configure_proxy_from_url "$proxy_url" "$proxy_no_proxy"

    # Save model selection to config if specified
    if [[ -n "$model_value" ]]; then
        save_model_to_config "$model_value"
    fi

    # Display configuration
    display_proxy_info "$show_password"

    # Test proxy (unless skipped)
    proxy_test_passed=true
    if [[ "$skip_test" == false ]]; then
        if ! test_proxy; then
            proxy_test_passed=false
        fi
        echo ""
    fi

    # If test mode, exit here
    if [[ "$test_mode" == true ]]; then
        if [[ "$proxy_test_passed" == true ]]; then
            print_success "Test complete"
        else
            print_warning "Test completed with warnings"
        fi
        exit 0
    fi

    # If proxy test failed, disable proxy and launch without it
    if [[ "$proxy_test_passed" == false ]]; then
        echo ""
        print_warning "Proxy unavailable - launching without proxy"
        echo ""

        # Unset proxy environment variables
        unset HTTPS_PROXY
        unset HTTP_PROXY
        unset NO_PROXY

        # Restore git proxy settings if backup exists
        if [[ -f "$GIT_BACKUP_FILE" ]]; then
            restore_git_proxy
        fi

        no_proxy=true
    fi

    # Check OAuth token expiration
    check_token_expiration

    # Check if lockfile has changed since last environment update
    check_lockfile_changes

    # Add --dangerously-skip-permissions only when --no-save is used
    if [[ "$skip_permissions" == true ]]; then
        claude_args+=("--dangerously-skip-permissions")
    fi

    # Add --chrome flag if explicitly enabled via --chrome and Chrome extension available
    if [[ "$USE_CHROME" == true ]]; then
        # Check if Chrome extension is installed
        if warn_chrome_integration 2>/dev/null; then
            claude_args+=("--chrome")
        else
            # Extension not available - automatically disable Chrome integration
            print_info "Chrome integration disabled (extension not detected)"
            print_info "Launching without browser automation..."
            echo ""
        fi
    fi

    # Add --model flag if specified
    if [[ -n "$model_value" ]]; then
        claude_args+=("--model" "$model_value")
        export CLAUDE_CODE_MODEL="$model_value"
        print_info "Using model: $model_value"
    fi

    # Launch Claude Code
    launch_claude "$use_system" "${claude_args[@]}"
