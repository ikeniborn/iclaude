#!/usr/bin/env bash
# User-space launcher symlink management for iclaude.

iclaude_link_dir() {
    local dir="${ICLAUDE_LINK_DIR:-$HOME/.local/bin}"
    dir="${dir/#\~\//$HOME/}"
    printf '%s\n' "$dir"
}

_iclaude_realpath() {
    if command -v readlink >/dev/null 2>&1; then
        readlink -f "$1"
    else
        local base name
        base="$(dirname "$1")"
        name="$(basename "$1")"
        (cd "$base" && printf '%s/%s\n' "$PWD" "$name")
    fi
}

detect_iclaude_isolated_launcher() {
    local prefix="$ISOLATED_NVM_DIR/npm-global"
    local pkg="$prefix/lib/node_modules/@anthropic-ai/claude-code"
    local bin_link="$prefix/bin/claude"
    local native_bin="$pkg/bin/claude.exe"
    local legacy_cli="$pkg/cli.js"

    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found"
        echo ""
        echo "Run: ./iclaude.sh --isolated-install"
        return 1
    fi

    if [[ -x "$bin_link" || -L "$bin_link" ]]; then
        print_success "Claude Code launcher found: $bin_link"
        return 0
    fi

    if [[ -x "$native_bin" ]]; then
        print_success "Claude Code native binary found: $native_bin"
        return 0
    fi

    if [[ -f "$legacy_cli" ]]; then
        print_success "Claude Code legacy CLI found: $legacy_cli"
        return 0
    fi

    print_error "Claude Code not found in isolated environment"
    echo ""
    echo "Checked:"
    echo "  $bin_link"
    echo "  $native_bin"
    echo "  $legacy_cli"
    echo ""
    echo "Run: ./iclaude.sh --repair-isolated"
    echo "Or reinstall: ./iclaude.sh --isolated-install"
    return 1
}

install_iclaude_symlink() {
    local dir target link target_real link_real
    dir="$(iclaude_link_dir)"
    target="$SCRIPT_DIR/iclaude.sh"
    link="$dir/iclaude"

    mkdir -p "$dir" || {
        print_error "Cannot create launcher directory: $dir"
        return 1
    }

    target_real="$(_iclaude_realpath "$target")"

    if [[ -L "$link" ]]; then
        link_real="$(_iclaude_realpath "$link" 2>/dev/null || true)"
        if [[ "$link_real" == "$target_real" ]]; then
            print_info "iclaude symlink already up to date: $link"
        else
            ln -sf "$target" "$link"
            print_info "repaired iclaude symlink: $link -> $target"
        fi
    elif [[ -e "$link" ]]; then
        print_warning "$link exists and is not an iclaude symlink; left untouched"
        return 0
    else
        ln -s "$target" "$link"
        print_info "created iclaude symlink: $link -> $target"
    fi

    return 0
}

ensure_iclaude_path_entry() {
    local dir marker profile line shell_name
    dir="$(iclaude_link_dir)"

    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
    esac

    marker="# added by iclaude (PATH for the iclaude launcher)"
    shell_name="$(basename "${SHELL:-}")"

    case "$shell_name" in
        fish)
            profile="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
            line="fish_add_path \"$dir\""
            ;;
        zsh)
            profile="$HOME/.zshrc"
            line="export PATH=\"$dir:\$PATH\""
            ;;
        bash)
            profile="$HOME/.bashrc"
            line="export PATH=\"$dir:\$PATH\""
            ;;
        *)
            print_warning "$dir is not on your PATH; add it manually to run 'iclaude' directly"
            return 0
            ;;
    esac

    if [[ -f "$profile" ]] && grep -qF "$dir" "$profile" 2>/dev/null; then
        return 0
    fi

    mkdir -p "$(dirname "$profile")" || {
        print_warning "Cannot create $(dirname "$profile"); add $dir to PATH manually"
        return 0
    }

    printf '\n%s\n%s\n' "$marker" "$line" >> "$profile" || {
        print_warning "Cannot write $profile; add $dir to PATH manually"
        return 0
    }

    print_info "added $dir to PATH in $profile; restart your shell or source the profile"
    return 0
}

uninstall_iclaude_symlink() {
    local dir target link target_real link_real
    dir="$(iclaude_link_dir)"
    target="$SCRIPT_DIR/iclaude.sh"
    link="$dir/iclaude"

    if [[ ! -e "$link" && ! -L "$link" ]]; then
        print_info "Symlink not found at: $link"
        return 0
    fi

    if [[ ! -L "$link" ]]; then
        print_warning "$link exists and is not a symlink; left untouched"
        return 0
    fi

    target_real="$(_iclaude_realpath "$target")"
    link_real="$(_iclaude_realpath "$link" 2>/dev/null || true)"

    if [[ "$link_real" != "$target_real" ]]; then
        print_warning "$link points elsewhere; left untouched"
        echo "  Current: $link_real"
        echo "  Expected: $target_real"
        return 0
    fi

    rm -f "$link"
    print_success "Removed iclaude symlink: $link"
    return 0
}

install_iclaude_user_launcher() {
    detect_iclaude_isolated_launcher || return 1
    install_iclaude_symlink || return 1
    ensure_iclaude_path_entry
    return 0
}
