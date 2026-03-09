#!/bin/bash
# Sandbox installation module
# Provides functions for installing microVM (Firecracker) dependencies

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
# Verify SHA-256 checksum of a downloaded file.
# If expected hash is empty, verification is skipped (opt-in security).
# Arguments:
#   $1 - file: path to file to verify
#   $2 - expected: expected SHA-256 hex digest (empty = skip)
#   $3 - label: human-readable name for error messages (optional)
# Returns:
#   0 - verification passed (or skipped)
#   1 - hash mismatch
#######################################
_verify_sha256() {
	local file="$1"
	local expected="$2"
	local label="${3:-file}"

	if [[ -z "$expected" ]]; then
		return 0  # Skip verification if no hash provided
	fi

	if ! command -v sha256sum &>/dev/null; then
		print_warning "sha256sum not available — skipping integrity check for ${label}"
		return 0
	fi

	local actual
	actual=$(sha256sum "$file" | cut -d' ' -f1)
	if [[ "$actual" == "$expected" ]]; then
		print_info "SHA-256 verified: ${label}"
		return 0
	fi

	print_error "SHA-256 mismatch for ${label}:"
	print_error "  expected: ${expected}"
	print_error "  actual:   ${actual}"
	print_error "The download may be corrupted or tampered with."
	return 1
}

#######################################
# Download Firecracker binary from GitHub releases, extract from tgz, verify.
# Arguments:
#   $1 - bin_dir: destination directory for the binary
#   $2 - arch: target architecture (x86_64 or aarch64)
#   $3 - fc_version: Firecracker version string (e.g. "v1.11.0")
#   $4 - sha256: expected SHA-256 hash (empty = skip verification)
# Returns:
#   0 - success; binary installed at $bin_dir/firecracker
#   1 - failure
#######################################
_download_firecracker() {
	local bin_dir="$1"
	local arch="$2"
	local fc_version="$3"
	local sha256="$4"

	local fc_bin="${bin_dir}/firecracker"
	local fc_url="https://github.com/firecracker-microvm/firecracker/releases/download/${fc_version}/firecracker-${fc_version}-${arch}.tgz"

	print_info "Downloading Firecracker ${fc_version} (${arch})..."
	echo "  Source: $fc_url"
	echo ""

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
	if ! _verify_sha256 "$fc_bin" "$sha256" "firecracker ${fc_version}"; then
		rm -f "$fc_bin"
		return 1
	fi
	print_success "Firecracker: $fc_bin"
}

#######################################
# Download vmlinux kernel image from Firecracker CI S3 bucket.
# Arguments:
#   $1 - kernel_path: destination file path for the kernel
#   $2 - arch: target architecture (x86_64 or aarch64)
#   $3 - sha256: expected SHA-256 hash (empty = skip verification)
# Returns:
#   0 - success
#   1 - failure
#######################################
_download_vmlinux() {
	local kernel_path="$1"
	local arch="$2"
	local sha256="$3"

	# Kernel: Firecracker CI kernel (ELF vmlinux, works with all Firecracker versions).
	# Note: Firecracker v1.11.0 does not implement virtiofs backend — block devices used instead.
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
	if ! _verify_sha256 "$kernel_path" "$sha256" "vmlinux kernel"; then
		rm -f "$kernel_path"
		return 1
	fi
	print_success "Kernel: $kernel_path"
}

