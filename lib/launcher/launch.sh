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

    # Unset CHROME_DESKTOP so Claude Code correctly identifies Chrome as the browser.
    # VS Code sets CHROME_DESKTOP=code.desktop in its terminal environment, which
    # confuses the Claude-in-Chrome extension into opening Yandex or wrong browser.
    unset CHROME_DESKTOP

    # Auto-repair stale settings.json paths (silent if no change needed)
    repair_settings_paths

    # Check OAuth token expiration before launching
    check_oauth_token "$skip_isolated"

    # NEW: Check if router should be used (only if --router flag is set)
    local use_router=false
    if [[ "$USE_ROUTER_FLAG" == "true" ]] && detect_router "$skip_isolated"; then
        use_router=true
    fi

    # PII proxy: intercept and mask PII/secrets in Anthropic API traffic
    local use_pii_proxy=false
    if [[ "${USE_PII_PROXY_FLAG:-false}" == "true" ]]; then
        if [[ "$skip_isolated" == "true" ]]; then
            # System mode uses host Node.js; PII proxy requires isolated venv — abort (fail-secure)
            print_error "PII proxy is not supported in --system mode (isolated environment only)"
            print_info "Remove --pii-proxy or omit --system to use PII masking"
            exit 1
        elif type detect_pii_proxy &>/dev/null && detect_pii_proxy "$skip_isolated"; then
            use_pii_proxy=true
            # PII proxy and CCR router are mutually exclusive (CCR spawns its own claude child
            # and overwrites ANTHROPIC_BASE_URL, bypassing the proxy)
            if [[ "$use_router" == "true" ]]; then
                print_warning "PII proxy active: CCR router disabled for this session"
                use_router=false
            fi
        else
            print_warning "PII proxy not installed (run: ./iclaude.sh --install-pii-proxy)"
        fi
    fi

    echo ""
    if [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code via Router..."
    elif [[ "$use_pii_proxy" == "true" ]]; then
        print_info "Launching Claude Code with PII masking..."
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
            if [[ "$use_pii_proxy" == "true" ]]; then
                if ! start_pii_proxy_server "$skip_isolated"; then
                    print_error "PII proxy failed to start — aborting for safety"
                    print_info "To launch without masking, remove USE_PII_PROXY from .claude_config"
                    exit 1
                fi
                trap 'stop_pii_proxy_server' EXIT INT TERM
                npx @anthropic-ai/claude-code "$@"
                exit $?
            fi
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

    # Launch Claude Code
    # When PII proxy is active: cannot use exec — EXIT trap would fire before the
    # new process starts, killing the proxy before claude makes its first API call.
    # BUG-10: removed eval (double-quoted variables handle spaces in paths correctly)
    if [[ "$use_pii_proxy" == "true" ]]; then
        if ! start_pii_proxy_server "$skip_isolated"; then
            print_error "PII proxy failed to start — aborting for safety"
            print_info "To launch without masking, remove USE_PII_PROXY from .claude_config"
            exit 1
        fi
        trap 'stop_pii_proxy_server' EXIT INT TERM
        "$claude_cmd" "$@"
        exit $?
    fi

    # Standard exec path: replace shell process (no cleanup needed)
    if [[ "$claude_cmd" == *" "* ]]; then
        eval exec "$claude_cmd" '"$@"'
    else
        exec "$claude_cmd" "$@"
    fi
}

