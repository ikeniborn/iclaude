#!/bin/bash

#######################################
# init_claude.sh - Initialize Claude Code with HTTP Proxy
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
# Validate proxy URL format
#######################################
validate_proxy_url() {
    local url=$1

    # Regex: http(s)://[user:pass@]host:port
    if [[ ! "$url" =~ ^(http|https|socks5)://.*:[0-9]+$ ]]; then
        return 1
    fi

    return 0
}

#######################################
# Validate certificate file (PEM format)
#######################################
validate_certificate_file() {
    local cert_path=$1

    # Check if file exists
    if [[ ! -f "$cert_path" ]]; then
        print_error "Certificate file not found: $cert_path"
        return 1
    fi

    # Check if file is readable
    if [[ ! -r "$cert_path" ]]; then
        print_error "Certificate file not readable: $cert_path"
        return 1
    fi

    # Check if file contains PEM certificate markers
    if ! grep -q "BEGIN CERTIFICATE" "$cert_path" 2>/dev/null; then
        print_error "Invalid certificate format (PEM expected): $cert_path"
        echo ""
        echo "Expected PEM format with '-----BEGIN CERTIFICATE-----' marker"
        return 1
    fi

    # Optionally verify with openssl (if available)
    if command -v openssl &> /dev/null; then
        if ! openssl x509 -in "$cert_path" -noout 2>/dev/null; then
            print_error "Certificate validation failed (openssl): $cert_path"
            return 1
        fi
    fi

    return 0
}

#######################################
# Show help for exporting proxy certificate
#######################################
export_proxy_certificate_help() {
    local proxy_host=${1:-proxy.example.com}
    local proxy_port=${2:-8118}

    cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Как экспортировать сертификат HTTPS прокси
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${BLUE}Метод 1: Используя openssl${NC}

  openssl s_client -showcerts -connect ${proxy_host}:${proxy_port} < /dev/null 2>/dev/null | \\
    openssl x509 -outform PEM > proxy-cert.pem

${BLUE}Метод 2: Используя браузер${NC}

  1. Откройте настройки прокси в браузере
  2. Подключитесь через прокси к любому HTTPS сайту
  3. Нажмите на иконку замка в адресной строке
  4. Просмотр сертификата → Экспорт → Выберите формат PEM
  5. Сохраните как proxy-cert.pem

${BLUE}Метод 3: Если у вас есть доступ к прокси-серверу${NC}

  Найдите файл сертификата (обычно .crt, .pem, .cer) в конфигурации
  прокси-сервера и скопируйте его.

${BLUE}После экспорта используйте:${NC}

  init_claude --proxy https://user:pass@${proxy_host}:${proxy_port} \\
              --proxy-ca /path/to/proxy-cert.pem

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
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
#######################################
detect_nvm() {
	# Priority 1: Check for isolated environment (if enabled by default)
	if [[ "$USE_ISOLATED_BY_DEFAULT" == "true" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
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

	# Add isolated paths to PATH (prepend to prioritize isolated over system)
	export PATH="$NPM_CONFIG_PREFIX/bin:$NVM_DIR/versions/node/*/bin:$PATH"

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
		echo "Run: init_claude --isolated-install first"
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
		echo "Run: init_claude --isolated-install first"
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

	# Try to get Claude version
	if command -v claude &>/dev/null; then
		claude_version=$(claude --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
	else
		claude_version="unknown"
	fi

	local installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	# Create lockfile
	cat > "$ISOLATED_LOCKFILE" << EOF
{
  "nodeVersion": "$node_version",
  "claudeCodeVersion": "$claude_version",
  "installedAt": "$installed_at",
  "nvmVersion": "0.39.7"
}
EOF

	chmod 644 "$ISOLATED_LOCKFILE"
	print_success "Lockfile saved: $ISOLATED_LOCKFILE"
	print_info "Commit this file to git for reproducibility"
	echo ""
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
		echo "Create lockfile first with: init_claude --isolated-install"
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
		echo "Install first with: ./init_claude.sh --isolated-install"
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
		echo "  ./init_claude.sh --cleanup-isolated"
		echo "  ./init_claude.sh --isolated-install"
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
				echo "  Run: ./init_claude.sh --repair-isolated"
			fi
		fi
	else
		print_warning "Isolated NVM: NOT INSTALLED"
		echo "  Run: init_claude --isolated-install"
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
		echo "  Will be created after: init_claude --isolated-install"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}

#######################################
# Save credentials to file
#######################################
save_credentials() {
    local proxy_url=$1
    local insecure=${2:-false}
    local ca_path=${3:-}
    local no_proxy=${4:-localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org}

    # Create credentials file with restricted permissions
    touch "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    # Save URL, insecure flag, CA path, and NO_PROXY
    cat > "$CREDENTIALS_FILE" << EOF
PROXY_URL=$proxy_url
PROXY_INSECURE=$insecure
PROXY_CA_PATH=$ca_path
NO_PROXY=$no_proxy
EOF

    print_success "Credentials saved to: $CREDENTIALS_FILE"
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
        PROXY_INSECURE=false
        PROXY_CA_PATH=""
        NO_PROXY="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    if [[ -z "$PROXY_URL" ]]; then
        return 1
    fi

    # Validate URL
    if ! validate_proxy_url "$PROXY_URL"; then
        print_warning "Saved credentials are invalid, will prompt for new URL"
        return 1
    fi

    # Validate CA path if present
    if [[ -n "${PROXY_CA_PATH:-}" ]] && [[ "$PROXY_CA_PATH" != "" ]]; then
        if [[ ! -f "$PROXY_CA_PATH" ]]; then
            print_warning "Saved CA certificate not found: $PROXY_CA_PATH"
            print_info "Will ignore CA certificate setting"
            PROXY_CA_PATH=""
        fi
    fi

    # Set default NO_PROXY if not present (backward compatibility)
    if [[ -z "${NO_PROXY:-}" ]]; then
        NO_PROXY="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    # Return URL, insecure flag, CA path, and NO_PROXY (space-separated)
    echo "$PROXY_URL ${PROXY_INSECURE:-false} ${PROXY_CA_PATH:-} ${NO_PROXY}"
    return 0
}

#######################################
# Prompt for proxy URL
#######################################
prompt_proxy_url() {
    local saved_credentials

    # Check if credentials exist
    if saved_credentials=$(load_credentials); then
        # Parse space-separated output: URL INSECURE_FLAG CA_PATH NO_PROXY
        local saved_url=$(echo "$saved_credentials" | awk '{print $1}')
        local saved_insecure=$(echo "$saved_credentials" | awk '{print $2}')
        local saved_ca=$(echo "$saved_credentials" | awk '{print $3}')
        local saved_no_proxy=$(echo "$saved_credentials" | awk '{print $4}')

        print_info "Saved proxy found" >&2
        echo "" >&2
        # Hide password in display
        local display_url=$(echo "$saved_url" | sed -E 's|://([^:]+):([^@]+)@|://\1:****@|')
        echo "  URL: $display_url" >&2

        # Display security options
        if [[ -n "$saved_ca" ]] && [[ "$saved_ca" != "" ]]; then
            echo "  CA Certificate: $saved_ca" >&2
        elif [[ "$saved_insecure" == "true" ]]; then
            echo "  Options: --proxy-insecure (⚠️  небезопасно)" >&2
        fi
        echo "" >&2

        # Auto-use saved proxy (no confirmation needed)
        echo "$saved_url $saved_insecure $saved_ca $saved_no_proxy"
        return 0
    fi

    # Prompt for new URL
    echo "" >&2
    print_info "Enter HTTP proxy URL" >&2
    echo "" >&2
    echo "Format: protocol://username:password@host:port" >&2
    echo "Example: https://alice:secret123@127.0.0.1:8118" >&2
    echo "" >&2
    echo "Supported protocols: http, https, socks5" >&2
    echo "" >&2

    while true; do
        local proxy_url=""
        if [ -t 0 ]; then
            read -p "Proxy URL: " proxy_url >&2
        else
            # Non-interactive mode: cannot prompt for new URL
            print_error "Cannot prompt for proxy URL in non-interactive mode" >&2
            echo "Use: init_claude --proxy <url>" >&2
            exit 1
        fi

        if [[ -z "$proxy_url" ]]; then
            print_error "URL cannot be empty" >&2
            continue
        fi

        if ! validate_proxy_url "$proxy_url"; then
            print_error "Invalid URL format" >&2
            echo "Expected: protocol://[user:pass@]host:port" >&2
            continue
        fi

        # Return URL with default insecure=false, no CA, and default NO_PROXY
        echo "$proxy_url false  localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
        return 0
    done
}

#######################################
# Configure proxy from URL
#######################################
configure_proxy_from_url() {
    local proxy_url=$1
    local insecure=${2:-false}
    local ca_path=${3:-}
    local no_proxy=${4:-localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org}

    # Set environment variables
    export HTTPS_PROXY="$proxy_url"
    export HTTP_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"

    # Set flags for test_proxy()
    export PROXY_INSECURE="$insecure"
    export PROXY_CA_PATH="$ca_path"

    # Security configuration for HTTPS proxies
    if [[ "$proxy_url" =~ ^https:// ]]; then
        # Priority 1: Use CA certificate (SECURE)
        if [[ -n "$ca_path" ]] && [[ -f "$ca_path" ]]; then
            export NODE_EXTRA_CA_CERTS="$ca_path"
            print_success "Using proxy CA certificate: $ca_path"
            print_info "TLS verification enabled for all connections"
            echo ""
        # Priority 2: Use insecure mode (INSECURE - with warning)
        elif [[ "$insecure" == "true" ]]; then
            export NODE_TLS_REJECT_UNAUTHORIZED=0
            echo ""
            print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            print_warning "  ВНИМАНИЕ: РЕЖИМ НЕБЕЗОПАСНОГО ПОДКЛЮЧЕНИЯ"
            print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "  Отключена проверка TLS сертификатов для ВСЕХ соединений:"
            echo "  • Прокси-сервер (это нужно)"
            echo "  • Claude Code → Anthropic API (⚠️  НЕБЕЗОПАСНО!)"
            echo ""
            echo "  Возможна атака Man-in-the-Middle на API соединения!"
            echo ""
            print_info "Рекомендация: используйте --proxy-ca вместо --proxy-insecure"
            echo ""
            echo "  Для экспорта сертификата прокси см.: init_claude --help-export-cert"
            print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
        fi
    fi

    # Configure git to ignore proxy
    configure_git_no_proxy

    # Save credentials (including NO_PROXY)
    save_credentials "$proxy_url" "$insecure" "$ca_path" "$no_proxy"
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

    # Prepare curl command with proxy
    local curl_opts=(-x "$proxy_url" -s -m 5 -o /dev/null -w "%{http_code}")

    # Configure TLS for HTTPS proxies
    if [[ "$proxy_url" =~ ^https:// ]]; then
        # Priority 1: Use CA certificate (secure)
        if [[ -n "${PROXY_CA_PATH:-}" ]] && [[ -f "${PROXY_CA_PATH}" ]]; then
            curl_opts+=(--proxy-cacert "${PROXY_CA_PATH}")
            print_info "Using CA certificate for proxy validation"
        # Priority 2: Use insecure mode (insecure)
        elif [[ "${PROXY_INSECURE:-false}" == "true" ]]; then
            curl_opts+=(--proxy-insecure)
            print_info "Using insecure mode (no certificate validation)"
        fi
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
        if [[ "$proxy_url" =~ ^https:// ]] && [[ -z "${PROXY_CA_PATH:-}" ]] && [[ "${PROXY_INSECURE:-false}" != "true" ]]; then
            echo "  - Self-signed proxy certificate (use --proxy-ca or --proxy-insecure)"
        fi
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
#######################################
check_update() {
    print_info "Checking for Claude Code updates..."
    echo ""

    # Detect NVM environment
    local using_nvm=false
    if detect_nvm; then
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
            echo "Install with: sudo init_claude --install"
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
            echo "Run to update: init_claude --update"
            echo "Or directly:   npm install -g @anthropic-ai/claude-code@latest"
        else
            echo "Run to update: sudo init_claude --update"
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
#######################################
update_claude_code() {
    local using_nvm=false

    # Detect NVM environment
    if detect_nvm; then
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
            echo "Try reinstalling with: ./init_claude.sh --isolated-install"
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
            echo "  init_claude --update"
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
            echo "Install first with: sudo init_claude --install"
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
            echo "  init_claude --update"
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
                # Isolated environment: Update lockfile and repair
                print_info "Updating lockfile..."
                save_isolated_lockfile
                echo ""

                print_info "Repairing symlinks and permissions..."
                repair_isolated_environment
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
            echo "  1. Run: init_claude --update (cleanup will run automatically)"
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
            echo "You can still install init_claude, but it won't work until Claude Code is installed."
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
    local target_path="/usr/local/bin/init_claude"

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
    echo "You can now run: init_claude"
}

#######################################
# Uninstall script
#######################################
uninstall_script() {
    local target_path="/usr/local/bin/init_claude"

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
# Launch Claude Code
#######################################
launch_claude() {
    echo ""
    print_info "Launching Claude Code..."
    echo ""

    # Find claude installation
    local claude_cmd=""

    # Priority 1: Check NVM environment first (user's active version)
    if detect_nvm; then
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
Usage: init_claude [OPTIONS] [CLAUDE_ARGS...]

Initialize Claude Code with HTTP proxy settings

OPTIONS:
  -h, --help                        Show this help message
  --help-export-cert                Show instructions for exporting proxy certificate
  -p, --proxy URL                   Set proxy URL directly (skip prompt)
  --proxy-ca PATH                   Path to proxy CA certificate (PEM format) - SECURE
  --proxy-insecure                  Ignore TLS certs for HTTPS proxy - ⚠️  INSECURE (NOT recommended)
  -t, --test                        Test proxy and exit (don't launch Claude)
  -c, --clear                       Clear saved credentials
  --no-proxy                        Launch Claude Code without proxy
  --restore-git-proxy               Restore git proxy settings from backup
  --install                         Install script globally (requires sudo)
  --uninstall                       Uninstall script from system (requires sudo)
  --update                          Update Claude Code to latest version (requires sudo)
  --check-update                    Check for available updates without installing
  --isolated-install                Install NVM + Node.js + Claude in isolated environment
  --install-from-lockfile           Install from .nvm-isolated-lockfile.json (reproducible setup)
  --check-isolated                  Show status of isolated environment
  --cleanup-isolated                Remove isolated environment (keeps lockfile)
  --repair-isolated                 Repair symlinks and permissions after git clone
  --no-test                         Skip proxy connectivity test
  --show-password                   Display password in output (default: masked)
  --dangerously-skip-permissions    Pass --dangerously-skip-permissions to Claude Code

EXAMPLES:
  # Install globally (run once)
  sudo $0 --install

  # First run - prompt for proxy URL
  init_claude

  # Second run - use saved credentials automatically
  init_claude

  # Set proxy URL directly
  init_claude --proxy http://user:pass@127.0.0.1:8118

  # Set HTTPS proxy with CA certificate (SECURE - recommended)
  init_claude --proxy https://user:pass@proxy.example.com:8118 --proxy-ca /path/to/proxy-cert.pem

  # Set HTTPS proxy WITHOUT certificate validation (⚠️  INSECURE - not recommended)
  init_claude --proxy https://user:pass@proxy.example.com:8118 --proxy-insecure

  # Get help exporting proxy certificate
  init_claude --help-export-cert

  # Test proxy without launching Claude
  init_claude --test

  # Clear saved credentials
  init_claude --clear

  # Restore git proxy settings from backup
  init_claude --restore-git-proxy

  # Launch without proxy
  init_claude --no-proxy

  # Uninstall
  sudo init_claude --uninstall

  # Check for updates
  init_claude --check-update

  # Update Claude Code to latest version
  sudo init_claude --update

  # Pass arguments to Claude Code
  init_claude -- --model claude-3-opus

  # Skip permission checks (use with caution)
  init_claude --dangerously-skip-permissions

ISOLATED ENVIRONMENT (Recommended):
  # Install in isolated environment (first time)
  init_claude --isolated-install

  # Check isolated environment status (includes symlink check)
  init_claude --check-isolated

  # Install from lockfile (reproducible setup on another machine)
  init_claude --install-from-lockfile

  # After git clone - repair symlinks and permissions
  ./init_claude.sh --repair-isolated

  # Update Claude Code in isolated environment
  ./init_claude.sh --update

  # Clean up isolated environment (keeps lockfile for reinstall)
  init_claude --cleanup-isolated

PROXY URL FORMAT:
  http://username:password@host:port
  https://username:password@host:port  (recommended: use with --proxy-ca)
  socks5://username:password@host:port

  Examples:
    http://alice:secret123@127.0.0.1:8118
    https://alice:secret123@proxy.example.com:8118 --proxy-ca /path/to/cert.pem  (SECURE)
    https://alice:secret123@proxy.example.com:8118 --proxy-insecure  (⚠️  INSECURE)
    socks5://bob:pass456@proxy.example.com:1080

HTTPS PROXY SECURITY:
  When using HTTPS proxies with self-signed certificates, you have two options:

  1. --proxy-ca /path/to/cert.pem (✅ RECOMMENDED - SECURE)
     - Adds ONLY the proxy certificate to trusted CAs
     - TLS verification remains ENABLED for all other connections
     - Claude Code → Anthropic API connections are SECURE
     - Use: init_claude --help-export-cert for certificate export instructions

  2. --proxy-insecure (⚠️  NOT RECOMMENDED - INSECURE)
     - Disables TLS certificate verification for ALL Node.js connections
     - Proxy connection: no verification (needed)
     - Claude Code → Anthropic API: NO VERIFICATION (⚠️  DANGEROUS!)
     - Vulnerable to Man-in-the-Middle attacks on API calls
     - Only use with trusted networks and as last resort

CREDENTIALS:
  - Saved to: ${CREDENTIALS_FILE}
  - File permissions: 600 (owner read/write only)
  - Automatically excluded from git (.gitignore)
  - Reused on subsequent runs (prompt to confirm/change)
  - Includes: PROXY_URL, PROXY_INSECURE, PROXY_CA_PATH, NO_PROXY

ENVIRONMENT:
  After loading proxy, these variables are set:
    HTTPS_PROXY, HTTP_PROXY, NO_PROXY

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
    init_claude --restore-git-proxy

INSTALLATION:
  After installing with --install, you can run 'init_claude' from anywhere.
  The script will be available at: /usr/local/bin/init_claude

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
    local skip_permissions=false
    local no_proxy=false
    local proxy_insecure=false
    local proxy_ca_path=""
    local claude_args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --help-export-cert)
                export_proxy_certificate_help
                exit 0
                ;;
            -p|--proxy)
                proxy_url="$2"
                shift 2
                ;;
            --proxy-ca)
                proxy_ca_path="$2"
                shift 2
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
            --update)
                update_claude_code
                exit $?
                ;;
            --check-update)
                check_update
                exit $?
                ;;
            --isolated-install)
                install_isolated_nvm
                install_isolated_nodejs
                install_isolated_claude
                exit $?
                ;;
            --install-from-lockfile)
                install_from_lockfile
                exit $?
                ;;
            --cleanup-isolated)
                cleanup_isolated_nvm
                exit $?
                ;;
            --repair-isolated)
                repair_isolated_environment
                exit $?
                ;;
            --check-isolated)
                check_isolated_status
                exit 0
                ;;
            --no-test)
                skip_test=true
                shift
                ;;
            --show-password)
                show_password=true
                shift
                ;;
            --dangerously-skip-permissions)
                skip_permissions=true
                shift
                ;;
            --proxy-insecure)
                proxy_insecure=true
                shift
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

        # Add --dangerously-skip-permissions flag if requested
        if [[ "$skip_permissions" == true ]]; then
            claude_args+=("--dangerously-skip-permissions")
            print_warning "Skipping permission checks (--dangerously-skip-permissions)"
            echo ""
        fi

        # Launch Claude Code without proxy
        launch_claude "${claude_args[@]}"
        exit 0
    fi

    # Validate proxy CA certificate if provided
    if [[ -n "$proxy_ca_path" ]]; then
        if ! validate_certificate_file "$proxy_ca_path"; then
            exit 1
        fi
    fi

    # Get proxy URL (from argument, saved file, or prompt)
    local proxy_credentials
    local proxy_no_proxy=""
    if [[ -z "$proxy_url" ]]; then
        proxy_credentials=$(prompt_proxy_url)
        # Parse space-separated output: URL INSECURE_FLAG CA_PATH NO_PROXY
        proxy_url=$(echo "$proxy_credentials" | awk '{print $1}')
        local saved_insecure=$(echo "$proxy_credentials" | awk '{print $2}')
        local saved_ca=$(echo "$proxy_credentials" | awk '{print $3}')
        proxy_no_proxy=$(echo "$proxy_credentials" | awk '{print $4}')

        # Override with command-line flags if provided
        if [[ "$proxy_insecure" == true ]]; then
            saved_insecure="true"
        elif [[ "$saved_insecure" != "true" ]]; then
            saved_insecure="false"
        fi
        proxy_insecure="$saved_insecure"

        # Use saved CA if no command-line CA provided
        if [[ -z "$proxy_ca_path" ]] && [[ -n "$saved_ca" ]] && [[ "$saved_ca" != "" ]]; then
            proxy_ca_path="$saved_ca"
        fi
    else
        # Validate provided URL
        if ! validate_proxy_url "$proxy_url"; then
            print_error "Invalid proxy URL: $proxy_url"
            echo "Expected format: protocol://[user:pass@]host:port"
            exit 1
        fi
        # Use default NO_PROXY if not loaded from saved credentials
        proxy_no_proxy="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
    fi

    # Configure proxy
    print_info "Configuring proxy..."
    configure_proxy_from_url "$proxy_url" "$proxy_insecure" "$proxy_ca_path" "$proxy_no_proxy"

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
            echo "  2. Run without proxy: init_claude --no-proxy"
            echo "  3. Skip proxy test: init_claude --no-test"
            echo "  4. Check proxy credentials: init_claude --clear"
            exit 0
        fi
        echo ""
    fi

    # Add --dangerously-skip-permissions flag if requested
    if [[ "$skip_permissions" == true ]]; then
        claude_args+=("--dangerously-skip-permissions")
        print_warning "Skipping permission checks (--dangerously-skip-permissions)"
        echo ""
    fi

    # Launch Claude Code
    launch_claude "${claude_args[@]}"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
