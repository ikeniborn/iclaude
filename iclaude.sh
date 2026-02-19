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
# Load Sandbox modules (Phase 9.1)
#######################################
if [[ -d "$LIB_DIR/sandbox" ]]; then
    source "${LIB_DIR}/sandbox/detect.sh"
    source "${LIB_DIR}/sandbox/install.sh"
    source "${LIB_DIR}/sandbox/status.sh"
fi

#######################################
# Load GH CLI modules (Phase 9.2)
#######################################
if [[ -d "$LIB_DIR/gh" ]]; then
    source "${LIB_DIR}/gh/install.sh"
    source "${LIB_DIR}/gh/status.sh"
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
# Load Context Management modules (Phase 10)
#######################################
if [[ -d "$LIB_DIR/context" ]]; then
    source "${LIB_DIR}/context/init.sh"
    source "${LIB_DIR}/context/operations.sh"
    source "${LIB_DIR}/context/memory.sh"
fi

#######################################
# Load Loop Mode modules (Phase 11-13)
#######################################
if [[ -d "$LIB_DIR/loop" ]]; then
    source "${LIB_DIR}/loop/validator.sh"
    source "${LIB_DIR}/loop/parser.sh"
    source "${LIB_DIR}/loop/state.sh"
    source "${LIB_DIR}/loop/retry.sh"
    source "${LIB_DIR}/loop/git.sh"
    source "${LIB_DIR}/loop/executor.sh"
    source "${LIB_DIR}/loop/worktree.sh"
    source "${LIB_DIR}/loop/parallel.sh"
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
# Load Docs modules (Phase 16: Sphinx integration)
#######################################
if [[ -d "$LIB_DIR/docs" ]]; then
    source "${LIB_DIR}/docs/bash-parser.sh"
    source "${LIB_DIR}/docs/install.sh"
    source "${LIB_DIR}/docs/build.sh"
    source "${LIB_DIR}/docs/serve.sh"
    source "${LIB_DIR}/docs/status.sh"
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
    USE_CHROME=true  # Chrome integration enabled by default
    USE_LOOP_MODE=false
    posh_insecure=false
    LOOP_TASK_FILE=""
    LOOP_MAX_PARALLEL=5
    LOOP_MODE_TYPE="sequential"  # sequential | parallel

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
            --install-gh)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --install-gh"
                    echo ""
                    echo "gh CLI is only available in isolated environment"
                    exit 1
                fi
                install_isolated_gh
                exit $?
                ;;
            --check-gh)
                check_gh_status
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
            --context-export)
                context_cmd_export "${2:-$(pwd)}"
                exit $?
                ;;
            --context-import)
                if [[ -z "${2:-}" ]]; then
                    print_error "--context-import requires archive file"
                    echo "Usage: ./iclaude.sh --context-import ARCHIVE [PATH]"
                    exit 1
                fi
                context_cmd_import "$2" "${3:-$(pwd)}"
                exit $?
                ;;
            --context-sync)
                context_cmd_sync "${2:-pull}" "${3:-$(pwd)}"
                exit $?
                ;;
            --context-clean)
                context_cmd_clean "${2:-30}"
                exit $?
                ;;
            --context-backup)
                context_cmd_backup "${2:-manual}"
                exit $?
                ;;
            --context-status)
                context_cmd_status "${2:-$(pwd)}"
                exit $?
                ;;
            --context-memory-init)
                context_memory_init "${2:-$(pwd)}"
                exit $?
                ;;
            --context-memory-validate)
                context_memory_validate "${2:-$(pwd)}"
                exit $?
                ;;
            --context-memory-organize)
                context_memory_organize "${2:-$(pwd)}"
                exit $?
                ;;
            --context-memory-add)
                if [[ -z "${2:-}" ]]; then
                    print_error "--context-memory-add requires entry text"
                    echo "Usage: ./iclaude.sh --context-memory-add \"Entry text\" [PATH]"
                    exit 1
                fi
                context_memory_add "$2" "${3:-$(pwd)}"
                exit $?
                ;;
            --context-memory-status)
                context_memory_status "${2:-$(pwd)}"
                exit $?
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
            --sandbox-install)
                if [[ "$use_system" == true ]]; then
                    print_error "--system cannot be used with --sandbox-install"
                    echo ""
                    echo "Sandboxing is only available in isolated environment"
                    exit 1
                fi
                install_sandbox_dependencies
                # Update lockfile after installation
                save_isolated_lockfile
                exit $?
                ;;
            --sandbox-check|--check-sandbox)
                check_sandbox_status
                exit 0
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
            --no-chrome)
                USE_CHROME=false
                shift
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
            --loop)
                if [[ -z "${2:-}" ]]; then
                    print_error "--loop requires a Markdown file argument"
                    echo "Usage: ./iclaude.sh --loop task.md"
                    exit 1
                fi
                USE_LOOP_MODE=true
                LOOP_TASK_FILE="$2"
                LOOP_MODE_TYPE="sequential"
                shift 2
                ;;
            --loop-parallel)
                if [[ -z "${2:-}" ]]; then
                    print_error "--loop-parallel requires a Markdown file argument"
                    echo "Usage: ./iclaude.sh --loop-parallel task.md"
                    exit 1
                fi
                USE_LOOP_MODE=true
                LOOP_TASK_FILE="$2"
                LOOP_MODE_TYPE="parallel"
                shift 2
                ;;
            --max-parallel)
                if [[ -z "${2:-}" ]]; then
                    print_error "--max-parallel requires a number argument"
                    echo "Usage: ./iclaude.sh --max-parallel 5"
                    exit 1
                fi
                LOOP_MAX_PARALLEL="$2"
                shift 2
                ;;
            --isolated-config)
                use_isolated_config=true
                shift
                ;;
            --shared-config)
                use_shared_config=true
                shift
                ;;
            --install-docs)
                install_sphinx_docs
                exit $?
                ;;
            --build-docs)
                build_sphinx_docs "${2:-}"
                exit $?
                ;;
            --serve-docs)
                serve_sphinx_docs "${2:-8000}"
                exit $?
                ;;
            --check-docs)
                check_docs_status
                exit 0
                ;;
            --check-config)
                check_config_status
                exit 0
                ;;
            --list-sessions)
                list_sessions_cmd
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

        # Check OAuth token expiration
        check_token_expiration

        # Add --dangerously-skip-permissions only when --no-save is used
        if [[ "$skip_permissions" == true ]]; then
            claude_args+=("--dangerously-skip-permissions")
        fi

        # Add --chrome flag if enabled (default)
        if [[ "$USE_CHROME" == true ]]; then
            claude_args+=("--chrome")
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
        local validation_result
        validate_proxy_url "$proxy_url"
        validation_result=$?

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

    # If proxy test failed, ask user if they want to continue
    if [[ "$proxy_test_passed" == false ]]; then
        echo ""
        print_warning "Proxy test failed - Claude Code may not work properly"
        echo ""
        read -p "Continue anyway? (y/N): " continue_anyway

        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo ""
            print_info "Launch cancelled"
            echo ""
            echo "You can try:"
            echo "  1. Fix proxy configuration and try again"
            echo "  2. Run without proxy: iclaude --no-proxy"
            echo "  3. Skip proxy test: iclaude --no-test"
            echo "  4. Check proxy credentials: iclaude --clear"
            exit 0
        fi
        echo ""
    fi

    # Check OAuth token expiration
    check_token_expiration

    # Add --dangerously-skip-permissions only when --no-save is used
    if [[ "$skip_permissions" == true ]]; then
        claude_args+=("--dangerously-skip-permissions")
    fi

    # Add --chrome flag if enabled (default) and Chrome extension available
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

    # Check if loop mode is enabled
    if [[ "$USE_LOOP_MODE" == true ]]; then
        if [[ ! -f "$LOOP_TASK_FILE" ]]; then
            print_error "Task file not found: $LOOP_TASK_FILE"
            echo ""
            echo "Tip: If the file path contains spaces, enclose it in quotes:"
            echo "  ./iclaude.sh --loop \"/path/with spaces/task.md\""
            exit 1
        fi

        case "$LOOP_MODE_TYPE" in
            sequential)
                execute_sequential_mode "$LOOP_TASK_FILE"
                exit $?
                ;;
            parallel)
                execute_parallel_mode "$LOOP_TASK_FILE" "$LOOP_MAX_PARALLEL"
                exit $?
                ;;
            *)
                print_error "Unknown loop mode: $LOOP_MODE_TYPE"
                exit 1
                ;;
        esac
    fi

    # Launch Claude Code
    launch_claude "$use_system" "${claude_args[@]}"
