#!/bin/bash
# Oh-My-Posh installation module
# Provides function for installing Oh-My-Posh in isolated environment

#######################################
# Install Oh My Posh in isolated environment (pre-bundled)
# Uses pre-bundled platform-specific binary from git repository
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_ohmyposh() {
	setup_isolated_nvm

	local platform
	platform=$(detect_ohmyposh_platform)
	if [ $? -ne 0 ]; then
		echo "Error: Platform not supported for Oh My Posh ($platform)" >&2
		return 1
	fi

	local omp_binary="${ISOLATED_NVM_DIR}/npm-global/bin/oh-my-posh-${platform}"
	local omp_symlink="${ISOLATED_NVM_DIR}/npm-global/bin/oh-my-posh"

	# Verify pre-bundled binary exists
	if [ ! -f "$omp_binary" ]; then
		echo "Error: Pre-bundled Oh My Posh binary not found: $omp_binary" >&2
		echo "Expected file: oh-my-posh-${platform}" >&2
		echo "" >&2
		echo "Please ensure the git repository includes the pre-bundled binary." >&2
		return 1
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
	echo "1. Theme file already created: .nvm-isolated/.claude-isolated/themes/claude-statusline.omp.json"
	echo "2. Customize theme (optional): edit .nvm-isolated/.claude-isolated/themes/claude-statusline.omp.json"
	echo "3. Oh My Posh will be used automatically by statusline script when available"
}
