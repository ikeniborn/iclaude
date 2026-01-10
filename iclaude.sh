#!/bin/bash

#######################################
# iclaude.sh - Initialize Claude Code with HTTP Proxy
# Version: 2.0
# Description: Auto-configure proxy settings and launch Claude Code
#              Stores credentials for reuse
#######################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
# Resolve script directory (follows symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CREDENTIALS_FILE="${SCRIPT_DIR}/.claude_proxy_credentials"
GIT_BACKUP_FILE="${SCRIPT_DIR}/.claude_git_proxy_backup"
ISOLATED_NVM_DIR="${SCRIPT_DIR}/.nvm-isolated"
ISOLATED_LOCKFILE="${SCRIPT_DIR}/.nvm-isolated-lockfile.json"
USE_ISOLATED_BY_DEFAULT=true  # Use isolated environment by default

# Token refresh threshold in seconds (7 days = 604800)
# Token will be refreshed if it expires within this time
TOKEN_REFRESH_THRESHOLD=604800

#######################################
# Print colored message
#######################################
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

#######################################
# Validate proxy URL format (requires IP address)
#######################################
validate_proxy_url() {
    local url=$1

    # Basic format check: http(s)://[user:pass@]host:port
    if [[ ! "$url" =~ ^(http|https|socks5)://.*:[0-9]+$ ]]; then
        return 1
    fi

    # Extract host from URL
    local remainder=$(echo "$url" | sed 's|^[^:]*://||')
    local host

    # Check if credentials present (contains @)
    if [[ "$remainder" =~ @ ]]; then
        # Extract host:port after @
        local hostport=$(echo "$remainder" | sed 's|^[^@]*@||')
        host=$(echo "$hostport" | cut -d':' -f1)
    else
        # No credentials, extract host directly
        host=$(echo "$remainder" | cut -d':' -f1)
    fi

    # Validate that host is an IP address
    if ! is_ip_address "$host"; then
        return 2  # Return 2 to indicate "domain instead of IP"
    fi

    return 0
}

#######################################
# Check if host is IP address (IPv4)
#######################################
is_ip_address() {
    local host=$1
    # Regex for IPv4 address
    if [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Validate each octet is 0-255
        local IFS='.'
        local -a octets=($host)
        for octet in "${octets[@]}"; do
            if (( octet > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

#######################################
# Resolve domain to IP address
# Returns IP address on success, empty on failure
#######################################
resolve_domain_to_ip() {
    local domain=$1

    # Try using getent first (most reliable)
    if command -v getent &> /dev/null; then
        local ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # Fallback to host command
    if command -v host &> /dev/null; then
        local ip=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -n1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # Fallback to dig command
    if command -v dig &> /dev/null; then
        local ip=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    fi

    # Fallback to nslookup
    if command -v nslookup &> /dev/null; then
        local ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | tail -n1 | awk '{print $2}')
        if [[ -n "$ip" ]] && is_ip_address "$ip"; then
            echo "$ip"
            return 0
        fi
    fi

    return 1
}

#######################################
# Parse proxy URL and extract components
#######################################
parse_proxy_url() {
    local url=$1

    # Extract protocol
    local protocol=$(echo "$url" | grep -oP '^[^:]+')

    # Extract everything after protocol://
    local remainder=$(echo "$url" | sed 's|^[^:]*://||')

    # Check if credentials present (contains @)
    if [[ "$remainder" =~ @ ]]; then
        # Extract user:pass
        local credentials=$(echo "$remainder" | grep -oP '^[^@]+')
        local username=$(echo "$credentials" | cut -d':' -f1)
        local password=$(echo "$credentials" | cut -d':' -f2-)

        # Extract host:port after @
        local hostport=$(echo "$remainder" | sed 's|^[^@]*@||')
        local host=$(echo "$hostport" | cut -d':' -f1)
        local port=$(echo "$hostport" | cut -d':' -f2)

        echo "protocol=$protocol"
        echo "username=$username"
        echo "password=$password"
        echo "host=$host"
        echo "port=$port"
    else
        # No credentials
        local host=$(echo "$remainder" | cut -d':' -f1)
        local port=$(echo "$remainder" | cut -d':' -f2)

        echo "protocol=$protocol"
        echo "username="
        echo "password="
        echo "host=$host"
        echo "port=$port"
    fi
}

#######################################
# Detect if NVM is installed and active
# Prioritizes isolated environment when USE_ISOLATED_BY_DEFAULT=true
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment check
#######################################
detect_nvm() {
	local skip_isolated="${1:-false}"

	# Priority 1: Check for isolated environment (if enabled by default and not skipped)
	if [[ "$skip_isolated" != "true" ]] && [[ "$USE_ISOLATED_BY_DEFAULT" == "true" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
		# Isolated environment exists, set it up
		if [[ -s "${ISOLATED_NVM_DIR}/nvm.sh" ]]; then
			setup_isolated_nvm
			return 0
		fi
	fi

	# Priority 2: Check if NVM_DIR is set and nvm.sh exists (system NVM)
	if [[ -n "${NVM_DIR:-}" ]] && [[ -s "${NVM_DIR}/nvm.sh" ]]; then
		return 0
	fi

	# Priority 3: Check if npm/node is from NVM by examining the path
	local npm_path=$(command -v npm 2>/dev/null)
	if [[ -n "$npm_path" ]] && [[ "$npm_path" == *".nvm"* ]]; then
		return 0
	fi

	local node_path=$(command -v node 2>/dev/null)
	if [[ -n "$node_path" ]] && [[ "$node_path" == *".nvm"* ]]; then
		return 0
	fi

	return 1
}

#######################################
# Get Claude path from NVM environment
#######################################
get_nvm_claude_path() {
	# Try to find claude in active NVM node version
	if [[ -n "${NVM_DIR:-}" ]]; then
		# Get current node version
		local current_node=""
		if command -v nvm &> /dev/null; then
			current_node=$(nvm current 2>/dev/null)
		fi

		# Check if valid version
		if [[ -n "$current_node" ]] && [[ "$current_node" != "none" ]] && [[ "$current_node" != "system" ]]; then
			local nvm_bin="${NVM_DIR}/versions/node/$current_node/bin"
			local nvm_lib="${NVM_DIR}/versions/node/$current_node/lib/node_modules/@anthropic-ai"

			# First try standard 'claude' binary
			if [[ -x "$nvm_bin/claude" ]]; then
				echo "$nvm_bin/claude"
				return 0
			fi

			# Then try temporary .claude-* binaries (sorted by modification time, newest first)
			if ls "$nvm_bin/.claude-"* &>/dev/null; then
				local temp_claude=$(ls -t "$nvm_bin/.claude-"* 2>/dev/null | head -n 1)
				if [[ -x "$temp_claude" ]]; then
					echo "$temp_claude"
					return 0
				fi
			fi

			# If binaries not found, try to find cli.js in node_modules (including temp folders)
			if [[ -d "$nvm_lib" ]]; then
				# Try standard claude-code folder first
				if [[ -f "$nvm_lib/claude-code/cli.js" ]]; then
					echo "node $nvm_lib/claude-code/cli.js"
					return 0
				fi

				# Then try temporary .claude-code-* folders (sorted by modification time, newest first)
				local temp_cli=$(find "$nvm_lib" -maxdepth 2 -name "cli.js" -path "*/.claude-code-*/cli.js" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)
				if [[ -n "$temp_cli" ]] && [[ -f "$temp_cli" ]]; then
					echo "node $temp_cli"
					return 0
				fi
			fi
		fi
	fi

	# Alternative: use npm prefix to find global bin
	local npm_prefix=$(npm prefix -g 2>/dev/null)
	if [[ -n "$npm_prefix" ]] && [[ "$npm_prefix" == *".nvm"* ]]; then
		# First try standard 'claude' binary
		if [[ -x "$npm_prefix/bin/claude" ]]; then
			echo "$npm_prefix/bin/claude"
			return 0
		fi

		# Then try temporary .claude-* binaries (sorted by modification time, newest first)
		if ls "$npm_prefix/bin/.claude-"* &>/dev/null; then
			local temp_claude=$(ls -t "$npm_prefix/bin/.claude-"* 2>/dev/null | head -n 1)
			if [[ -x "$temp_claude" ]]; then
				echo "$temp_claude"
				return 0
			fi
		fi

		# If binaries not found, try to find cli.js in node_modules
		local npm_lib="$npm_prefix/lib/node_modules/@anthropic-ai"
		if [[ -d "$npm_lib" ]]; then
			# Try standard claude-code folder first
			if [[ -f "$npm_lib/claude-code/cli.js" ]]; then
				echo "node $npm_lib/claude-code/cli.js"
				return 0
			fi

			# Then try temporary .claude-code-* folders (sorted by modification time, newest first)
			local temp_cli=$(find "$npm_lib" -maxdepth 2 -name "cli.js" -path "*/.claude-code-*/cli.js" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)
			if [[ -n "$temp_cli" ]] && [[ -f "$temp_cli" ]]; then
				echo "node $temp_cli"
				return 0
			fi
		fi
	fi

	return 1
}

#######################################
# Detect if router should be used
# Checks for router.json existence and ccr binary
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   0 - router should be used
#   1 - use native Claude Code
#######################################
detect_router() {
	local skip_isolated="${1:-false}"
	local router_config=""

	# Determine config location
	if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
		router_config="$ISOLATED_NVM_DIR/.claude-isolated/router.json"
	else
		router_config="$HOME/.claude/router.json"
	fi

	# Router config must exist
	[[ ! -f "$router_config" ]] && return 1

	# Check ccr binary
	local ccr_cmd=$(get_router_path "$skip_isolated")
	if [[ -z "$ccr_cmd" ]]; then
		print_warning "router.json found but ccr binary not installed"
		print_info "Install with: ./iclaude.sh --install-router"
		return 1
	fi

	return 0  # Router available
}

#######################################
# Get path to ccr binary
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   ccr binary path or empty string
#######################################
get_router_path() {
	local skip_isolated="${1:-false}"

	# Check isolated environment first
	if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
		local npm_global_bin="$ISOLATED_NVM_DIR/npm-global/bin"
		[[ -x "$npm_global_bin/ccr" ]] && echo "$npm_global_bin/ccr" && return 0
	fi

	# Check system PATH
	command -v ccr &> /dev/null && command -v ccr && return 0

	echo ""
	return 1
}

#######################################
# Get version from cli.js installation
#######################################
get_cli_version() {
	local cli_path=$1

	# If it's a "node /path/to/cli.js" command, extract the cli.js path
	if [[ "$cli_path" == node* ]]; then
		cli_path=$(echo "$cli_path" | awk '{print $2}')
	fi

	# If it's a full path to cli.js, get the directory
	if [[ "$cli_path" == *"cli.js" ]]; then
		cli_path=$(dirname "$cli_path")
	fi

	# Check if package.json exists
	local package_json="$cli_path/package.json"
	if [[ ! -f "$package_json" ]]; then
		echo "unknown"
		return 1
	fi

	# Extract version from package.json
	local version=$(grep -oP '(?<="version":\s")[^"]+' "$package_json" 2>/dev/null)

	if [[ -z "$version" ]]; then
		echo "unknown"
		return 1
	fi

	echo "$version"
	return 0
}

#######################################
# Setup isolated NVM environment in project directory
# Returns:
#   0 - success
#   1 - error
#######################################
setup_isolated_nvm() {
	# Export isolated environment
	export NVM_DIR="$ISOLATED_NVM_DIR"
	export NPM_CONFIG_PREFIX="$NVM_DIR/npm-global"

	# Найти установленную версию Node.js (раскрыть глоб)
	local node_version_dir=$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v*" 2>/dev/null | head -1)

	if [[ -n "$node_version_dir" ]] && [[ -d "$node_version_dir/bin" ]]; then
		# Add isolated paths to PATH (prepend to prioritize isolated over system)
		export PATH="$NPM_CONFIG_PREFIX/bin:$node_version_dir/bin:$PATH"
	else
		# Fallback: add npm-global/bin only
		export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
		print_warning "Node.js not found in isolated environment"
	fi

	return 0
}

#######################################
# Install NVM to isolated directory
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_nvm() {
	setup_isolated_nvm

	# Create isolated NVM directory
	mkdir -p "$NVM_DIR"

	# Check if NVM already installed
	if [[ -s "$NVM_DIR/nvm.sh" ]]; then
		print_info "NVM already installed in isolated environment"
		return 0
	fi

	print_info "Installing NVM to isolated directory..."
	print_info "Location: $NVM_DIR"
	echo ""

	# Download and install NVM
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | \
		NVM_DIR="$NVM_DIR" bash

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install NVM"
		return 1
	fi

	print_success "NVM installed to isolated environment"
	return 0
}

#######################################
# Install Node.js in isolated NVM
# Arguments:
#   $1 - Node.js version (default: 18)
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_nodejs() {
	local node_version=${1:-18}

	setup_isolated_nvm

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo "Run: iclaude --isolated-install first"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	# Check if Node.js already installed
	if nvm ls "$node_version" &>/dev/null; then
		print_info "Node.js $node_version already installed"
		nvm use "$node_version"
		return 0
	fi

	print_info "Installing Node.js $node_version to isolated environment..."
	echo ""

	# Install and use Node.js
	nvm install "$node_version"
	nvm use "$node_version"

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Node.js"
		return 1
	fi

	print_success "Node.js $node_version installed"
	node --version
	npm --version
	echo ""

	return 0
}

#######################################
# Install Claude Code in isolated environment
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_claude() {
	setup_isolated_nvm

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	# Ensure Node.js is available
	if ! command -v npm &>/dev/null; then
		print_error "Node.js not found in isolated environment"
		echo "Run: iclaude --isolated-install first"
		return 1
	fi

	print_info "Installing Claude Code to isolated environment..."
	echo ""

	# Install Claude Code globally (in isolated prefix)
	npm install -g @anthropic-ai/claude-code

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Claude Code"
		return 1
	fi

	# Clear bash command hash cache
	hash -r 2>/dev/null || true

	# Verify installation
	local claude_version=""
	if command -v claude &>/dev/null; then
		claude_version=$(claude --version 2>/dev/null | head -n 1)
	fi

	if [[ -n "$claude_version" ]]; then
		print_success "Claude Code installed: $claude_version"
	else
		print_success "Claude Code installed"
	fi

	echo ""

	# Save lockfile for reproducibility
	save_isolated_lockfile

	return 0
}

#######################################
# Install Claude Code Router in isolated environment
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_router() {
	setup_isolated_nvm

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	print_info "Installing Claude Code Router to isolated environment..."
	echo ""

	# Install router globally (in isolated prefix)
	npm install -g @musistudio/claude-code-router

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Claude Code Router"
		return 1
	fi

	# Clear bash command hash cache
	hash -r 2>/dev/null || true

	# Check if router.json exists, if not copy from example
	local router_config="${ISOLATED_NVM_DIR}/.claude-isolated/router.json"
	local router_example="${ISOLATED_NVM_DIR}/.claude-isolated/router.json.example"

	if [[ ! -f "$router_config" ]] && [[ -f "$router_example" ]]; then
		print_info "Creating router.json from template..."
		cp "$router_example" "$router_config"
		print_success "Created router.json (configure providers and commit to git)"
		echo ""
	fi

	print_success "Claude Code Router installed successfully"
	echo ""
	print_info "Next steps:"
	print_info "  1. Edit: $router_config"
	print_info "  2. Export API keys: export DEEPSEEK_API_KEY=your-key"
	print_info "  3. Commit router.json to git (with \${VAR} placeholders)"
	print_info "  4. Launch: ./iclaude.sh"
	echo ""

	return 0
}

#######################################
# Install LSP servers and plugins in isolated environment
# Arguments:
#   $@ - Language servers to install (default: typescript, python)
# Returns:
#   0 - success
#   1 - error (Claude Code not installed)
#######################################
install_isolated_lsp_servers() {
	local servers=("$@")  # Allow selecting specific servers

	# Default: Install TypeScript + Python (most common)
	if [[ ${#servers[@]} -eq 0 ]]; then
		servers=("typescript" "python")
	fi

	# Setup environment
	setup_isolated_nvm
	source "$NVM_DIR/nvm.sh"

	# Get Claude Code path using existing function
	local claude_path
	claude_path=$(get_nvm_claude_path)

	if [[ -z "$claude_path" ]]; then
		print_error "Claude Code not installed."
		echo ""
		print_info "Run './iclaude.sh --isolated-install' first to install Claude Code."
		return 1
	fi

	echo ""
	print_info "Installing LSP servers and plugins..."
	print_info "Claude Code path: $claude_path"
	echo ""

	for server in "${servers[@]}"; do
		case "$server" in
			typescript|ts)
				# Install server
				print_info "Installing TypeScript LSP server..."
				npm install -g @vtsls/language-server || print_warning "Server install failed (continuing...)"
				echo ""

				# Install plugin (check if already installed first)
				local plugin_list
				if [[ "$claude_path" =~ ^node\  ]]; then
					local cli_path="${claude_path#node }"
					plugin_list=$(node "$cli_path" plugin list 2>/dev/null || echo "")
				else
					plugin_list=$("$claude_path" plugin list 2>/dev/null || echo "")
				fi

				if echo "$plugin_list" | grep -q "typescript-lsp@claude-plugins-official"; then
					echo "✓ typescript-lsp plugin already installed (skipping)"
				else
					print_info "Installing typescript-lsp plugin..."
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						node "$cli_path" plugin install typescript-lsp@claude-plugins-official -s project --project-path "$SCRIPT_DIR" || print_warning "Plugin install failed"
					else
						"$claude_path" plugin install typescript-lsp@claude-plugins-official -s project --project-path "$SCRIPT_DIR" || print_warning "Plugin install failed"
					fi
				fi
				echo ""
				;;
			python|py)
				# Install server
				print_info "Installing Python LSP server..."
				npm install -g pyright || print_warning "Server install failed (continuing...)"
				echo ""

				# Install plugin (check if already installed first)
				local plugin_list
				if [[ "$claude_path" =~ ^node\  ]]; then
					local cli_path="${claude_path#node }"
					plugin_list=$(node "$cli_path" plugin list 2>/dev/null || echo "")
				else
					plugin_list=$("$claude_path" plugin list 2>/dev/null || echo "")
				fi

				if echo "$plugin_list" | grep -q "pyright-lsp@claude-plugins-official"; then
					echo "✓ pyright-lsp plugin already installed (skipping)"
				else
					print_info "Installing pyright-lsp plugin..."
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						node "$cli_path" plugin install pyright-lsp@claude-plugins-official -s project --project-path "$SCRIPT_DIR" || print_warning "Plugin install failed"
					else
						"$claude_path" plugin install pyright-lsp@claude-plugins-official -s project --project-path "$SCRIPT_DIR" || print_warning "Plugin install failed"
					fi
				fi
				echo ""
				;;
			go)
				# Go requires GOPATH setup, skip npm
				print_warning "Go LSP (gopls): Install via 'go install golang.org/x/tools/gopls@latest'"
				print_info "    Plugin: claude plugin install gopls-lsp@claude-plugins-official -s project --project-path \"$SCRIPT_DIR\""
				echo ""
				;;
			rust)
				print_warning "Rust LSP (rust-analyzer): Install via 'rustup component add rust-analyzer'"
				print_info "    Plugin: claude plugin install rust-analyzer-lsp@claude-plugins-official -s project --project-path \"$SCRIPT_DIR\""
				echo ""
				;;
			# Add other languages as needed
			*)
				print_error "Unknown LSP server: $server"
				echo ""
				;;
		esac
	done

	hash -r  # Clear bash cache
	save_isolated_lockfile  # Update lockfile with LSP versions

	echo ""
	print_success "LSP installation complete. Run './iclaude.sh --check-lsp' to verify."
	echo ""

	return 0
}

#######################################
# Update Claude Code in isolated environment
# Returns:
#   0 - success
#   1 - error
#######################################
update_isolated_claude() {
	setup_isolated_nvm

	echo ""
	print_info "Updating Claude Code in isolated environment..."
	echo ""

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	# Ensure Node.js is available
	if ! command -v npm &>/dev/null; then
		print_error "Node.js not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	# Get current version before update
	local current_version=""
	local claude_cli="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
	if [[ -f "$claude_cli" ]]; then
		current_version=$(node "$claude_cli" --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
		print_info "Current version: $current_version"
		echo ""
	else
		print_warning "Claude Code not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	# Update Claude Code
	print_info "Running: npm update -g @anthropic-ai/claude-code"
	echo ""

	if npm update -g @anthropic-ai/claude-code; then
		# Clear bash command hash cache
		hash -r 2>/dev/null || true

		# Get new version
		local new_version=""
		if [[ -f "$claude_cli" ]]; then
			new_version=$(node "$claude_cli" --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
		fi

		echo ""
		print_success "Claude Code updated successfully"
		echo ""
		echo "  Previous version: $current_version"
		echo "  New version:      $new_version"
		echo ""

		# Update lockfile with new version
		print_info "Updating lockfile..."
		save_isolated_lockfile

		if [[ "$current_version" == "$new_version" ]]; then
			print_info "Already on latest version"
		fi

		return 0
	else
		echo ""
		print_error "Failed to update Claude Code"
		echo ""
		echo "Try:"
		echo "  1. Check internet connection"
		echo "  2. Run: ./iclaude.sh --repair-isolated"
		echo "  3. Reinstall: ./iclaude.sh --cleanup-isolated && ./iclaude.sh --isolated-install"
		return 1
	fi
}

#######################################
# Save lockfile with installed versions
# Returns:
#   0 - success
#   1 - error
#######################################
save_isolated_lockfile() {
	setup_isolated_nvm

	# Source NVM
	[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

	# Get versions
	local node_version=$(node --version 2>/dev/null | sed 's/v//')
	local claude_version=""

	# Clear bash command hash cache (ensures fresh command lookup)
	hash -r 2>/dev/null || true

	# Try multiple methods to get Claude version (most reliable first)

	# Method 1: Direct path to cli.js (most reliable - works even with broken symlinks)
	local claude_cli="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
	if [[ -f "$claude_cli" ]]; then
		claude_version=$(node "$claude_cli" --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "")
	fi

	# Method 2: Fallback to command lookup (requires working symlink)
	if [[ -z "$claude_version" ]] && command -v claude &>/dev/null; then
		claude_version=$(claude --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "")
	fi

	# Method 3: Fallback to package.json (last resort)
	if [[ -z "$claude_version" ]]; then
		local package_json="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json"
		if [[ -f "$package_json" ]]; then
			claude_version=$(grep -oP '"version":\s*"\K[^"]+' "$package_json" 2>/dev/null || echo "unknown")
		else
			claude_version="unknown"
		fi
	fi

	# Get router version if installed
	local router_version="not installed"
	local ccr_cmd=$(get_router_path "false")
	if [[ -n "$ccr_cmd" ]]; then
		router_version=$("$ccr_cmd" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
	fi

	# Detect LSP servers
	local lsp_servers_json="{"
	local first=true

	for server_cmd in pyright vtsls typescript-language-server; do
		if command -v "$server_cmd" &>/dev/null; then
			local version
			case "$server_cmd" in
				pyright)
					version=$(pyright --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
					;;
				vtsls)
					version=$(vtsls --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
					;;
				typescript-language-server)
					version=$(typescript-language-server --version 2>/dev/null)
					;;
			esac

			if [[ -n "$version" ]]; then
				[[ "$first" == false ]] && lsp_servers_json+=", "
				lsp_servers_json+="\"$server_cmd\": \"$version\""
				first=false
			fi
		fi
	done

	lsp_servers_json+="}"

	# Detect LSP plugins
	local lsp_plugins_json="{"
	first=true

	# Get Claude Code path
	local claude_path
	claude_path=$(get_nvm_claude_path)

	if [[ -n "$claude_path" ]] && command -v jq &>/dev/null; then
		# Get plugin list
		local plugin_list
		if [[ "$claude_path" =~ ^node\  ]]; then
			local cli_path="${claude_path#node }"
			plugin_list=$(node "$cli_path" plugin list 2>/dev/null || echo "")
		else
			plugin_list=$("$claude_path" plugin list 2>/dev/null || echo "")
		fi

		# Parse for LSP plugins in current project
		for plugin in "pyright-lsp@claude-plugins-official" "typescript-lsp@claude-plugins-official" "gopls-lsp@claude-plugins-official" "rust-analyzer-lsp@claude-plugins-official"; do
			if echo "$plugin_list" | grep -q "$plugin"; then
				# Extract version (appears after plugin name in output)
				local plugin_version
				plugin_version=$(echo "$plugin_list" | grep -A2 "$plugin" | grep "Version:" | awk '{print $2}' | head -1)

				if [[ -n "$plugin_version" ]]; then
					[[ "$first" == false ]] && lsp_plugins_json+=", "
					lsp_plugins_json+="\"$plugin\": \"$plugin_version\""
					first=false
				fi
			fi
		done
	fi

	lsp_plugins_json+="}"

	local installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	# Create lockfile
	cat > "$ISOLATED_LOCKFILE" << EOF
{
  "nodeVersion": "$node_version",
  "claudeCodeVersion": "$claude_version",
  "routerVersion": "$router_version",
  "lspServers": $lsp_servers_json,
  "lspPlugins": $lsp_plugins_json,
  "installedAt": "$installed_at",
  "nvmVersion": "0.39.7"
}
EOF

	chmod 644 "$ISOLATED_LOCKFILE"

	# Validate lockfile was created successfully
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		print_error "Failed to create lockfile: $ISOLATED_LOCKFILE"
		return 1
	fi

	print_success "Lockfile saved: $ISOLATED_LOCKFILE"

	# Show lockfile content for verification
	echo ""
	print_info "Lockfile content:"
	cat "$ISOLATED_LOCKFILE" | grep -E "(nodeVersion|claudeCodeVersion|installedAt)" | sed 's/^/  /'
	echo ""

	# Warn if Claude version is unknown
	if [[ "$claude_version" == "unknown" ]]; then
		print_warning "Claude Code version could not be determined"
		echo "  This may indicate Claude Code is not properly installed."
		echo "  Try: ./iclaude.sh --repair-isolated"
		echo ""
	fi

	print_info "Commit this file to git for reproducibility"
	echo ""

	return 0
}

#######################################
# Install from lockfile
# Returns:
#   0 - success
#   1 - error
#######################################
install_from_lockfile() {
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		print_error "Lockfile not found: $ISOLATED_LOCKFILE"
		echo ""
		echo "Create lockfile first with: iclaude --isolated-install"
		return 1
	fi

	print_info "Installing from lockfile..."
	echo ""

	# Parse lockfile (using grep for portability)
	local node_version=$(grep -oP '"nodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "18")
	local claude_version=$(grep -oP '"claudeCodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "")

	print_info "Node.js version from lockfile: $node_version"
	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		print_info "Claude Code version from lockfile: $claude_version"
	fi
	echo ""

	# Install NVM if needed
	if [[ ! -s "$ISOLATED_NVM_DIR/nvm.sh" ]]; then
		install_isolated_nvm
		if [[ $? -ne 0 ]]; then
			return 1
		fi
	fi

	# Install Node.js
	setup_isolated_nvm
	source "$NVM_DIR/nvm.sh"

	# Remove 'v' prefix if present
	node_version=$(echo "$node_version" | sed 's/^v//')

	nvm install "$node_version"
	nvm use "$node_version"

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Node.js $node_version"
		return 1
	fi

	# Install Claude Code with specific version if available
	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		npm install -g "@anthropic-ai/claude-code@$claude_version"
	else
		npm install -g "@anthropic-ai/claude-code"
	fi

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Claude Code"
		return 1
	fi

	# Install router if version specified in lockfile
	local router_version=$(grep -oP '"routerVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "not installed")

	if [[ "$router_version" != "not installed" ]] && [[ "$router_version" != "unknown" ]]; then
		echo ""
		print_info "Installing Claude Code Router version: $router_version"
		echo ""

		npm install -g "@musistudio/claude-code-router@$router_version"

		if [[ $? -eq 0 ]]; then
			print_success "Router installed: $router_version"
			echo ""
		else
			print_warning "Failed to install router (non-critical)"
			echo ""
		fi
	fi

	# Install LSP servers and plugins from lockfile
	# Check jq dependency
	if ! command -v jq &>/dev/null; then
		print_warning "jq not installed - skipping LSP installation from lockfile"
		echo "   Install jq to enable this feature: sudo apt-get install jq"
		echo ""
	else
		# Install LSP servers from lockfile
		local lsp_servers
		lsp_servers=$(jq -r '.lspServers // {} | keys[]' "$ISOLATED_LOCKFILE" 2>/dev/null)

		if [[ -n "$lsp_servers" ]]; then
			echo ""
			print_info "Installing LSP servers from lockfile..."
			echo ""

			while IFS= read -r server; do
				local version
				version=$(jq -r ".lspServers[\"$server\"]" "$ISOLATED_LOCKFILE")

				case "$server" in
					pyright)
						npm install -g "pyright@$version" || print_warning "pyright install failed"
						;;
					vtsls)
						npm install -g "@vtsls/language-server@$version" || print_warning "vtsls install failed"
						;;
					typescript-language-server)
						npm install -g "typescript-language-server@$version" || print_warning "typescript-language-server install failed"
						;;
				esac
			done <<< "$lsp_servers"

			echo ""
		fi

		# Install LSP plugins from lockfile
		local lsp_plugins
		lsp_plugins=$(jq -r '.lspPlugins // {} | keys[]' "$ISOLATED_LOCKFILE" 2>/dev/null)

		if [[ -n "$lsp_plugins" ]]; then
			print_info "Installing LSP plugins from lockfile..."
			echo ""

			# Get Claude Code path
			local claude_path
			claude_path=$(get_nvm_claude_path)

			if [[ -z "$claude_path" ]]; then
				print_warning "Claude Code not found - skipping plugin installation"
				echo "   Install Claude Code first: ./iclaude.sh --isolated-install"
				echo ""
			else
				while IFS= read -r plugin; do
					local version
					version=$(jq -r ".lspPlugins[\"$plugin\"]" "$ISOLATED_LOCKFILE")

					print_info "Installing $plugin@$version..."

					# Handle both binary and cli.js paths
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						node "$cli_path" plugin install "$plugin" -s project --project-path "$SCRIPT_DIR" || print_warning "Plugin install failed (may already exist)"
					else
						"$claude_path" plugin install "$plugin" -s project --project-path "$SCRIPT_DIR" || print_warning "Plugin install failed (may already exist)"
					fi
				done <<< "$lsp_plugins"

				echo ""
			fi
		fi
	fi

	print_success "Installation from lockfile complete"
	echo ""

	return 0
}

#######################################
# Cleanup isolated NVM installation
# Returns:
#   0 - success
#   1 - error
#######################################
cleanup_isolated_nvm() {
	if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
		print_info "No isolated installation found"
		return 0
	fi

	# Show info
	echo ""
	print_warning "This will delete the isolated NVM installation:"
	echo "  Directory: $ISOLATED_NVM_DIR"
	local size=$(du -sh "$ISOLATED_NVM_DIR" 2>/dev/null | cut -f1 || echo "unknown")
	echo "  Size: $size"
	echo ""
	echo "Lockfile will be preserved for reinstallation:"
	echo "  $ISOLATED_LOCKFILE"
	echo ""

	# Confirm cleanup
	read -p "Continue? (y/N): " confirm

	if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
		print_info "Cleanup cancelled"
		return 0
	fi

	# Remove directory
	rm -rf "$ISOLATED_NVM_DIR"

	print_success "Isolated installation removed"

	if [[ -f "$ISOLATED_LOCKFILE" ]]; then
		print_info "Lockfile preserved: $ISOLATED_LOCKFILE"
	fi

	echo ""
}

#######################################
# Repair isolated environment after git clone
# Restores symlinks and file permissions
# Returns:
#   0 - success
#   1 - error
#######################################
repair_isolated_environment() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Repairing Isolated Environment"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Check if isolated environment exists
	if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
		print_error "Isolated environment not found"
		echo ""
		echo "Directory: $ISOLATED_NVM_DIR"
		echo ""
		echo "Install first with: ./iclaude.sh --isolated-install"
		return 1
	fi

	print_info "Checking isolated environment: $ISOLATED_NVM_DIR"
	echo ""

	local errors=0
	local fixed=0

	# Find Node.js version directory
	local node_version_dir=$(find "$ISOLATED_NVM_DIR/versions/node" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)

	if [[ -z "$node_version_dir" ]]; then
		print_error "No Node.js version found in isolated environment"
		errors=$((errors + 1))
	else
		local node_version=$(basename "$node_version_dir")
		print_info "Found Node.js version: $node_version"
		echo ""

		# Check and repair Node.js binary permissions
		print_info "Checking Node.js binary..."
		local node_bin="$node_version_dir/bin/node"
		if [[ -f "$node_bin" ]]; then
			if [[ ! -x "$node_bin" ]]; then
				chmod +x "$node_bin"
				print_success "  ✓ Fixed: Made node binary executable"
				fixed=$((fixed + 1))
			else
				print_success "  ✓ OK: node binary is executable"
			fi
		else
			print_error "  ✗ MISSING: node binary not found"
			errors=$((errors + 1))
		fi

		# Array of symlinks to check/repair: [link_path]=[target_path]
		declare -A symlinks=(
			["$node_version_dir/bin/npm"]="../lib/node_modules/npm/bin/npm-cli.js"
			["$node_version_dir/bin/npx"]="../lib/node_modules/npm/bin/npx-cli.js"
			["$node_version_dir/bin/corepack"]="../lib/node_modules/corepack/dist/corepack.js"
		)

		echo ""
		print_info "Checking Node.js symlinks..."

		for link_path in "${!symlinks[@]}"; do
			local target="${symlinks[$link_path]}"
			local link_name=$(basename "$link_path")

			# Check if symlink exists and is correct
			if [[ -L "$link_path" ]]; then
				local current_target=$(readlink "$link_path")
				if [[ "$current_target" == "$target" ]]; then
					print_success "  ✓ OK: $link_name → $target"
				else
					print_warning "  ! WRONG: $link_name → $current_target (expected $target)"
					rm -f "$link_path"
					ln -s "$target" "$link_path"
					print_success "  ✓ Fixed: $link_name"
					fixed=$((fixed + 1))
				fi
			elif [[ -e "$link_path" ]]; then
				print_error "  ✗ NOT SYMLINK: $link_name is a regular file"
				errors=$((errors + 1))
			else
				print_warning "  ! MISSING: $link_name"
				ln -s "$target" "$link_path"
				print_success "  ✓ Created: $link_name"
				fixed=$((fixed + 1))
			fi

			# Verify target exists
			local target_full_path=$(dirname "$link_path")/$target
			if [[ ! -f "$target_full_path" ]]; then
				print_error "  ✗ TARGET MISSING: $target_full_path"
				errors=$((errors + 1))
			fi
		done
	fi

	# Check Claude Code symlink in npm-global
	echo ""
	print_info "Checking Claude Code symlink..."

	local claude_link="$ISOLATED_NVM_DIR/npm-global/bin/claude"
	local claude_target="../lib/node_modules/@anthropic-ai/claude-code/cli.js"

	if [[ -L "$claude_link" ]]; then
		local current_target=$(readlink "$claude_link")
		if [[ "$current_target" == "$claude_target" ]]; then
			print_success "  ✓ OK: claude → $claude_target"
		else
			print_warning "  ! WRONG: claude → $current_target"
			rm -f "$claude_link"
			ln -s "$claude_target" "$claude_link"
			print_success "  ✓ Fixed: claude symlink"
			fixed=$((fixed + 1))
		fi
	elif [[ -e "$claude_link" ]]; then
		print_error "  ✗ NOT SYMLINK: claude is a regular file"
		errors=$((errors + 1))
	else
		print_warning "  ! MISSING: claude symlink"
		mkdir -p "$(dirname "$claude_link")"
		ln -s "$claude_target" "$claude_link"
		print_success "  ✓ Created: claude symlink"
		fixed=$((fixed + 1))
	fi

	# Verify Claude Code cli.js exists and is executable
	local claude_cli="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
	if [[ -f "$claude_cli" ]]; then
		if [[ ! -x "$claude_cli" ]]; then
			chmod +x "$claude_cli"
			print_success "  ✓ Fixed: Made cli.js executable"
			fixed=$((fixed + 1))
		fi
	else
		print_error "  ✗ MISSING: Claude Code cli.js not found"
		errors=$((errors + 1))
	fi

	# Summary
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if [[ $errors -eq 0 ]]; then
		print_success "Repair completed successfully"
		if [[ $fixed -gt 0 ]]; then
			echo "  Fixed: $fixed issue(s)"
		else
			echo "  No issues found"
		fi
	else
		print_error "Repair completed with errors"
		echo "  Fixed: $fixed issue(s)"
		echo "  Errors: $errors issue(s)"
		echo ""
		echo "You may need to reinstall:"
		echo "  ./iclaude.sh --cleanup-isolated"
		echo "  ./iclaude.sh --isolated-install"
	fi
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return $errors
}

#######################################
# Check isolated environment status
# Returns:
#   0 - success
#######################################
check_isolated_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Isolated Environment Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Check if isolated NVM exists
	if [[ -d "$ISOLATED_NVM_DIR" ]]; then
		print_success "Isolated NVM: INSTALLED"
		echo "  Location: $ISOLATED_NVM_DIR"
		local size=$(du -sh "$ISOLATED_NVM_DIR" 2>/dev/null | cut -f1 || echo "unknown")
		echo "  Size: $size"

		# Check Node.js version
		setup_isolated_nvm
		if [[ -s "$NVM_DIR/nvm.sh" ]]; then
			source "$NVM_DIR/nvm.sh"

			if command -v node &>/dev/null; then
				echo "  Node.js: $(node --version)"
			fi

			if command -v npm &>/dev/null; then
				echo "  npm: $(npm --version)"
			fi

			# Use explicit path to isolated Claude (avoid PATH conflicts with system NVM)
			local claude_bin="$ISOLATED_NVM_DIR/npm-global/bin/claude"
			if [[ -x "$claude_bin" ]]; then
				echo "  Claude Code: $($claude_bin --version 2>/dev/null | head -n 1 || echo 'unknown')"
			else
				echo "  Claude Code: not installed"
			fi
		fi

		# Check symlinks status
		echo ""
		print_info "Symlinks Status:"

		local node_version_dir=$(find "$ISOLATED_NVM_DIR/versions/node" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)
		local symlink_issues=0

		if [[ -n "$node_version_dir" ]]; then
			# Check Node.js symlinks
			local symlinks=(
				"$node_version_dir/bin/npm"
				"$node_version_dir/bin/npx"
				"$node_version_dir/bin/corepack"
			)

			for link in "${symlinks[@]}"; do
				if [[ -L "$link" ]]; then
					local target=$(readlink "$link")
					local target_full=$(dirname "$link")/$target
					if [[ -f "$target_full" ]]; then
						echo "  ✓ $(basename "$link")"
					else
						echo "  ✗ $(basename "$link") (broken - target missing)"
						symlink_issues=$((symlink_issues + 1))
					fi
				else
					echo "  ✗ $(basename "$link") (missing)"
					symlink_issues=$((symlink_issues + 1))
				fi
			done

			# Check Claude symlink
			local claude_link="$ISOLATED_NVM_DIR/npm-global/bin/claude"
			if [[ -L "$claude_link" ]]; then
				local target=$(readlink "$claude_link")
				local target_full=$(dirname "$claude_link")/$target
				if [[ -f "$target_full" ]]; then
					echo "  ✓ claude"
				else
					echo "  ✗ claude (broken - target missing)"
					symlink_issues=$((symlink_issues + 1))
				fi
			else
				echo "  ✗ claude (missing)"
				symlink_issues=$((symlink_issues + 1))
			fi

			if [[ $symlink_issues -gt 0 ]]; then
				echo ""
				print_warning "  Found $symlink_issues symlink issue(s)"
				echo "  Run: ./iclaude.sh --repair-isolated"
			fi
		fi
	else
		print_warning "Isolated NVM: NOT INSTALLED"
		echo "  Run: iclaude --isolated-install"
	fi

	echo ""

	# Check if lockfile exists
	if [[ -f "$ISOLATED_LOCKFILE" ]]; then
		print_success "Lockfile: PRESENT"
		echo "  File: $ISOLATED_LOCKFILE"
		echo "  Content:"
		cat "$ISOLATED_LOCKFILE" | grep -E "(nodeVersion|claudeCodeVersion|installedAt)" | sed 's/^/    /'
	else
		print_warning "Lockfile: NOT FOUND"
		echo "  Will be created after: iclaude --isolated-install"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}

#######################################
# Setup isolated config directory for Claude Code
# Sets CLAUDE_CONFIG_DIR to isolated location
# Returns:
#   0 - success
#######################################
setup_isolated_config() {
	local isolated_config_dir="${ISOLATED_NVM_DIR}/.claude-isolated"

	# Create isolated config directory if it doesn't exist
	if [[ ! -d "$isolated_config_dir" ]]; then
		mkdir -p "$isolated_config_dir"
		print_info "Created isolated config directory: $isolated_config_dir"
	fi

	# Export CLAUDE_CONFIG_DIR to isolated location
	export CLAUDE_CONFIG_DIR="$isolated_config_dir"

	return 0
}

#######################################
# Check config directory status
# Shows current CLAUDE_CONFIG_DIR and its content
# Returns:
#   0 - success
#######################################
check_config_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Claude Code Configuration Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Determine config directory
	local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

	print_info "Config directory: $config_dir"
	echo ""

	# Check if directory exists
	if [[ ! -d "$config_dir" ]]; then
		print_warning "Config directory does not exist yet"
		echo "  Will be created on first Claude Code run"
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	# Show directory size
	local size=$(du -sh "$config_dir" 2>/dev/null | cut -f1 || echo "unknown")
	echo "  Size: $size"
	echo ""

	# Check key files
	print_info "Key files:"

	local files=(
		".credentials.json:Credentials"
		"history.jsonl:History"
		"settings.json:Settings"
	)

	for file_info in "${files[@]}"; do
		local file="${file_info%%:*}"
		local label="${file_info##*:}"
		local file_path="$config_dir/$file"

		if [[ -f "$file_path" ]]; then
			local file_size=$(du -sh "$file_path" 2>/dev/null | cut -f1 || echo "unknown")
			echo "  ✓ $label ($file): $file_size"
		else
			echo "  ✗ $label ($file): not found"
		fi
	done

	echo ""

	# Check subdirectories
	print_info "Key directories:"

	local dirs=(
		"projects:Projects"
		"session-env:Sessions"
		"file-history:File History"
		"todos:TODOs"
	)

	for dir_info in "${dirs[@]}"; do
		local dir="${dir_info%%:*}"
		local label="${dir_info##*:}"
		local dir_path="$config_dir/$dir"

		if [[ -d "$dir_path" ]]; then
			local dir_size=$(du -sh "$dir_path" 2>/dev/null | cut -f1 || echo "unknown")
			local count=$(find "$dir_path" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)
			echo "  ✓ $label ($dir): $dir_size, $count items"
		else
			echo "  ✗ $label ($dir): not found"
		fi
	done

	echo ""

	# Determine config type
	if [[ "$config_dir" == "$HOME/.claude" ]]; then
		print_info "Configuration type: SHARED (system-wide)"
		echo "  All installations use this config"
	elif [[ "$config_dir" == *".nvm-isolated/.claude-isolated"* ]]; then
		print_info "Configuration type: ISOLATED (project-local)"
		echo "  Only this project uses this config"
	else
		print_info "Configuration type: CUSTOM"
		echo "  Custom CLAUDE_CONFIG_DIR set"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}

#######################################
# Check router status
# Shows router installation, config location, and settings
# Returns:
#   0 - success
#######################################
check_router_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Claude Code Router Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Check if router binary exists
	local ccr_cmd=$(get_router_path "false")

	if [[ -z "$ccr_cmd" ]]; then
		print_warning "Router not installed"
		echo ""
		echo "Install with: ./iclaude.sh --install-router"
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	print_success "Router installed: $ccr_cmd"

	# Show version
	local router_version=$("$ccr_cmd" --version 2>/dev/null | head -1 || echo "unknown")
	if [[ "$router_version" != "unknown" ]]; then
		echo "  Version: $router_version"
	fi
	echo ""

	# Check router config
	local router_config=""
	if [[ -d "$ISOLATED_NVM_DIR" ]]; then
		router_config="$ISOLATED_NVM_DIR/.claude-isolated/router.json"
	else
		router_config="$HOME/.claude/router.json"
	fi

	print_info "Router config location:"
	echo "  $router_config"
	echo ""

	if [[ ! -f "$router_config" ]]; then
		print_warning "Router config not found"
		echo ""
		echo "Create config file at: $router_config"
		echo "Or use template: ${router_config}.example"
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	print_success "Router config exists"

	# Show config size
	local size=$(du -sh "$router_config" 2>/dev/null | cut -f1 || echo "unknown")
	echo "  Size: $size"
	echo ""

	# Parse config and show summary
	print_info "Configuration summary:"

	# Show provider names and default model
	if command -v jq &> /dev/null; then
		local providers=$(jq -r '.providers | keys[]' "$router_config" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
		if [[ -n "$providers" ]]; then
			echo "  Providers: $providers"
		fi

		local default_model=$(jq -r '.routing.default // "not set"' "$router_config" 2>/dev/null)
		echo "  Default model: $default_model"
	else
		echo "  (Install jq for detailed config summary)"
	fi

	echo ""

	# Check if router is configured
	if detect_router "false"; then
		print_success "Router configured and ready"
		echo "  (router.json exists and ccr binary found)"
		echo "  Use --router flag to launch via router"
	else
		print_info "Router not fully configured"
		echo "  Run --install-router to set up router"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}

#######################################
# Check LSP server and plugin installation status
# Returns:
#   0 - always succeeds (informational only)
#######################################
check_lsp_status() {
	# Check jq dependency
	if ! command -v jq &>/dev/null; then
		print_warning "jq not installed - lockfile display unavailable"
		echo "   Install: sudo apt-get install jq (or brew install jq)"
		echo ""
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  LSP Server Status for Isolated Environment"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Check TypeScript server
	if command -v vtsls &>/dev/null || command -v typescript-language-server &>/dev/null; then
		local ts_version
		ts_version=$(vtsls --version 2>/dev/null || typescript-language-server --version 2>/dev/null)
		print_success "TypeScript LSP server: $ts_version"
	else
		print_error "TypeScript LSP server: Not installed"
		echo "   Install: ./iclaude.sh --install-lsp typescript"
	fi
	echo ""

	# Check Python server
	if command -v pyright &>/dev/null; then
		local py_version
		py_version=$(pyright --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
		print_success "Python LSP server: $py_version"
	else
		print_error "Python LSP server: Not installed"
		echo "   Install: ./iclaude.sh --install-lsp python"
	fi
	echo ""

	print_info "LSP Plugins (Claude Code):"
	echo ""

	# Get Claude Code path
	local claude_path
	claude_path=$(get_nvm_claude_path)

	if [[ -z "$claude_path" ]]; then
		print_error "Claude Code not installed - cannot check plugins"
		echo "   Install: ./iclaude.sh --isolated-install"
		echo ""
	else
		# Get plugin list
		local plugin_list
		if [[ "$claude_path" =~ ^node\  ]]; then
			local cli_path="${claude_path#node }"
			plugin_list=$(node "$cli_path" plugin list 2>/dev/null || echo "")
		else
			plugin_list=$("$claude_path" plugin list 2>/dev/null || echo "")
		fi

		# Check TypeScript plugin
		if echo "$plugin_list" | grep -q "typescript-lsp"; then
			local ts_plugin_ver
			ts_plugin_ver=$(echo "$plugin_list" | grep -A2 "typescript-lsp" | grep "Version:" | awk '{print $2}')
			print_success "typescript-lsp plugin: ${ts_plugin_ver:-unknown}"
		else
			print_error "typescript-lsp plugin: Not installed"
			echo "   Install: ./iclaude.sh --install-lsp typescript"
		fi
		echo ""

		# Check Python plugin
		if echo "$plugin_list" | grep -q "pyright-lsp"; then
			local py_plugin_ver
			py_plugin_ver=$(echo "$plugin_list" | grep -A2 "pyright-lsp" | grep "Version:" | awk '{print $2}')
			print_success "pyright-lsp plugin: ${py_plugin_ver:-unknown}"
		else
			print_error "pyright-lsp plugin: Not installed"
			echo "   Install: ./iclaude.sh --install-lsp python"
		fi
		echo ""
	fi

	# Check lockfile tracking
	local lockfile="$SCRIPT_DIR/.nvm-isolated-lockfile.json"
	if [[ -f "$lockfile" ]] && command -v jq &>/dev/null; then
		print_info "Lockfile Tracking:"
		echo "  - LSP Servers:"
		jq -r '.lspServers // {} | to_entries[] | "    \(.key): \(.value)"' "$lockfile" 2>/dev/null || echo "    Not tracked"
		echo "  - LSP Plugins:"
		jq -r '.lspPlugins // {} | to_entries[] | "    \(.key): \(.value)"' "$lockfile" 2>/dev/null || echo "    Not tracked"
		echo ""
	fi

	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}

#######################################
# Export config directory to backup location
# Arguments:
#   $1 - destination directory (required)
# Returns:
#   0 - success
#   1 - error
#######################################
export_config() {
	local dest_dir=$1

	if [[ -z "$dest_dir" ]]; then
		print_error "Destination directory required"
		echo ""
		echo "Usage: $0 --export-config /path/to/backup"
		return 1
	fi

	# Determine config directory
	local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

	# Check if config directory exists
	if [[ ! -d "$config_dir" ]]; then
		print_error "Config directory does not exist: $config_dir"
		echo ""
		echo "Nothing to export"
		return 1
	fi

	print_info "Exporting configuration..."
	echo "  From: $config_dir"
	echo "  To: $dest_dir"
	echo ""

	# Create destination directory
	mkdir -p "$dest_dir"

	# Copy config directory
	cp -r "$config_dir"/* "$dest_dir/" 2>/dev/null || {
		print_error "Failed to export configuration"
		return 1
	}

	local size=$(du -sh "$dest_dir" 2>/dev/null | cut -f1 || echo "unknown")
	print_success "Configuration exported successfully"
	echo "  Size: $size"
	echo "  Location: $dest_dir"
	echo ""

	return 0
}

#######################################
# Import config directory from backup location
# Arguments:
#   $1 - source directory (required)
# Returns:
#   0 - success
#   1 - error
#######################################
import_config() {
	local source_dir=$1

	if [[ -z "$source_dir" ]]; then
		print_error "Source directory required"
		echo ""
		echo "Usage: $0 --import-config /path/to/backup"
		return 1
	fi

	# Check if source directory exists
	if [[ ! -d "$source_dir" ]]; then
		print_error "Source directory does not exist: $source_dir"
		return 1
	fi

	# Determine config directory
	local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

	print_info "Importing configuration..."
	echo "  From: $source_dir"
	echo "  To: $config_dir"
	echo ""

	# Warn if config directory exists
	if [[ -d "$config_dir" ]]; then
		print_warning "Config directory already exists"
		echo "  Existing: $config_dir"
		echo ""
		read -p "Overwrite existing configuration? (y/N): " confirm

		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			print_info "Import cancelled"
			return 0
		fi
		echo ""
	fi

	# Create config directory
	mkdir -p "$config_dir"

	# Copy configuration
	cp -r "$source_dir"/* "$config_dir/" 2>/dev/null || {
		print_error "Failed to import configuration"
		return 1
	}

	# Fix permissions for credentials file
	if [[ -f "$config_dir/.credentials.json" ]]; then
		chmod 600 "$config_dir/.credentials.json"
	fi

	local size=$(du -sh "$config_dir" 2>/dev/null | cut -f1 || echo "unknown")
	print_success "Configuration imported successfully"
	echo "  Size: $size"
	echo "  Location: $config_dir"
	echo ""

	return 0
}

#######################################
# Save credentials to file
# HTTPS proxies: Domain names are PRESERVED (required for OAuth/TLS)
# HTTP proxies: Offers to convert domain to IP (optional, for reliability)
# Returns: final proxy URL (domain preserved for HTTPS, may be IP for HTTP)
#######################################
save_credentials() {
    local proxy_url=$1
    local no_proxy=${2:-localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org}

    # Extract protocol first
    local protocol=$(echo "$proxy_url" | grep -oP '^[^:]+')

    # Extract host from URL to check if it's a domain
    local remainder=$(echo "$proxy_url" | sed 's|^[^:]*://||')
    local host

    # Check if credentials present (contains @)
    if [[ "$remainder" =~ @ ]]; then
        local hostport=$(echo "$remainder" | sed 's|^[^@]*@||')
        host=$(echo "$hostport" | cut -d':' -f1)
    else
        host=$(echo "$remainder" | cut -d':' -f1)
    fi

    # If host is domain (not IP), handle based on protocol
    if ! is_ip_address "$host"; then
        # For HTTPS proxies, NEVER replace domain with IP
        # This is critical for OAuth and TLS (SNI, Host header)
        if [[ "$protocol" == "https" ]]; then
            print_info "Proxy URL contains domain name: $host" >&2
            echo "" >&2
            print_warning "IMPORTANT: Domain name will be preserved for HTTPS proxy" >&2
            print_info "Reason: OAuth/TLS requires proper domain for SNI and Host header" >&2
            print_info "Converting to IP would break authentication token refresh" >&2
            echo "" >&2
        else
            # For HTTP/SOCKS5, offer to resolve (old behavior)
            print_warning "Proxy URL contains domain name instead of IP address: $host" >&2
            echo "" >&2
            print_info "Attempting to resolve domain to IP address..." >&2

            local resolved_ip=$(resolve_domain_to_ip "$host")

            if [[ -n "$resolved_ip" ]]; then
                print_success "Resolved $host → $resolved_ip" >&2
                echo "" >&2
                print_info "Recommendation: Use IP address for better reliability" >&2
                echo "" >&2

                # Offer to replace domain with IP
                read -p "Replace domain with IP address? (Y/n): " -n 1 -r
                echo "" >&2

                if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                    # Replace domain with IP in URL
                    if [[ "$remainder" =~ @ ]]; then
                        # URL has credentials: protocol://user:pass@domain:port
                        local credentials=$(echo "$remainder" | grep -oP '^[^@]+')
                        local port=$(echo "$hostport" | cut -d':' -f2)
                        proxy_url="${protocol}://${credentials}@${resolved_ip}:${port}"
                    else
                        # URL has no credentials: protocol://domain:port
                        local port=$(echo "$remainder" | cut -d':' -f2)
                        proxy_url="${protocol}://${resolved_ip}:${port}"
                    fi
                    print_success "Updated URL to use IP address" >&2
                    # Show new URL with masked password
                    local display_url=$(echo "$proxy_url" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
                    echo "  New URL: $display_url" >&2
                else
                    print_warning "Keeping domain name (not recommended)" >&2
                    print_info "Domain resolution may fail or be unreliable" >&2
                fi
            else
                print_error "Failed to resolve domain: $host" >&2
                print_warning "Saving URL with domain name (may be unreliable)" >&2
            fi
            echo "" >&2
        fi
    fi

    # Create credentials file with restricted permissions
    touch "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    # Save URL, PROXY_INSECURE, PROXY_CA, and NO_PROXY
    cat > "$CREDENTIALS_FILE" << EOF
PROXY_URL=$proxy_url
PROXY_INSECURE=${PROXY_INSECURE:-true}
PROXY_CA=${PROXY_CA:-}
NO_PROXY=$no_proxy
EOF

    print_success "Credentials saved to: $CREDENTIALS_FILE" >&2

    # Return final URL (after possible domain-to-IP conversion)
    echo "$proxy_url"
}

#######################################
# Load credentials from file
#######################################
load_credentials() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        return 1
    fi

    # Source the credentials file
    source "$CREDENTIALS_FILE"

    # Check if old format (single line with URL only)
    if [[ -z "${PROXY_URL:-}" ]]; then
        # Old format: first line is the URL
        PROXY_URL=$(head -n 1 "$CREDENTIALS_FILE")
        NO_PROXY="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    # Export loaded credentials to environment
    if [[ -n "${PROXY_CA:-}" ]] && [[ -f "$PROXY_CA" ]]; then
        export PROXY_CA
        export PROXY_INSECURE=false
    elif [[ "${PROXY_INSECURE:-true}" == "false" ]]; then
        export PROXY_INSECURE=false
    else
        export PROXY_INSECURE=true
    fi

    if [[ -z "$PROXY_URL" ]]; then
        return 1
    fi

    # Validate URL format (allow domains for backward compatibility)
    local validation_result
    validate_proxy_url "$PROXY_URL"
    validation_result=$?

    if [[ $validation_result -eq 1 ]]; then
        # Invalid format
        print_warning "Saved credentials have invalid format, will prompt for new URL" >&2
        return 1
    elif [[ $validation_result -eq 2 ]]; then
        # Domain instead of IP (warn only for HTTP, not HTTPS)
        local protocol=$(echo "$PROXY_URL" | grep -oP '^[^:]+')
        if [[ "$protocol" != "https" ]]; then
            # For HTTP: domain is not recommended
            print_warning "Saved proxy URL uses domain name instead of IP address" >&2
            print_info "Consider updating to IP address for better reliability" >&2
        fi
        # For HTTPS: domain is correct, no warning needed
    fi

    # Set default NO_PROXY if not present (backward compatibility)
    if [[ -z "${NO_PROXY:-}" ]]; then
        NO_PROXY="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    # Return URL and NO_PROXY (pipe-separated for reliable parsing)
    echo "$PROXY_URL|${NO_PROXY}"
    return 0
}

#######################################
# Prompt for proxy URL
#######################################
prompt_proxy_url() {
    local saved_credentials

    # Check if credentials exist
    if saved_credentials=$(load_credentials); then
        # Parse pipe-separated output: URL|NO_PROXY
        local saved_url=$(echo "$saved_credentials" | cut -d'|' -f1)
        local saved_no_proxy=$(echo "$saved_credentials" | cut -d'|' -f2)

        print_info "Saved proxy found" >&2
        echo "" >&2
        # Hide password in display
        local display_url=$(echo "$saved_url" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
        echo "  URL: $display_url" >&2
        echo "" >&2

        # Auto-use saved proxy (no confirmation needed)
        echo "$saved_url|$saved_no_proxy"
        return 0
    fi

    # Prompt for new URL
    echo "" >&2
    print_info "Enter proxy URL" >&2
    echo "" >&2
    echo "Format: protocol://username:password@host:port" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  HTTPS (recommended): https://alice:secret123@proxy.example.com:8118" >&2
    echo "  HTTP (not recommended): http://alice:secret123@192.168.1.100:8118" >&2
    echo "" >&2
    echo "Note: HTTPS proxies REQUIRE domain names (not IPs) for OAuth/TLS to work" >&2
    echo "Supported protocols: https (recommended), http" >&2
    echo "" >&2

    while true; do
        local proxy_url=""
        if [ -t 0 ]; then
            read -p "Proxy URL: " proxy_url >&2
        else
            # Non-interactive mode: cannot prompt for new URL
            print_error "Cannot prompt for proxy URL in non-interactive mode" >&2
            echo "Use: iclaude --proxy <url>" >&2
            exit 1
        fi

        if [[ -z "$proxy_url" ]]; then
            print_error "URL cannot be empty" >&2
            continue
        fi

        local validation_result
        validate_proxy_url "$proxy_url"
        validation_result=$?

        if [[ $validation_result -eq 1 ]]; then
            print_error "Invalid URL format" >&2
            echo "Expected: protocol://[user:pass@]host:port" >&2
            continue
        elif [[ $validation_result -eq 2 ]]; then
            # Domain in URL - check protocol
            local protocol=$(echo "$proxy_url" | grep -oP '^[^:]+')
            if [[ "$protocol" == "https" ]]; then
                # For HTTPS: domain is REQUIRED (no warning)
                print_success "HTTPS proxy with domain name - correct for OAuth/TLS!" >&2
                echo "" >&2
            else
                # For HTTP: domain is not recommended
                print_warning "URL contains domain name instead of IP address" >&2
                echo "Domains may be less reliable than IP addresses" >&2
                echo "Consider using IP address (will be resolved during save)" >&2
                echo "" >&2
            fi
        fi

        # Return URL with default NO_PROXY (pipe-separated)
        echo "$proxy_url|localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
        return 0
    done
}

#######################################
# Configure proxy from URL
#######################################
configure_proxy_from_url() {
    local proxy_url=$1
    local no_proxy=${2:-localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org}
    local final_proxy_url="$proxy_url"

    # Only save credentials if this is a new URL (not loaded from file)
    # Check if credentials file exists and URL matches
    local skip_save=false
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        source "$CREDENTIALS_FILE"
        if [[ "${PROXY_URL:-}" == "$proxy_url" ]]; then
            # URL matches saved credentials - skip save to preserve PROXY_CA and PROXY_INSECURE
            skip_save=true
        fi
    fi

    if [[ "$skip_save" == false ]]; then
        # Save credentials (may convert domain to IP)
        # and get the final URL (possibly with IP instead of domain)
        final_proxy_url=$(save_credentials "$proxy_url" "$no_proxy")
    fi

    # Set environment variables with final URL (after possible domain-to-IP conversion)
    export HTTPS_PROXY="$final_proxy_url"
    export HTTP_PROXY="$final_proxy_url"
    export NO_PROXY="$no_proxy"

    # Configure TLS certificate handling
    if [[ -n "${PROXY_CA:-}" ]] && [[ -f "$PROXY_CA" ]]; then
        # Use provided CA certificate (secure mode)
        export NODE_EXTRA_CA_CERTS="$PROXY_CA"
        print_info "Using proxy CA certificate: $PROXY_CA"
    elif [[ "${PROXY_INSECURE:-true}" == "true" ]]; then
        # Fallback to insecure mode (disable TLS verification)
        export NODE_TLS_REJECT_UNAUTHORIZED=0
        print_warning "TLS certificate verification disabled (insecure mode)"
    fi

    # Configure git to ignore proxy
    configure_git_no_proxy
}

#######################################
# Save current git proxy settings
#######################################
save_git_proxy_settings() {
    # Create backup file with restricted permissions
    touch "$GIT_BACKUP_FILE"
    chmod 600 "$GIT_BACKUP_FILE"

    # Get current git proxy settings (global config)
    local http_proxy=$(git config --global --get http.proxy 2>/dev/null || echo "")
    local https_proxy=$(git config --global --get https.proxy 2>/dev/null || echo "")

    # Save to backup file
    cat > "$GIT_BACKUP_FILE" << EOF
HTTP_PROXY=$http_proxy
HTTPS_PROXY=$https_proxy
EOF
}

#######################################
# Configure git to ignore proxy (deprecated - now we don't modify git config)
#######################################
configure_git_no_proxy() {
    # IMPORTANT: We no longer modify git config globally as it can break other tools
    # Git will automatically use NO_PROXY environment variable if set

    # Just log for information
    print_info "Git will use NO_PROXY for localhost/127.0.0.1 and git hosting services"

    # Note: We keep save_git_proxy_settings call for compatibility with restore function
    # but we don't actually modify git config anymore
}

#######################################
# Restore git proxy settings from backup
#######################################
restore_git_proxy() {
    if [[ ! -f "$GIT_BACKUP_FILE" ]]; then
        print_info "No git proxy backup found"
        return 0
    fi

    # Load backup settings
    source "$GIT_BACKUP_FILE"

    # Restore settings
    if [[ -n "$HTTP_PROXY" ]]; then
        git config --global http.proxy "$HTTP_PROXY"
    else
        git config --global --unset http.proxy 2>/dev/null || true
    fi

    if [[ -n "$HTTPS_PROXY" ]]; then
        git config --global https.proxy "$HTTPS_PROXY"
    else
        git config --global --unset https.proxy 2>/dev/null || true
    fi

    print_success "Git proxy settings restored"

    # Remove backup file
    rm -f "$GIT_BACKUP_FILE"
}

#######################################
# Display proxy info
#######################################
display_proxy_info() {
    local show_password=${1:-false}

    echo ""
    print_success "Proxy configured:"
    echo ""

    if [[ "$show_password" == "true" ]]; then
        echo "  HTTPS_PROXY: $HTTPS_PROXY"
        echo "  HTTP_PROXY:  $HTTP_PROXY"
    else
        # Hide password
        local masked_https=$(echo "$HTTPS_PROXY" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
        local masked_http=$(echo "$HTTP_PROXY" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
        echo "  HTTPS_PROXY: $masked_https"
        echo "  HTTP_PROXY:  $masked_http"
    fi

    echo "  NO_PROXY:    $NO_PROXY"
    echo ""

    # Note: We no longer modify git proxy settings
    # Git respects NO_PROXY environment variable automatically
    print_info "Git will bypass proxy for: localhost, 127.0.0.1, github.com, gitlab.com, bitbucket.org"
    echo ""
}

#######################################
# Test proxy connectivity
#######################################
test_proxy() {
    print_info "Testing proxy connectivity..."

    # Use -x flag to explicitly pass proxy to curl (works better than env vars)
    local proxy_url="${HTTPS_PROXY:-${HTTP_PROXY}}"

    if [[ -z "$proxy_url" ]]; then
        print_warning "No proxy configured, skipping test"
        return 0
    fi

    # Prepare curl command with proxy (use -k for insecure mode by default)
    local curl_opts=(-x "$proxy_url" -k -s -m 5 -o /dev/null -w "%{http_code}")

    # For HTTPS proxies, also use --proxy-insecure
    if [[ "$proxy_url" =~ ^https:// ]]; then
        curl_opts+=(--proxy-insecure)
    fi

    # Test connection through proxy
    local http_code=$(curl "${curl_opts[@]}" https://www.google.com 2>/dev/null)

    if [[ "$http_code" == "200" ]]; then
        print_success "Proxy connection successful"
        return 0
    elif [[ "$http_code" == "000" ]]; then
        print_warning "Proxy connection failed (timeout or refused)"
        echo ""
        echo "  This could mean:"
        echo "  - Proxy server is unreachable or down"
        echo "  - Incorrect credentials"
        echo "  - Firewall blocking the connection"
        echo ""
        echo "  Claude Code may still work if proxy becomes available"
        return 1
    else
        print_warning "Proxy test returned HTTP $http_code (not 200 OK)"
        echo ""
        echo "  Claude Code may still work - the test URL might be blocked"
        return 1
    fi
}

#######################################
# Clear saved credentials
#######################################
clear_credentials() {
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        rm -f "$CREDENTIALS_FILE"
        print_success "Saved credentials cleared"
    else
        print_info "No saved credentials found"
    fi
}

#######################################
# Check OAuth token expiration
# Checks both system and isolated credentials
# Returns:
#   0 - token valid or not found
#   1 - token expired
#   2 - token expiring soon (< 1 hour)
#######################################
check_token_expiration() {
    local warn_threshold=3600  # 1 hour in seconds
    local credentials_files=()

    # Check system credentials
    if [[ -f "$HOME/.claude/.credentials.json" ]]; then
        credentials_files+=("$HOME/.claude/.credentials.json")
    fi

    # Check isolated credentials if exists
    if [[ -f "$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json" ]]; then
        credentials_files+=("$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json")
    fi

    # If no credentials found, skip check
    if [[ ${#credentials_files[@]} -eq 0 ]]; then
        return 0
    fi

    # Check each credentials file
    local most_critical_status=0
    for creds_file in "${credentials_files[@]}"; do
        # Extract expires_at (in milliseconds)
        local expires_ms=$(jq -r '.claudeAiOauth.expiresAt // 0' "$creds_file" 2>/dev/null)

        # Skip if no expiration found or jq failed
        if [[ -z "$expires_ms" || "$expires_ms" == "0" || "$expires_ms" == "null" ]]; then
            continue
        fi

        # Convert to seconds
        local expires_sec=$((expires_ms / 1000))
        local current_sec=$(date +%s)
        local diff=$((expires_sec - current_sec))

        # Determine status
        if [[ $diff -lt 0 ]]; then
            # Token expired
            print_warning "OAuth token EXPIRED $((-diff / 60)) minutes ago"
            print_info "File: $creds_file"
            print_info "Expired at: $(date -d @$expires_sec '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
            echo ""
            print_info "Run '/login' in Claude Code to refresh authentication"
            echo ""
            most_critical_status=1
        elif [[ $diff -lt $warn_threshold ]]; then
            # Token expiring soon
            local minutes=$((diff / 60))
            print_warning "OAuth token expires in $minutes minutes"
            print_info "File: $creds_file"
            print_info "Expires at: $(date -d @$expires_sec '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
            echo ""
            if [[ $most_critical_status -eq 0 ]]; then
                most_critical_status=2
            fi
        fi
    done

    return $most_critical_status
}

#######################################
# Install Node.js and npm
#######################################
install_nodejs() {
    print_info "Installing Node.js and npm..."
    echo ""

    # Use NodeSource setup script for latest LTS
    if curl -fsSL https://deb.nodesource.com/setup_18.x | bash -; then
        if apt-get install -y nodejs; then
            print_success "Node.js and npm installed successfully"
            echo ""
            node --version
            npm --version
            echo ""
            return 0
        else
            print_error "Failed to install Node.js package"
            return 1
        fi
    else
        print_error "Failed to download Node.js setup script"
        return 1
    fi
}

#######################################
# Install Claude Code globally
#######################################
install_claude_code() {
    local using_nvm=false

    # Detect NVM environment
    if detect_nvm; then
        using_nvm=true
        print_info "Detected NVM environment"
        echo ""
    fi

    if [[ "$using_nvm" == true ]]; then
        print_info "Installing Claude Code to NVM environment..."
    else
        print_info "Installing Claude Code globally..."
    fi
    echo ""

    if npm install -g @anthropic-ai/claude-code; then
        print_success "Claude Code installed successfully"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            print_info "Installed to: $(npm prefix -g)/bin/claude"
        fi
        claude --version 2>/dev/null || print_warning "Claude version check failed (may need to restart shell)"
        echo ""
        return 0
    else
        print_error "Failed to install Claude Code"
        return 1
    fi
}

#######################################
# Get Claude Code version
#######################################
get_claude_version() {
    local claude_cmd=""

    # Priority 1: Check NVM environment first
    if detect_nvm; then
        local nvm_claude=$(get_nvm_claude_path)
        if [[ -n "$nvm_claude" ]]; then
            claude_cmd="$nvm_claude"
        fi
    fi

    # Priority 2: Check system locations if NVM not found
    if [[ -z "$claude_cmd" ]]; then
        if command -v claude &> /dev/null; then
            local cmd_path=$(command -v claude)
            # Skip if it's from NVM (already checked)
            if [[ "$cmd_path" != *".nvm"* ]]; then
                claude_cmd="claude"
            fi
        elif [[ -x "/usr/local/bin/claude" ]]; then
            claude_cmd="/usr/local/bin/claude"
        elif [[ -x "/usr/bin/claude" ]]; then
            claude_cmd="/usr/bin/claude"
        else
            local global_npm_prefix=$(npm prefix -g 2>/dev/null)
            if [[ -n "$global_npm_prefix" ]] && [[ -x "$global_npm_prefix/bin/claude" ]]; then
                claude_cmd="$global_npm_prefix/bin/claude"
            fi
        fi
    fi

    if [[ -z "$claude_cmd" ]]; then
        echo "not installed"
        return 1
    fi

    # Get version
    local version=$($claude_cmd --version 2>/dev/null | head -n 1)
    if [[ -z "$version" ]]; then
        echo "unknown"
        return 1
    fi

    echo "$version"
    return 0
}

#######################################
# Check for available updates
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
#######################################
check_update() {
    local skip_isolated="${1:-false}"
    print_info "Checking for Claude Code updates..."
    echo ""

    # Detect NVM environment
    local using_nvm=false
    if detect_nvm "$skip_isolated"; then
        using_nvm=true
    fi

    # Get current version
    local current_version=$(get_claude_version)
    if [[ "$current_version" == "not installed" ]]; then
        print_error "Claude Code is not installed"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            echo "Install with: npm install -g @anthropic-ai/claude-code"
        else
            echo "Install with: sudo iclaude --install"
        fi
        return 1
    fi

    print_info "Current version: $current_version"
    echo ""

    # Get latest version from npm
    print_info "Fetching latest version from npm..."
    local latest_version=$(npm view @anthropic-ai/claude-code version 2>/dev/null)

    if [[ -z "$latest_version" ]]; then
        print_error "Failed to fetch latest version from npm"
        return 1
    fi

    print_info "Latest version:  $latest_version"
    echo ""

    # Compare versions
    if [[ "$current_version" == *"$latest_version"* ]]; then
        print_success "You are running the latest version"
    else
        print_warning "An update is available: $latest_version"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            echo "Run to update: iclaude --update"
            echo "Or directly:   npm install -g @anthropic-ai/claude-code@latest"
        else
            echo "Run to update: sudo iclaude --update"
        fi
    fi

    return 0
}

#######################################
# Cleanup old Claude Code installations (NVM only)
#######################################
cleanup_old_claude_installations() {
	if [[ -z "${NVM_DIR:-}" ]]; then
		return 0  # Only for NVM installations
	fi

	local npm_prefix=$(npm prefix -g 2>/dev/null)
	if [[ -z "$npm_prefix" ]] || [[ "$npm_prefix" != *".nvm"* ]]; then
		return 0  # Not NVM environment
	fi

	local lib_dir="$npm_prefix/lib/node_modules/@anthropic-ai"
	local bin_dir="$npm_prefix/bin"

	if [[ ! -d "$lib_dir" ]]; then
		return 0  # No installations to clean
	fi

	local cleaned=false

	# Find temporary .claude-code-* folders
	local temp_folders=$(find "$lib_dir" -maxdepth 1 -type d -name ".claude-code-*" 2>/dev/null)

	if [[ -n "$temp_folders" ]]; then
		local old_folders=""
		local recent_folders=""
		local current_time=$(date +%s)
		local seven_days_ago=$((current_time - 7*24*60*60))

		# Separate old (>7 days) and recent folders
		while read folder; do
			[[ -z "$folder" ]] && continue
			local mod_time=$(stat -c %Y "$folder" 2>/dev/null || echo "0")
			local folder_version=$(get_cli_version "$folder")
			local folder_name=$(basename "$folder")

			if [[ $mod_time -lt $seven_days_ago ]]; then
				old_folders+="$folder|$folder_version"$'\n'
			else
				recent_folders+="$folder|$folder_version"$'\n'
			fi
		done <<< "$temp_folders"

		# Auto-remove old folders (>7 days)
		if [[ -n "$old_folders" ]]; then
			print_info "Found old temporary installations (>7 days, auto-removing):"
			echo "$old_folders" | while IFS='|' read folder version; do
				[[ -z "$folder" ]] && continue
				echo "  - $(basename "$folder") (version: $version)"
			done
			echo ""

			echo "$old_folders" | while IFS='|' read folder version; do
				[[ -z "$folder" ]] && continue
				if rm -rf "$folder" 2>/dev/null; then
					print_success "Removed: $(basename "$folder")"
					cleaned=true
				else
					print_warning "Failed to remove: $(basename "$folder")"
				fi
			done
			echo ""
		fi

		# Ask for confirmation for recent folders
		if [[ -n "$recent_folders" ]]; then
			print_info "Found recent temporary installations (<7 days):"
			echo "$recent_folders" | while IFS='|' read folder version; do
				[[ -z "$folder" ]] && continue
				echo "  - $(basename "$folder") (version: $version)"
			done
			echo ""

			read -p "Remove recent installations? (Y/n): " confirm
			if [[ -z "$confirm" ]] || [[ "$confirm" =~ ^[Yy]$ ]]; then
				echo "$recent_folders" | while IFS='|' read folder version; do
					[[ -z "$folder" ]] && continue
					if rm -rf "$folder" 2>/dev/null; then
						print_success "Removed: $(basename "$folder")"
						cleaned=true
					else
						print_warning "Failed to remove: $(basename "$folder")"
					fi
				done
				echo ""
			fi
		fi
	fi

	# Find and remove broken symlinks in bin/
	if [[ -d "$bin_dir" ]]; then
		local broken_links=$(find "$bin_dir" -type l -name ".claude-*" ! -exec test -e {} \; -print 2>/dev/null)

		if [[ -n "$broken_links" ]]; then
			print_info "Found broken Claude symlinks:"
			echo "$broken_links" | while read link; do
				echo "  - $(basename "$link")"
			done
			echo ""

			read -p "Remove broken symlinks? (Y/n): " confirm
			if [[ -z "$confirm" ]] || [[ "$confirm" =~ ^[Yy]$ ]]; then
				echo "$broken_links" | while read link; do
					if rm -f "$link" 2>/dev/null; then
						print_success "Removed: $(basename "$link")"
						cleaned=true
					fi
				done
				echo ""
			fi
		fi
	fi

	# Check for incomplete claude-code installation (without cli.js)
	if [[ -d "$lib_dir/claude-code" ]] && [[ ! -f "$lib_dir/claude-code/cli.js" ]]; then
		print_warning "Found incomplete installation: claude-code (no cli.js)"
		echo ""

		read -p "Remove incomplete installation? (Y/n): " confirm
		if [[ -z "$confirm" ]] || [[ "$confirm" =~ ^[Yy]$ ]]; then
			if rm -rf "$lib_dir/claude-code" 2>/dev/null; then
				print_success "Removed incomplete installation"
				cleaned=true
				echo ""
			fi
		fi
	fi

	if [[ "$cleaned" == true ]]; then
		print_success "Cleanup completed"
		echo ""
	fi

	return 0
}

#######################################
# Recreate Claude symlinks after update (NVM only)
#######################################
recreate_claude_symlinks() {
	if [[ -z "${NVM_DIR:-}" ]]; then
		return 0  # Only for NVM installations
	fi

	local npm_prefix=$(npm prefix -g 2>/dev/null)
	if [[ -z "$npm_prefix" ]] || [[ "$npm_prefix" != *".nvm"* ]]; then
		return 0  # Not NVM environment
	fi

	local bin_dir="$npm_prefix/bin"
	local lib_dir="$npm_prefix/lib/node_modules/@anthropic-ai"

	if [[ ! -d "$lib_dir" ]]; then
		return 0  # No installations
	fi

	# Find the actual cli.js (prioritize standard installation)
	local cli_path=""
	if [[ -f "$lib_dir/claude-code/cli.js" ]]; then
		cli_path="$lib_dir/claude-code/cli.js"
		print_info "Found standard installation: claude-code"
	else
		# Find newest temporary installation
		cli_path=$(find "$lib_dir" -maxdepth 2 -name "cli.js" -path "*/.claude-code-*/cli.js" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)
		if [[ -n "$cli_path" ]]; then
			local temp_name=$(basename $(dirname "$cli_path"))
			print_info "Found temporary installation: $temp_name"
		fi
	fi

	if [[ -z "$cli_path" ]] || [[ ! -f "$cli_path" ]]; then
		print_error "Cannot find Claude Code cli.js"
		return 1
	fi

	print_info "Recreating Claude symlinks..."

	# Remove all old Claude symlinks (both standard and temporary)
	rm -f "$bin_dir/claude" "$bin_dir/.claude-"* 2>/dev/null

	# Create new standard symlink
	ln -sf "$cli_path" "$bin_dir/claude"
	chmod +x "$bin_dir/claude"

	local install_name=$(basename $(dirname "$cli_path"))
	print_success "Symlink created: claude -> $install_name/cli.js"

	# Show version
	local version=$(get_cli_version "$cli_path")
	if [[ "$version" != "unknown" ]]; then
		print_info "Symlink points to version: $version"
	fi

	return 0
}

#######################################
# Update Claude Code
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
#######################################
update_claude_code() {
    local skip_isolated="${1:-false}"
    local using_nvm=false

    # Detect NVM environment
    if detect_nvm "$skip_isolated"; then
        using_nvm=true
        print_info "Detected NVM environment"
        echo ""
    fi

    # Check if this is isolated environment and source nvm.sh
    local is_isolated=false
    if [[ -d "$ISOLATED_NVM_DIR" ]] && [[ "${NVM_DIR:-}" == "$ISOLATED_NVM_DIR" ]]; then
        is_isolated=true
        # Source NVM for isolated environment (required for correct npm operation)
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            source "$NVM_DIR/nvm.sh"
            print_info "Using isolated NVM environment"
            echo ""
        else
            print_error "NVM not found in isolated environment"
            echo ""
            echo "Directory: $ISOLATED_NVM_DIR"
            echo "Expected: $NVM_DIR/nvm.sh"
            echo ""
            echo "Try reinstalling with: ./iclaude.sh --isolated-install"
            exit 1
        fi
    fi

    # Check if running with sudo (only required for system installations)
    if [[ "$using_nvm" == false ]] && [[ $EUID -ne 0 ]]; then
        print_error "Update requires sudo privileges for system installation"
        echo ""
        echo "Run: sudo $0 --update"
        exit 1
    fi

    # Warn if using sudo with NVM
    if [[ "$using_nvm" == true ]] && [[ $EUID -eq 0 ]]; then
        print_warning "Running with sudo, but NVM installation detected"
        print_warning "This will update the system installation, not NVM"
        echo ""
        read -p "Continue with system update? (y/N): " confirm_sudo
        if [[ ! "$confirm_sudo" =~ ^[Yy]$ ]]; then
            print_info "Update cancelled"
            echo ""
            echo "Run without sudo to update NVM installation:"
            echo "  iclaude --update"
            exit 0
        fi
        using_nvm=false  # Treat as system installation
    fi

    print_info "Updating Claude Code..."
    echo ""

    # Get current version
    local current_version=$(get_claude_version)
    if [[ "$current_version" == "not installed" ]]; then
        print_error "Claude Code is not installed"
        echo ""
        if [[ "$using_nvm" == true ]]; then
            echo "Install first with: npm install -g @anthropic-ai/claude-code"
        else
            echo "Install first with: sudo iclaude --install"
        fi
        exit 1
    fi

    print_info "Current version: $current_version"
    echo ""

    # Get latest version
    local latest_version=$(npm view @anthropic-ai/claude-code version 2>/dev/null)
    if [[ -n "$latest_version" ]]; then
        print_info "Latest version:  $latest_version"
        echo ""
    fi

    # Check if already up to date
    if [[ "$current_version" == *"$latest_version"* ]]; then
        print_success "Already running the latest version"
        echo ""

        # For isolated environment, update lockfile even if version is current
        if [[ "$using_nvm" == true ]] && [[ "$is_isolated" == true ]]; then
            print_info "Updating lockfile to reflect current state..."
            save_isolated_lockfile
        fi

        return 0
    fi

    # Confirm update
    read -p "Proceed with update? (Y/n): " confirm_update
    if [[ -n "$confirm_update" ]] && [[ ! "$confirm_update" =~ ^[Yy]$ ]]; then
        print_info "Update cancelled"
        return 0
    fi

    echo ""

    # Pre-update cleanup: Remove ALL symlinks and temporary installations (NVM only)
    if [[ "$using_nvm" == true ]]; then
        local npm_prefix=$(npm prefix -g 2>/dev/null)
        if [[ -n "$npm_prefix" ]] && [[ "$npm_prefix" == *".nvm"* ]]; then
            local bin_dir="$npm_prefix/bin"
            local lib_dir="$npm_prefix/lib/node_modules/@anthropic-ai"

            print_info "Pre-update cleanup..."

            # Remove ALL Claude symlinks (both broken and working) to avoid EEXIST errors
            if [[ -d "$bin_dir" ]]; then
                rm -f "$bin_dir/claude" "$bin_dir/.claude-"* 2>/dev/null
                print_info "Removed existing symlinks"
            fi

            # Remove ALL temporary .claude-code-* folders to avoid ENOTEMPTY errors
            if [[ -d "$lib_dir" ]]; then
                local temp_folders=$(find "$lib_dir" -maxdepth 1 -type d -name ".claude-code-*" 2>/dev/null)
                if [[ -n "$temp_folders" ]]; then
                    echo "$temp_folders" | while read folder; do
                        [[ -z "$folder" ]] && continue
                        rm -rf "$folder" 2>/dev/null
                        print_info "Removed old temporary installation: $(basename "$folder")"
                    done
                fi
            fi

            # Remove incomplete claude-code installation (without cli.js)
            if [[ -d "$lib_dir/claude-code" ]] && [[ ! -f "$lib_dir/claude-code/cli.js" ]]; then
                print_info "Removing incomplete installation: claude-code"
                rm -rf "$lib_dir/claude-code" 2>/dev/null
            fi

            echo ""
        fi
    fi

    if [[ "$using_nvm" == true ]]; then
        print_info "Installing update to NVM environment..."
    else
        print_info "Installing update to system..."
    fi
    echo ""

    # Update via npm (use install instead of update for npm 10+ compatibility)
    if npm install -g @anthropic-ai/claude-code@latest; then
        echo ""

        # Clear bash command hash cache BEFORE checking version
        hash -r 2>/dev/null || true

        # Verify installation success using universal get_claude_version (works for NVM and system)
        local new_version=$(get_claude_version)
        if [[ "$new_version" == "not installed" ]] || [[ "$new_version" == "unknown" ]]; then
            print_error "Update installed but Claude Code not found"
            echo ""
            echo "The npm install succeeded but Claude Code is not accessible."
            echo "This might be due to temporary installation files."
            echo ""
            echo "Try running cleanup again:"
            echo "  iclaude --update"
            echo ""
            echo "Or manually:"
            echo "  npm uninstall -g @anthropic-ai/claude-code"
            echo "  npm install -g @anthropic-ai/claude-code@latest"
            return 1
        fi

        print_success "Claude Code updated successfully"
        echo ""
        print_info "New version: $new_version"
        echo ""

        # Cleanup old installations after successful update (NVM only)
        if [[ "$using_nvm" == true ]]; then
            # Use is_isolated variable set at the beginning of function
            if [[ "$is_isolated" == true ]]; then
                # Isolated environment: Repair FIRST, then update lockfile
                print_info "Repairing symlinks and permissions..."
                repair_isolated_environment
                echo ""

                print_info "Updating lockfile..."
                save_isolated_lockfile
            else
                # System NVM: Standard cleanup
                cleanup_old_claude_installations
                echo ""

                # Recreate symlinks to point to the newest installation
                recreate_claude_symlinks
                echo ""
            fi
        fi

        # Check if version actually updated
        if [[ "$new_version" != *"$latest_version"* ]]; then
            print_warning "Version still shows: $new_version"
            echo ""
            echo "The update was installed but your shell may be using a cached version."
            echo "Please restart your terminal or run: hash -r"
        fi

        return 0
    else
        echo ""
        print_error "Failed to update Claude Code"
        echo ""

        # Suggest cleanup if it's an NVM installation
        if [[ "$using_nvm" == true ]]; then
            echo "If you see ENOTEMPTY errors, try:"
            echo "  1. Run: iclaude --update (cleanup will run automatically)"
            echo "  2. Or manually remove old installations:"
            echo "     rm -rf ~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/.claude-code-*"
            echo ""
        fi

        echo "Or try manually:"
        echo "  npm install -g @anthropic-ai/claude-code@latest"
        return 1
    fi
}

#######################################
# Check and install dependencies
#######################################
check_dependencies() {
    local needs_install=false

    echo ""
    print_info "Checking dependencies..."
    echo ""

    # Check npm
    if ! command -v npm &> /dev/null; then
        print_warning "npm not found"
        needs_install=true

        read -p "Install Node.js and npm? (Y/n): " install_node
        if [[ -z "$install_node" ]] || [[ "$install_node" =~ ^[Yy]$ ]]; then
            if ! install_nodejs; then
                print_error "Cannot proceed without npm"
                exit 1
            fi
        else
            print_error "npm is required to run Claude Code"
            echo ""
            echo "Install manually:"
            echo "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
            echo "  sudo apt-get install -y nodejs"
            exit 1
        fi
    else
        print_success "npm found: $(npm --version)"

        # Detect and show NVM info
        if detect_nvm; then
            local npm_prefix=$(npm prefix -g 2>/dev/null)
            print_info "NVM environment detected"
            if [[ -n "$npm_prefix" ]]; then
                print_info "Global packages location: $npm_prefix"
            fi
        fi
    fi

    # Check Claude Code (check multiple locations, prioritize NVM)
    local claude_found=false

    # Check NVM first
    if detect_nvm; then
        local nvm_claude=$(get_nvm_claude_path)
        if [[ -n "$nvm_claude" ]]; then
            claude_found=true
        fi
    fi

    # Check system locations if not found in NVM
    if [[ "$claude_found" == false ]]; then
        if command -v claude &> /dev/null; then
            local cmd_path=$(command -v claude)
            # Don't count NVM paths here (already checked)
            if [[ "$cmd_path" != *".nvm"* ]]; then
                claude_found=true
            fi
        elif [[ -x "/usr/local/bin/claude" || -x "/usr/bin/claude" ]]; then
            claude_found=true
        else
            # Check npm global prefix (non-NVM)
            local global_npm_prefix=$(npm prefix -g 2>/dev/null)
            if [[ -n "$global_npm_prefix" ]] && [[ "$global_npm_prefix" != *".nvm"* ]]; then
                if [[ -x "$global_npm_prefix/bin/claude" ]] || ls "$global_npm_prefix/bin/.claude-"* &>/dev/null; then
                    claude_found=true
                fi
            fi
        fi
    fi

    if [[ "$claude_found" == false ]]; then
        print_warning "Claude Code not found"
        needs_install=true

        echo ""
        read -p "Install Claude Code globally? (Y/n): " install_claude
        if [[ -z "$install_claude" ]] || [[ "$install_claude" =~ ^[Yy]$ ]]; then
            if ! install_claude_code; then
                print_error "Cannot proceed without Claude Code"
                exit 1
            fi
        else
            print_warning "Claude Code is not installed"
            echo ""
            echo "Install manually:"
            echo "  npm install -g @anthropic-ai/claude-code"
            echo ""
            echo "You can still install iclaude, but it won't work until Claude Code is installed."
            read -p "Continue anyway? (y/N): " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_success "Claude Code found"
    fi

    echo ""
}

#######################################
# Install script globally
#######################################
install_script() {
    local script_path="${BASH_SOURCE[0]}"
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Installation requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --install"
        exit 1
    fi

    # Check and install dependencies
    check_dependencies

    # Check if already installed
    if [[ -L "$target_path" ]]; then
        local current_target=$(readlink -f "$target_path")
        local script_realpath=$(readlink -f "$script_path")

        if [[ "$current_target" == "$script_realpath" ]]; then
            print_info "Already installed at: $target_path"
            return 0
        else
            print_warning "Different version found at: $target_path"
            echo "  Current: $current_target"
            echo "  New:     $script_realpath"
            echo ""
            read -p "Replace existing installation? (y/N): " replace

            if [[ ! "$replace" =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                return 1
            fi
        fi
    fi

    # Create symlink
    ln -sf "$(readlink -f "$script_path")" "$target_path"
    chmod +x "$target_path"

    print_success "Installed to: $target_path"
    echo ""
    echo "You can now run: iclaude"
}

#######################################
# Uninstall script
#######################################
uninstall_script() {
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Uninstallation requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --uninstall"
        exit 1
    fi

    # Check if installed
    if [[ ! -e "$target_path" ]]; then
        print_info "Not installed (no file at $target_path)"
        return 0
    fi

    # Remove symlink
    rm -f "$target_path"
    print_success "Uninstalled from: $target_path"
}

#######################################
# Create global symlink using isolated environment
# (Does NOT require system npm - uses .nvm-isolated/)
#######################################
create_symlink_only() {
    local script_path="${BASH_SOURCE[0]}"
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Creating symlink requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --create-symlink"
        exit 1
    fi

    echo ""
    print_info "Checking isolated environment..."
    echo ""

    # Check if isolated environment exists
    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found"
        echo ""
        echo "The isolated environment is required for --create-symlink"
        echo "This allows you to install globally WITHOUT system npm!"
        echo ""
        echo "First, install isolated environment:"
        echo "  ./iclaude.sh --isolated-install"
        echo ""
        echo "Then create symlink:"
        echo "  sudo ./iclaude.sh --create-symlink"
        exit 1
    fi

    # Verify isolated environment is functional
    local claude_cli="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    if [[ ! -f "$claude_cli" ]]; then
        print_error "Claude Code not found in isolated environment"
        echo ""
        echo "Run: ./iclaude.sh --isolated-install"
        exit 1
    fi

    print_success "Isolated environment found and functional"
    echo "  Location: $ISOLATED_NVM_DIR"
    echo "  Claude Code: $claude_cli"
    echo ""

    # Check if already installed
    if [[ -L "$target_path" ]]; then
        local current_target=$(readlink -f "$target_path")
        local script_realpath=$(readlink -f "$script_path")

        if [[ "$current_target" == "$script_realpath" ]]; then
            print_success "Already installed at: $target_path"
            echo ""
            echo "You can now run: iclaude"
            return 0
        else
            print_warning "Different installation found at: $target_path"
            echo "  Current: $current_target"
            echo "  New:     $script_realpath"
            echo ""
            echo "Remove existing installation first:"
            echo "  sudo iclaude --uninstall-symlink"
            return 1
        fi
    fi

    # Create symlink
    ln -sf "$(readlink -f "$script_path")" "$target_path"
    chmod +x "$target_path"

    echo ""
    print_success "Global symlink created successfully!"
    echo ""
    echo "  Symlink: $target_path"
    echo "  Target:  $(readlink -f "$script_path")"
    echo ""
    print_info "Using isolated environment (NO system npm required):"
    echo "  Node.js: $(find "$ISOLATED_NVM_DIR/versions/node" -name node -type f 2>/dev/null | head -1)"
    echo "  Claude Code: $claude_cli"
    echo ""
    echo "You can now run: iclaude"
}

#######################################
# Remove global symlink only (keeps isolated environment)
#######################################
uninstall_symlink_only() {
    local target_path="/usr/local/bin/iclaude"

    # Check if running with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "Removing symlink requires sudo privileges"
        echo ""
        echo "Run: sudo $0 --uninstall-symlink"
        exit 1
    fi

    echo ""

    # Check if symlink exists
    if [[ ! -e "$target_path" ]]; then
        print_info "Symlink not found at: $target_path"
        echo ""
        echo "Nothing to remove"
        return 0
    fi

    # Show what will be removed
    if [[ -L "$target_path" ]]; then
        local link_target=$(readlink -f "$target_path")
        print_info "Removing symlink:"
        echo "  Symlink: $target_path"
        echo "  Target:  $link_target"
    else
        print_warning "File at $target_path is not a symlink"
        echo ""
        read -p "Remove anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            return 1
        fi
    fi

    # Remove symlink
    rm -f "$target_path"

    echo ""
    print_success "Symlink removed successfully"
    echo ""
    print_info "Note: Isolated environment is preserved"
    echo "  Location: $ISOLATED_NVM_DIR"
    echo "  To use locally: ./iclaude.sh"
    echo "  To recreate symlink: sudo ./iclaude.sh --create-symlink"
}

#######################################
# Check OAuth token expiration and handle renewal
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   0 - Token valid or doesn't exist
#   1 - Token expired and requires login
#######################################
check_oauth_token() {
    local skip_isolated="${1:-false}"

    # Determine credentials file path
    local credentials_file=""

    if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
        # Use isolated config
        credentials_file="$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json"
    else
        # Use system config
        credentials_file="$HOME/.claude/.credentials.json"
    fi

    # If credentials file doesn't exist, nothing to check
    if [[ ! -f "$credentials_file" ]]; then
        return 0
    fi

    # Validate jq is installed
    if ! validate_jq_installed; then
        print_warning "Cannot check token expiration without jq - skipping check"
        return 0
    fi

    # Extract expiresAt field using jq with specific JSON path
    # CRITICAL: Use .claudeAiOauth.expiresAt to avoid matching mcpOAuth.*.expiresAt
    local expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' "$credentials_file" 2>/dev/null)

    # If we couldn't parse expiresAt or it's invalid, show warning and skip check
    if [[ -z "$expires_at" || "$expires_at" == "0" || "$expires_at" == "null" ]]; then
        print_warning "OAuth token expiration not found in: $credentials_file"
        print_info "Run '/login' in Claude Code if you encounter authentication issues"
        return 0
    fi

    # Validate that expires_at is a number (catches jq errors)
    if ! [[ "$expires_at" =~ ^[0-9]+$ ]]; then
        print_warning "Invalid token expiration format in: $credentials_file"
        print_info "Expected numeric timestamp, got: $expires_at"
        return 0
    fi

    # Get current time in milliseconds
    local current_time_ms=$(($(date +%s) * 1000))

    # Calculate time remaining in seconds
    local time_remaining_ms=$((expires_at - current_time_ms))
    local time_remaining_sec=$((time_remaining_ms / 1000))
    local time_remaining_min=$((time_remaining_sec / 60))

    # If token is expired or will expire within threshold (7 days default)
    if [[ $time_remaining_sec -le $TOKEN_REFRESH_THRESHOLD ]]; then
        echo ""
        if [[ $time_remaining_sec -le 0 ]]; then
            print_warning "OAuth token has expired"
        else
            local days_remaining=$((time_remaining_sec / 86400))
            local hours_remaining=$(((time_remaining_sec % 86400) / 3600))
            if [[ $days_remaining -gt 0 ]]; then
                print_warning "OAuth token expires in ${days_remaining}d ${hours_remaining}h"
            else
                print_warning "OAuth token expires in $time_remaining_min minutes"
            fi
        fi
        print_info "File: $credentials_file"
        echo ""

        # Try to refresh the token automatically
        print_info "Attempting to refresh token automatically..."
        echo ""

        if refresh_oauth_token "$skip_isolated"; then
            echo ""
            print_success "Token refreshed successfully!"
            return 0
        else
            echo ""
            print_warning "Automatic token refresh failed"
            print_info "Please run '/login' in Claude Code to authenticate"
            # Don't delete credentials - refreshToken might still be usable by Claude Code
            return 1
        fi
    fi

    # Token is valid - show remaining time if less than 1 hour
    if [[ $time_remaining_min -lt 60 ]]; then
        print_warning "OAuth token expires in $time_remaining_min minutes"
        print_info "File: $credentials_file"
        # Safely calculate timestamp (already validated as numeric above)
        local expires_sec=$((expires_at / 1000))
        local expires_date=$(date -d "@${expires_sec}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
        print_info "Expires at: $expires_date"
        echo ""
    fi

    return 0
}

#######################################
# Refresh OAuth token using setup-token
# Uses 'claude setup-token' to generate a long-lived token (~1 year)
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   0 - Token refreshed successfully
#   1 - Failed to refresh token
#######################################
refresh_oauth_token() {
    local skip_isolated="${1:-false}"

    print_info "Generating new long-lived OAuth token..."
    echo ""

    # Determine which claude binary to use
    local claude_cmd=""

    if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
        # Try isolated environment first
        if detect_nvm "false"; then
            claude_cmd=$(get_nvm_claude_path)
        fi
    else
        # Try system installation
        if detect_nvm "true"; then
            claude_cmd=$(get_nvm_claude_path)
        fi
    fi

    # Fallback to which claude
    if [[ -z "$claude_cmd" ]]; then
        claude_cmd=$(which claude 2>/dev/null || true)
    fi

    if [[ -z "$claude_cmd" ]]; then
        print_error "Claude Code not found. Cannot refresh token."
        return 1
    fi

    print_info "Using: $claude_cmd"
    echo ""

    # Run setup-token command
    # This opens browser for OAuth and creates long-lived token
    if "$claude_cmd" setup-token; then
        echo ""
        print_success "Long-lived OAuth token created successfully!"
        print_info "Token is valid for approximately 1 year"
        return 0
    else
        echo ""
        print_error "Failed to generate token"
        print_info "Please run '/login' manually in Claude Code"
        return 1
    fi
}

#######################################
# Validate that jq is installed
# Required for parsing JSON credentials file
# Returns:
#   0 - jq is installed
#   1 - jq is not installed
#######################################
validate_jq_installed() {
    if ! command -v jq &>/dev/null; then
        print_error "jq is not installed. Cannot parse credentials file."
        print_info "Install jq: sudo apt-get install jq (Debian/Ubuntu) or brew install jq (macOS)"
        return 1
    fi
    return 0
}

#######################################
# Launch Claude Code
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
#   Remaining arguments: passed to Claude Code
#######################################
launch_claude() {
    local skip_isolated="${1:-false}"
    shift  # Remove first argument, rest are Claude args

    # Check OAuth token expiration before launching
    check_oauth_token "$skip_isolated"

    # NEW: Check if router should be used (only if --router flag is set)
    local use_router=false
    if [[ "$USE_ROUTER_FLAG" == "true" ]] && detect_router "$skip_isolated"; then
        use_router=true
    fi

    echo ""
    if [[ "$use_router" == "true" ]]; then
        print_info "Launching Claude Code via Router..."
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
    echo ""

    # Pass through any additional arguments
    # Use eval if command contains spaces (e.g., "node /path/to/cli.js")
    if [[ "$claude_cmd" == *" "* ]]; then
        eval exec "$claude_cmd" '"$@"'
    else
        exec "$claude_cmd" "$@"
    fi
}

#######################################
# Show usage
#######################################
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
  --install-from-lockfile           Install from .nvm-isolated-lockfile.json (reproducible setup)
  --check-isolated                  Show status of isolated environment
  --cleanup-isolated                Remove isolated environment (keeps lockfile)
  --repair-isolated                 Repair symlinks and permissions after git clone
  --isolated-config                 Use isolated config directory (automatic for isolated install)
  --shared-config                   Use shared config directory (default: ~/.claude/)
  --check-config                    Show current configuration directory status
  --refresh-token                   Refresh OAuth token using setup-token (long-lived ~1 year)
  --export-config DIR               Export configuration to backup directory
  --import-config DIR               Import configuration from backup directory
  --install-router                  Install Claude Code Router in isolated environment
  --check-router                    Show router status and configuration
  --router                          Launch via Claude Code Router (requires router.json)
  --install-lsp [LANGUAGES]         Install LSP servers+plugins (typescript, python, go, rust)
                                    Default: typescript and python
                                    Examples: --install-lsp | --install-lsp python | --install-lsp typescript go
  --check-lsp                       Show LSP server and plugin installation status
  --no-test                         Skip proxy connectivity test
  --show-password                   Display password in output (default: masked)
  --save                            Enable permission checks (disables default --dangerously-skip-permissions)
  --system                          Force system installation (skip isolated environment)

EXAMPLES:
  # Install globally (run once)
  sudo $0 --install

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

  # Enable permission checks (safe mode)
  iclaude --save

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

CREDENTIALS:
  - Saved to: ${CREDENTIALS_FILE}
  - File permissions: 600 (owner read/write only)
  - Automatically excluded from git (.gitignore)
  - Reused on subsequent runs (prompt to confirm/change)
  - Includes: PROXY_URL, NO_PROXY

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

#######################################
# Main
#######################################
main() {
    local test_mode=false
    local skip_test=false
    local show_password=false
    local proxy_url=""
    local skip_permissions=true  # По умолчанию используется --dangerously-skip-permissions
    local no_proxy=false
    local use_system=false
    local use_isolated_config=false
    local use_shared_config=false
    local claude_args=()
    local USE_ROUTER_FLAG=false

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
            --router)
                USE_ROUTER_FLAG=true
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
            --save)
                skip_permissions=false  # Отключаем --dangerously-skip-permissions для безопасного режима
                shift
                ;;
            --system)
                use_system=true
                shift
                ;;
            --isolated-config)
                use_isolated_config=true
                shift
                ;;
            --shared-config)
                use_shared_config=true
                shift
                ;;
            --check-config)
                check_config_status
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
        print_info "Using isolated configuration: $CLAUDE_CONFIG_DIR"
        echo ""
    elif [[ "$use_shared_config" == false ]] && [[ "$use_system" == false ]] && [[ -d "$ISOLATED_NVM_DIR" ]] && [[ "$USE_ISOLATED_BY_DEFAULT" == true ]]; then
        # Auto-enable isolated config for isolated installations (unless --shared-config)
        setup_isolated_config
        print_info "Using isolated configuration (automatic): $CLAUDE_CONFIG_DIR"
        echo ""
    else
        # Use shared config (default)
        if [[ "$use_shared_config" == true ]]; then
            print_info "Using shared configuration: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
            echo ""
        fi
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

        # Add --dangerously-skip-permissions by default (unless --save is used)
        if [[ "$skip_permissions" == true ]]; then
            claude_args+=("--dangerously-skip-permissions")
        fi

        # Launch Claude Code without proxy
        launch_claude "$use_system" "${claude_args[@]}"
        exit 0
    fi

    # Get proxy URL (from argument, saved file, or prompt)
    local proxy_credentials
    local proxy_no_proxy=""
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
    local proxy_test_passed=true
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

    # Add --dangerously-skip-permissions by default (unless --save is used)
    if [[ "$skip_permissions" == true ]]; then
        claude_args+=("--dangerously-skip-permissions")
    fi

    # Launch Claude Code
    launch_claude "$use_system" "${claude_args[@]}"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
