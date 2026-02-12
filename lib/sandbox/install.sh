#!/bin/bash
# Sandbox installation module
# Provides functions for checking and installing sandbox dependencies

#######################################
# Check sandbox system dependencies
# Returns:
#   0 - all dependencies installed
#   1 - missing dependencies (outputs list to stdout)
# Output: space-separated list of missing dependencies
#######################################
check_sandbox_dependencies() {
	local platform=$(detect_sandbox_platform)

	case "$platform" in
		macos)
			# macOS has native Seatbelt
			return 0
			;;
		linux|wsl2)
			local missing=()

			# System packages
			command -v bwrap &>/dev/null || missing+=("bubblewrap")
			command -v socat &>/dev/null || missing+=("socat")

			# NPM package for seccomp filter (blocks unix domain sockets)
			local sandbox_runtime_installed=false
			if command -v srt &>/dev/null; then
				sandbox_runtime_installed=true
			elif [[ -n "$ISOLATED_NVM_DIR" ]]; then
				# Check in isolated environment
				local sandbox_cli="$ISOLATED_NVM_DIR/npm-global/bin/srt"
				[[ -x "$sandbox_cli" ]] && sandbox_runtime_installed=true
			fi

			if [[ "$sandbox_runtime_installed" == "false" ]]; then
				missing+=("@anthropic-ai/sandbox-runtime")
			fi

			if [[ ${#missing[@]} -gt 0 ]]; then
				echo "${missing[@]}"
				return 1
			fi
			return 0
			;;
		*)
			# Platform not supported
			return 1
			;;
	esac
}

#######################################
# Install sandbox system dependencies
# Returns:
#   0 - success or already installed
#   1 - installation error (recoverable)
#   2 - platform not supported (non-recoverable)
#######################################
install_sandbox_dependencies() {
	local platform
	platform=$(detect_sandbox_platform)
	local platform_status=$?

	echo ""
	print_info "Installing sandbox dependencies..."
	echo ""

	# Check platform support
	if [[ $platform_status -ne 0 ]]; then
		case "$platform" in
			wsl1)
				print_error "WSL1 is not supported for sandboxing"
				echo ""
				echo "Please upgrade to WSL2:"
				echo "  wsl --set-version <distro-name> 2"
				echo "  wsl --shutdown"
				echo ""
				echo "Verify upgrade:"
				echo "  wsl --list --verbose"
				;;
			windows)
				print_error "Native Windows is not supported for sandboxing"
				echo ""
				echo "Please install WSL2:"
				echo "  wsl --install"
				echo ""
				echo "Or install Ubuntu from Microsoft Store and enable WSL2"
				;;
			*)
				print_error "Platform '$platform' is not supported for sandboxing"
				;;
		esac
		return 2
	fi

	# macOS - native support
	if [[ "$platform" == "macos" ]]; then
		print_success "macOS uses native Seatbelt (no installation required)"
		return 0
	fi

	# Linux/WSL2 - check current status
	local missing
	missing=$(check_sandbox_dependencies) || true
	if check_sandbox_dependencies &>/dev/null; then
		print_success "All dependencies already installed"
		echo ""
		return 0
	fi

	echo "Missing dependencies: $missing"
	echo ""

	# Ensure isolated environment is set up
	if [[ -z "$ISOLATED_NVM_DIR" ]]; then
		setup_isolated_nvm
	fi

	# A. Install system packages (bubblewrap, socat)
	local system_packages=()
	[[ "$missing" == *"bubblewrap"* ]] && system_packages+=("bubblewrap")
	[[ "$missing" == *"socat"* ]] && system_packages+=("socat")

	if [[ ${#system_packages[@]} -gt 0 ]]; then
		print_info "Installing system packages: ${system_packages[*]}"
		echo ""

		# Detect package manager
		local pkg_manager=""
		if command -v apt-get &>/dev/null; then
			pkg_manager="apt-get"
		elif command -v dnf &>/dev/null; then
			pkg_manager="dnf"
		elif command -v yum &>/dev/null; then
			pkg_manager="yum"
		else
			print_error "No supported package manager found (apt-get, dnf, yum)"
			echo ""
			echo "Please install manually:"
			echo "  bubblewrap: https://github.com/containers/bubblewrap"
			echo "  socat: http://www.dest-unreach.org/socat/"
			return 1
		fi

		# Install packages
		local install_cmd="sudo $pkg_manager install -y ${system_packages[*]}"
		echo "Running: $install_cmd"
		echo ""

		if ! $install_cmd; then
			print_error "Failed to install system packages"
			echo ""
			echo "Please ensure:"
			echo "  1. You have sudo privileges"
			echo "  2. Package manager is working: sudo $pkg_manager update"
			echo ""
			echo "Manual installation:"
			echo "  $install_cmd"
			return 1
		fi

		# Verify installation
		for pkg in "${system_packages[@]}"; do
			local binary="${pkg/bubblewrap/bwrap}"  # bubblewrap installs as 'bwrap'
			if ! command -v "$binary" &>/dev/null; then
				print_error "Package $pkg installed but binary not found"
				return 1
			fi
		done

		print_success "System packages installed successfully"
		echo ""
	fi

	# B. Install NPM package (@anthropic-ai/sandbox-runtime)
	if [[ "$missing" == *"@anthropic-ai/sandbox-runtime"* ]]; then
		print_info "Installing @anthropic-ai/sandbox-runtime npm package..."
		echo ""

		# Setup PATH for npm
		export PATH="$ISOLATED_NVM_DIR/npm-global/bin:$ISOLATED_NVM_DIR/versions/node/$(ls "$ISOLATED_NVM_DIR/versions/node" | head -1)/bin:$PATH"

		if ! npm install -g @anthropic-ai/sandbox-runtime; then
			print_error "Failed to install @anthropic-ai/sandbox-runtime"
			echo ""
			echo "Please check:"
			echo "  1. Isolated environment is set up: ./iclaude.sh --check-isolated"
			echo "  2. npm is working: npm --version"
			return 1
		fi

		# Verify installation
		if ! command -v srt &>/dev/null && [[ ! -x "$ISOLATED_NVM_DIR/npm-global/bin/srt" ]]; then
			print_error "@anthropic-ai/sandbox-runtime installed but binary not found"
			return 1
		fi

		print_success "@anthropic-ai/sandbox-runtime installed successfully"
		echo ""
	fi

	# Show versions
	print_success "Sandbox dependencies installed:"
	echo ""
	if command -v bwrap &>/dev/null; then
		local bwrap_ver=$(bwrap --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
		echo "  bubblewrap: $bwrap_ver"
	fi
	if command -v socat &>/dev/null; then
		local socat_ver=$(socat -V 2>&1 | grep "socat version" | grep -oP '\d+\.\d+\.\d+\.\d+')
		echo "  socat: $socat_ver"
	fi
	local runtime_ver=$(get_sandbox_runtime_version)
	if [[ "$runtime_ver" != "not installed" ]]; then
		echo "  @anthropic-ai/sandbox-runtime: $runtime_ver"
	fi
	echo ""

	return 0
}
