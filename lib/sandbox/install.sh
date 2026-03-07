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

#######################################
# Check microVM dependencies
# Returns:
#   0 - all dependencies present
#   1 - missing dependencies (list to stdout)
#######################################
check_microvm_dependencies() {
	local missing=()

	# KVM support
	local kvm_reason
	if ! kvm_reason=$(detect_kvm_support 2>&1); then
		missing+=("kvm: $kvm_reason")
	fi

	# Firecracker binary
	if ! detect_microvm_binary &>/dev/null; then
		missing+=("firecracker (run: ./iclaude.sh --install-microvm)")
	fi

	# Kernel image
	local kernel="${MICRO_VM_KERNEL_PATH:-${ISOLATED_CONFIG_DIR}/bin/vmlinux}"
	if [[ ! -f "$kernel" ]]; then
		missing+=("vmlinux kernel (run: ./iclaude.sh --install-microvm)")
	fi

	# Root filesystem image
	local rootfs="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
	if [[ ! -f "$rootfs" ]]; then
		missing+=("rootfs.ext4 (run: ./iclaude.sh --install-microvm)")
	fi

	# virtiofsd (required for workspace/nvm mounts)
	if ! detect_virtiofsd &>/dev/null; then
		local vfsd_hint; vfsd_hint=$(_virtiofsd_install_hint 2>/dev/null || echo "sudo apt-get install virtiofsd")
		missing+=("virtiofsd: ${vfsd_hint}")
	fi

	# ip tool for TAP networking
	if [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
		command -v ip &>/dev/null || missing+=("iproute2 (sudo apt-get install iproute2)")
		command -v iptables &>/dev/null || missing+=("iptables (sudo apt-get install iptables)")
	fi

	# Distro version check (warning only — doesn't block if user installed virtiofsd manually)
	local distro_reason
	if ! distro_reason=$(check_distro_microvm_support 2>&1); then
		missing+=("distro: $distro_reason")
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		printf '%s\n' "${missing[@]}"
		return 1
	fi
	return 0
}

#######################################
# Install virtiofsd from source via cargo (for Debian 10 / distros without package)
# Stores binary in ISOLATED_CONFIG_DIR/bin/virtiofsd (no sudo, gitignored)
# Returns:
#   0 - success
#   1 - failure
#######################################
_install_virtiofsd_cargo() {
	local bin_dir="${ISOLATED_CONFIG_DIR}/bin"
	local dest="${bin_dir}/virtiofsd"

	mkdir -p "$bin_dir"

	print_info "Installing virtiofsd from source (cargo)..."
	echo "  This is required for Debian 10 (Buster) — no package in repos."
	echo ""

	# Ensure cargo is available; install rustup if needed
	if ! command -v cargo &>/dev/null; then
		print_info "Rust/cargo not found — installing rustup (non-interactive)..."
		echo ""
		if ! command -v curl &>/dev/null; then
			print_error "curl is required to install rustup. Install it first: sudo apt-get install curl"
			return 1
		fi
		# Install rustup in non-interactive mode
		# Download first (separate from exec) so curl exit code is properly checked
		local rustup_installer
		rustup_installer=$(mktemp /tmp/rustup-init-XXXXXX.sh)
		if ! curl --proto '=https' --tlsv1.2 -sSf -o "$rustup_installer" https://sh.rustup.rs; then
			print_error "Failed to download rustup installer"
			rm -f "$rustup_installer"
			return 1
		fi
		if ! sh "$rustup_installer" -- -y --no-modify-path; then
			print_error "Failed to install rustup"
			rm -f "$rustup_installer"
			return 1
		fi
		rm -f "$rustup_installer"
		# Source cargo env for this session
		# shellcheck source=/dev/null
		[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
		if ! command -v cargo &>/dev/null; then
			print_error "cargo not found after rustup install. Try: source \$HOME/.cargo/env"
			return 1
		fi
		print_success "Rust toolchain installed"
		echo ""
	fi

	# Install virtiofsd crate
	print_info "Running: cargo install virtiofsd (may take a few minutes)..."
	echo ""
	if ! cargo install virtiofsd 2>&1; then
		print_error "cargo install virtiofsd failed"
		echo "  Check the output above for details."
		return 1
	fi

	# Locate installed binary (cargo installs to ~/.cargo/bin by default)
	local cargo_bin
	cargo_bin=$(command -v virtiofsd 2>/dev/null || echo "${CARGO_HOME:-$HOME/.cargo}/bin/virtiofsd")
	if [[ ! -x "$cargo_bin" ]]; then
		print_error "virtiofsd binary not found after cargo install"
		return 1
	fi

	# Copy to isolated bin dir (so detect_virtiofsd() finds it without PATH changes)
	install -m 755 "$cargo_bin" "$dest"
	print_success "virtiofsd installed: $dest"
	echo "  Version: $("$dest" --version 2>&1 | head -1 || echo "unknown")"
	echo ""

	return 0
}

# Install virtiofsd via apt-get (helper — reduces nesting in _install_virtiofsd_auto)
# Returns: 0 on success, 1 on failure
_apt_install_virtiofsd() {
	print_info "Installing virtiofsd via apt-get..."
	if sudo apt-get install -y virtiofsd 2>&1; then
		print_success "virtiofsd installed via apt-get"
		return 0
	fi
	print_error "apt-get install virtiofsd failed"
	return 1
}

#######################################
# Auto-install virtiofsd for current distro.
# - Ubuntu 22+ / Debian 11+ / ALT 10+: sudo apt-get install virtiofsd
# - Debian 10 (Buster): cargo install virtiofsd
# - Others: try apt-get, else print manual instructions
# Returns:
#   0 - virtiofsd available (pre-existing or freshly installed)
#   1 - installation failed
#######################################
_install_virtiofsd_auto() {
	# Already present — nothing to do
	if detect_virtiofsd &>/dev/null; then
		print_success "virtiofsd: $(detect_virtiofsd)"
		return 0
	fi

	local distro_ver; distro_ver=$(detect_linux_distro 2>/dev/null || echo "unknown:0")
	local distro="${distro_ver%%:*}"
	local ver="${distro_ver##*:}"
	local ver_major="${ver%%.*}"

	print_info "virtiofsd not found — attempting automatic installation..."
	echo "  Distro: ${distro_ver}"
	echo ""

	case "$distro" in
		ubuntu)
			if [[ "${ver_major:-0}" -lt 22 ]]; then
				print_error "Ubuntu ${ver} не поддерживается (требуется 22.04+)"
				return 1
			fi
			_apt_install_virtiofsd; return $?
			;;
		debian)
			if [[ "${ver_major:-0}" -ge 11 ]]; then
				_apt_install_virtiofsd; return $?
			elif [[ "${ver_major:-0}" -ge 10 ]]; then
				# Debian 10 (Buster) — no package, use cargo
				print_info "Debian 10: virtiofsd not in repos — building from source..."
				echo ""
				_install_virtiofsd_cargo; return $?
			fi
			print_error "Debian ${ver} не поддерживается (требуется Debian 10+)"
			return 1
			;;
		altlinux)
			if [[ "${ver_major:-0}" -lt 10 ]]; then
				print_error "ALT Linux ${ver} не поддерживается (требуется 10+)"
				return 1
			fi
			_apt_install_virtiofsd; return $?
			;;
		*)
			# Unknown/other distro — try apt-get, then print manual instructions
			if command -v apt-get &>/dev/null; then
				print_info "Trying: sudo apt-get install virtiofsd..."
				_apt_install_virtiofsd && return 0
			fi
			print_warning "Could not auto-install virtiofsd"
			echo ""
			echo "Install virtiofsd manually from your distro repos, or:"
			echo "  https://gitlab.com/virtio-fs/virtiofsd/-/releases"
			echo ""
			echo "Then re-run: ./iclaude.sh --install-microvm"
			return 1
			;;
	esac
}

