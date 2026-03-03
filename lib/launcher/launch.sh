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

    # Export project directory for PostToolUse hooks (e.g. log-tools.py)
    # This allows hooks to write to {project}/.claude/tools/ regardless of cwd
    export CLAUDE_PROJECT_DIR="${PWD}"

    # Archive stale sessions from previous runs (Stop hook may not fire on crash)
    archive_stale_sessions "${CLAUDE_PROJECT_DIR}"

    # Ensure .claude/tools/ is excluded from git in the current project
    local gitignore_file="${PWD}/.gitignore"
    local tools_pattern=".claude/tools/"
    if [[ -f "$gitignore_file" ]] && ! grep -qF "$tools_pattern" "$gitignore_file" 2>/dev/null; then
        echo "$tools_pattern" >> "$gitignore_file"
    fi

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
# Clean up stale session files from the sessions/ root.
#
# .toon.tmp.{PID} — internal Claude Code markers per turn; deleted when PID is dead.
# .toon (0-byte)  — Claude Code finalization marker; deleted (real .toon is in {date}/).
# .txt / .txt.meta — redundant transcripts created by Claude Code on /exit; deleted.
#
# Real session content (.toon with data) is written by the statusline directly into
# .claude/sessions/{YYYY-MM-DD}/ — no movement or archiving needed here.
#
# Arguments:
#   $1 - project_dir: path to project root (must contain .claude/sessions/)
#######################################
archive_stale_sessions() {
    local project_dir="${1:-}"
    local sessions_dir="${project_dir}/.claude/sessions"
    [[ -d "$sessions_dir" ]] || return 0

    # 1. Delete .toon.tmp.{PID} files whose process is dead.
    # These are internal child-process markers — users don't need them.
    # Files with alive PIDs are left alone (active turn in progress).
    while IFS= read -r -d '' f; do
        local filename
        filename="$(basename "$f")"
        local pid="${filename##*.}"
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$f" 2>/dev/null || true
        fi
    done < <(find "$sessions_dir" -maxdepth 1 -name "readable-*.toon.tmp.*" -print0 2>/dev/null)

    # 2. Delete leftover files from sessions/ root: 0-byte .toon markers,
    # .txt and .txt.meta transcripts — all redundant when .toon is in {date}/.
    find "$sessions_dir" -maxdepth 1 \
        \( -name "readable-*.toon" -o -name "readable-*.txt" -o -name "readable-*.txt.meta" \) \
        -print0 2>/dev/null \
        | xargs -0 rm -f 2>/dev/null || true
}

#######################################
# Cleanup orphaned PII proxy processes from terminated sessions.
# Removes stale per-session PID and port files when the associated process is gone.
# Called at the start of start_pii_proxy_server() to keep the log dir tidy.
#######################################
cleanup_orphaned_pii_proxies() {
    local dir="${ISOLATED_CONFIG_DIR:-}"
    [[ -z "$dir" ]] || [[ ! -d "$dir" ]] && return 0

    local cleaned=0
    for pid_file in "$dir"/pii-proxy-*.pid; do
        [[ -f "$pid_file" ]] || continue
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
            # Dead process — extract session ID from filename and remove both files
            local bn="${pid_file##*/}"                    # pii-proxy-<SID>.pid
            local sid="${bn#pii-proxy-}"; sid="${sid%.pid}"
            rm -f "$pid_file"
            rm -f "${PII_PROXY_LOG_DIR:-$dir/pii-proxy-logs}/pii-proxy-${sid}.port"
            cleaned=$((cleaned + 1))
        fi
    done
    [[ $cleaned -gt 0 ]] && print_info "PII proxy: cleaned $cleaned orphaned session(s)"
}

#######################################
# Start PII proxy server and redirect API traffic through it.
# Each iclaude session starts its own independent proxy on a dynamic port.
# Per-session PID and port files (pii-proxy-<SESSION_ID>.{pid,port}) prevent
# race conditions when multiple sessions run simultaneously.
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

    # Cleanup orphaned proxies from previous (terminated) sessions
    cleanup_orphaned_pii_proxies

    # Backward compatibility: migrate legacy global PID file (pre-per-session format).
    # Kill any still-running legacy proxy to avoid port 9000 squatting.
    local legacy_pid_file="${ISOLATED_CONFIG_DIR}/pii-proxy.pid"
    if [[ -f "$legacy_pid_file" ]]; then
        local legacy_pid
        legacy_pid=$(cat "$legacy_pid_file" 2>/dev/null)
        if [[ -n "$legacy_pid" ]] && kill -0 "$legacy_pid" 2>/dev/null; then
            print_info "PII proxy: stopping legacy shared instance (PID $legacy_pid)"
            kill "$legacy_pid" 2>/dev/null || true
        fi
        rm -f "$legacy_pid_file" "${PII_PROXY_LOG_DIR}/server.port"
    fi

    # Per-session port file: written by Python server after successful bind.
    # Using session-scoped name avoids the global server.port race where two concurrent
    # sessions overwrite each other's file and read the wrong port.
    local port_file="${PII_PROXY_LOG_DIR}/pii-proxy-${ICLAUDE_SESSION_ID}.port"
    local upstream_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"

    # Remove stale port file from any previous run with the same session ID (paranoia)
    rm -f "$port_file"
    # BUG-4R4-9: chmod 700 — restrict log dir to current user only
    mkdir -p "$PII_PROXY_LOG_DIR"
    chmod 700 "$PII_PROXY_LOG_DIR"

    # Start per-session proxy server in background.
    # ICLAUDE_SESSION_ID is passed so server.py names its port file accordingly.
    ANTHROPIC_UPSTREAM_URL="$upstream_url" \
    ICLAUDE_SESSION_ID="$ICLAUDE_SESSION_ID" \
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
        rm -f "$PII_PROXY_PID_FILE" "$port_file"
        return 1
    fi

    # Redirect all claude API traffic through this session's PII proxy
    export ANTHROPIC_BASE_URL="http://127.0.0.1:$PII_PROXY_ACTIVE_PORT"
    PII_PROXY_SESSION_OWNED=true
    print_info "PII proxy: active on :$PII_PROXY_ACTIVE_PORT → $upstream_url (session ${ICLAUDE_SESSION_ID})"
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
# Each session owns its own proxy process — always safe to kill on exit.
#######################################
stop_pii_proxy_server() {
    if [[ -f "${PII_PROXY_PID_FILE:-}" ]]; then
        local pid
        pid=$(cat "$PII_PROXY_PID_FILE" 2>/dev/null)
        rm -f "$PII_PROXY_PID_FILE"
        # Remove per-session port file so status.sh doesn't show stale entries.
        # Guard against empty vars to avoid accidentally deleting /pii-proxy-*.port
        [[ -n "${PII_PROXY_LOG_DIR:-}" && -n "${ICLAUDE_SESSION_ID:-}" ]] && \
            rm -f "${PII_PROXY_LOG_DIR}/pii-proxy-${ICLAUDE_SESSION_ID}.port"
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
