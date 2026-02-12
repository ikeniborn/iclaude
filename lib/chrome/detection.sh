#!/usr/bin/env bash
# lib/chrome/detection.sh
# Chrome browser and extension detection utilities

# Check if Chrome browser is running
if ! declare -F is_chrome_running &>/dev/null; then
is_chrome_running() {
    if ps aux | grep -E "(/opt/google/chrome/chrome|/usr/bin/chromium)" | grep -v "grep\|crashpad" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}
fi

# Check if Claude in Chrome extension is installed
if ! declare -F is_claude_chrome_extension_installed &>/dev/null; then
is_claude_chrome_extension_installed() {
    local chrome_dir="$HOME/.config/google-chrome"
    local chromium_dir="$HOME/.config/chromium"

    # Check Google Chrome
    if [[ -d "$chrome_dir/Default/Extensions" ]]; then
        # Look for Claude extension ID pattern
        if ls "$chrome_dir"/*/Extensions/*/*/manifest.json 2>/dev/null | \
           xargs grep -l "Claude in Chrome\|claude.*chrome" > /dev/null 2>&1; then
            return 0
        fi
    fi

    # Check Chromium
    if [[ -d "$chromium_dir/Default/Extensions" ]]; then
        if ls "$chromium_dir"/*/Extensions/*/*/manifest.json 2>/dev/null | \
           xargs grep -l "Claude in Chrome\|claude.*chrome" > /dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}
fi

# Warn user if Chrome integration won't work
if ! declare -F warn_chrome_integration &>/dev/null; then
warn_chrome_integration() {
    local chrome_running=false
    local extension_installed=false

    is_chrome_running && chrome_running=true
    is_claude_chrome_extension_installed && extension_installed=true

    if [[ "$chrome_running" == false ]]; then
        print_warning "Chrome is not running - browser automation won't work"
        echo ""
        echo "Start Chrome to enable browser automation features"
        echo "Or run with --no-chrome to skip this warning"
        echo ""
        return 1
    fi

    if [[ "$extension_installed" == false ]]; then
        print_warning "Claude in Chrome extension not detected"
        echo ""
        echo "Browser automation requires the Chrome extension:"
        echo "  https://chromewebstore.google.com/detail/claude-in-chrome/hgjbefmfenopoenbhdcfhclblnnfifhh"
        echo ""
        echo "Or run with --no-chrome to disable browser integration"
        echo ""
        return 1
    fi

    return 0
}
fi
