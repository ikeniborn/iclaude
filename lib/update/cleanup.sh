#!/bin/bash
# Update cleanup module
# Provides functions for cleaning up old Claude installations and recreating symlinks

#######################################
# Cleanup old Claude Code installations
# Removes temporary .claude-code-* folders and broken symlinks
# Returns:
#   0 - success
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
# Finds the newest Claude installation and creates standard symlink
# Returns:
#   0 - success
#   1 - error (cli.js not found)
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
