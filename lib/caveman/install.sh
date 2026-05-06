#!/usr/bin/env bash
# lib/caveman/install.sh — caveman token-compression hooks for iclaude isolated env

_CAVEMAN_HOOKS_BASE="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks"
_CAVEMAN_HOOK_FILES=(caveman-activate.js caveman-config.js caveman-mode-tracker.js caveman-stats.js)

#######################################
# Show caveman installation status.
#######################################
check_caveman() {
    local config_dir="${CLAUDE_CONFIG_DIR:-}"
    if [[ -z "$config_dir" ]]; then
        print_error "CLAUDE_CONFIG_DIR is not set"
        return 1
    fi

    local hooks_dir="$config_dir/hooks"
    local version_file="$config_dir/caveman-version"

    echo ""
    echo "=== Caveman Status ==="

    local missing=0
    for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
        if [[ -f "$hooks_dir/$f" ]]; then
            echo "  [OK]      $f"
        else
            echo "  [MISSING] $f"
            missing=$((missing + 1))
        fi
    done

    echo ""
    if [[ $missing -eq 0 ]]; then
        echo "  Status:  INSTALLED"
        [[ -f "$version_file" ]] && echo "  Version: $(cat "$version_file")"
    else
        echo "  Status:  NOT INSTALLED ($missing files missing)"
        echo "  Run:     ./iclaude.sh --install-caveman"
    fi

    local mode="${CAVEMAN_DEFAULT_MODE:-full (default)}"
    echo "  Mode:    $mode"
    echo ""
}

