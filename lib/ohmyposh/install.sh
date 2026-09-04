#!/bin/bash
# Oh-My-Posh installation module
# Provides function for installing Oh-My-Posh in isolated environment

#######################################
# Install Oh My Posh in isolated environment (pre-bundled or auto-downloaded)
# Uses pre-bundled platform-specific binary from git repository.
# If binary is missing, automatically downloads the latest version from GitHub.
# Arguments:
#   [--insecure] - disable TLS verification for download (corporate proxy)
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_ohmyposh() {
	local insecure_flag=""
	for arg in "$@"; do
		if [[ "$arg" == "--insecure" ]]; then
			insecure_flag="--insecure"
		fi
	done

	setup_isolated_nvm

	local platform
	platform=$(detect_ohmyposh_platform)
	if [ $? -ne 0 ]; then
		echo "Error: Platform not supported for Oh My Posh ($platform)" >&2
		return 1
	fi

	local omp_binary="${ISOLATED_NVM_DIR}/npm-global/bin/oh-my-posh-${platform}"
	local omp_symlink="${ISOLATED_NVM_DIR}/npm-global/bin/oh-my-posh"

	# If binary missing — auto-download latest version from GitHub
	if [ ! -f "$omp_binary" ]; then
		echo "Binary not found: oh-my-posh-${platform}"
		echo "Auto-downloading latest version from GitHub..."
		echo ""

		local version
		version=$(curl ${insecure_flag:+-k} -fsSL \
			"https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest" \
			2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null)

		if [[ -z "$version" ]]; then
			echo "Error: Failed to fetch latest Oh My Posh version from GitHub" >&2
			echo "" >&2
			echo "Download manually:" >&2
			echo "  ./scripts/download-ohmyposh-binaries.sh ${insecure_flag} vX.Y.Z" >&2
			echo "  ./iclaude.sh --install-posh" >&2
			return 1
		fi

		local download_script="${SCRIPT_DIR}/scripts/download-ohmyposh-binaries.sh"
		if [ ! -f "$download_script" ]; then
			echo "Error: Download script not found: $download_script" >&2
			return 1
		fi

		bash "$download_script" ${insecure_flag} "$version"
		if [ $? -ne 0 ]; then
			echo "Error: Download failed" >&2
			return 1
		fi
		echo ""
	fi

	# Create symlink
	echo "Creating symlink: oh-my-posh -> oh-my-posh-${platform}"
	ln -sf "oh-my-posh-${platform}" "$omp_symlink"
	if [ $? -ne 0 ]; then
		echo "Error: Failed to create symlink" >&2
		return 1
	fi

	# Set executable permissions
	chmod +x "$omp_binary" "$omp_symlink"

	# Verify installation
	local version
	version=$("$omp_symlink" --version 2>/dev/null | head -n 1)
	if [ $? -ne 0 ]; then
		echo "Error: Oh My Posh installation verification failed" >&2
		return 1
	fi

	# Update lockfile
	save_isolated_lockfile

	echo ""
	echo "Oh My Posh installed successfully!"
	echo "Version: $version"
	echo "Platform: $platform"
	echo "Binary: $omp_binary"
	echo ""
	echo "Next steps:"
	echo "1. Theme file already created: .claude-isolated/themes/claude-statusline.omp.json"
	echo "2. Customize theme (optional): edit .claude-isolated/themes/claude-statusline.omp.json"
	echo "3. Oh My Posh will be used automatically by statusline script when available"
}