#######################################
# Download and install Firecracker microVM binaries
# Downloads: firecracker binary, vmlinux kernel, rootfs.ext4
# All stored in ISOLATED_CONFIG_DIR/bin/ (covered by .gitignore)
# Returns:
#   0 - success
#   1 - failure
#######################################
install_microvm() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  microVM: Install Firecracker"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Isolated env required
	if [[ ! -d "${ISOLATED_NVM_DIR:-}" ]]; then
		print_error "Isolated environment not found. Run --isolated-install first."
		return 1
	fi

	# Detect architecture
	local arch
	arch=$(uname -m)
	case "$arch" in
		x86_64)  arch="x86_64" ;;
		aarch64) arch="aarch64" ;;
		*)
			print_error "Unsupported architecture: $arch (only x86_64 and aarch64)"
			return 1
			;;
	esac
	print_info "Architecture: $arch"

	# Check KVM early
	local kvm_reason
	if ! kvm_reason=$(detect_kvm_support 2>&1); then
		print_error "KVM not available: $kvm_reason"
		echo ""
		echo "microVM requires hardware virtualization (KVM)."
		echo "On bare metal Linux: ensure VT-x/AMD-V is enabled in BIOS."
		echo "In a VM: enable nested virtualization."
		return 1
	fi
	print_success "KVM: available"

	# Distro version gate — check early, before any downloads
	local distro_ver; distro_ver=$(detect_linux_distro 2>/dev/null || echo "unknown:0")
	local distro_reason
	if ! distro_reason=$(check_distro_microvm_support 2>&1); then
		print_error "$distro_reason"
		return 1
	fi
	if [[ "${distro_ver%%:*}" != "unknown" ]]; then
		print_info "OS: ${distro_ver} — supported"
	fi

	# Install virtiofsd automatically (distro-aware; Debian 10 uses cargo)
	if ! _install_virtiofsd_auto; then
		print_warning "virtiofsd not available — workspace/NVM mounts will be disabled"
		echo ""
	fi

	# Prepare bin directory (inside .gitignore-covered path)
	local bin_dir="${ISOLATED_CONFIG_DIR}/bin"
	mkdir -p "$bin_dir"
	chmod 700 "$bin_dir"
	print_info "Install directory: $bin_dir"
	echo ""

	# Firecracker version to install
	local fc_version="v1.11.0"
	local fc_bin="${bin_dir}/firecracker"
	local fc_url="https://github.com/firecracker-microvm/firecracker/releases/download/${fc_version}/firecracker-${fc_version}-${arch}.tgz"

	print_info "Downloading Firecracker ${fc_version} (${arch})..."
	echo "  Source: $fc_url"
	echo ""

	# Download with curl or wget
	local tmp_tgz="${bin_dir}/firecracker.tgz.tmp"
	if command -v curl &>/dev/null; then
		if ! curl -fsSL --progress-bar -o "$tmp_tgz" "$fc_url"; then
			print_error "Failed to download Firecracker"
			rm -f "$tmp_tgz"
			return 1
		fi
	elif command -v wget &>/dev/null; then
		if ! wget -q --show-progress -O "$tmp_tgz" "$fc_url"; then
			print_error "Failed to download Firecracker"
			rm -f "$tmp_tgz"
			return 1
		fi
	else
		print_error "Neither curl nor wget found. Install one of them first."
		return 1
	fi

	# Extract firecracker binary from tgz
	print_info "Extracting Firecracker binary..."
	local tmp_dir="${bin_dir}/fc_extract_tmp"
	mkdir -p "$tmp_dir"
	if ! tar -xzf "$tmp_tgz" -C "$tmp_dir" 2>/dev/null; then
		print_error "Failed to extract Firecracker archive"
		rm -rf "$tmp_tgz" "$tmp_dir"
		return 1
	fi
	rm -f "$tmp_tgz"

	# Find the firecracker binary inside extracted dir
	local fc_extracted
	fc_extracted=$(find "$tmp_dir" -name "firecracker-${fc_version}-${arch}" -o -name "firecracker" 2>/dev/null | head -1)
	if [[ -z "$fc_extracted" ]]; then
		# Fallback: find any executable named firecracker*
		fc_extracted=$(find "$tmp_dir" -type f -name "firecracker*" 2>/dev/null | head -1)
	fi
	if [[ -z "$fc_extracted" ]]; then
		print_error "firecracker binary not found in archive"
		rm -rf "$tmp_dir"
		return 1
	fi

	cp "$fc_extracted" "$fc_bin"
	chmod 755 "$fc_bin"
	rm -rf "$tmp_dir"
	print_success "Firecracker: $fc_bin"

	# Download kernel (microvm-optimized vmlinux)
	local kernel_path="${MICRO_VM_KERNEL_PATH:-${bin_dir}/vmlinux}"
	local kernel_url="https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/${arch}/vmlinux-6.1.102"

	print_info "Downloading Linux kernel (vmlinux, ~40MB)..."
	echo "  Source: $kernel_url"
	echo ""

	if command -v curl &>/dev/null; then
		if ! curl -fsSL --progress-bar -o "$kernel_path" "$kernel_url"; then
			print_error "Failed to download vmlinux kernel"
			return 1
		fi
	else
		if ! wget -q --show-progress -O "$kernel_path" "$kernel_url"; then
			print_error "Failed to download vmlinux kernel"
			return 1
		fi
	fi
	chmod 644 "$kernel_path"
	print_success "Kernel: $kernel_path"

	# Download rootfs (Alpine-based microVM rootfs)
	local rootfs_path="${MICRO_VM_ROOTFS_PATH:-${bin_dir}/rootfs.ext4}"
	local rootfs_url="https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/${arch}/ubuntu-22.04.ext4"

	print_info "Downloading rootfs image (~300MB)..."
	echo "  Source: $rootfs_url"
	echo ""

	if command -v curl &>/dev/null; then
		if ! curl -fsSL --progress-bar -o "$rootfs_path" "$rootfs_url"; then
			print_error "Failed to download rootfs image"
			return 1
		fi
	else
		if ! wget -q --show-progress -O "$rootfs_path" "$rootfs_url"; then
			print_error "Failed to download rootfs image"
			return 1
		fi
	fi
	chmod 644 "$rootfs_path"
	print_success "Rootfs: $rootfs_path"

	# Create working directories
	local work_dir="${MICRO_VM_WORK_DIR:-${ISOLATED_CONFIG_DIR}/microvm-run}"
	local snap_dir="${MICRO_VM_SNAPSHOT_DIR:-${ISOLATED_CONFIG_DIR}/microvm-snapshots}"
	mkdir -p "$work_dir" "$snap_dir"
	chmod 700 "$work_dir" "$snap_dir"

	# Setup TAP networking (requires sudo)
	if [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
		echo ""
		_setup_microvm_network_or_instruct
	fi

	echo ""
	print_success "microVM installed successfully!"
	echo ""
	print_info "Firecracker: $("$fc_bin" --version 2>/dev/null | head -1 || echo "installed")"
	echo ""
	print_info "Next steps:"
	print_info "  1. Enable: add MICRO_VM_ENABLED=true to .claude_config"
	print_info "  2. Launch: ./iclaude.sh --sandbox-microvm"
	print_info "  3. Status: ./iclaude.sh --check-microvm"
	echo ""

	return 0
}

