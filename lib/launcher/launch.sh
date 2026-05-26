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
######################################
# Sync GRAPHIFY_OUT to settings.json env block so Claude Code's bash tool
# subshells always inherit the configured value.
# Without this, ${GRAPHIFY_OUT:-graphify-out} in skill bash blocks falls back
# to "graphify-out" in fresh bash tool calls that don't inherit exported vars.
#######################################
_sync_graphify_env_to_settings() {
    local settings_file="${ISOLATED_CONFIG_DIR:-}/settings.json"
    [[ -f "$settings_file" ]] || return 0
    [[ -z "${GRAPHIFY_OUT:-}" ]] && return 0
    python3 - "$settings_file" "$GRAPHIFY_OUT" <<'PYEOF'
import sys, json
settings_file, graphify_out = sys.argv[1], sys.argv[2]
with open(settings_file) as f:
    s = json.load(f)
env = s.setdefault('env', {})
if env.get('GRAPHIFY_OUT') == graphify_out:
    sys.exit(0)
env['GRAPHIFY_OUT'] = graphify_out
with open(settings_file, 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
}

launch_claude() {
    local skip_isolated="${1:-false}"
    shift  # Remove first argument, rest are Claude args

    # Sync GRAPHIFY_OUT into settings.json env block before launch
    _sync_graphify_env_to_settings

    # Unset CHROME_DESKTOP so Claude Code correctly identifies Chrome as the browser.
    # VS Code sets CHROME_DESKTOP=code.desktop in its terminal environment, which
    # confuses the Claude-in-Chrome extension into opening Yandex or wrong browser.
    unset CHROME_DESKTOP

    # Check OAuth token expiration before launching
    check_oauth_token "$skip_isolated"

    # Background maintenance: prune stale session-env dirs on every launch
    cleanup_stale_session_env

    # NEW: Check if router should be used (only if --router flag is set)
    local use_router=false
    if [[ "$USE_ROUTER_FLAG" == "true" ]] && detect_router "$skip_isolated"; then
        use_router=true
    fi

    # Disable x-anthropic-billing-header when routing to third-party backends.
    # The billing hash (cch=) changes every request and invalidates KV cache on
    # proxies/routers that treat it as part of the system prompt (Ollama, CCR, Bedrock).
    # Auto-enabled when --router is active; also enabled by --no-attribution-header flag.
    # Respects explicit user override: if CLAUDE_CODE_ATTRIBUTION_HEADER is already set
    # in the environment (e.g. via settings.json env block), leave it unchanged.
    if [[ "$use_router" == "true" ]] || [[ "${NO_ATTRIBUTION_HEADER:-false}" == "true" ]]; then
        if [[ -z "${CLAUDE_CODE_ATTRIBUTION_HEADER:-}" ]]; then
            export CLAUDE_CODE_ATTRIBUTION_HEADER=0
            if [[ "$use_router" == "true" ]]; then
                print_info "Attribution header disabled (router mode — prevents KV cache invalidation)"
            else
                print_info "Attribution header disabled (--no-attribution-header)"
            fi
        fi
    fi

    # microVM sandbox: run Claude inside Firecracker VM (kernel isolation)
    local use_microvm=false
    if [[ "${USE_MICRO_VM_FLAG:-false}" == "true" ]]; then
        if [[ "$skip_isolated" == "true" ]]; then
            print_error "microVM is not supported in --system mode (isolated environment only)"
            print_info "Remove --sandbox-microvm or omit --system to use microVM isolation"
            exit 1
        elif type detect_microvm &>/dev/null && detect_microvm "$skip_isolated"; then
            use_microvm=true
        else
            print_warning "microVM not available (run: ./iclaude.sh --install-microvm)"
            print_info "Continuing without microVM isolation..."
        fi
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

    if [[ "$use_microvm" == "true" ]] && [[ "$use_pii_proxy" == "true" ]] && [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code in microVM + PII masking → CCR router chain..."
    elif [[ "$use_microvm" == "true" ]] && [[ "$use_pii_proxy" == "true" ]]; then
        print_info "Launching Claude Code in microVM with PII masking..."
    elif [[ "$use_microvm" == "true" ]] && [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code in microVM via Router..."
    elif [[ "$use_microvm" == "true" ]]; then
        print_info "Launching Claude Code in microVM (Firecracker kernel isolation)..."
    elif [[ "$use_pii_proxy" == "true" ]] && [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code with PII masking → CCR router chain..."
    elif [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code via Router..."
    elif [[ "$use_pii_proxy" == "true" ]]; then
        print_info "Launching Claude Code with PII masking..."
    else
        print_info "Launching Claude Code..."
    fi
    echo ""

    # Start microVM if requested (before PII proxy / CCR, as it must wrap everything)
    if [[ "$use_microvm" == "true" ]]; then
        # Remove stale FC sockets and session dirs from sessions that exited without cleanup
        cleanup_orphaned_microvm_sessions
        # Start CCR and/or PII proxy on host first so configure_guest_environment()
        # can see their ports when building the guest env file.
        if [[ "$use_router" == "true" ]]; then
            local ccr_cmd
            ccr_cmd=$(get_router_path "$skip_isolated")
            if [[ -z "$ccr_cmd" ]]; then
                print_error "Router enabled but ccr binary not found"
                print_info "Install with: ./iclaude.sh --install-router"
                exit 1
            fi
            if ! start_ccr_server "$skip_isolated" "$ccr_cmd"; then
                print_error "CCR router failed to start — aborting"
                exit 1
            fi
        fi
        if [[ "$use_pii_proxy" == "true" ]]; then
            if ! start_pii_proxy_server "$skip_isolated"; then
                print_error "PII proxy failed to start — aborting for safety"
                [[ "$use_router" == "true" ]] && stop_ccr_server
                exit 1
            fi
            # The proxy listens on 127.0.0.1; guest reaches it via TAP host IP + NAT.
        fi

        if ! start_microvm "$skip_isolated"; then
            print_error "microVM failed to start"
            [[ "$use_pii_proxy" == "true" ]] && stop_pii_proxy_server
            [[ "$use_router" == "true" ]] && stop_ccr_server
            exit 1
        fi

        # E2E test hooks — only active when ICLAUDE_E2E_HEADLESS=1 was set at launch
        if [[ "${ICLAUDE_E2E_KILL_AFTER_BOOT:-0}" == "1" ]]; then
            echo "E2E: simulating crash via SIGKILL on self (PID $$)"
            kill -9 $$
        fi
        if [[ "${ICLAUDE_E2E_EXIT_AFTER_BOOT:-0}" == "1" ]]; then
            echo "E2E: clean exit after microVM boot"
            stop_microvm 2>/dev/null || true
            [[ "$use_pii_proxy" == "true" ]] && stop_pii_proxy_server 2>/dev/null || true
            [[ "$use_router" == "true" ]] && stop_ccr_server 2>/dev/null || true
            exit 0
        fi

        # SSH ControlMaster socket path — initialized below after ControlMaster setup.
        # Declared here (empty) so _cm_cleanup trap can reference it safely before initialization.
        local _ssh_control_socket=""
        _cm_cleanup() {
            if [[ -n "${_ssh_control_socket:-}" ]]; then
                ssh -o "ControlPath=${_ssh_control_socket}" -O exit \
                    "iclaude@${guest_ip}" 2>/dev/null || true
                rm -f "${_ssh_control_socket}" 2>/dev/null || true
            fi
        }

        # Register cleanup trap for all active components (+ ControlMaster cleanup)
        if [[ "$use_pii_proxy" == "true" ]] && [[ "$use_router" == "true" ]]; then
            trap '_cm_cleanup; stop_microvm; stop_pii_proxy_server; stop_ccr_server' EXIT INT TERM
        elif [[ "$use_pii_proxy" == "true" ]]; then
            trap '_cm_cleanup; stop_microvm; stop_pii_proxy_server' EXIT INT TERM
        elif [[ "$use_router" == "true" ]]; then
            trap '_cm_cleanup; stop_microvm; stop_ccr_server' EXIT INT TERM
        else
            trap '_cm_cleanup; stop_microvm' EXIT
            trap '_cm_cleanup; stop_microvm; exit 130' INT
            trap '_cm_cleanup; stop_microvm; exit 143' TERM
        fi

        # v2: execute claude inside guest VM via SSH
        local ssh_key="${ISOLATED_CONFIG_DIR}/ssh/microvm"
        local guest_ip="${MICRO_VM_NET_GUEST_IP:-172.16.0.2}"

        if [[ ! -f "$ssh_key" ]]; then
            print_error "microVM SSH key not found: ${ssh_key}"
            print_info "Re-run: ./iclaude.sh --install-microvm"
            stop_microvm; exit 1
        fi

        # Use pinned host key if extracted at install time (set by start_microvm).
        # Falls back to no verification for installs that predate host key extraction.
        local _ssh_kh_opts=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null")
        if [[ -f "${MICRO_VM_KNOWN_HOSTS:-}" ]]; then
            _ssh_kh_opts=("-o" "StrictHostKeyChecking=yes" "-o" "UserKnownHostsFile=${MICRO_VM_KNOWN_HOSTS}")
        else
            print_warning "microVM: MICRO_VM_KNOWN_HOSTS not set — falling back to StrictHostKeyChecking=no. Run --install-microvm to enable host key pinning."
        fi

        # SSH ControlMaster: persistent mux connection, reduces per-op overhead 200ms→5ms.
        # Security: ControlPersist=60 auto-closes orphaned connections after 60s.
        _ssh_control_socket="${MICRO_VM_SOCKET%.sock}-ssh.sock"

        if ssh -M -N -f \
               -o "ControlPath=${_ssh_control_socket}" \
               -o "ControlPersist=60" \
               -o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR \
               -i "$ssh_key" "${_ssh_kh_opts[@]}" \
               "iclaude@${guest_ip}" 2>/dev/null; then
            print_info "microVM: SSH ControlMaster ready (mux active)"
        else
            print_warning "microVM: SSH ControlMaster failed — using direct connections (slower)"
            _ssh_control_socket=""
        fi

        # Build rsync -e SSH command strings with all connection options pre-quoted.
        # Using strings (not arrays) because rsync passes -e value to sh -c for subprocess exec.
        # Paths with spaces are explicitly single-quoted to prevent word splitting by sh -c.
        #
        # _e_ssh_cmd     — primary: uses ControlMaster socket if available (5ms overhead).
        # _e_ssh_fallback — secondary: direct SSH without ControlMaster (for final sync fallback).
        local _e_ssh_cmd="ssh -o BatchMode=yes -o LogLevel=ERROR -i '${ssh_key}'"
        if [[ -n "$_ssh_control_socket" ]]; then
            _e_ssh_cmd+=" -o ControlPath='${_ssh_control_socket}' -o ControlMaster=no"
        fi
        if [[ -f "${MICRO_VM_KNOWN_HOSTS:-}" ]]; then
            _e_ssh_cmd+=" -o StrictHostKeyChecking=yes -o UserKnownHostsFile='${MICRO_VM_KNOWN_HOSTS}'"
        else
            _e_ssh_cmd+=" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        fi

        # Fallback e-SSH command: direct connection, no ControlMaster, longer timeouts.
        local _e_ssh_fallback="ssh -o BatchMode=yes -o LogLevel=ERROR -i '${ssh_key}'"
        _e_ssh_fallback+=" -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3"
        if [[ -f "${MICRO_VM_KNOWN_HOSTS:-}" ]]; then
            _e_ssh_fallback+=" -o StrictHostKeyChecking=yes -o UserKnownHostsFile='${MICRO_VM_KNOWN_HOSTS}'"
        else
            _e_ssh_fallback+=" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        fi

        # Detect if guest has rsync (v7+ rootfs). Fallback to tar if absent.
        local _guest_has_rsync=false
        if ssh -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=5 \
               ${_ssh_control_socket:+-o "ControlPath=${_ssh_control_socket}" -o ControlMaster=no} \
               -i "$ssh_key" "${_ssh_kh_opts[@]}" \
               "iclaude@${guest_ip}" \
               'command -v rsync >/dev/null 2>&1' 2>/dev/null; then
            _guest_has_rsync=true
        fi

        # Build quoted arg list for safe passing through SSH.
        # Strip flags that must not be forwarded into the guest VM:
        #   --chrome: Claude-in-Chrome extension runs on the HOST. The extension connects to
        #             Claude Code CLI via a local IPC port; Claude inside the VM cannot reach it
        #             without SSH reverse port forwarding (future work).
        #   --ide:    IDE (VS Code / JetBrains) runs on the HOST. Claude inside the VM cannot
        #             connect to an IDE socket on the host network namespace.
        # Note: --dangerously-skip-permissions IS forwarded — claude runs as uid=1000 (iclaude user),
        #       not root, so it accepts the flag. KVM isolation makes this safe inside the VM.
        local quoted_args=""
        for arg in "$@"; do
            [[ "$arg" == "--chrome" ]] && continue
            [[ "$arg" == "--ide" ]] && continue
            quoted_args+=" $(printf '%q' "$arg")"
        done

        # Request PTY only when stdin is a terminal (avoid "not a TTY" error in CI)
        local ssh_tty="-T"
        [[ -t 0 ]] && ssh_tty="-t"

        # Sync workspace host→guest: populate /workspace before claude runs.
        # Uses rsync (v7+ rootfs, delta sync) or tar-over-SSH (fallback for older rootfs).
        # 'full' mode:     bidirectional sync (host→guest at start, guest→host on exit).
        # 'isolated' mode: one-way copy (host→guest at start only); host files remain unchanged.
        local _ws_mode="${MICRO_VM_WORKSPACE_MODE:-full}"
        if [[ -n "${MICRO_VM_WORKSPACE_HOSTDIR:-}" ]]; then
            print_info "microVM: syncing workspace → guest (${MICRO_VM_WORKSPACE_HOSTDIR})..."
            # Exclude heavyweight dirs and secret files from host→guest sync:
            #   .nvm-isolated/           — NVM env provided via /dev/vdb (mounted at /mnt/nvm)
            #   .git/                    — git history: large, rarely needed for claude tool calls
            #   .claude_config           — contains HTTPS_PROXY credentials and API keys
            #   .claude_proxy_credentials — legacy credentials file
            #   .iclaude-guest-env.sh    — may exist in PWD from a previous sync-back; never needed
            #   .iclaude-ssh/            — SSH keys for microVM access
            # User can add more exclusions via MICRO_VM_SYNC_EXCLUDE (colon-separated paths).
            local _sync_excludes=(
                "--exclude=./.nvm-isolated"
                "--exclude=./.git"
                "--exclude=./.claude_config"
                "--exclude=./.claude_proxy_credentials"
                "--exclude=./.iclaude-guest-env.sh"
                "--exclude=./.iclaude-ssh"
            )
            if [[ -n "${MICRO_VM_SYNC_EXCLUDE:-}" ]]; then
                local IFS=':'; local _extra
                for _extra in $MICRO_VM_SYNC_EXCLUDE; do
                    _sync_excludes+=("--exclude=./${_extra#./}")
                done
                unset IFS
            fi
            if [[ "$_guest_has_rsync" == "true" ]]; then
                # Build rsync excludes from _sync_excludes (convert --exclude=./.foo → --exclude=.foo)
                local _rsync_excludes=()
                for _excl in "${_sync_excludes[@]}"; do
                    _rsync_excludes+=("${_excl//--exclude=.\//--exclude=}")
                done
                rsync -az --delete "${_rsync_excludes[@]}" \
                    -e "$_e_ssh_cmd" \
                    "${MICRO_VM_WORKSPACE_HOSTDIR}/" \
                    "iclaude@${guest_ip}:/workspace/" 2>/dev/null || \
                print_warning "microVM: workspace sync had errors — guest may have incomplete files"
            else
                tar -czf - -C "${MICRO_VM_WORKSPACE_HOSTDIR}" "${_sync_excludes[@]}" . 2>/dev/null \
                    | ssh -T \
                        ${_ssh_control_socket:+-o "ControlPath=${_ssh_control_socket}" -o ControlMaster=no} \
                        -i "$ssh_key" "${_ssh_kh_opts[@]}" -o LogLevel=ERROR \
                        "iclaude@${guest_ip}" \
                        'tar -xzf - -C /workspace 2>/dev/null' 2>/dev/null || \
                print_warning "microVM: workspace sync had errors — guest may have incomplete files"
            fi
        fi

        # Periodic background sync (full mode + MICRO_VM_SYNC_INTERVAL > 0).
        # Runs a background loop that pulls /workspace from guest to host every N seconds
        # while claude is running, so changes are visible on host without waiting for exit.
        # Disabled by default (0); enable via MICRO_VM_SYNC_INTERVAL=30 in .claude_config.
        local _sync_interval="${MICRO_VM_SYNC_INTERVAL:-0}"
        local _periodic_sync_pid=""
        if [[ "$_ws_mode" != "isolated" && -n "${MICRO_VM_WORKSPACE_HOSTDIR:-}" ]] && \
           [[ "$_sync_interval" =~ ^[0-9]+$ ]] && [[ "$_sync_interval" -gt 0 ]]; then
            (
                local _sync_lock="/tmp/iclaude-${MICRO_VM_SESSION_ID:-$$}-sync.lock"
                # Capture variables for subshell (arrays not inherited via export)
                local _sub_e_ssh_cmd="$_e_ssh_cmd"
                local _sub_guest_has_rsync="$_guest_has_rsync"
                local _sub_host_dir="$MICRO_VM_WORKSPACE_HOSTDIR"
                local _sub_guest_ip="$guest_ip"
                local _sub_ssh_key="$ssh_key"
                local _sub_kh_opts=("${_ssh_kh_opts[@]}")
                while true; do
                    sleep "$_sync_interval" || break
                    # Stop if FC socket is gone (VM no longer running)
                    [[ -S "${MICRO_VM_SOCKET:-/dev/null}" ]] || break
                    # Overlap protection: skip iteration if previous sync still running
                    [[ -f "$_sync_lock" ]] && continue
                    touch "$_sync_lock"
                    if [[ "$_sub_guest_has_rsync" == "true" ]]; then
                        rsync -az --delete \
                            --exclude=lost+found --exclude=.iclaude-guest-env.sh --exclude=.claude-guest \
                            -e "$_sub_e_ssh_cmd" \
                            "iclaude@${_sub_guest_ip}:/workspace/" \
                            "${_sub_host_dir}/" 2>/dev/null || true
                    else
                        ssh -T -o BatchMode=yes \
                            -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
                            -i "$_sub_ssh_key" "${_sub_kh_opts[@]}" -o LogLevel=ERROR \
                            "iclaude@${_sub_guest_ip}" \
                            'tar -czf - -C /workspace --exclude=./lost+found --exclude=./.iclaude-guest-env.sh --exclude=./.claude-guest . 2>/dev/null' 2>/dev/null \
                            | tar -xzf - -C "${_sub_host_dir}" 2>/dev/null || true
                    fi
                    rm -f "$_sync_lock"
                done
            ) &
            _periodic_sync_pid=$!
            print_info "microVM: periodic sync every ${_sync_interval}s via $( [[ "$_guest_has_rsync" == "true" ]] && echo "rsync+ControlMaster" || echo "tar-over-SSH" ) (PID ${_periodic_sync_pid})"
        fi

        print_info "microVM: connecting to guest VM via SSH (${guest_ip})..."
        export ICLAUDE_MICROVM_ACTIVE=1
        # Unset CLAUDECODE so nested claude process doesn't detect parent session
        unset CLAUDECODE

        # Restore local terminal to sane state before the interactive SSH session.
        # The workspace sync (tar | ssh -T pipeline) may leave the terminal with icrnl disabled
        # or other non-standard stty settings. SSH copies local terminal settings to the remote PTY
        # on connect, so a corrupted local state means the remote PTY also has wrong settings —
        # causing Enter (\r) not to be translated to \n and never reaching claude's UI.
        [[ -t 0 ]] && stty sane 2>/dev/null || true

        # Run claude inside guest as iclaude user (non-root; fixes Enter at 'Trust project?' dialog).
        # PTY flag (-t when stdin is terminal) is critical for interactive prompts.
        # Use '.' instead of 'source': iclaude shell is /bin/sh (dash on Ubuntu), which does not
        # support 'source' as a built-in — only POSIX '.' works.
        # cd /workspace: must set CWD before starting claude so it treats /workspace as the project
        # root (not /home/iclaude). Without this the 'Trust project?' dialog shows /home/iclaude.
        # shellcheck disable=SC2086
        ssh $ssh_tty \
            -i "$ssh_key" \
            "${_ssh_kh_opts[@]}" \
            -o ConnectTimeout=15 \
            -o ServerAliveInterval=30 \
            -o LogLevel=ERROR \
            "iclaude@${guest_ip}" \
            ". /workspace/.iclaude-guest-env.sh 2>/dev/null; rm -f /workspace/.iclaude-guest-env.sh 2>/dev/null; cd /workspace 2>/dev/null || true; /mnt/nvm/npm-global/bin/claude${quoted_args}"

        local exit_code=$?

        # Stop periodic sync loop (if running)
        if [[ -n "${_periodic_sync_pid:-}" ]]; then
            kill "$_periodic_sync_pid" 2>/dev/null || true
            wait "$_periodic_sync_pid" 2>/dev/null || true
            _periodic_sync_pid=""
        fi

        # Sync workspace guest→host (full mode only): persist changes claude made in guest.
        # 'isolated' mode: no sync-back — host files remain untouched.
        # Run BEFORE stop_microvm (which kills Firecracker and makes SSH inaccessible).
        if [[ "$_ws_mode" != "isolated" && -n "${MICRO_VM_WORKSPACE_HOSTDIR:-}" ]]; then
            print_info "microVM: syncing workspace ← guest..."
            if [[ "$_guest_has_rsync" == "true" ]]; then
                # Full bidirectional sync (full mode only): --delete propagates guest deletions to host.
                # Try via ControlMaster first; fallback to direct SSH if master died.
                rsync -az --delete \
                    --exclude=lost+found --exclude=.iclaude-guest-env.sh --exclude=.claude-guest \
                    -e "$_e_ssh_cmd" \
                    "iclaude@${guest_ip}:/workspace/" \
                    "${MICRO_VM_WORKSPACE_HOSTDIR}/" 2>/dev/null || \
                rsync -az --delete \
                    --exclude=lost+found --exclude=.iclaude-guest-env.sh --exclude=.claude-guest \
                    -e "$_e_ssh_fallback" \
                    "iclaude@${guest_ip}:/workspace/" \
                    "${MICRO_VM_WORKSPACE_HOSTDIR}/" 2>/dev/null || \
                print_warning "microVM: workspace sync-back had errors — some changes may not persist"
            else
                ssh -T \
                    ${_ssh_control_socket:+-o "ControlPath=${_ssh_control_socket}" -o ControlMaster=no} \
                    -i "$ssh_key" "${_ssh_kh_opts[@]}" \
                    -o ConnectTimeout=10 \
                    -o ServerAliveInterval=5 \
                    -o ServerAliveCountMax=3 \
                    -o LogLevel=ERROR \
                    "iclaude@${guest_ip}" \
                    'tar -czf - -C /workspace --exclude=./lost+found --exclude=./.iclaude-guest-env.sh --exclude=./.claude-guest . 2>/dev/null' 2>/dev/null \
                    | tar -xzf - -C "${MICRO_VM_WORKSPACE_HOSTDIR}" 2>/dev/null || \
                print_warning "microVM: workspace sync-back had errors — some changes may not persist"
            fi
        fi

        # Clean up periodic sync lock file if it exists (e.g. after abrupt sync death)
        rm -f "/tmp/iclaude-${MICRO_VM_SESSION_ID:-$$}-sync.lock" 2>/dev/null || true

        # Traps handle cleanup (stop_microvm, PII proxy, CCR)
        exit $exit_code
    fi

    # NEW: Router launch path
    if [[ "$use_router" == "true" ]]; then
        local ccr_cmd=$(get_router_path "$skip_isolated")
        if [[ -z "$ccr_cmd" ]]; then
            print_error "Router enabled but ccr binary not found"
            print_info "Install with: ./iclaude.sh --install-router"
            exit 1
        fi

        # Determine CCR home directory: isolated env takes priority over user home.
        # CCR has no CCR_HOME env var — it reads os.homedir() / process.env.HOME.
        # We override HOME for the CCR process so all its state (PID file, logs, config)
        # stays inside the isolated environment instead of ~/.claude-code-router/.
        local ccr_home=""
        if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
            ccr_home="$ISOLATED_NVM_DIR/.claude-isolated"
        else
            ccr_home="$HOME"
        fi
        export CCR_HOME="$ccr_home"

        # Copy router config to CCR's expected location inside isolated home
        local router_config=""
        if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
            router_config="$ISOLATED_NVM_DIR/.claude-isolated/router.json"
        else
            router_config="$HOME/.claude/router.json"
        fi

        if [[ -f "$router_config" ]]; then
            mkdir -p "$ccr_home/.claude-code-router"
            cp "$router_config" "$ccr_home/.claude-code-router/config.json"
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
            # Also add npm-global/bin so CCR can find the 'claude' binary when spawning it
            if [[ -d "$ISOLATED_NVM_DIR/npm-global/bin" ]]; then
                export PATH="$ISOLATED_NVM_DIR/npm-global/bin:$PATH"
            fi
        fi

        # Show router version (CCR uses 'ccr -v' or 'ccr version', not '--version')
        local router_version=$(HOME="$ccr_home" "$ccr_cmd" -v 2>/dev/null | head -1 || echo "unknown")
        if [[ -n "$router_version" ]] && [[ "$router_version" != "unknown" ]]; then
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
            # Solo router mode: pass isolated HOME so CCR stores state in isolated env
            HOME="$ccr_home" exec "$ccr_cmd" code "$@"
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

    # Caveman: pass config to hook (process.env.CAVEMAN_DEFAULT_MODE) and statusline
    [[ -n "${CAVEMAN_DEFAULT_MODE:-}" ]] && export CAVEMAN_DEFAULT_MODE
    [[ -n "${CAVEMAN_STATUSLINE:-}" ]] && export CAVEMAN_STATUSLINE

    # Word-split claude_cmd into an array so multi-word commands like
    # "node /path/cli.js" (legacy pre-v2.1.114 fallback) execute correctly.
    # Native-binary path is a single word — splits into one-element array.
    local -a claude_cmd_arr
    read -ra claude_cmd_arr <<< "$claude_cmd"

    # Launch Claude Code
    # When PII proxy is active: cannot use exec — EXIT trap would fire before the
    # new process starts, killing the proxy before claude makes its first API call.
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
        "${claude_cmd_arr[@]}" "$@"
        exit $?
    fi

    # Standard exec path: replace shell process (no cleanup needed)
    exec "${claude_cmd_arr[@]}" "$@"
}

#######################################
# Cleanup orphaned PII proxy processes from terminated sessions.
# Removes stale per-session PID and port files when the associated process is gone
# or the PID has been recycled by an unrelated process. Also sweeps dead legacy
# PID files from the root of ISOLATED_CONFIG_DIR (pre-PII_PROXY_PID_DIR layout);
# live legacy files are left untouched so their owning sessions can still find
# them via the exported PII_PROXY_PID_FILE env var on exit.
# Called at the start of start_pii_proxy_server() to keep the config dir tidy.
#######################################
cleanup_orphaned_pii_proxies() {
    local dir="${ISOLATED_CONFIG_DIR:-}"
    [[ -z "$dir" ]] || [[ ! -d "$dir" ]] && return 0

    local pid_dir="${PII_PROXY_PID_DIR:-$dir/pii-proxy-pid}"
    local log_dir="${PII_PROXY_LOG_DIR:-$dir/pii-proxy-logs}"

    # Ensure the dedicated PID directory exists before use
    mkdir -p "$pid_dir" 2>/dev/null
    chmod 700 "$pid_dir" 2>/dev/null

    # Legacy sweep: pre-PII_PROXY_PID_DIR layouts placed PID files directly at the
    # root of ISOLATED_CONFIG_DIR as pii-proxy-<SID>.pid. We DO NOT move live legacy
    # files into $pid_dir — the sessions that wrote them still hold the old path in
    # their exported PII_PROXY_PID_FILE env var, so relocating would make their
    # stop_pii_proxy_server trap miss the file on exit and leak the server. Instead
    # we just drop dead legacy entries here; live ones drain naturally as those
    # sessions terminate.
    local legacy_dropped=0
    for legacy_pid_file in "$dir"/pii-proxy-*.pid; do
        [[ -f "$legacy_pid_file" ]] || continue
        local lbn="${legacy_pid_file##*/}"                 # pii-proxy-<SID>.pid
        local lsid="${lbn#pii-proxy-}"; lsid="${lsid%.pid}"
        local lpid lalive=false
        lpid=$(cat "$legacy_pid_file" 2>/dev/null)
        if [[ -n "$lpid" ]] && kill -0 "$lpid" 2>/dev/null && \
           ps -p "$lpid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
            lalive=true
        fi
        if [[ "$lalive" != "true" ]]; then
            rm -f "$legacy_pid_file"
            rm -f "$log_dir/pii-proxy-${lsid}.port"
            legacy_dropped=$((legacy_dropped + 1))
        fi
    done
    [[ $legacy_dropped -gt 0 ]] && print_info "PII proxy: dropped $legacy_dropped legacy orphan PID file(s)"

    # Sweep new PID directory: remove entries whose process is gone OR whose PID
    # has been recycled for an unrelated command.
    local cleaned_sessions=0
    for pid_file in "$pid_dir"/*.pid; do
        [[ -f "$pid_file" ]] || continue
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        local alive=false
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            if ps -p "$pid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
                alive=true
            fi
        fi
        if [[ "$alive" != "true" ]]; then
            local bn="${pid_file##*/}"                    # <SID>.pid
            local sid="${bn%.pid}"
            rm -f "$pid_file"
            rm -f "$log_dir/pii-proxy-${sid}.port"
            cleaned_sessions=$((cleaned_sessions + 1))
        fi
    done

    # Rotate session log files older than PII_LOG_RETENTION_DAYS (default: 7 days).
    # access.log and ccr-daemon.log are persistent aggregates — never rotated here.
    local log_retention="${PII_LOG_RETENTION_DAYS:-7}"
    local cleaned_logs=0
    if [[ -d "$log_dir" ]]; then
        local now cutoff log_file fname mtime
        now=$(date +%s)
        cutoff=$(( now - log_retention * 86400 ))
        for log_file in "$log_dir"/*.log; do
            [[ -f "$log_file" ]] || continue
            fname="${log_file##*/}"
            [[ "$fname" == "access.log" || "$fname" == "ccr-daemon.log" ]] && continue
            mtime=$(stat -c %Y "$log_file" 2>/dev/null) || continue
            if [[ $mtime -lt $cutoff ]]; then
                rm -f "$log_file" 2>/dev/null && cleaned_logs=$(( cleaned_logs + 1 ))
            fi
        done
    fi

    [[ $cleaned_sessions -gt 0 ]] && print_info "PII proxy: cleaned $cleaned_sessions orphaned session(s)"
    [[ $cleaned_logs -gt 0 ]] && print_info "PII proxy: rotated $cleaned_logs log file(s) older than ${log_retention}d"
    return 0
}

#######################################
# Cleanup stale session-env directories left by terminated sessions.
# Claude Code creates one subdir per session under CLAUDE_CONFIG_DIR/session-env/.
# Empty dirs older than SESSION_ENV_RETENTION_DAYS (default: 7) are removed.
# Non-empty dirs older than SESSION_ENV_RETENTION_DAYS × 4 (default: 28) are removed.
# Safe for concurrent sessions: active dirs have recent mtime.
# Called once per launch from launch_claude() regardless of mode.
#######################################
cleanup_stale_session_env() {
    local dir="${ISOLATED_CONFIG_DIR:-}"
    local session_env_dir="${dir}/session-env"
    [[ -z "$dir" ]] || [[ ! -d "$session_env_dir" ]] && return 0

    local retention="${SESSION_ENV_RETENTION_DAYS:-7}"
    local long_retention now cutoff_empty cutoff_full
    long_retention=$(( retention * 4 ))
    now=$(date +%s)
    cutoff_empty=$(( now - retention * 86400 ))
    cutoff_full=$(( now - long_retention * 86400 ))

    local cleaned=0 d mtime
    for d in "$session_env_dir"/*/; do
        [[ -d "$d" ]] || continue
        mtime=$(stat -c %Y "$d" 2>/dev/null) || continue
        if [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
            # Empty dir: remove after short retention
            if [[ $mtime -lt $cutoff_empty ]]; then
                rm -rf "$d" 2>/dev/null && cleaned=$(( cleaned + 1 ))
            fi
        else
            # Non-empty dir: remove after long retention
            if [[ $mtime -lt $cutoff_full ]]; then
                rm -rf "$d" 2>/dev/null && cleaned=$(( cleaned + 1 ))
            fi
        fi
    done
    [[ $cleaned -gt 0 ]] && print_info "session-env: cleaned $cleaned stale session dir(s)"
    return 0
}

#######################################
# Sweep dead consumer registrations from pii-proxy-pid/consumers/.
# Must be called while holding flock on shared.lock.
# Removes files whose stored PID is dead (kill -0 fails).
#######################################
_sweep_dead_pii_consumers() {
    local consumers_dir="${PII_PROXY_PID_DIR}/consumers"
    [[ -d "$consumers_dir" ]] || return 0
    local _cf _cpid
    for _cf in "$consumers_dir"/*.pid; do
        [[ -f "$_cf" ]] || continue
        _cpid=$(cat "$_cf" 2>/dev/null)
        if [[ -z "$_cpid" ]] || ! kill -0 "$_cpid" 2>/dev/null; then
            rm -f "$_cf"
        fi
    done
}

#######################################
# Register current session as a consumer of the shared PII proxy.
# Creates pii-proxy-pid/consumers/$ICLAUDE_SESSION_ID.pid with current bash PID.
# Must be called while holding flock on shared.lock.
#######################################
_register_pii_consumer() {
    local consumers_dir="${PII_PROXY_PID_DIR}/consumers"
    mkdir -p "$consumers_dir"
    chmod 700 "$consumers_dir"
    echo "$$" > "$consumers_dir/${ICLAUDE_SESSION_ID}.pid"
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

    # Guard: if ICLAUDE_SESSION_ID was inherited from a parent iclaude session (e.g.
    # when this script is invoked as a subprocess via Claude Code's Bash tool) and that
    # parent already owns a live PII proxy, we must NOT start a second proxy for the same
    # SID. Doing so would overwrite the parent's PID file, causing the parent to lose
    # track of its proxy (leaked process) and the sub-session to kill the wrong PID on exit.
    # Instead, reuse the parent's proxy: inherit ANTHROPIC_BASE_URL and skip startup.
    #
    # Exception: combined mode (PII+CCR) — this session started a CCR daemon
    # (CCR_SESSION_OWNED=true) and needs a FRESH PII proxy to chain PII→CCR→providers.
    # Reusing the parent's proxy would bypass CCR entirely because the parent proxy's
    # upstream was baked in at its startup and cannot be changed retroactively.
    if [[ "${CCR_SESSION_OWNED:-false}" != "true" ]] && [[ -f "$PII_PROXY_PID_FILE" ]]; then
        local _existing_pid
        _existing_pid=$(cat "$PII_PROXY_PID_FILE" 2>/dev/null)
        if [[ -n "$_existing_pid" ]] && kill -0 "$_existing_pid" 2>/dev/null && \
           ps -p "$_existing_pid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
            # Live proxy found for our SID — reuse it (ANTHROPIC_BASE_URL already set by parent)
            local _existing_port
            _existing_port=$(cat "${PII_PROXY_LOG_DIR}/pii-proxy-${ICLAUDE_SESSION_ID}.port" 2>/dev/null || echo "")
            if [[ -n "$_existing_port" && "$_existing_port" =~ ^[0-9]+$ ]]; then
                PII_PROXY_ACTIVE_PORT="$_existing_port"
                export ANTHROPIC_BASE_URL="http://127.0.0.1:$PII_PROXY_ACTIVE_PORT"
                export ICLAUDE_PII_ACTIVE=1
                export ICLAUDE_PII_MASKING_LEVEL="${PII_PROXY_MASKING_LEVEL:-standard}"
                export ICLAUDE_PII_ACTIVE_PORT="${PII_PROXY_ACTIVE_PORT}"
                export ICLAUDE_PII_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}"
                export ICLAUDE_PII_LOG_PATH="${PII_PROXY_LOG_DIR}/${ICLAUDE_SESSION_ID}.log"
                # Mark as NOT owned by this sub-session so stop_pii_proxy_server won't kill it
                PII_PROXY_SESSION_OWNED=false
                print_info "PII proxy: reusing parent session proxy on :$PII_PROXY_ACTIVE_PORT (PID $_existing_pid)"
                unset -f _pii_proxy_http_health
                return 0
            fi
        fi
    fi

    # Shared proxy mode (non-CCR only): attach to existing shared proxy or start one.
    # All clean-PII sessions share one Python process to avoid loading Presidio NLP
    # multiple times. A flock on shared.lock serializes start/stop decisions.
    # CCR sessions bypass this and always start a per-session proxy, even when they
    # reused an existing CCR daemon (CCR_SESSION_OWNED=false). CCR_UPSTREAM_ACTIVE is
    # set by start_ccr_server() in both the fresh-start and reuse paths — it signals
    # that ANTHROPIC_BASE_URL points to CCR and a per-session proxy is required.
    # Without this, a reused-CCR session would attach to a shared proxy whose upstream
    # was baked as api.anthropic.com by an earlier --pii-proxy session, bypassing CCR.
    if [[ "${CCR_UPSTREAM_ACTIVE:-false}" != "true" ]]; then
        local _shared_lock="${PII_PROXY_PID_DIR}/shared.lock"
        local _shared_pid_file="${PII_PROXY_PID_DIR}/shared.pid"
        local _shared_port_file="${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
        # Capture upstream before subshell (subshells cannot set parent vars)
        local _upstream_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
        # Temp file to pass port out of the flock subshell (subshells cannot set parent vars)
        local _shared_result="${PII_PROXY_PID_DIR}/shared-attach-${ICLAUDE_SESSION_ID}.tmp"
        rm -f "$_shared_result"
        mkdir -p "$PII_PROXY_PID_DIR"
        chmod 700 "$PII_PROXY_PID_DIR"

        (
            flock -x 9
            _sweep_dead_pii_consumers

            # Check if shared proxy is alive
            local _spid _sport _salive=false
            _spid=$(cat "$_shared_pid_file" 2>/dev/null || true)
            if [[ -n "$_spid" ]] && kill -0 "$_spid" 2>/dev/null && \
               ps -p "$_spid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
                _sport=$(cat "$_shared_port_file" 2>/dev/null || true)
                [[ "$_sport" =~ ^[0-9]+$ ]] && _salive=true
            fi

            if [[ "$_salive" == "true" ]]; then
                # Attach to existing shared proxy
                _register_pii_consumer
                # Query proxy metadata for display (best-effort; failure degrades gracefully)
                local _meta_json _meta_suffix=""
                _meta_json=$(curl -sf --max-time 2 "http://127.0.0.1:${_sport}/api/meta" 2>/dev/null || true)
                if [[ -n "$_meta_json" ]]; then
                    _meta_suffix=$("$python_bin" -c "
import json, sys
d = json.loads(sys.stdin.read())
print(f\"[{d['masking_level']}] → {d['upstream_url']} | log: {d['log_level']} | started by: {d['session_id']} from {d['pwd']}\")
" <<< "$_meta_json" 2>/dev/null || true)
                fi
                echo "attach:${_sport}:${_meta_suffix}" > "$_shared_result"
            else
                # Start new shared proxy
                rm -f "$_shared_pid_file" "$_shared_port_file"
                local _upstream="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
                mkdir -p "$PII_PROXY_LOG_DIR"
                chmod 700 "$PII_PROXY_LOG_DIR"

                ANTHROPIC_UPSTREAM_URL="$_upstream" \
                ICLAUDE_SESSION_ID="shared" \
                PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
                    setsid "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
                    --port "$PII_PROXY_PORT" \
                    --log-dir "$PII_PROXY_LOG_DIR" \
                    </dev/null >/dev/null 2>&1 9>&- &

                local _proxy_pid=$!
                disown "$_proxy_pid" 2>/dev/null || true
                echo "$_proxy_pid" > "$_shared_pid_file"

                # Poll for port file then HTTP health (max 15s, 0.5s intervals)
                local _max=30 _tick=0 _health=false _port=""
                while [[ $_tick -lt $_max ]]; do
                    if ! kill -0 "$_proxy_pid" 2>/dev/null; then
                        echo "fail:process_exited" > "$_shared_result"
                        rm -f "$_shared_pid_file"
                        exit 1
                    fi
                    if [[ -f "$_shared_port_file" ]]; then
                        _port=$(cat "$_shared_port_file" 2>/dev/null || true)
                        if [[ "$_port" =~ ^[0-9]+$ ]]; then
                            if (: >/dev/tcp/127.0.0.1/"$_port") 2>/dev/null; then
                                if _pii_proxy_http_health "$_port"; then
                                    _health=true
                                    break
                                fi
                            fi
                        fi
                    fi
                    sleep 0.5
                    _tick=$((_tick + 1))
                done

                if [[ "$_health" != "true" ]]; then
                    kill "$_proxy_pid" 2>/dev/null || true
                    rm -f "$_shared_pid_file" "$_shared_port_file"
                    echo "fail:timeout" > "$_shared_result"
                    exit 1
                fi

                _register_pii_consumer
                echo "start:${_port}" > "$_shared_result"
            fi
        ) 9>"$_shared_lock"

        # Process result from flock subshell
        local _result _mode _port
        if [[ -f "$_shared_result" ]]; then
            _result=$(cat "$_shared_result" 2>/dev/null || true)
            rm -f "$_shared_result"
        else
            _result="fail:no_result"
        fi
        local _rest _meta_suffix=""
        _mode="${_result%%:*}"
        _rest="${_result#*:}"
        _port="${_rest%%:*}"
        _meta_suffix="${_rest#*:}"

        case "$_mode" in
            attach|start)
                if [[ ! "$_port" =~ ^[0-9]+$ ]]; then
                    print_warning "PII proxy: shared proxy returned invalid port"
                    unset -f _pii_proxy_http_health
                    return 1
                fi
                PII_PROXY_ACTIVE_PORT="$_port"
                PII_PROXY_SESSION_OWNED=shared
                export ANTHROPIC_BASE_URL="http://127.0.0.1:$PII_PROXY_ACTIVE_PORT"
                export ICLAUDE_PII_ACTIVE=1
                export ICLAUDE_PII_MASKING_LEVEL="${PII_PROXY_MASKING_LEVEL:-standard}"
                export ICLAUDE_PII_ACTIVE_PORT="$PII_PROXY_ACTIVE_PORT"
                export ICLAUDE_PII_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}"
                export ICLAUDE_PII_LOG_PATH="${PII_PROXY_LOG_DIR}/shared.log"
                if [[ "$_mode" == "attach" ]]; then
                    print_info "PII proxy: attached to shared proxy on :$PII_PROXY_ACTIVE_PORT${_meta_suffix:+ $_meta_suffix}"
                else
                    print_info "PII proxy: shared proxy started on :$PII_PROXY_ACTIVE_PORT → $_upstream_url [${PII_PROXY_MASKING_LEVEL:-standard}]"
                fi
                unset -f _pii_proxy_http_health
                command -v print_telemetry_status >/dev/null 2>&1 && print_telemetry_status
                return 0
                ;;
            *)
                print_warning "PII proxy: shared proxy failed to start (${_result})"
                print_info "To launch without masking, remove USE_PII_PROXY from .claude_config"
                unset -f _pii_proxy_http_health
                return 1
                ;;
        esac
    fi

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

    # Remove stale port file from any previous run with the same session ID (paranoia).
    # Safe to do only here because the inherited-SID guard above already returned early
    # if a live proxy owns this port file.
    rm -f "$port_file"
    # BUG-4R4-9: chmod 700 — restrict log dir to current user only
    mkdir -p "$PII_PROXY_LOG_DIR"
    chmod 700 "$PII_PROXY_LOG_DIR"

    # Start per-session proxy server in background.
    # ICLAUDE_SESSION_ID is passed so server.py names its port file accordingly.
    # PII_PROXY_LOG_LEVEL is passed so server.py activates debug logging if configured.
    ANTHROPIC_UPSTREAM_URL="$upstream_url" \
    ICLAUDE_SESSION_ID="$ICLAUDE_SESSION_ID" \
    PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
        "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
        --port "$PII_PROXY_PORT" \
        --log-dir "$PII_PROXY_LOG_DIR" \
        >/dev/null 2>&1 &

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
    # Signal to statusline that PII proxy is active (enables live metrics display)
    export ICLAUDE_PII_ACTIVE=1
    export ICLAUDE_PII_MASKING_LEVEL="${PII_PROXY_MASKING_LEVEL:-standard}"
    export ICLAUDE_PII_ACTIVE_PORT="${PII_PROXY_ACTIVE_PORT}"
    export ICLAUDE_PII_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}"
    # Export TOON audit log path so statusline can hyperlink the PII icon
    export ICLAUDE_PII_LOG_PATH="${PII_PROXY_LOG_DIR}/${ICLAUDE_SESSION_ID}.log"
    print_info "PII proxy: active on :$PII_PROXY_ACTIVE_PORT → $upstream_url (session ${ICLAUDE_SESSION_ID}) [${ICLAUDE_PII_MASKING_LEVEL}]"
    if [[ "${PII_PROXY_LOG_LEVEL:-info}" == "debug" ]]; then
        print_warning "PII proxy: DEBUG mode — log contains PII metadata, preserved after exit: ${PII_PROXY_LOG_DIR}/${ICLAUDE_SESSION_ID}.log"
    fi
    echo ""
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
        CCR_UPSTREAM_ACTIVE=true
        # Set ANTHROPIC_BASE_URL so start_pii_proxy_server() captures CCR as upstream_url
        export ANTHROPIC_BASE_URL="http://${CCR_HOST}:${CCR_PORT}"
        export CCR_UPSTREAM_ACTIVE
        return 0
    fi

    # Start CCR as background daemon using 'ccr start' (server-only mode, no claude child).
    # Note: PATH must already include node v20+ before this function is called
    # (launch_claude() prepends v20 bin to PATH before invoking start_ccr_server).
    print_info "CCR router: starting daemon on ${CCR_HOST}:${CCR_PORT}..."
    HOME="${CCR_HOME:-$HOME}" nohup "$ccr_cmd" start >>"${PII_PROXY_LOG_DIR:-/tmp}/ccr-daemon.log" 2>&1 &
    CCR_PID=$!
    CCR_SESSION_OWNED=true
    CCR_UPSTREAM_ACTIVE=true
    export CCR_PID CCR_SESSION_OWNED CCR_UPSTREAM_ACTIVE

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
# Only kills the proxy if this session started it (PII_PROXY_SESSION_OWNED=true).
# Sub-sessions that reused a parent's proxy set PII_PROXY_SESSION_OWNED=false and
# must not kill or clean up the shared proxy.
#######################################
stop_pii_proxy_server() {
    # Do not kill proxy started by a parent session (inherited SID reuse path)
    if [[ "${PII_PROXY_SESSION_OWNED:-}" == "false" ]]; then
        return 0
    fi

    # Shared proxy: deregister this session; kill proxy only if no consumers remain
    if [[ "${PII_PROXY_SESSION_OWNED:-}" == "shared" ]]; then
        local _shared_lock="${PII_PROXY_PID_DIR}/shared.lock"
        local _shared_pid_file="${PII_PROXY_PID_DIR}/shared.pid"
        mkdir -p "$PII_PROXY_PID_DIR"
        (
            flock -x 9
            rm -f "${PII_PROXY_PID_DIR}/consumers/${ICLAUDE_SESSION_ID}.pid"
            _sweep_dead_pii_consumers
            local _count
            _count=$(ls "${PII_PROXY_PID_DIR}/consumers/"*.pid 2>/dev/null | wc -l)
            if [[ "$_count" -eq 0 ]]; then
                local _spid
                _spid=$(cat "$_shared_pid_file" 2>/dev/null || true)
                if [[ -n "$_spid" ]] && kill -0 "$_spid" 2>/dev/null; then
                    kill "$_spid" 2>/dev/null || true
                    local _waited=0
                    while kill -0 "$_spid" 2>/dev/null && [[ $_waited -lt 10 ]]; do
                        sleep 0.1
                        _waited=$((_waited + 1))
                    done
                    kill -9 "$_spid" 2>/dev/null || true
                fi
                rm -f "$_shared_pid_file"
                rm -f "${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
                if [[ "${PII_PROXY_LOG_LEVEL:-info}" != "debug" ]]; then
                    rm -f "${PII_PROXY_LOG_DIR}/shared.log"
                fi
            fi
        ) 9>"$_shared_lock"
        return 0
    fi

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
        # In info mode: auto-delete session log after process termination.
        # Deleted AFTER process termination so Python's shutdown log entry
        # (written on SIGTERM) doesn't recreate the file after deletion.
        # In debug mode: log is preserved for inspection.
        # Only delete if this session owns the proxy (PII_PROXY_SESSION_OWNED=true).
        if [[ "${PII_PROXY_SESSION_OWNED:-}" == "true" && \
              "${PII_PROXY_LOG_LEVEL:-info}" != "debug" && \
              -n "${PII_PROXY_LOG_DIR:-}" && \
              -n "${ICLAUDE_SESSION_ID:-}" ]]; then
            rm -f "${PII_PROXY_LOG_DIR}/${ICLAUDE_SESSION_ID}.log"
        fi
    fi
}
