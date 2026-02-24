#!/bin/bash

#######################################
# NVM Repair Module
# Description: Repair symlinks and permissions after git clone or repository moves
#######################################

#######################################
# Repair isolated environment
# Fixes broken symlinks and permissions after git clone
# Returns:
#   0 - success (all repairs successful)
#   1 - errors found that couldn't be fixed
# Side effects:
#   - Recreates npm/npx/corepack symlinks
#   - Recreates Claude Code symlink
#   - Fixes file permissions
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
		return 1
	fi

	local node_version=$(basename "$node_version_dir")
	print_info "Found Node.js version: $node_version"
	echo ""

	# Repair npm/npx/corepack symlinks
	create_npm_symlinks "$node_version_dir" || errors=$((errors + 1))

	# Repair Claude Code symlink
	echo ""
	create_claude_symlink || errors=$((errors + 1))

	# Repair settings.json absolute paths
	echo ""
	print_info "Checking settings.json paths..."
	repair_settings_paths || errors=$((errors + 1))

	# Summary
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if [[ $errors -eq 0 ]]; then
		print_success "Repair completed successfully"
	else
		print_warning "Repair completed with $errors error(s)"
	fi
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return $errors
}

#######################################
# Create npm/npx/corepack symlinks
# Arguments:
#   $1 - Node.js version directory (e.g., /path/to/.nvm-isolated/versions/node/v18.20.8)
# Returns:
#   0 - success
#   1 - errors found
#######################################
create_npm_symlinks() {
	local node_version_dir="$1"

	print_info "Checking Node.js symlinks..."

	# Array of symlinks to check/repair: [link_path]=[target_path]
	declare -A symlinks=(
		["$node_version_dir/bin/npm"]="../lib/node_modules/npm/bin/npm-cli.js"
		["$node_version_dir/bin/npx"]="../lib/node_modules/npm/bin/npx-cli.js"
		["$node_version_dir/bin/corepack"]="../lib/node_modules/corepack/dist/corepack.js"
	)

	local errors=0

	for link_path in "${!symlinks[@]}"; do
		local target="${symlinks[$link_path]}"
		local link_name=$(basename "$link_path")

		# Remove and recreate symlink
		rm -f "$link_path"
		ln -s "$target" "$link_path"

		if [[ -L "$link_path" ]]; then
			print_success "  ✓ Created: $link_name"
		else
			print_error "  ✗ Failed: $link_name"
			errors=$((errors + 1))
		fi
	done

	return $errors
}

#######################################
# Create Claude Code symlink
# Returns:
#   0 - success
#   1 - error
#######################################
create_claude_symlink() {
	print_info "Checking Claude Code symlink..."

	local claude_link="$ISOLATED_NVM_DIR/npm-global/bin/claude"

	# Find Claude Code installation
	local node_version_dir=$(find "$ISOLATED_NVM_DIR/versions/node" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)

	if [[ -z "$node_version_dir" ]]; then
		print_error "  ✗ Node.js version not found"
		return 1
	fi

	local claude_target="$node_version_dir/lib/node_modules/@anthropic-ai/claude-code/cli.js"

	if [[ ! -f "$claude_target" ]]; then
		print_warning "  ! Claude Code not installed yet"
		return 0
	fi

	# Create symlink (relative path for portability)
	local relative_target="../../versions/node/$(basename "$node_version_dir")/lib/node_modules/@anthropic-ai/claude-code/cli.js"

	mkdir -p "$(dirname "$claude_link")"
	rm -f "$claude_link"
	ln -s "$relative_target" "$claude_link"
	chmod +x "$claude_link"

	if [[ -L "$claude_link" ]]; then
		print_success "  ✓ Created: claude symlink"
		return 0
	else
		print_error "  ✗ Failed: claude symlink"
		return 1
	fi
}

#######################################
# Repair absolute paths in settings.json
# Detects hardcoded .claude-isolated paths from another machine/installation
# and replaces them with the current ISOLATED_CONFIG_DIR path.
# Called automatically at every launch and during --repair-isolated.
# Returns:
#   0 - success (paths correct or fixed)
#   1 - could not repair
#######################################
repair_settings_paths() {
	local settings_file="$ISOLATED_CONFIG_DIR/settings.json"

	[[ ! -f "$settings_file" ]] && return 0

	# Resolve current config dir to absolute path
	local current_dir
	if command -v realpath &>/dev/null; then
		current_dir=$(realpath "$ISOLATED_CONFIG_DIR")
	else
		current_dir="$(cd "$ISOLATED_CONFIG_DIR" && pwd)"
	fi

	# Find any .claude-isolated path prefix that differs from current location
	local stale_dir
	stale_dir=$(grep -o '[^"[:space:]]*\.claude-isolated' "$settings_file" 2>/dev/null \
		| sort -u | grep -vxF "$current_dir" | head -1)

	[[ -z "$stale_dir" ]] && return 0

	print_info "  Stale paths detected in settings.json"
	print_info "    Was: $stale_dir"
	print_info "    Now: $current_dir"

	local temp_file="${settings_file}.tmp"
	if sed "s|${stale_dir}|${current_dir}|g" "$settings_file" > "$temp_file" \
		&& [[ -s "$temp_file" ]]; then
		mv "$temp_file" "$settings_file"
		chmod 600 "$settings_file"
		print_success "  settings.json paths repaired"
		return 0
	else
		rm -f "$temp_file"
		print_error "  Failed to repair settings.json paths"
		return 1
	fi
}