#######################################
# Start PII proxy server and redirect API traffic through it
# Arguments:
#   $1 - skip_isolated: "true" to skip isolated environment
# Returns:
#   0 on success, 1 on failure
# Globals set:
#   PII_PROXY_ACTIVE_PORT - actual TCP port the server bound to
#######################################
start_pii_proxy_server() {
    local skip_isolated="${1:-false}"

    local python_bin
    python_bin=$(get_pii_proxy_python "$skip_isolated")
    if [[ -z "$python_bin" ]]; then
        print_warning "PII proxy: venv not found - run --install-pii-proxy"
        return 1
    fi

    if [[ ! -f "$PII_PROXY_SERVER_SCRIPT" ]]; then
        print_warning "PII proxy: server script not found - run --install-pii-proxy"
        return 1
    fi

    # BUG-4R4-1: health check helper — port passed as argv (not bash-interpolated into
    # Python string), preventing injection if port_file content is unexpected
    _pii_proxy_http_health() {
        local port="$1"
        # Validate port is a pure integer before use
        [[ "$port" =~ ^[0-9]+$ ]] || return 1
        "$python_bin" -c '
import urllib.request, sys
port = sys.argv[1]
try:
    urllib.request.urlopen("http://127.0.0.1:" + port + "/api/health", timeout=2)
    sys.exit(0)
except Exception:
    sys.exit(1)
' -- "$port" 2>/dev/null
    }

    # BUG-4R4-7: Check for existing running instance before starting a new one
    # (prevents duplicate proxies on concurrent launches / stale PID file)
    local port_file="$PII_PROXY_LOG_DIR/server.port"
    if [[ -f "$PII_PROXY_PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$PII_PROXY_PID_FILE" 2>/dev/null)
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            # Process alive — try to reuse if healthy
            if [[ -f "$port_file" ]]; then
                local existing_port
                existing_port=$(cat "$port_file" 2>/dev/null)
                if _pii_proxy_http_health "$existing_port"; then
                    PII_PROXY_ACTIVE_PORT="$existing_port"
                    export ANTHROPIC_BASE_URL="http://127.0.0.1:$PII_PROXY_ACTIVE_PORT"
                    # Reuse-then-kill fix: mark proxy as NOT owned by this session so
                    # stop_pii_proxy_server will NOT kill it when this session exits
                    PII_PROXY_SESSION_OWNED=false
                    print_info "PII proxy: reusing existing instance on :$PII_PROXY_ACTIVE_PORT"
                    return 0
                fi
            fi
            # Unhealthy existing instance — kill it, start fresh
            kill "$existing_pid" 2>/dev/null || true
        fi
        rm -f "$PII_PROXY_PID_FILE"
    fi

    # Preserve current ANTHROPIC_BASE_URL as upstream URL
    # This enables future CCR chaining: claude → PII proxy → CCR → Anthropic
    local upstream_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"

    # Remove stale port file from any previous session
    rm -f "$port_file"
    # BUG-4R4-9: chmod 700 — restrict log dir to current user only
    mkdir -p "$PII_PROXY_LOG_DIR"
    chmod 700 "$PII_PROXY_LOG_DIR"

    # Start server in background; redirect stdout/stderr to log file
    ANTHROPIC_UPSTREAM_URL="$upstream_url" \
        "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
        --port "$PII_PROXY_PORT" \
        --log-dir "$PII_PROXY_LOG_DIR" \
        >>"$PII_PROXY_LOG_DIR/server.log" 2>&1 &

    local proxy_pid=$!
    echo "$proxy_pid" > "$PII_PROXY_PID_FILE"

    # Poll for port file, then verify HTTP readiness via /api/health (max 15 seconds)
    # B3: TCP check via bash /dev/tcp filters out ticks before socket is bound,
    # avoiding python subprocess spawns before the server is even listening.
    # HTTP health check is still required (TCP succeeds at bind; serve_forever may lag).
    local max_ticks=30
    local ticks=0
    local health_ok=false
    PII_PROXY_ACTIVE_PORT=""

    while [[ $ticks -lt $max_ticks ]]; do
        # Detect early process exit to fail fast instead of waiting 15s
        if ! kill -0 "$proxy_pid" 2>/dev/null; then
            print_warning "PII proxy: server process exited unexpectedly"
            break
        fi
        if [[ -f "$port_file" ]]; then
            PII_PROXY_ACTIVE_PORT=$(cat "$port_file" 2>/dev/null)
            if [[ -n "$PII_PROXY_ACTIVE_PORT" ]] && \
               [[ "$PII_PROXY_ACTIVE_PORT" =~ ^[0-9]+$ ]]; then
                # B3: TCP check first (bash built-in, no subprocess)
                # then HTTP health check only when TCP is up
                if (: >/dev/tcp/127.0.0.1/"$PII_PROXY_ACTIVE_PORT") 2>/dev/null; then
                    if _pii_proxy_http_health "$PII_PROXY_ACTIVE_PORT"; then
                        health_ok=true
                        break
                    fi
                fi
            fi
        fi
        sleep 0.5
        ticks=$((ticks + 1))
    done

    if [[ "$health_ok" != "true" ]]; then
        print_warning "PII proxy: server did not become ready within 15s"
        kill "$proxy_pid" 2>/dev/null
        rm -f "$PII_PROXY_PID_FILE"
        return 1
    fi

    # Redirect all claude API traffic through PII proxy
    export ANTHROPIC_BASE_URL="http://127.0.0.1:$PII_PROXY_ACTIVE_PORT"
    PII_PROXY_SESSION_OWNED=true  # this session started the proxy; stop_pii_proxy_server may kill it
    print_info "PII proxy: active on :$PII_PROXY_ACTIVE_PORT → $upstream_url"
    return 0
}

#######################################
# Stop PII proxy server (trap cleanup on EXIT/INT/TERM)
#######################################
stop_pii_proxy_server() {
    # Reuse-then-kill fix: only kill the proxy if THIS session started it.
    # When reusing a proxy from another session, PII_PROXY_SESSION_OWNED=false
    # and we leave the shared proxy running so other sessions are not interrupted.
    if [[ "${PII_PROXY_SESSION_OWNED:-true}" != "true" ]]; then
        return 0
    fi
    if [[ -f "${PII_PROXY_PID_FILE:-}" ]]; then
        local pid
        pid=$(cat "$PII_PROXY_PID_FILE" 2>/dev/null)
        rm -f "$PII_PROXY_PID_FILE"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            # Wait for clean shutdown (up to 1s), then force-kill
            local waited=0
            while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 10 ]]; do
                sleep 0.1
                waited=$((waited + 1))
            done
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
}
