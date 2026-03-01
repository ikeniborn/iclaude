#!/bin/bash
# LSP repair module
# Provides function for repairing plugin paths after project relocation

#######################################
# Repair plugin paths after git clone or project move
# Fixes paths in known_marketplaces.json and installed_plugins.json
# Arguments:
#   $1 - quiet_mode (optional): "quiet" to suppress output
# Returns:
#   0 - success
#######################################
repair_plugin_paths() {
	local quiet_mode="${1:-}"
	local plugins_dir="$ISOLATED_NVM_DIR/.claude-isolated/plugins"
	local known_marketplaces="$plugins_dir/known_marketplaces.json"
	local installed_plugins="$plugins_dir/installed_plugins.json"
	local fixed=0

	# Nothing to fix if plugins directory doesn't exist
	if [[ ! -d "$plugins_dir" ]]; then
		return 0
	fi

	# Create known_marketplaces.json if missing but marketplaces directory exists
	# (happens after git rm deleted the file — marketplace dir survives but registry is gone)
	if [[ ! -f "$known_marketplaces" ]]; then
		local marketplaces_dir="$plugins_dir/marketplaces"
		if [[ -d "$marketplaces_dir" ]]; then
			local new_json="{}"
			local any_created=false

			while IFS= read -r -d '' mdir; do
				local mname
				mname=$(basename "$mdir")

				# Prefer the canonical name from the marketplace manifest
				local manifest_file="$mdir/.claude-plugin/marketplace.json"
				if [[ -f "$manifest_file" ]]; then
					local manifest_name
					manifest_name=$(jq -r '.name // empty' "$manifest_file" 2>/dev/null)
					[[ -n "$manifest_name" ]] && mname="$manifest_name"
				fi

				# Get GitHub repo from the local git remote (best-effort)
				local repo_path=""
				if [[ -d "$mdir/.git" ]]; then
					local remote_url
					remote_url=$(git -C "$mdir" remote get-url origin 2>/dev/null || true)
					if [[ "$remote_url" =~ github\.com[:/](.+) ]]; then
						repo_path="${BASH_REMATCH[1]%.git}"
					fi
				fi

				local install_location="$plugins_dir/marketplaces/$mname"
				local timestamp
				timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

				local entry
				if [[ -n "$repo_path" ]]; then
					entry=$(jq -n \
						--arg loc "$install_location" \
						--arg ts "$timestamp" \
						--arg repo "$repo_path" \
						'{"source":{"source":"github","repo":$repo},"installLocation":$loc,"lastUpdated":$ts}' 2>/dev/null)
				else
					entry=$(jq -n \
						--arg loc "$install_location" \
						--arg ts "$timestamp" \
						'{"installLocation":$loc,"lastUpdated":$ts}' 2>/dev/null)
				fi

				[[ -z "$entry" ]] && continue

				new_json=$(jq --arg name "$mname" --argjson entry "$entry" \
					'. + {($name): $entry}' <<< "$new_json" 2>/dev/null) || continue
				any_created=true
			done < <(find "$marketplaces_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

			if [[ "$any_created" == true ]]; then
				echo "$new_json" > "$known_marketplaces"
				chmod 600 "$known_marketplaces"
				fixed=$((fixed + 1))
				if [[ "$quiet_mode" != "quiet" ]]; then
					print_success "  ✓ Created: known_marketplaces.json"
				fi
			fi
		fi
	fi

	# Fix known_marketplaces.json
	if [[ -f "$known_marketplaces" ]]; then
		# Check if file contains installLocation paths that don't match current SCRIPT_DIR
		local current_install_location
		current_install_location=$(jq -r '."claude-plugins-official".installLocation // empty' "$known_marketplaces" 2>/dev/null)

		if [[ -n "$current_install_location" ]]; then
			# Compute correct path
			local correct_path="$plugins_dir/marketplaces/claude-plugins-official"

			# Check if path needs fixing (doesn't match correct path)
			if [[ "$current_install_location" != "$correct_path" ]]; then
				if [[ "$quiet_mode" != "quiet" ]]; then
					print_info "Fixing marketplace paths in known_marketplaces.json..."
				fi

				# Update JSON using jq
				local tmp_file
				tmp_file=$(mktemp)
				if jq --arg path "$correct_path" \
				       '."claude-plugins-official".installLocation = $path' \
				       "$known_marketplaces" > "$tmp_file" 2>/dev/null; then
					mv "$tmp_file" "$known_marketplaces"
					fixed=$((fixed + 1))
					if [[ "$quiet_mode" != "quiet" ]]; then
						print_success "  ✓ Fixed: known_marketplaces.json"
					fi
				else
					rm -f "$tmp_file"
					if [[ "$quiet_mode" != "quiet" ]]; then
						print_error "  ✗ Failed to fix known_marketplaces.json"
					fi
				fi
			fi
		fi
	fi

	# Fix installed_plugins.json (version 2 format with nested .plugins structure)
	if [[ -f "$installed_plugins" ]]; then
		# Check if any plugin paths don't match current SCRIPT_DIR
		# Format: { "version": 2, "plugins": { "name@marketplace": [{ "installPath": "...", "projectPath": "..." }] } }
		local needs_fix=false
		local plugin_paths
		plugin_paths=$(jq -r '.plugins[][]?.installPath // empty' "$installed_plugins" 2>/dev/null)

		if [[ -n "$plugin_paths" ]]; then
			while IFS= read -r path; do
				if [[ -n "$path" && "$path" != *"$SCRIPT_DIR"* ]]; then
					needs_fix=true
					break
				fi
			done <<< "$plugin_paths"

			if [[ "$needs_fix" == true ]]; then
				if [[ "$quiet_mode" != "quiet" ]]; then
					print_info "Fixing plugin paths in installed_plugins.json..."
				fi

				# Find the first INCORRECT path (one that doesn't contain SCRIPT_DIR)
				local old_base_path=""
				while IFS= read -r path; do
					if [[ -n "$path" && "$path" != *"$SCRIPT_DIR"* ]]; then
						old_base_path="$path"
						break
					fi
				done <<< "$plugin_paths"

				if [[ -n "$old_base_path" ]]; then
					# Extract project path from old path (everything before .nvm-isolated)
					local old_project_path
					old_project_path=$(echo "$old_base_path" | sed 's|/\.nvm-isolated/.*||')

					if [[ -n "$old_project_path" && "$old_project_path" != "$SCRIPT_DIR" ]]; then
						# Replace old project path with new one in all paths
						# Use split/join instead of gsub to avoid regex escaping issues
						local tmp_file
						tmp_file=$(mktemp)
						if jq --arg old "$old_project_path" \
						       --arg new "$SCRIPT_DIR" \
						       '.plugins |= with_entries(.value |= map(
						           .installPath = (.installPath | split($old) | join($new)) |
						           if .projectPath then .projectPath = (.projectPath | split($old) | join($new)) else . end
						       ))' \
						       "$installed_plugins" > "$tmp_file" 2>/dev/null; then
							mv "$tmp_file" "$installed_plugins"
							fixed=$((fixed + 1))
							if [[ "$quiet_mode" != "quiet" ]]; then
								print_success "  ✓ Fixed: installed_plugins.json"
							fi
						else
							rm -f "$tmp_file"
							if [[ "$quiet_mode" != "quiet" ]]; then
								print_error "  ✗ Failed to fix installed_plugins.json"
							fi
						fi
					fi
				fi
			fi
		fi
	fi

	if [[ $fixed -gt 0 && "$quiet_mode" != "quiet" ]]; then
		print_success "Plugin paths repaired ($fixed file(s) fixed)"
	fi

	return 0
}