#######################################
# Attempt to setup TAP networking; if sudo unavailable — print manual instructions.
# Called from install_microvm().
#######################################
_setup_microvm_network_or_instruct() {
	local tap_iface="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
	local host_ip="${MICRO_VM_NET_HOST_IP:-172.16.0.1}"

	# Validate inputs before use in sudo commands (prevent command injection)
	if ! [[ "$tap_iface" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then
		print_error "microVM network: invalid TAP interface name '${tap_iface}' (alphanumeric, dash, underscore, max 15 chars)"
		return 1
	fi
	if ! [[ "$host_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		print_error "microVM network: invalid host IP '${host_ip}'"
		return 1
	fi

	print_info "Setting up TAP networking (${tap_iface}, ${host_ip}/24)..."

	# Check if TAP already exists
	if ip link show "$tap_iface" &>/dev/null; then
		print_success "TAP interface ${tap_iface} already exists"
		return 0
	fi

	# Try sudo (non-interactive)
	if sudo -n true 2>/dev/null; then
		if sudo ip tuntap add dev "$tap_iface" mode tap 2>/dev/null && \
		   sudo ip addr add "${host_ip}/24" dev "$tap_iface" 2>/dev/null && \
		   sudo ip link set "$tap_iface" up 2>/dev/null; then
			# Enable IP forwarding and NAT
			sudo sysctl -w net.ipv4.ip_forward=1 &>/dev/null || true
			# Find outbound interface for masquerade; validate before use in iptables
			local out_iface
			out_iface=$(ip route | awk '/^default/ {print $5; exit}')
			if [[ -n "$out_iface" ]]; then
				if ! [[ "$out_iface" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then
					print_warning "microVM: unusual outbound interface name '${out_iface}' — skipping iptables setup"
				else
					sudo iptables -t nat -A POSTROUTING -o "$out_iface" -j MASQUERADE 2>/dev/null || true
					sudo iptables -A FORWARD -i "$tap_iface" -o "$out_iface" -j ACCEPT 2>/dev/null || true
					sudo iptables -A FORWARD -i "$out_iface" -o "$tap_iface" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
				fi
			fi
			print_success "TAP interface configured: ${tap_iface} (${host_ip}/24)"
			return 0
		fi
	fi

	# sudo unavailable or failed — print manual instructions
	print_warning "Cannot configure TAP networking automatically (sudo required)"
	echo ""
	echo "Run the following commands manually to enable networking in microVM:"
	echo ""
	echo "  sudo ip tuntap add dev ${tap_iface} mode tap"
	echo "  sudo ip addr add ${host_ip}/24 dev ${tap_iface}"
	echo "  sudo ip link set ${tap_iface} up"
	echo "  sudo sysctl -w net.ipv4.ip_forward=1"
	echo "  OUT=\$(ip route | awk '/^default/ {print \$5; exit}')"
	echo "  sudo iptables -t nat -A POSTROUTING -o \"\$OUT\" -j MASQUERADE"
	echo ""
	echo "Or launch without networking: ./iclaude.sh --sandbox-microvm (MICRO_VM_NET_ENABLED=false)"
	echo ""
}
