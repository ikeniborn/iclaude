#!/usr/bin/env bash
# lib/caveman/install.sh — caveman token-compression hooks for iclaude isolated env

_CAVEMAN_HOOKS_BASE="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/src/hooks"
_CAVEMAN_HOOK_FILES=(caveman-activate.js caveman-config.js caveman-mode-tracker.js caveman-stats.js)
_CAVEMAN_SKILL_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/skills/caveman/SKILL.md"

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

    local skill_file="$config_dir/skills/caveman/SKILL.md"
    if [[ -f "$skill_file" ]]; then
        echo "  [OK]      skills/caveman/SKILL.md"
        [[ -f "${skill_file}.new" ]] && echo "  [PENDING] skills/caveman/SKILL.md.new  (review and replace manually)"
    else
        echo "  [MISSING] skills/caveman/SKILL.md"
        missing=$((missing + 1))
    fi

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
# Download caveman files via python3 urllib (ssl.CERT_NONE fallback).
# Used when curl and git clone both fail due to TLS algorithm issues on ALT Linux.
#######################################
_caveman_python_download() {
    local hooks_dir="$1" skills_dir="$2"
    mkdir -p "$hooks_dir" "$skills_dir"
    OPENSSL_CONF=/dev/null python3 - "$hooks_dir" "$skills_dir" \
        "$_CAVEMAN_HOOKS_BASE" "$_CAVEMAN_SKILL_URL" \
        "${_CAVEMAN_HOOK_FILES[@]}" <<'PYEOF'
# -*- coding: utf-8 -*-
_urllib = __import__('urllib.request', fromlist=['request'])
import ssl, sys, os

hooks_dir  = sys.argv[1]
skills_dir = sys.argv[2]
hooks_base = sys.argv[3]
skill_url  = sys.argv[4]
files      = sys.argv[5:]

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

for f in files:
    with _urllib.urlopen(hooks_base + '/' + f, context=ctx) as r:
        with open(os.path.join(hooks_dir, f), 'wb') as fp:
            fp.write(r.read())
    print('  ' + f)

skill_dst = os.path.join(skills_dir, 'SKILL.md')
skill_dst_new = skill_dst + '.new' if os.path.exists(skill_dst) else skill_dst
with _urllib.urlopen(skill_url, context=ctx) as r:
    with open(skill_dst_new, 'wb') as fp:
        fp.write(r.read())
label = 'skills/caveman/SKILL.md'
if skill_dst_new.endswith('.new'):
    label += '.new (existing preserved -- review manually)'
print('  ' + label)
PYEOF
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
    source_iclaude_config
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
    # with OPENSSL_CONF=/dev/null to bypass algorithm restrictions, then python3 urllib
    # as last resort. Use `|| _exit=$?` — compatible with set -euo pipefail.
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

    # Download SKILL.md (only via curl; git-clone fallback handles it below)
    if [[ "$_all_curl_ok" == true ]]; then
        local _skills_dir="$config_dir/skills/caveman"
        mkdir -p "$_skills_dir"
        local _skill_dst="$_skills_dir/SKILL.md"
        if [[ -f "$_skill_dst" ]]; then
            _skill_dst="${_skill_dst}.new"
            _exit=0
            curl -fsSL "${_proxy_args[@]}" -o "$_skill_dst" "$_CAVEMAN_SKILL_URL" 2>/dev/null || _exit=$?
            if [[ $_exit -eq 0 ]]; then
                print_info "  skills/caveman/SKILL.md.new (existing preserved — review manually)"
            elif [[ $_exit -eq 35 ]]; then
                rm -f "$_skill_dst"
                _all_curl_ok=false
            else
                print_warning "Failed to download SKILL.md (curl exit $_exit) — skill level differentiation unavailable"
                rm -f "$_skill_dst"
            fi
        else
            _exit=0
            curl -fsSL "${_proxy_args[@]}" -o "$_skill_dst" "$_CAVEMAN_SKILL_URL" 2>/dev/null || _exit=$?
            if [[ $_exit -eq 0 ]]; then
                print_info "  skills/caveman/SKILL.md"
            elif [[ $_exit -eq 35 ]]; then
                rm -f "$_skill_dst"
                _all_curl_ok=false
            else
                print_warning "Failed to download SKILL.md (curl exit $_exit) — skill level differentiation unavailable"
                rm -f "$_skill_dst"
            fi
        fi
    fi

    if [[ "$_all_curl_ok" == false ]]; then
        print_warning "curl TLS error (exit 35) — falling back to git clone with GIT_SSL_NO_VERIFY=1"
        _clone_dir=$(mktemp -d)
        _exit=0
        # OPENSSL_CONF=/dev/null bypasses OpenSSL algorithm restrictions on ALT Linux
        OPENSSL_CONF=/dev/null GIT_SSL_NO_VERIFY=1 git clone --quiet --depth=1 \
            https://github.com/JuliusBrussee/caveman.git "$_clone_dir" 2>&1 || _exit=$?
        local _python_ok=false
        if [[ $_exit -ne 0 ]]; then
            rm -rf "$_clone_dir" && _clone_dir=""
            print_warning "git clone failed (exit $_exit) — trying python3 urllib fallback..."
            if _caveman_python_download "$hooks_dir" "$config_dir/skills/caveman"; then
                _python_ok=true
            else
                print_error "All download methods failed."
                print_info "Manual install — run these commands:"
                for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
                    print_info "  curl -fsSL ${_CAVEMAN_HOOKS_BASE}/$f -o $hooks_dir/$f"
                done
                print_info "  mkdir -p $config_dir/skills/caveman"
                print_info "  curl -fsSL ${_CAVEMAN_SKILL_URL} -o $config_dir/skills/caveman/SKILL.md"
                return 1
            fi
        fi
        if [[ "$_python_ok" == false ]]; then
            for f in "${_CAVEMAN_HOOK_FILES[@]}"; do
                if [[ ! -f "$_clone_dir/src/hooks/$f" ]]; then
                    rm -rf "$_clone_dir"
                    print_error "File not found in clone: src/hooks/$f"
                    return 1
                fi
                cp "$_clone_dir/src/hooks/$f" "$hooks_dir/$f"
                print_info "  $f"
            done

            # Copy SKILL.md from clone
            local _skill_src="$_clone_dir/skills/caveman/SKILL.md"
            if [[ -f "$_skill_src" ]]; then
                local _skills_dir="$config_dir/skills/caveman"
                mkdir -p "$_skills_dir"
                local _skill_dst="$_skills_dir/SKILL.md"
                if [[ -f "$_skill_dst" ]]; then
                    cp "$_skill_src" "${_skill_dst}.new"
                    print_info "  skills/caveman/SKILL.md.new (existing preserved — review manually)"
                else
                    cp "$_skill_src" "$_skill_dst"
                    print_info "  skills/caveman/SKILL.md"
                fi
            else
                print_warning "SKILL.md not found in clone — skill level differentiation unavailable"
            fi

            rm -rf "$_clone_dir"
        fi
    fi

    # Patch settings.json (idempotent)
    print_info "Patching settings.json..."
    python3 - "$settings_file" <<'PYEOF'
import sys, json, re

settings_file = sys.argv[1]

ACTIVATE_CMD = 'node "$CLAUDE_CONFIG_DIR/hooks/caveman-activate.js"'
TRACKER_CMD  = 'node "$CLAUDE_CONFIG_DIR/hooks/caveman-mode-tracker.js"'

def _is_caveman_cmd(cmd):
    return bool(re.search(r'caveman-activate\.js|caveman-mode-tracker\.js', cmd or ''))

def already_has_caveman(hook_list, pattern_fn):
    return any(
        any(pattern_fn(h.get('command', '')) for h in entry.get('hooks', []))
        for entry in hook_list
    )

def remove_caveman_entries(hook_list):
    return [
        e for e in hook_list
        if not any(_is_caveman_cmd(h.get('command', '')) for h in e.get('hooks', []))
    ]

def make_entry(cmd, msg):
    return {"hooks": [{"type": "command", "command": cmd,
                        "timeout": 5, "statusMessage": msg}]}

with open(settings_file) as f:
    s = json.load(f)

hooks = s.setdefault('hooks', {})

# Remove all existing caveman entries (any path form) then add canonical form
session = remove_caveman_entries(hooks.get('SessionStart', []))
session.append(make_entry(ACTIVATE_CMD, "Loading caveman mode..."))
hooks['SessionStart'] = session

prompt = remove_caveman_entries(hooks.get('UserPromptSubmit', []))
prompt.append(make_entry(TRACKER_CMD, "Tracking caveman mode..."))
hooks['UserPromptSubmit'] = prompt

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
        python3 - "$settings_file" <<'PYEOF'
import sys, json, re

settings_file = sys.argv[1]

def _is_caveman_cmd(cmd):
    return bool(re.search(r'caveman-activate\.js|caveman-mode-tracker\.js', cmd or ''))

with open(settings_file) as f:
    s = json.load(f)

hooks = s.get('hooks', {})
for event in ('SessionStart', 'UserPromptSubmit'):
    if event not in hooks:
        continue
    hooks[event] = [
        e for e in hooks[event]
        if not any(_is_caveman_cmd(h.get('command', '')) for h in e.get('hooks', []))
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

    local skills_dir="$config_dir/skills/caveman"
    if [[ -d "$skills_dir" ]]; then
        rm -rf "$skills_dir"
        print_info "  Removed skills/caveman/"
    fi

    rm -f "$config_dir/caveman-version"
    print_info "caveman removed"
}
