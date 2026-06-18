#!/usr/bin/env bash
# lib/command/usage.sh
# Command Handling - Usage/Help Text
#
# Part of Phase 14: Command Handling extraction from iclaude-legacy.sh
# Contains help message displayed with --help flag

#######################################
# Display comprehensive help message
# Shows all available CLI options, examples, and documentation
# Arguments:
#   None
# Returns:
#   0 - Always succeeds
# Globals:
#   Reads CREDENTIALS_FILE, GIT_BACKUP_FILE
# Output:
#   Prints help text to stdout
#######################################
if ! declare -F show_usage &>/dev/null; then
show_usage() {
    cat << EOF
Usage: iclaude [OPTIONS] [CLAUDE_ARGS...]

Initialize Claude Code with HTTPS/HTTP proxy settings (HTTPS recommended)

OPTIONS:
  -h, --help                        Show this help message
  -p, --proxy URL                   Set proxy URL directly (skip prompt)
  --proxy-ca FILE                   Use CA certificate for HTTPS proxy (secure mode)
  --proxy-insecure                  Disable TLS verification (use NODE_TLS_REJECT_UNAUTHORIZED=0)
  -t, --test                        Test proxy and exit (don't launch Claude)
  -c, --clear                       Clear saved credentials
  --no-proxy                        Launch Claude Code without proxy
  --restore-git-proxy               Restore git proxy settings from backup
  --install                         Install script globally (requires sudo + system npm)
  --uninstall                       Uninstall script from system (requires sudo)
  --create-symlink                  Create global symlink using isolated environment (NO system npm)
  --uninstall-symlink               Remove global symlink only (keeps isolated environment)
  --update                          Update system Claude Code to latest version
  --check-update                    Check for available updates without installing
  --isolated-install                Install NVM + Node.js + Claude in isolated environment
  --isolated-update                 Update Claude Code in isolated environment (NO sudo)
  --install-from-lockfile           Install from .nvm-isolated-lockfile.json (reproducible setup, auto-detected on launch)
  --check-isolated                  Show status of isolated environment
  --cleanup-isolated                Remove isolated environment (keeps lockfile)
  --repair-isolated                 Repair symlinks, permissions, and plugins after git clone
  --repair-plugins                  Repair plugin paths after moving project directory
  --isolated-config                 Use isolated config directory (automatic for isolated install)
  --shared-config                   Use shared config directory (default: ~/.claude/)
  --check-config                    Show current configuration directory status
  --refresh-token                   Refresh OAuth token using setup-token (long-lived ~1 year)
  --export-config DIR               Export configuration to backup directory
  --import-config DIR               Import configuration from backup directory
  --install-router                  Install Claude Code Router in isolated environment
  --check-router                    Show router status and configuration
  --router                          Launch via Claude Code Router (requires router.json)
                                    Can be combined with --pii-proxy: traffic goes PII proxy → CCR → providers
  --install-pii-proxy               Install PII proxy (Python venv + Presidio NLP)
  --check-pii-proxy                 Show PII proxy status (venv, models, running PID)
  --pii-proxy                       Launch with PII/secrets masking proxy (overrides USE_PII_PROXY config)
                                    Can be combined with --router: activates chain claude → PII proxy(:9000) → CCR(:3456) → providers
  --install-iwiki                   Install iwiki engine (uv + Python 3.12) and register the plugin
  --no-attribution-header           Disable x-anthropic-billing-header (fixes KV cache on proxies/routers)
                                    Auto-enabled with --router. Use manually with custom ANTHROPIC_BASE_URL
  --chrome                          Enable Chrome browser integration (disabled by default)
  --no-chrome                       Disable Chrome integration (explicit override)
  --model MODEL                     Select Claude model (e.g. claude-opus-4-6, claude-sonnet-4-6, claude-haiku-3-5)
                                    Saved to config and applied on every launch until changed
  --install-lsp [LANGUAGES]         Install LSP servers+plugins (typescript, python, go, rust)
                                    Default: typescript and python
                                    Examples: --install-lsp | --install-lsp python | --install-lsp typescript go
  --check-lsp                       Show LSP server and plugin installation status
  --install-microvm                 Install Firecracker microVM (binary, kernel, rootfs, TAP networking)
                                    Downloads ~72MB to isolated environment (not in git)
                                    Requires: KVM (/dev/kvm), iproute2
  --check-microvm                   Show microVM status (KVM, binaries, networking, configuration)
  --install-caveman                 Install caveman token-compression hooks (downloads 4 JS files to hooks/)
  --uninstall-caveman               Remove caveman hooks and clean settings.json
  --check-caveman                   Show caveman installation status and active mode
  --sandbox-microvm                 Launch Claude Code inside Firecracker microVM (kernel isolation)
                                    Requires prior --install-microvm setup
                                    Can be combined with --pii-proxy: traffic routed through host TAP IP
                                    Enable permanently: add MICRO_VM_ENABLED=true to .claude_config
  --no-test                         Skip proxy connectivity test

Oh My Posh Commands:
  --install-posh, --install-ohmyposh    Install Oh My Posh binary in isolated environment
  --check-posh, --check-ohmyposh        Show Oh My Posh installation status
  --show-password                   Display password in output (default: masked)
  --no-save                         Disable permission checks (enables --dangerously-skip-permissions)
  --save                            [DEPRECATED] Safe mode is now default, use --no-save for unsafe mode
  --system                          Force system installation (skip isolated environment)

EXAMPLES:
  # Install globally (run once)
  sudo \$0 --install

  # First run - prompt for proxy URL
  iclaude

  # Second run - use saved credentials automatically
  iclaude

  # Set proxy URL directly (HTTPS with domain recommended)
  iclaude --proxy https://user:pass@proxy.example.com:8118

  # Use proxy with CA certificate (secure mode, recommended)
  iclaude --proxy https://user:pass@proxy.example.com:8118 --proxy-ca /path/to/proxy-cert.pem

  # Use proxy with insecure mode (not recommended)
  iclaude --proxy https://user:pass@proxy.example.com:8118 --proxy-insecure

  # Test proxy without launching Claude
  iclaude --test

  # Clear saved credentials
  iclaude --clear

  # Restore git proxy settings from backup
  iclaude --restore-git-proxy

  # Launch without proxy
  iclaude --no-proxy

  # Uninstall
  sudo iclaude --uninstall

  # Check for updates
  iclaude --check-update

  # Update Claude Code to latest version
  sudo iclaude --update

  # Pass arguments to Claude Code
  iclaude -- --model claude-3-opus

  # Select and save model for all future launches
  iclaude --model claude-opus-4-6
  iclaude --model claude-sonnet-4-6
  iclaude --model claude-haiku-3-5

  # Disable permission checks (unsafe mode, skip confirmations)
  iclaude --no-save

ISOLATED ENVIRONMENT (Recommended):
  # Install in isolated environment (first time, NO system npm needed)
  ./iclaude.sh --isolated-install

  # Create global symlink to use 'iclaude' from anywhere (NO system npm!)
  sudo ./iclaude.sh --create-symlink

  # Check isolated environment status (includes symlink check)
  ./iclaude.sh --check-isolated

  # Update Claude Code in isolated environment (NO sudo needed)
  ./iclaude.sh --isolated-update

  # Install from lockfile (reproducible setup on another machine)
  ./iclaude.sh --install-from-lockfile

  # After git clone - repair symlinks and permissions
  ./iclaude.sh --repair-isolated

  # Refresh OAuth token (generates long-lived token ~1 year)
  ./iclaude.sh --refresh-token

  # Remove global symlink only (keeps isolated environment)
  sudo iclaude --uninstall-symlink

  # Clean up isolated environment (keeps lockfile for reinstall)
  ./iclaude.sh --cleanup-isolated

SYSTEM INSTALLATION (Alternative):
  # Update system Claude Code installation (requires sudo for system install)
  sudo iclaude --update

  # Run Claude Code from system installation (skip isolated)
  iclaude --system

  # Update system installation explicitly (skip isolated)
  sudo iclaude --system --update

ISOLATED CONFIGURATION:
  # Check current configuration directory
  iclaude --check-config

  # Use isolated configuration (automatic with isolated install)
  iclaude --isolated-config

  # Use shared configuration (default behavior)
  iclaude --shared-config

  # Export configuration to backup
  iclaude --export-config /path/to/backup

  # Import configuration from backup
  iclaude --import-config /path/to/backup

ROUTER INTEGRATION:
  # Install router in isolated environment
  ./iclaude.sh --install-router

  # Check router status and configuration
  ./iclaude.sh --check-router

  # Launch with native Claude (default)
  ./iclaude.sh

  # Launch via Claude Code Router
  ./iclaude.sh --router

PII PROXY (MASKING):
  # Install Python venv + Presidio NLP (~500MB, one-time)
  ./iclaude.sh --install-pii-proxy

  # Check installation status
  ./iclaude.sh --check-pii-proxy

  # Launch with PII/secrets masking (one-time override)
  ./iclaude.sh --pii-proxy

  # Enable permanently via config
  echo 'USE_PII_PROXY=true' >> .claude_config

  # Combined mode: PII masking + CCR router (chain: claude → PII:9000 → CCR:3456 → providers)
  ./iclaude.sh --pii-proxy --router

PROXY URL FORMAT:
  http://username:password@IP:port
  https://username:password@IP:port
  socks5://username:password@IP:port

  ⚠️  Important: Use IP addresses instead of domain names for better reliability

  Examples:
    http://alice:secret123@127.0.0.1:8118
    https://alice:secret123@192.168.1.100:8118
    socks5://bob:pass456@10.0.0.5:1080

  Note: TLS certificate verification is disabled by default (NODE_TLS_REJECT_UNAUTHORIZED=0)

CONFIGURATION:
  - Saved to: ${CREDENTIALS_FILE}
  - File permissions: 600 (owner read/write only)
  - Automatically excluded from git (.gitignore)
  - Reused on subsequent runs (prompt to confirm/change)
  - Includes: PROXY_URL, NO_PROXY, CLAUDE_CODE_* settings, DEBUG flags

AUTHENTICATION:
  OAuth Token (default):
    - Stored in ~/.claude/.credentials.json (system) and .nvm-isolated/.claude-isolated/.credentials.json (isolated)
    - Automatically refreshed every 5 minutes or on HTTP 401
    - Token expiration checked at startup (warns if < 1 hour remaining)
    - Run '/login' in Claude Code if token expired

ENVIRONMENT:
  After loading proxy, these variables are set:
    HTTPS_PROXY, HTTP_PROXY, NO_PROXY, NODE_TLS_REJECT_UNAUTHORIZED=0

NO_PROXY CONFIGURATION:
  - Default value: localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org
  - Stored in ${CREDENTIALS_FILE}
  - Can be edited manually to add custom domains
  - Format: comma-separated list of hosts/domains to bypass proxy

GIT PROXY:
  When proxy is configured, git automatically bypasses proxy for hosts in NO_PROXY:
    - localhost, 127.0.0.1 (local addresses)
    - github.com, githubusercontent.com (GitHub)
    - gitlab.com (GitLab)
    - bitbucket.org (Bitbucket)

  This prevents issues with git push/pull through HTTP proxies.

  Your original git proxy settings are backed up to:
    ${GIT_BACKUP_FILE}

  To restore original git proxy settings:
    iclaude --restore-git-proxy

INSTALLATION:
  After installing with --install, you can run 'iclaude' from anywhere.
  The script will be available at: /usr/local/bin/iclaude

EOF
}
fi
