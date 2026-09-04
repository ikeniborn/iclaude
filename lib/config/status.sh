#!/bin/bash

#######################################
# Config Status Module
# Description: Status checking for configuration and isolated environment
#######################################

#######################################
# Check config directory status
# Shows current CLAUDE_CONFIG_DIR and its content
# Returns:
#   0 - success
# Example:
#   check_config_status || return 1
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

	# Per-project home mode (S5): report the active mode and, when a home is
	# selected, the resolved home directory with its project root.
	local home_mode="${ICLAUDE_HOME_MODE:-per-project}"
	print_info "Home mode: $home_mode (ICLAUDE_HOME_MODE)"
	if [[ "$home_mode" == "per-project" ]] && [[ -f "$config_dir/home.json" ]]; then
		local home_root
		home_root=$(jq -r '.project_root // "unknown"' "$config_dir/home.json" 2>/dev/null || echo "unknown")
		echo "  Per-project home for: $home_root"
	fi
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
	elif [[ "$config_dir" == *"/.claude-isolated"* ]]; then
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
# Check isolated environment status
# Shows NVM, Node.js, Claude, symlinks, lockfile status
# Returns:
#   0 - success
# Example:
#   check_isolated_status || return 1
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

		local node_version_dir
		if declare -F get_isolated_node_version_dir &>/dev/null; then
			node_version_dir=$(get_isolated_node_version_dir "$ISOLATED_NVM_DIR/versions/node")
		else
			node_version_dir=$(find "$ISOLATED_NVM_DIR/versions/node" -maxdepth 1 -type d -name "v*" 2>/dev/null | LC_ALL=C sort | tail -1)
		fi
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
		# Показать полный lockfile с форматированием
		if command -v jq &>/dev/null; then
			jq -r 'to_entries[] | "    \(.key): \(.value)"' "$ISOLATED_LOCKFILE"
		else
			cat "$ISOLATED_LOCKFILE" | sed 's/^/    /'
		fi
	else
		print_warning "Lockfile: NOT FOUND"
		echo "  Will be created after: iclaude --isolated-install"
	fi

	# Show native installer information (for Claude Code >= 2.1.0)
	show_native_installer_info

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}

#######################################
# Display native installer information
# Shows information about Anthropic's recommendation to use native installer
# Returns:
#   0 - success
#######################################
show_native_installer_info() {
	# Проверяем версию Claude Code из package.json
	local package_json="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json"

	if [[ ! -f "$package_json" ]]; then
		# Если package.json не найден, пытаемся найти в другом месте
		local node_version_dir
		if declare -F get_isolated_node_version_dir &>/dev/null; then
			node_version_dir=$(get_isolated_node_version_dir "$ISOLATED_NVM_DIR/versions/node")
		else
			node_version_dir=$(find "$ISOLATED_NVM_DIR/versions/node" -maxdepth 1 -type d -name "v*" 2>/dev/null | LC_ALL=C sort | tail -1)
		fi
		if [[ -n "$node_version_dir" ]]; then
			package_json="$node_version_dir/lib/node_modules/@anthropic-ai/claude-code/package.json"
		fi
	fi

	if [[ ! -f "$package_json" ]]; then
		return 0  # Нет установленного Claude Code, выходим молча
	fi

	# Получаем версию из package.json
	local claude_version=""
	if command -v jq &>/dev/null; then
		claude_version=$(jq -r '.version' "$package_json" 2>/dev/null)
	else
		claude_version=$(grep '"version"' "$package_json" | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
	fi

	# Проверяем, что версия >= 2.1.0 (когда началась рекомендация native installer)
	if [[ -z "$claude_version" ]]; then
		return 0
	fi

	# Простая проверка версии (мажорная.минорная)
	local major=$(echo "$claude_version" | cut -d. -f1)
	local minor=$(echo "$claude_version" | cut -d. -f2)

	if [[ "$major" -lt 2 ]] || { [[ "$major" -eq 2 ]] && [[ "$minor" -lt 1 ]]; }; then
		return 0  # Версия < 2.1.0, нет предупреждения
	fi

	# Показываем информационное сообщение
	echo ""
	print_info "Anthropic recommends native installer for auto-updates"
	echo "  Current installation: npm-based (deprecated but works)"
	echo "  Recommended: native installer from https://code.claude.com/docs/en/setup"
	echo ""
	echo "  Why native installer?"
	echo "    • Automatic updates without manual npm commands"
	echo "    • Better integration with system package managers"
	echo "    • Simplified installation process"
	echo ""
	echo "  What does this mean for iclaude.sh?"
	echo "    • npm installation continues to work normally"
	echo "    • No immediate action required"
	echo "    • See CLAUDE.md section 'Future Migration: Native Installer' for details"
	echo ""

	return 0
}
