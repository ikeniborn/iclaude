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
            # Combined mode: PII proxy + CCR router can now work together.
            # Chain: claude → PII proxy(:9000) → CCR(:3456) → providers
            # When both are active, CCR is started as a background daemon (not via exec ccr code).
            # ANTHROPIC_BASE_URL is set to http://CCR_HOST:CCR_PORT before starting PII proxy,
            # so all API traffic is masked by PII proxy before reaching CCR.
        else
            print_warning "PII proxy not installed (run: ./iclaude.sh --install-pii-proxy)"
        fi
    fi

    echo ""
    if [[ "$use_pii_proxy" == "true" ]] && [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code with PII masking → CCR router chain..."
    elif [[ "$use_router" == "true" ]]; then
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

        # CCR v2.0.0 requires Node.js v20+ (File global, unavailable in Node v18).
        # Prepend node v20+ to PATH so ccr binary's #!/usr/bin/env node resolves correctly.
        if [[ -n "${ISOLATED_NVM_DIR:-}" ]]; then
            local ccr_node_bin
            ccr_node_bin=$(find "$ISOLATED_NVM_DIR/versions/node" -maxdepth 1 -type d \
                -name "v2[0-9]*" 2>/dev/null | LC_ALL=C sort | tail -1)
            if [[ -n "$ccr_node_bin" ]] && [[ -d "$ccr_node_bin/bin" ]]; then
                export PATH="$ccr_node_bin/bin:$PATH"
                print_info "CCR: using Node $(basename "$ccr_node_bin") (v20+ required)"
            fi
        fi

        # Show router version
        local router_version=$("$ccr_cmd" --version 2>/dev/null | head -1 || echo "unknown")
        if [[ "$router_version" != "unknown" ]]; then
            print_info "Router version: $router_version"
        fi
        echo ""

        # Signal to statusline that router is active (suppresses RL display)
        export ICLAUDE_ROUTER_ACTIVE=1

        # Combined mode: PII proxy + CCR router
        # Start CCR as background daemon, then PII proxy in front of it.
        # Cannot use 'exec ccr code' here — combined mode requires both processes running.
        if [[ "$use_pii_proxy" == "true" ]]; then
            if ! start_ccr_server "$skip_isolated" "$ccr_cmd"; then
                print_error "CCR router failed to start — aborting"
                exit 1
            fi
            trap 'stop_pii_proxy_server; stop_ccr_server' EXIT INT TERM

            # start_ccr_server() sets ANTHROPIC_BASE_URL=http://CCR:PORT
            # start_pii_proxy_server() reads ANTHROPIC_BASE_URL as upstream_url → chains to CCR
            if ! start_pii_proxy_server "$skip_isolated"; then
                print_error "PII proxy failed to start — aborting for safety"
                stop_ccr_server
                exit 1
            fi

            # fall through to native claude launch below (exec disabled for combined mode)
            # (do NOT return here — need to reach claude binary detection below)
        else
            # Solo router mode: standard exec ccr code path
            exec "$ccr_cmd" code "$@"
        fi
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
                # Solo PII proxy mode: start proxy now (combined mode: proxy already started)
                if [[ "$use_router" != "true" ]]; then
                    if ! start_pii_proxy_server "$skip_isolated"; then
                        print_error "PII proxy failed to start — aborting for safety"
                        print_info "To launch without masking, remove USE_PII_PROXY from .claude_config"
                        exit 1
                    fi
                    trap 'stop_pii_proxy_server' EXIT INT TERM
                fi
                # Combined mode trap already set above
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
        # Combined mode (PII + router): both servers already started above in router block.
        # Solo PII proxy mode: start proxy now.
        if [[ "$use_router" != "true" ]]; then
            if ! start_pii_proxy_server "$skip_isolated"; then
                print_error "PII proxy failed to start — aborting for safety"
                print_info "To launch without masking, remove USE_PII_PROXY from .claude_config"
                exit 1
            fi
            trap 'stop_pii_proxy_server' EXIT INT TERM
        fi
        # In combined mode trap was already set (stop_pii_proxy_server + stop_ccr_server)
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
    # Python string), preventing injection if port_file content is unexpected.
    # NOTE: do NOT use '-- "$port"' here — python3 -c 'code' -- N gives sys.argv=['-c','--','N']
    # so sys.argv[1] == '--' instead of the port. Port is pre-validated to ^[0-9]+$ above.
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
' "$port" 2>/dev/null
    }

    # BUG-4R4-7: Check for existing running instance before starting a new one
    # (prevents duplicate proxies on concurrent launches / stale PID file)
    local port_file="$PII_PROXY_LOG_DIR/server.port"
    # Desired upstream: CCR URL in combined mode, Anthropic API in solo mode.
    # Computed here so the reuse check can compare against it.
    local desired_upstream="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
    if [[ -f "$PII_PROXY_PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$PII_PROXY_PID_FILE" 2>/dev/null)
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            # Process alive — try to reuse if healthy AND upstream matches.
            # In combined mode (desired_upstream=CCR URL) an existing solo-mode proxy
            # has ANTHROPIC_UPSTREAM_URL=api.anthropic.com baked in its process env
            # (immutable after spawn). Reusing it would silently bypass CCR.
            # Kill and restart only when upstream mismatch is detected.
            if [[ -f "$port_file" ]]; then
                local existing_port
                existing_port=$(cat "$port_file" 2>/dev/null)
                if _pii_proxy_http_health "$existing_port"; then
                    if [[ "$desired_upstream" == "https://api.anthropic.com" ]]; then
                        # Solo mode: upstream matches — safe to reuse
                        PII_PROXY_ACTIVE_PORT="$existing_port"
                        export ANTHROPIC_BASE_URL="http://127.0.0.1:$PII_PROXY_ACTIVE_PORT"
                        # Reuse-then-kill fix: mark proxy as NOT owned by this session so
                        # stop_pii_proxy_server will NOT kill it when this session exits
                        PII_PROXY_SESSION_OWNED=false
                        print_info "PII proxy: reusing existing instance on :$PII_PROXY_ACTIVE_PORT"
                        return 0
                    else
                        # Combined mode: existing proxy has wrong upstream — kill and restart
                        print_info "PII proxy: restarting (upstream changed to $desired_upstream)"
                        kill "$existing_pid" 2>/dev/null || true
                    fi
                fi
            fi
            # Unhealthy or upstream-mismatched instance — kill, start fresh
            kill "$existing_pid" 2>/dev/null || true
        fi
        rm -f "$PII_PROXY_PID_FILE"
    fi

    # desired_upstream was computed at the top of this function (before the reuse check).
    # Use it directly — ANTHROPIC_BASE_URL has not changed since then.
    local upstream_url="$desired_upstream"

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
# Start CCR (Claude Code Router) as a background daemon
# Used in combined PII proxy + CCR router mode.
# In this mode CCR is started with 'ccr start' (not 'ccr code') so it runs as a
# persistent HTTP server without spawning a claude child process.
# After CCR is ready, sets ANTHROPIC_BASE_URL to http://CCR_HOST:CCR_PORT so that
# the subsequent start_pii_proxy_server() call will chain: PII proxy → CCR → providers.
# (start_pii_proxy_server reads ANTHROPIC_BASE_URL as upstream_url; after it runs,
# ANTHROPIC_BASE_URL is overwritten to point to the PII proxy port instead.)
# Arguments:
#   $1 - skip_isolated: "true" to skip isolated environment
#   $2 - ccr_cmd: path to ccr binary (optional; detected via get_router_path if omitted)
# Returns:
#   0 on success, 1 on failure
# Globals set:
#   CCR_PID - PID of background CCR daemon
#   CCR_SESSION_OWNED - true (this session started CCR)
#   ANTHROPIC_BASE_URL - http://CCR_HOST:CCR_PORT (overwritten by PII proxy after chaining)
#######################################
start_ccr_server() {
    local skip_isolated="${1:-false}"
    local ccr_cmd="${2:-}"

    # Resolve CCR binary path if not provided
    if [[ -z "$ccr_cmd" ]]; then
        ccr_cmd=$(get_router_path "$skip_isolated")
        if [[ -z "$ccr_cmd" ]]; then
            print_warning "CCR router: binary not found - run --install-router"
            return 1
        fi
    fi

    # Parse CCR host and port from router.json (updates CCR_HOST and CCR_PORT globals)
    get_ccr_port "$skip_isolated" || true  # Retain defaults on failure

    # Check if CCR is already running on the target port
    if (: >/dev/tcp/"$CCR_HOST"/"$CCR_PORT") 2>/dev/null; then
        print_info "CCR router: reusing existing instance on ${CCR_HOST}:${CCR_PORT}"
        CCR_SESSION_OWNED=false
        # Set ANTHROPIC_BASE_URL so start_pii_proxy_server() captures CCR as upstream_url
        export ANTHROPIC_BASE_URL="http://${CCR_HOST}:${CCR_PORT}"
        return 0
    fi

    # Start CCR as background daemon using 'ccr start' (server-only mode, no claude child).
    # Note: PATH must already include node v20+ before this function is called
    # (launch_claude() prepends v20 bin to PATH before invoking start_ccr_server).
    print_info "CCR router: starting daemon on ${CCR_HOST}:${CCR_PORT}..."
    nohup "$ccr_cmd" start >>"${PII_PROXY_LOG_DIR:-/tmp}/ccr-daemon.log" 2>&1 &
    CCR_PID=$!
    CCR_SESSION_OWNED=true
    export CCR_PID CCR_SESSION_OWNED

    # Wait for CCR to be ready (max 10 × 0.5s = 5 seconds) via bash /dev/tcp health check
    local max_ticks=10
    local ticks=0
    local ccr_ready=false

    while [[ $ticks -lt $max_ticks ]]; do
        # Detect early process exit to fail fast
        if ! kill -0 "$CCR_PID" 2>/dev/null; then
            print_warning "CCR router: daemon process exited unexpectedly"
            break
        fi
        if (: >/dev/tcp/"$CCR_HOST"/"$CCR_PORT") 2>/dev/null; then
            ccr_ready=true
            break
        fi
        sleep 0.5
        ticks=$((ticks + 1))
    done

    if [[ "$ccr_ready" != "true" ]]; then
        print_warning "CCR router: daemon did not become ready within 5s"
        kill "$CCR_PID" 2>/dev/null || true
        CCR_PID=""
        CCR_SESSION_OWNED=false
        return 1
    fi

    # Set ANTHROPIC_BASE_URL so start_pii_proxy_server() captures CCR as upstream_url.
    # start_pii_proxy_server() reads ANTHROPIC_BASE_URL (not ANTHROPIC_UPSTREAM_URL) to
    # determine the upstream it forwards masked traffic to.
    # After start_pii_proxy_server() runs, ANTHROPIC_BASE_URL is overwritten to the PII proxy port.
    export ANTHROPIC_BASE_URL="http://${CCR_HOST}:${CCR_PORT}"
    print_info "CCR router: ready on ${CCR_HOST}:${CCR_PORT} (PID $CCR_PID)"
    return 0
}

#######################################
# Stop CCR background daemon (trap cleanup on EXIT/INT/TERM)
# Mirrors stop_pii_proxy_server() pattern.
#######################################
stop_ccr_server() {
    # Only kill CCR if this session started it
    if [[ "${CCR_SESSION_OWNED:-false}" != "true" ]]; then
        return 0
    fi
    if [[ -n "${CCR_PID:-}" ]] && kill -0 "$CCR_PID" 2>/dev/null; then
        kill "$CCR_PID" 2>/dev/null || true
        # Wait for clean shutdown (up to 1s), then force-kill
        local waited=0
        while kill -0 "$CCR_PID" 2>/dev/null && [[ $waited -lt 10 ]]; do
            sleep 0.1
            waited=$((waited + 1))
        done
        kill -9 "$CCR_PID" 2>/dev/null || true
        CCR_PID=""
    fi
}

#######################################
# Stop PII proxy server (trap cleanup on EXIT/INT/TERM)
#######################################
stop_pii_proxy_server() {
    # Reuse-then-kill fix: only kill the proxy if THIS session started it.
    # When reusing a proxy from another session, PII_PROXY_SESSION_OWNED=false
    # and we leave the shared proxy running so other sessions are not interrupted.
    # Default is false (not true) so that calling stop before start is a safe no-op.
    if [[ "${PII_PROXY_SESSION_OWNED:-false}" != "true" ]]; then
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