#######################################
# Resize rootfs ext4 image to at least target_mb MB.
# Uses truncate + e2fsck + resize2fs. No-op if image is already large enough.
# Arguments:
#   $1 - rootfs_path: path to rootfs.ext4
#   $2 - target_mb:   minimum size in MB (e.g. 500)
# Returns:
#   0 - success (resized or already large enough)
#######################################
_resize_rootfs() {
	local rootfs_path="$1"
	local target_mb="${2:-500}"

	if [[ ! -f "$rootfs_path" ]]; then
		print_error "rootfs not found: $rootfs_path"
		return 1
	fi

	local current_bytes; current_bytes=$(stat -c%s "$rootfs_path" 2>/dev/null || echo 0)
	local current_mb=$(( current_bytes / 1048576 ))
	if [[ $current_mb -ge $target_mb ]]; then
		print_success "rootfs already ${current_mb}MB (≥ ${target_mb}MB) — no resize needed"
		return 0
	fi

	if ! command -v resize2fs &>/dev/null; then
		print_warning "resize2fs not found (install e2fsprogs) — rootfs resize skipped"
		return 0
	fi

	print_info "Resizing rootfs from ${current_mb}MB to ${target_mb}MB..."
	truncate -s "${target_mb}M" "$rootfs_path"
	if command -v e2fsck &>/dev/null; then
		e2fsck -fy "$rootfs_path" &>/dev/null || true
	fi
	if ! resize2fs "$rootfs_path" &>/dev/null; then
		print_warning "resize2fs failed — rootfs may not have full ${target_mb}MB"
		return 0
	fi
	print_success "rootfs resized to ${target_mb}MB"
	return 0
}