#######################################
# Download caveman hooks and patch settings.json.
# Idempotent: safe to run multiple times.
#######################################
install_caveman() {
    local config_dir="${CLAUDE_CONFIG_DIR:-}"
    if [[ -z "$config_dir" ]]; then
        print_error "CLAUDE_CONFIG_DIR is not set"
        return 1
    fi

    local hooks_dir="$config_dir/hooks"
    local settings_file="$config_dir/settings.json"

    if ! command -v curl &>/dev/null; then
        print_error "curl is required for --caveman-install"
        return 1
    fi

    # Load proxy credentials (PROXY_URL / PROXY_CA / PROXY_INSECURE from .claude_config)
    [[ -f "${CREDENTIALS_FILE:-}" ]] && source "$CREDENTIALS_FILE"
    # Export HTTPS_PROXY so python3 urllib picks it up automatically (fallback path)
    if [[ -n "${PROXY_URL:-}" ]] && [[ -z "${HTTPS_PROXY:-}" ]]; then
        export HTTPS_PROXY="$PROXY_URL"
    fi

    # Build curl proxy args — mirrors pattern in lib/sandbox/install.sh::_curl_download()
    local _proxy_args=()
    local _eff_proxy="${PROXY_URL:-${HTTPS_PROXY:-}}"
    if [[ -n "$_eff_proxy" ]]; then
        _proxy_args+=("--proxy" "$_eff_proxy")
        if [[ -n "${PROXY_CA:-}" ]] && [[ -f "$PROXY_CA" ]]; then
            _proxy_args+=("--proxy-cacert" "$PROXY_CA" "--cacert" "$PROXY_CA")
        fi
        [[ "${PROXY_INSECURE:-false}" == "true" ]] && _proxy_args+=("--proxy-insecure")
    fi

    # Download hook files via curl (fast path) or git clone fallback.
    # Strategy: curl with proxy → on exit 35 (ALT Linux TLS algorithm issue, ECDSA cert
    # unsupported by OpenSSL on ALT Linux) fall back to GIT_SSL_NO_VERIFY=1 git clone
    # which works through corporate MITM proxy even when TLS cert algorithm is unsupported.
    # Use `|| _exit=$?` — compatible with set -euo pipefail.
    print_info "Downloading caveman hook files..."
    local _dest _exit _url _clone_dir
    local _all_curl_ok=true
    for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
        _dest="$hooks_dir/$f"
        _url="$_CAVEMAN_HOOKS_BASE/$f"
        _exit=0
        curl -fsSL "${_proxy_args[@]}" -o "$_dest" "$_url" 2>/dev/null || _exit=$?
        if [[ $_exit -eq 35 ]]; then
            _all_curl_ok=false
            break
        elif [[ $_exit -ne 0 ]]; then
            print_error "Failed to download $f (curl exit $_exit)"
            return 1
        fi
        print_info "  $f"
    done

    if [[ "$_all_curl_ok" == false ]]; then
        print_warning "curl TLS error (exit 35) — falling back to git clone with GIT_SSL_NO_VERIFY=1"
        _clone_dir=$(mktemp -d)
        _exit=0
        GIT_SSL_NO_VERIFY=1 git clone --quiet --depth=1 \
            https://github.com/JuliusBrussee/caveman.git "$_clone_dir" 2>&1 || _exit=$?
        if [[ $_exit -ne 0 ]]; then
            rm -rf "$_clone_dir"
            print_error "git clone failed (exit $_exit)"
            return 1
        fi
        for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
            if [[ ! -f "$_clone_dir/hooks/$f" ]]; then
                rm -rf "$_clone_dir"
                print_error "File not found in clone: hooks/$f"
                return 1
            fi
            cp "$_clone_dir/hooks/$f" "$hooks_dir/$f"
            print_info "  $f"
        done
        rm -rf "$_clone_dir"
    fi

    # Patch settings.json (idempotent)
    print_info "Patching settings.json..."
    python3 - "$settings_file" "$hooks_dir" <<'PYEOF'
import sys, json

settings_file, hooks_dir = sys.argv[1], sys.argv[2]

with open(settings_file) as f:
    s = json.load(f)

hooks = s.setdefault('hooks', {})

activate_cmd  = f'node "{hooks_dir}/caveman-activate.js"'
tracker_cmd   = f'node "{hooks_dir}/caveman-mode-tracker.js"'

def already_has(hook_list, cmd):
    return any(
        any(h.get('command') == cmd for h in entry.get('hooks', []))
        for entry in hook_list
    )

def make_entry(cmd, msg):
    return {"hooks": [{"type": "command", "command": cmd,
                        "timeout": 5, "statusMessage": msg}]}

session = hooks.setdefault('SessionStart', [])
if not already_has(session, activate_cmd):
    session.append(make_entry(activate_cmd, "Loading caveman mode..."))

prompt = hooks.setdefault('UserPromptSubmit', [])
if not already_has(prompt, tracker_cmd):
    prompt.append(make_entry(tracker_cmd, "Tracking caveman mode..."))

with open(settings_file, 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("settings.json patched")
PYEOF

    if [[ $? -ne 0 ]]; then
        print_error "Failed to patch settings.json"
        return 1
    fi

    # Save version via git ls-remote (no GitHub API rate limit)
    print_info "Fetching version..."
    local sha
    sha=$(git ls-remote https://github.com/JuliusBrussee/caveman.git main 2>/dev/null \
          | cut -f1 | cut -c1-12)
    echo "${sha:-unknown}" > "$config_dir/caveman-version"

    echo ""
    print_info "caveman installed (sha: ${sha:-unknown})"
    print_info "Restart iclaude to activate"
}

#######################################
# Remove caveman hooks and clean settings.json.
#######################################
remove_caveman() {
    local config_dir="${CLAUDE_CONFIG_DIR:-}"
    if [[ -z "$config_dir" ]]; then
        print_error "CLAUDE_CONFIG_DIR is not set"
        return 1
    fi

    local hooks_dir="$config_dir/hooks"
    local settings_file="$config_dir/settings.json"

    print_info "Removing caveman hook files..."
    for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
        local path="$hooks_dir/$f"
        if [[ -f "$path" ]]; then
            rm -f "$path"
            print_info "  Removed $f"
        fi
    done

    if [[ -f "$settings_file" ]]; then
        print_info "Cleaning settings.json..."
        python3 - "$settings_file" "$hooks_dir" <<'PYEOF'
import sys, json

settings_file, hooks_dir = sys.argv[1], sys.argv[2]
caveman_cmds = {
    f'node "{hooks_dir}/caveman-activate.js"',
    f'node "{hooks_dir}/caveman-mode-tracker.js"',
}

with open(settings_file) as f:
    s = json.load(f)

hooks = s.get('hooks', {})
for event in ('SessionStart', 'UserPromptSubmit'):
    if event not in hooks:
        continue
    hooks[event] = [
        e for e in hooks[event]
        if not any(h.get('command') in caveman_cmds for h in e.get('hooks', []))
    ]
    if not hooks[event]:
        del hooks[event]

with open(settings_file, 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("settings.json cleaned")
PYEOF
        if [[ $? -ne 0 ]]; then
            print_error "Failed to clean settings.json"
            return 1
        fi
    fi

    rm -f "$config_dir/caveman-version"
    print_info "caveman removed"
}
