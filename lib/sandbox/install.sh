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

	# ── Fast-path: check existing install status ────────────────────────────────
	local _bin_dir="${ISOLATED_CONFIG_DIR}/bin"
	local _rootfs="${MICRO_VM_ROOTFS_PATH:-${_bin_dir}/rootfs.ext4}"
	local _v2_marker="${_rootfs%.ext4}.v2-ready"
	local _ssh_key="${ISOLATED_CONFIG_DIR}/ssh/microvm"

	local _nvm_img="${MICRO_VM_NVM_IMG:-${_bin_dir}/nvm.img}"

	if [[ -f "$_rootfs" ]]; then
		if [[ -f "$_v2_marker" && -f "$_ssh_key" && -f "$_nvm_img" ]]; then
			print_success "microVM already installed and up-to-date (v2)"
			print_info "Rootfs: $_rootfs"
			print_info "NVM image: $_nvm_img"
			print_info "To force re-download: rm $_rootfs && ./iclaude.sh --install-microvm"
			return 0
		fi

		# Rootfs exists but v2 not applied — upgrade without re-downloading
		print_info "Existing rootfs found — upgrading to v2 (keygen + inject + NVM image)..."
		echo ""
		# Key must be generated before inject (inject bakes pubkey into rootfs authorized_keys)
		_generate_microvm_ssh_key || print_warning "SSH key generation failed — SSH access unavailable"
		local _guest_init_src="${BASH_SOURCE[0]%/*}/guest-init.sh"
		if [[ -f "$_guest_init_src" ]]; then
			_inject_rootfs_guest_init "$_rootfs" "$_guest_init_src" \
				|| print_warning "v2 inject failed"
		else
			print_warning "guest-init.sh not found at $_guest_init_src — v2 unavailable"
		fi
		_create_microvm_nvm_image || print_warning "NVM block image creation failed — claude unavailable in guest"
		echo ""
		print_success "microVM v2 upgrade complete"
		print_info "Verify: debugfs -R 'stat /usr/sbin/iclaude-guest-init' $_rootfs"
		return 0
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

	# Kernel: Firecracker CI kernel (ELF vmlinux, works with all Firecracker versions).
	# Note: Firecracker v1.11.0 does not implement virtiofs backend — block devices used instead.
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

	# Generate SSH key pair FIRST — public key is baked into rootfs by _inject_rootfs_guest_init
	# so the guest can accept SSH connections without any per-session key passing.
	_generate_microvm_ssh_key || print_warning "SSH key generation failed — SSH access unavailable"

	# Inject guest init for v2 (claude runs inside guest via SSH)
	# Also bakes authorized_keys from the key generated above into /root/.ssh/
	local guest_init_src="${BASH_SOURCE[0]%/*}/guest-init.sh"
	if [[ -f "$guest_init_src" ]]; then
		if ! _inject_rootfs_guest_init "$rootfs_path" "$guest_init_src"; then
			print_warning "microVM v2 init injection failed"
		fi
	else
		print_warning "guest-init.sh not found at $guest_init_src — v2 unavailable"
	fi

	# Build NVM block image (pre-built, attached read-only each session as /dev/vdb → /mnt/nvm)
	# Replaces per-session virtiofsd: simpler, more reliable, works with FC v1.11.0
	_create_microvm_nvm_image || print_warning "NVM block image creation failed — claude unavailable in guest"

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

	# Derive host IP and prefix from MICRO_VM_NET_SUBNET (slot 0 = base+1).
	# Legacy: fall back to MICRO_VM_NET_HOST_IP if SUBNET not set.
	local host_ip prefix
	if [[ -n "${MICRO_VM_NET_SUBNET:-}" ]]; then
		local subnet="${MICRO_VM_NET_SUBNET}"
		local base="${subnet%/*}"
		prefix="${subnet#*/}"
		if ! [[ "$prefix" =~ ^[0-9]+$ ]] || (( prefix < 1 || prefix > 30 )); then
			print_error "microVM network: invalid prefix in MICRO_VM_NET_SUBNET='${subnet}'"
			return 1
		fi
		# Compute base+1 for slot-0 host IP
		IFS='.' read -r _o1 _o2 _o3 _o4 <<< "$base"
		local base_int=$(( _o1*16777216 + _o2*65536 + _o3*256 + _o4 ))
		local host_int=$(( base_int + 1 ))
		host_ip=$(printf '%d.%d.%d.%d' \
			$(( (host_int>>24)&255 )) $(( (host_int>>16)&255 )) \
			$(( (host_int>>8)&255 )) $(( host_int&255 )))
	else
		host_ip="${MICRO_VM_NET_HOST_IP:-172.16.0.1}"
		prefix=24
	fi

	# Validate inputs before use in sudo commands (prevent command injection)
	if ! [[ "$tap_iface" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then
		print_error "microVM network: invalid TAP interface name '${tap_iface}' (alphanumeric, dash, underscore, max 15 chars)"
		return 1
	fi
	if ! [[ "$host_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		print_error "microVM network: invalid host IP '${host_ip}'"
		return 1
	fi

	print_info "Setting up TAP networking (${tap_iface}, ${host_ip}/${prefix})..."

	# Check if TAP already exists
	if ip link show "$tap_iface" &>/dev/null; then
		# Verify IP matches — update if not
		local tap_ip
		tap_ip=$(ip addr show "$tap_iface" 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]; exit}')
		if [[ "$tap_ip" == "$host_ip" ]]; then
			print_success "TAP interface ${tap_iface} already configured (${host_ip}/${prefix})"
			return 0
		fi
		print_warning "TAP ${tap_iface} has IP ${tap_ip:-none}, expected ${host_ip}/${prefix} — updating"
		if sudo -n true 2>/dev/null; then
			[[ -n "$tap_ip" ]] && sudo ip addr del "${tap_ip}/${prefix}" dev "$tap_iface" 2>/dev/null || true
			sudo ip addr add "${host_ip}/${prefix}" dev "$tap_iface" 2>/dev/null && \
			sudo ip link set "$tap_iface" up 2>/dev/null && \
			print_success "TAP ${tap_iface} IP updated → ${host_ip}/${prefix}" || \
			print_warning "TAP IP update failed — routing may not work"
		else
			print_warning "Cannot update TAP IP (sudo unavailable) — routing may fail"
			print_info "  Fix: sudo ip addr add ${host_ip}/${prefix} dev ${tap_iface}"
		fi
		return 0
	fi

	# TAP doesn't exist — try to create via sudo
	if sudo -n true 2>/dev/null; then
		if sudo ip tuntap add dev "$tap_iface" mode tap 2>/dev/null && \
		   sudo ip addr add "${host_ip}/${prefix}" dev "$tap_iface" 2>/dev/null && \
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
			print_success "TAP interface configured: ${tap_iface} (${host_ip}/${prefix})"
			return 0
		fi
	fi

	# sudo unavailable or failed — print manual instructions
	print_warning "Cannot configure TAP networking automatically (sudo required)"
	echo ""
	echo "Run the following commands manually to enable networking in microVM:"
	echo ""
	echo "  sudo ip tuntap add dev ${tap_iface} mode tap"
	echo "  sudo ip addr add ${host_ip}/${prefix} dev ${tap_iface}"
	echo "  sudo ip link set ${tap_iface} up"
	echo "  sudo sysctl -w net.ipv4.ip_forward=1"
	echo "  OUT=\$(ip route | awk '/^default/ {print \$5; exit}')"
	echo "  sudo iptables -t nat -A POSTROUTING -o \"\$OUT\" -j MASQUERADE"
	echo ""
	echo "Or launch without networking: ./iclaude.sh --sandbox-microvm (MICRO_VM_NET_ENABLED=false)"
	echo ""
}

#######################################
# Generate SSH key pair for microVM guest access (v2).
# Key stored in ISOLATED_CONFIG_DIR/ssh/microvm (ed25519, no passphrase).
# Public key is baked into rootfs /root/.ssh/authorized_keys by _inject_rootfs_guest_init().
# Returns:
#   0 - key exists or generated successfully
#   1 - generation failed
#######################################
_generate_microvm_ssh_key() {
	local key_dir="${ISOLATED_CONFIG_DIR}/ssh"
	local key_path="${key_dir}/microvm"
	mkdir -p "$key_dir"
	chmod 700 "$key_dir"
	if [[ -f "${key_path}" ]]; then
		print_success "microVM SSH key: ${key_path}"
		return 0
	fi
	print_info "Generating SSH key pair for microVM access..."
	if ! ssh-keygen -t ed25519 -N "" -C "iclaude-microvm-$(date +%Y%m%d)" \
			-f "$key_path" >/dev/null 2>&1; then
		print_error "ssh-keygen failed"
		return 1
	fi
	chmod 600 "$key_path"
	chmod 644 "${key_path}.pub"
	print_success "SSH key: ${key_path}"
	return 0
}

#######################################
# Create pre-built NVM ext4 block image from the isolated NVM directory.
# The image is attached read-only to each session as /dev/vdb → /mnt/nvm.
# One-time at install; re-run --install-microvm to rebuild after NVM updates.
# Requires sudo (loop mount for populating the image via rsync).
# Image stored at ISOLATED_CONFIG_DIR/bin/nvm.img (covered by .gitignore).
# Returns:
#   0 - success (or image already up-to-date)
#   1 - failure
#######################################
_create_microvm_nvm_image() {
	local nvm_img="${MICRO_VM_NVM_IMG:-${ISOLATED_CONFIG_DIR}/bin/nvm.img}"
	local nvm_src="${ISOLATED_NVM_DIR:-}"

	if [[ -z "$nvm_src" || ! -d "$nvm_src" ]]; then
		print_error "microVM: isolated NVM directory not found: ${nvm_src:-<unset>}"
		print_error "Run --isolated-install first"
		return 1
	fi

	# Check sudo access (needed for loop mount)
	if ! sudo -n true 2>/dev/null; then
		print_error "microVM: sudo required to create NVM block image (loop mount)"
		echo "  Grant passwordless sudo then re-run: ./iclaude.sh --install-microvm"
		return 1
	fi

	# Estimate NVM content size (subtract large host-specific dirs: bin/, projects/, pii-proxy-venv/).
	# Note: du --exclude=PATTERN does not work reliably with full paths on all GNU versions.
	# Use subtraction: total minus excluded dirs (if they exist).
	# Add 20% headroom. Minimum 512MiB, round to 64MiB boundary.
	local nvm_size_kb
	nvm_size_kb=$(du -sk "$nvm_src" 2>/dev/null | awk '{print $1}')
	for _excl_dir in \
		"$nvm_src/.claude-isolated/bin" \
		"$nvm_src/.claude-isolated/projects" \
		"$nvm_src/.claude-isolated/pii-proxy-venv" \
		"$nvm_src/.claude-isolated/debug"; do
		if [[ -d "$_excl_dir" ]]; then
			local _excl_kb; _excl_kb=$(du -sk "$_excl_dir" 2>/dev/null | awk '{print $1}')
			nvm_size_kb=$(( nvm_size_kb - _excl_kb ))
		fi
	done
	[[ "$nvm_size_kb" -lt 1 ]] && nvm_size_kb=1
	local nvm_size_mb=$(( (nvm_size_kb * 12 / 10 + 1023) / 1024 ))
	nvm_size_mb=$(( (nvm_size_mb < 512 ? 512 : nvm_size_mb + 63) / 64 * 64 ))

	print_info "microVM: creating NVM block image (${nvm_size_mb}MiB from $(basename "$nvm_src"))..."

	local tmp_img="${nvm_img}.tmp"
	# Create sparse ext4 image
	if ! dd if=/dev/zero of="$tmp_img" bs=1M count=0 seek="$nvm_size_mb" 2>/dev/null; then
		print_error "microVM: failed to create NVM image at ${tmp_img}"
		rm -f "$tmp_img"; return 1
	fi
	if ! mkfs.ext4 -F -q -L iclaude-nvm "$tmp_img" 2>/dev/null; then
		print_error "microVM: failed to format NVM image (mkfs.ext4)"
		rm -f "$tmp_img"; return 1
	fi

	# Mount and populate via rsync (requires sudo for loop device setup).
	# Exclude host-specific dirs not needed in guest: microVM binaries, session history,
	# Python venvs, SSH keys, logs, caches, and other runtime-only data.
	local mnt_tmp; mnt_tmp=$(mktemp -d)
	if ! sudo mount -o loop "$tmp_img" "$mnt_tmp" 2>/dev/null; then
		print_error "microVM: failed to mount NVM image (loop device)"
		rm -f "$tmp_img"; rmdir "$mnt_tmp" 2>/dev/null; return 1
	fi

	print_info "microVM: populating NVM image via rsync..."
	if ! sudo rsync -a --delete \
		--exclude='.claude-isolated/bin/' \
		--exclude='.claude-isolated/projects/' \
		--exclude='.claude-isolated/pii-proxy-venv/' \
		--exclude='.claude-isolated/pii-proxy*' \
		--exclude='.claude-isolated/debug/' \
		--exclude='.claude-isolated/file-history/' \
		--exclude='.claude-isolated/todos/' \
		--exclude='.claude-isolated/paste-cache/' \
		--exclude='.claude-isolated/tasks/' \
		--exclude='.claude-isolated/telemetry/' \
		--exclude='.claude-isolated/session-env/' \
		--exclude='.claude-isolated/cache/' \
		--exclude='.claude-isolated/shell-snapshots/' \
		--exclude='.claude-isolated/plans/' \
		--exclude='.claude-isolated/statsig/' \
		--exclude='.claude-isolated/ssh/' \
		--exclude='.claude-isolated/chrome/' \
		--exclude='.claude-isolated/microvm-run/' \
		--exclude='.claude-isolated/microvm-snapshots/' \
		--exclude='.claude-isolated/backups/' \
		--exclude='versions/node/*/include/' \
		--exclude='versions/node/*/.npm/' \
		--exclude='.npm/' \
		"$nvm_src/" "$mnt_tmp/" 2>/dev/null; then
		print_warning "microVM: rsync had errors — NVM image may be incomplete"
	fi

	sudo umount "$mnt_tmp" && rmdir "$mnt_tmp" 2>/dev/null || true

	# Atomically replace old image
	mv "$tmp_img" "$nvm_img"
	chmod 644 "$nvm_img"

	local actual_size; actual_size=$(du -sh "$nvm_img" 2>/dev/null | awk '{print $1}')
	print_success "NVM block image: $nvm_img (${actual_size} on disk, ${nvm_size_mb}MiB virtual)"
	return 0
}

#######################################
# Inject guest init script into rootfs image (via debugfs, no sudo).
# Injects:
#   /usr/sbin/iclaude-guest-init  — PID 1 init script (block device mounts + sshd)
#   /etc/ssh/sshd_config.d/iclaude.conf — SSH config (PermitRootLogin yes, pubkey only)
#   /root/.ssh/authorized_keys    — static per-machine SSH pubkey (from ssh/microvm.pub)
#   /mnt, /mnt/nvm, /workspace    — mount point directories
# Marks rootfs as v2-ready via a sibling .v2-ready marker file.
# Arguments:
#   $1 - rootfs: path to rootfs.ext4 image
#   $2 - init_src: path to guest-init.sh on host
# Returns:
#   0 - success
#   1 - failure (debugfs missing or command failed)
#######################################
_inject_rootfs_guest_init() {
	local rootfs="$1"
	local init_src="$2"

	if ! command -v debugfs &>/dev/null; then
		print_error "debugfs not found (install e2fsprogs: sudo apt-get install e2fsprogs)"
		return 1
	fi

	print_info "Injecting guest init into rootfs (via debugfs)..."

	# Write SSH config override
	local ssh_conf_tmp; ssh_conf_tmp=$(mktemp)
	printf 'PermitRootLogin yes\nPubkeyAuthentication yes\nPasswordAuthentication no\n' \
		> "$ssh_conf_tmp"

	# NOTE: Ubuntu 22.04 rootfs has /sbin → /usr/sbin as a symlink.
	# debugfs does NOT follow symlinks when writing, so we must use /usr/sbin directly.
	# debugfs 'chmod' command is broken (no-op) in some versions — use 'set_inode_field' instead.
	# 0100755 = regular file (010----) + rwxr-xr-x (0755)
	# 0100644 = regular file (010----) + rw-r--r-- (0644)
	debugfs -w "$rootfs" <<EOF 2>/dev/null
write ${init_src} /usr/sbin/iclaude-guest-init
set_inode_field /usr/sbin/iclaude-guest-init mode 0100755
write ${ssh_conf_tmp} /etc/ssh/sshd_config.d/iclaude.conf
set_inode_field /etc/ssh/sshd_config.d/iclaude.conf mode 0100644
mkdir /mnt
mkdir /mnt/nvm
mkdir /workspace
EOF
	local rc=$?
	rm -f "$ssh_conf_tmp"
	if [[ $rc -ne 0 ]]; then
		print_error "debugfs injection failed (rc=$rc)"
		return 1
	fi

	# Bake SSH authorized_keys into rootfs (static per-machine key generated by _generate_microvm_ssh_key).
	# This allows guest to accept SSH connections without any per-session key injection.
	# The key is in /root/.ssh/authorized_keys; guest-init.sh reads from /workspace/.iclaude-ssh/
	# ONLY as a fallback — the baked key is authoritative.
	local ssh_pubkey="${ISOLATED_CONFIG_DIR}/ssh/microvm.pub"
	if [[ -f "$ssh_pubkey" ]]; then
		debugfs -w "$rootfs" <<EOF 2>/dev/null
mkdir /root
mkdir /root/.ssh
write ${ssh_pubkey} /root/.ssh/authorized_keys
set_inode_field /root/.ssh/authorized_keys mode 0100600
EOF
		if debugfs -R 'stat /root/.ssh/authorized_keys' "$rootfs" 2>/dev/null | grep -q "Inode:"; then
			print_success "SSH authorized_keys baked into rootfs"
		else
			print_warning "authorized_keys injection failed — SSH access may not work"
		fi
	else
		print_warning "SSH public key not found: $ssh_pubkey"
		print_warning "authorized_keys NOT baked — run _generate_microvm_ssh_key first"
	fi

	# Mark v2 ready (marker file alongside rootfs)
	touch "${rootfs%.ext4}.v2-ready"
	print_success "Guest init injected (rootfs ready for v2)"
	return 0
}