#######################################
# Download Ubuntu rootfs image from Firecracker CI S3 bucket.
# Arguments:
#   $1 - rootfs_path: destination file path for the rootfs image
#   $2 - arch: target architecture (x86_64 or aarch64)
#   $3 - sha256: expected SHA-256 hash (empty = skip verification)
# Returns:
#   0 - success
#   1 - failure
#######################################
_download_rootfs() {
	local rootfs_path="$1"
	local arch="$2"
	local sha256="$3"

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
	if ! _verify_sha256 "$rootfs_path" "$sha256" "rootfs image"; then
		rm -f "$rootfs_path"
		return 1
	fi
	print_success "Rootfs: $rootfs_path"
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
	local _v3_marker="${_rootfs%.ext4}.v3-ready"
	local _v4_marker="${_rootfs%.ext4}.v4-ready"
	local _v5_marker="${_rootfs%.ext4}.v5-ready"
	local _v6_marker="${_rootfs%.ext4}.v6-ready"
	local _v7_marker="${_rootfs%.ext4}.v7-ready"
	local _ssh_key="${ISOLATED_CONFIG_DIR}/ssh/microvm"

	local _nvm_img="${MICRO_VM_NVM_IMG:-${_bin_dir}/nvm.img}"

	if [[ -f "$_rootfs" ]]; then
		if [[ -f "$_v7_marker" && -f "$_ssh_key" && -f "$_nvm_img" ]]; then
			print_success "microVM already installed and up-to-date (v7)"
			print_info "Rootfs: $_rootfs"
			print_info "NVM image: $_nvm_img"
			print_info "To force re-download: rm $_rootfs && ./iclaude.sh --install-microvm"
			return 0
		fi

		# Safety check: abort if any Firecracker process is running.
		# debugfs -w on a rootfs actively mounted by a live VM causes ext4 corruption
		# (multiply-claimed blocks) because debugfs ignores the kernel VFS cache.
		local _fc_pids; _fc_pids=$(pgrep -x firecracker 2>/dev/null || true)
		if [[ -n "$_fc_pids" ]]; then
			print_error "Active Firecracker process(es) detected (PID: $_fc_pids)"
			print_error "Stop all microVM sessions before running --install-microvm."
			print_error "  If using --sandbox-microvm: exit Claude Code, then retry."
			print_error "  Or manually: kill $_fc_pids"
			return 1
		fi

		# Fast-path v6→v7: inject rsync for delta sync (ControlMaster + rsync).
		# Requires rsync on host (sudo apt-get install rsync).
		if [[ -f "$_v6_marker" && ! -f "$_v7_marker" ]]; then
			print_info "Existing rootfs found — upgrading to v7 (inject rsync for delta sync)..."
			local _rsync_host; _rsync_host=$(command -v rsync 2>/dev/null || true)
			if [[ -n "$_rsync_host" && -f "$_rsync_host" ]]; then
				e2fsck -fy "$_rootfs" &>/dev/null || true
				debugfs -w "$_rootfs" <<EOF 2>/dev/null
rm /usr/bin/rsync
write ${_rsync_host} /usr/bin/rsync
set_inode_field /usr/bin/rsync mode 0100755
EOF
				touch "$_v7_marker"
				print_success "rootfs upgraded to v7 (rsync injected — delta sync enabled)"
			else
				print_warning "rsync not found on host — v7 upgrade skipped (install: sudo apt-get install rsync)"
				print_warning "Periodic sync will fall back to tar-over-SSH"
			fi
			return 0
		fi

		# Fast-path v5→v6 upgrade: only resize needed, no re-injection.
		# v6 adds: rootfs resized to 500MB for headroom (avoids ENOSPC in npm/node on rootfs).
		if [[ -f "$_v5_marker" && ! -f "$_v6_marker" ]]; then
			print_info "Existing rootfs found — upgrading to v6 (resize to 500MB for headroom)..."
			echo ""
			_resize_rootfs "$_rootfs" 500
			touch "$_v6_marker"
			echo ""
			print_success "microVM v6 upgrade complete"
			print_info "Verify: ./iclaude.sh --check-microvm"
			return 0
		fi

		# Rootfs exists but v5/v6 not applied — upgrade without re-downloading.
		# v6 adds: rootfs resized to 500MB (avoids ENOSPC for npm/node writes on rootfs).
		# v5 adds: /tmp mounted as tmpfs in guest-init (world-writable, fixes Bash tool access).
		# v4 adds: CA certificate bundle (/etc/ssl/certs/ca-certificates.crt) for HTTPS in guest.
		# v3 adds: jq binary in guest (/usr/bin/jq for statusline), DNS configuration in guest-init.
		if [[ -f "$_v4_marker" ]]; then
			print_info "Existing rootfs found — upgrading to v6 (fix /tmp permissions + resize)..."
		elif [[ -f "$_v3_marker" ]]; then
			print_info "Existing rootfs found — upgrading to v6 (CA bundle + /tmp fix + resize)..."
		else
			print_info "Existing rootfs found — upgrading to v6 (jq + DNS + SSH keys + CA bundle + /tmp fix + resize)..."
		fi
		echo ""
		_resize_rootfs "$_rootfs" 500
		# Key must be generated before inject (inject bakes pubkey into rootfs authorized_keys)
		_generate_microvm_ssh_key || print_warning "SSH key generation failed — SSH access unavailable"
		local _guest_init_src="${BASH_SOURCE[0]%/*}/guest-init.sh"
		if [[ -f "$_guest_init_src" ]]; then
			_inject_rootfs_guest_init "$_rootfs" "$_guest_init_src" \
				|| print_warning "v6 inject failed"
		else
			print_warning "guest-init.sh not found at $_guest_init_src — v6 unavailable"
		fi
		# Only rebuild NVM image if it is missing (rebuild is slow and requires sudo)
		if [[ ! -f "$_nvm_img" ]]; then
			_create_microvm_nvm_image || print_warning "NVM block image creation failed — claude unavailable in guest"
		fi
		echo ""
		print_success "microVM v6 upgrade complete"
		print_info "Verify: ./iclaude.sh --sandbox-microvm (Bash tool + no ENOSPC in npm)"
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

	# Optional SHA-256 hashes — set MICRO_VM_FC_SHA256 / MICRO_VM_KERNEL_SHA256 / MICRO_VM_ROOTFS_SHA256
	# to verify downloads. Leave empty (default) to skip verification.
	local fc_sha256="${MICRO_VM_FC_SHA256:-}"
	local kernel_sha256="${MICRO_VM_KERNEL_SHA256:-}"
	local rootfs_sha256="${MICRO_VM_ROOTFS_SHA256:-}"

	local fc_version="v1.11.0"
	local fc_bin="${bin_dir}/firecracker"
	_download_firecracker "$bin_dir" "$arch" "$fc_version" "$fc_sha256" || return 1

	local kernel_path="${MICRO_VM_KERNEL_PATH:-${bin_dir}/vmlinux}"
	_download_vmlinux "$kernel_path" "$arch" "$kernel_sha256" || return 1

	local rootfs_path="${MICRO_VM_ROOTFS_PATH:-${bin_dir}/rootfs.ext4}"
	_download_rootfs "$rootfs_path" "$arch" "$rootfs_sha256" || return 1

	# Resize rootfs to 500MB for headroom (downloaded image ~265MB used space)
	_resize_rootfs "$rootfs_path" 500

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

	# Inject guest init for v2 (claude runs inside guest via SSH as iclaude user)
	# Also bakes authorized_keys from the key generated above into /home/iclaude/.ssh/
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
	# MICRO_VM_NET_TAP_IFACE is a prefix; slot-0 (the first TAP set up at install time) = prefix + "-1".
	local _tap_prefix="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
	local tap_iface="${_tap_prefix}-1"

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
# Public key is baked into rootfs /home/iclaude/.ssh/authorized_keys by _inject_rootfs_guest_init().
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
#   /etc/ssh/sshd_config.d/iclaude.conf — SSH config (PermitRootLogin no, AllowUsers iclaude)
#   /home/iclaude/.ssh/authorized_keys  — static per-machine SSH pubkey (from ssh/microvm.pub)
#   /etc/sudoers.d/iclaude-vm           — NOPASSWD sudo for iclaude user inside VM
#   /mnt, /mnt/nvm, /workspace          — mount point directories
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

	# Recover ext4 journal before any debugfs -w operation.
	# debugfs bypasses the journal entirely — modifying a dirty (uncleanly-unmounted) filesystem
	# with debugfs causes multiply-claimed block corruption. e2fsck -fy replays the journal and
	# clears the dirty flag, making it safe for direct debugfs writes.
	# This happens when a Firecracker VM is SIGKILLed without a clean guest shutdown.
	if command -v e2fsck &>/dev/null; then
		e2fsck -fy "$rootfs" &>/dev/null || true
	fi

	print_info "Injecting guest init into rootfs (via debugfs)..."

	# Write SSH config override:
	# PermitRootLogin no — root SSH disabled after migration to iclaude user.
	# AllowUsers iclaude — only the dedicated non-root user may connect via SSH.
	# KVM kernel isolation is the actual security boundary; full sudo inside VM is intentional.
	local ssh_conf_tmp; ssh_conf_tmp=$(mktemp)
	printf 'PermitRootLogin no\nAllowUsers iclaude\nPubkeyAuthentication yes\nPasswordAuthentication no\n' \
		> "$ssh_conf_tmp"

	# Write sudoers drop-in for iclaude user (NOPASSWD: full sudo inside VM).
	# Security note: KVM provides host isolation; root inside the VM is already
	# contained. NOPASSWD avoids the need for PAM/password auth inside the guest.
	local sudoers_tmp; sudoers_tmp=$(mktemp)
	printf 'iclaude ALL=(ALL) NOPASSWD: ALL\n' > "$sudoers_tmp"

	# NOTE: /etc/passwd is NOT modified here — iclaude user is created via useradd
	# inside guest-init.sh at first boot (before sshd starts), so sshd always has
	# the user entry available. authorized_keys are pre-seeded via debugfs so the
	# .ssh directory survives useradd -M (which skips home directory creation).
	# NOTE: Ubuntu 22.04 rootfs has /sbin → /usr/sbin as a symlink.
	# debugfs does NOT follow symlinks when writing, so we must use /usr/sbin directly.
	# debugfs 'chmod' command is broken (no-op) in some versions — use 'set_inode_field' instead.
	# 0100755 = regular file (010----) + rwxr-xr-x (0755)
	# 0100644 = regular file (010----) + rw-r--r-- (0644)
	# 0100440 = regular file (010----) + r--r----- (0440) — sudoers required mode
	# Use 'rm' before 'write' to handle re-injection (debugfs 'write' fails with
	# "Ext2 file already exists" if the target file exists — no overwrite support).
	debugfs -w "$rootfs" <<EOF 2>/dev/null
rm /usr/sbin/iclaude-guest-init
write "${init_src}" /usr/sbin/iclaude-guest-init
set_inode_field /usr/sbin/iclaude-guest-init mode 0100755
rm /etc/ssh/sshd_config.d/iclaude.conf
write "${ssh_conf_tmp}" /etc/ssh/sshd_config.d/iclaude.conf
set_inode_field /etc/ssh/sshd_config.d/iclaude.conf mode 0100644
mkdir /mnt
mkdir /mnt/nvm
mkdir /workspace
mkdir /etc/sudoers.d
rm /etc/sudoers.d/iclaude-vm
write "${sudoers_tmp}" /etc/sudoers.d/iclaude-vm
set_inode_field /etc/sudoers.d/iclaude-vm mode 0100440
EOF
	local rc=$?
	rm -f "$ssh_conf_tmp" "$sudoers_tmp"
	if [[ $rc -ne 0 ]]; then
		print_error "debugfs injection failed (rc=$rc)"
		return 1
	fi

	# Bake SSH authorized_keys for iclaude user into rootfs.
	# Static per-machine key generated by _generate_microvm_ssh_key.
	# Written to /home/iclaude/.ssh/authorized_keys (not /root/.ssh/).
	# guest-init.sh creates the iclaude user via useradd at first boot;
	# the .ssh directory and authorized_keys are pre-seeded here so sshd
	# can authenticate before useradd completes (race-safe: useradd only
	# creates the user, not the .ssh dir — the debugfs-written key survives).
	local ssh_pubkey="${ISOLATED_CONFIG_DIR}/ssh/microvm.pub"
	if [[ -f "$ssh_pubkey" ]]; then
		debugfs -w "$rootfs" <<EOF 2>/dev/null
mkdir /home
mkdir /home/iclaude
mkdir /home/iclaude/.ssh
write "${ssh_pubkey}" /home/iclaude/.ssh/authorized_keys
set_inode_field /home/iclaude/.ssh/authorized_keys mode 0100600
EOF
		if debugfs -R 'stat /home/iclaude/.ssh/authorized_keys' "$rootfs" 2>/dev/null | grep -q "Inode:"; then
			print_success "SSH authorized_keys baked into rootfs (/home/iclaude/.ssh/)"
		else
			print_warning "authorized_keys injection failed — SSH access may not work"
		fi
	else
		print_warning "SSH public key not found: $ssh_pubkey"
		print_warning "authorized_keys NOT baked — run _generate_microvm_ssh_key first"
	fi

	# Extract SSH host public key from rootfs for per-session known_hosts pinning.
	# Stored once at install time; used by start_microvm() to build known_hosts per slot.
	local host_key_pub="${ISOLATED_CONFIG_DIR}/ssh/microvm_host_key.pub"
	local _tmp_hk; _tmp_hk=$(mktemp)
	debugfs -R "dump /etc/ssh/ssh_host_ed25519_key.pub ${_tmp_hk}" "$rootfs" 2>/dev/null
	if [[ -s "$_tmp_hk" ]]; then
		cp "$_tmp_hk" "$host_key_pub"
		chmod 644 "$host_key_pub"
		print_success "SSH host pubkey extracted: ${host_key_pub}"
	else
		print_warning "ssh_host_ed25519_key.pub not found in rootfs — host key verification disabled"
	fi
	rm -f "$_tmp_hk"

	# Inject jq binary from host into guest rootfs (required by statusline for JSON parsing).
	# jq is a static binary — safe to copy across matching architectures (host = guest = x86_64/aarch64).
	local jq_host; jq_host=$(command -v jq 2>/dev/null || true)
	if [[ -n "$jq_host" && -f "$jq_host" ]]; then
		debugfs -w "$rootfs" <<EOF 2>/dev/null
rm /usr/bin/jq
write ${jq_host} /usr/bin/jq
set_inode_field /usr/bin/jq mode 0100755
EOF
		local _jq_rc=$?
		if [[ $_jq_rc -eq 0 ]]; then
			print_success "jq injected into guest rootfs (/usr/bin/jq)"
		else
			print_warning "jq injection failed (debugfs rc=${_jq_rc}) — statusline may not work in guest"
		fi
	else
		print_warning "jq not found on host — statusline requires jq (install: sudo apt install jq, then re-run --install-microvm)"
	fi

	# Inject CA certificate bundle from host into guest rootfs.
	# Required for HTTPS connections inside the VM (curl, node, claude CLI).
	# The Ubuntu 22.04 minimal rootfs may lack ca-certificates package.
	# mkdir is idempotent in debugfs (no-op if dir already exists).
	local ca_bundle="/etc/ssl/certs/ca-certificates.crt"
	if [[ -f "$ca_bundle" ]]; then
		debugfs -w "$rootfs" <<EOF 2>/dev/null
mkdir /etc/ssl
mkdir /etc/ssl/certs
rm /etc/ssl/certs/ca-certificates.crt
write ${ca_bundle} /etc/ssl/certs/ca-certificates.crt
set_inode_field /etc/ssl/certs/ca-certificates.crt mode 0100644
EOF
		local _ca_rc=$?
		if [[ $_ca_rc -eq 0 ]]; then
			print_success "CA bundle injected into guest rootfs (/etc/ssl/certs/ca-certificates.crt)"
		else
			print_warning "CA bundle injection failed (debugfs rc=${_ca_rc}) — HTTPS will fail in guest"
		fi
	else
		print_warning "CA bundle not found at ${ca_bundle} — HTTPS will fail in guest (install: sudo apt install ca-certificates)"
	fi

	# Inject rsync binary (enables delta sync via SSH ControlMaster from host).
	# rsync is a static binary — safe to copy across matching architectures (host = guest = x86_64/aarch64).
	local rsync_host; rsync_host=$(command -v rsync 2>/dev/null || true)
	if [[ -n "$rsync_host" && -f "$rsync_host" ]]; then
		debugfs -w "$rootfs" <<EOF 2>/dev/null
rm /usr/bin/rsync
write ${rsync_host} /usr/bin/rsync
set_inode_field /usr/bin/rsync mode 0100755
EOF
		local _rsync_rc=$?
		if [[ $_rsync_rc -eq 0 ]]; then
			print_success "rsync injected into guest rootfs (/usr/bin/rsync)"
		else
			print_warning "rsync injection failed (debugfs rc=${_rsync_rc}) — delta sync unavailable, tar fallback will be used"
		fi
	else
		print_warning "rsync not found on host — delta sync unavailable (install: sudo apt-get install rsync)"
	fi

	# Mark v7 ready: rootfs has guest-init + jq + SSH keys + CA bundle + /tmp fix + resize + rsync.
	# v2-v6 kept for backward compatibility with any tooling that checks for them.
	touch "${rootfs%.ext4}.v2-ready"
	touch "${rootfs%.ext4}.v3-ready"
	touch "${rootfs%.ext4}.v4-ready"
	touch "${rootfs%.ext4}.v5-ready"
	touch "${rootfs%.ext4}.v6-ready"
	touch "${rootfs%.ext4}.v7-ready"
	print_success "Guest init injected (rootfs ready for v7)"
	return 0
}
