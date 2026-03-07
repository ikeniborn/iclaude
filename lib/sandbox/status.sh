#!/bin/bash
# Sandbox status module
# Provides functions for checking sandbox runtime version and status

#######################################
# Get sandbox-runtime version
# Returns:
#   Version string or "not installed"
#######################################
get_sandbox_runtime_version() {
	# Check if srt binary exists
	if command -v srt &>/dev/null; then
		# Get version from srt --version
		local version=$(srt --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
		if [[ -n "$version" ]]; then
			echo "$version"
			return 0
		fi
	elif [[ -n "$ISOLATED_NVM_DIR" ]] && [[ -x "$ISOLATED_NVM_DIR/npm-global/bin/srt" ]]; then
		# srt exists in isolated environment but not in PATH
		local version=$("$ISOLATED_NVM_DIR/npm-global/bin/srt" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
		if [[ -n "$version" ]]; then
			echo "$version"
			return 0
		fi
	fi

	# Not installed or version unavailable
	echo "not installed"
	return 1
}

#######################################
# Check sandbox status and configuration
# Shows platform support, dependencies, and configuration info
# Returns:
#   0 - success
#######################################
check_sandbox_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Claude Code Sandbox Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Platform Detection
	print_info "Platform Detection:"
	local os=$(uname -s)
	local arch=$(uname -m)
	echo "  OS: $os"
	echo "  Architecture: $arch"

	local platform
	platform=$(detect_sandbox_platform)
	local platform_status=$?
	echo "  Sandbox Platform: $platform"

	if [[ $platform_status -eq 0 ]]; then
		echo "  Compatibility: ✓ Supported"
	else
		echo "  Compatibility: ❌ Not supported"
	fi
	echo ""

	# Handle unsupported platforms
	if [[ $platform_status -ne 0 ]]; then
		case "$platform" in
			wsl1)
				print_error "WSL1 is not supported for sandboxing"
				echo ""
				echo "Upgrade to WSL2:"
				echo "  wsl --set-version <distro-name> 2"
				echo "  wsl --shutdown"
				echo ""
				echo "Verify upgrade:"
				echo "  wsl --list --verbose"
				;;
			windows)
				print_error "Native Windows is not supported"
				echo ""
				echo "Install WSL2:"
				echo "  wsl --install"
				;;
			*)
				print_error "Platform '$platform' is not supported"
				;;
		esac
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	# System Dependencies
	print_info "System Dependencies:"

	if [[ "$platform" == "macos" ]]; then
		print_success "macOS Seatbelt (native, always available)"
		echo ""
	else
		# Linux/WSL2
		local missing
		missing=$(check_sandbox_dependencies) || true
		if check_sandbox_dependencies &>/dev/null; then
			print_success "All dependencies installed"
			echo ""

			# Show versions
			if command -v bwrap &>/dev/null; then
				local bwrap_ver=$(bwrap --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
				echo "  bubblewrap:              bubblewrap $bwrap_ver"
			fi
			if command -v socat &>/dev/null; then
				local socat_ver=$(socat -V 2>&1 | grep "socat version" | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "unknown")
				echo "  socat:                   socat version $socat_ver"
			fi

			# Check sandbox-runtime (srt binary)
			local runtime_ver=$(get_sandbox_runtime_version)
			echo "  sandbox-runtime (npm):   @anthropic-ai/sandbox-runtime $runtime_ver"
			echo ""
		else
			print_warning "Missing dependencies: $missing"
			echo ""
			echo "Install with: ./iclaude.sh --sandbox-install"
			echo ""
		fi
	fi

	# Claude Code Version
	print_info "Claude Code Version:"
	local claude_path=$(get_nvm_claude_path)
	if [[ -n "$claude_path" ]]; then
		local claude_ver=$(get_cli_version "$claude_path")
		echo "  Installed: v$claude_ver"

		# Check if version supports sandboxing (v2.0.0+)
		if [[ "$claude_ver" != "unknown" ]]; then
			local major_ver=$(echo "$claude_ver" | cut -d. -f1)
			if [[ "$major_ver" -ge 2 ]] 2>/dev/null; then
				print_success "Sandboxing supported (v2.0.0+)"
			else
				print_warning "Sandboxing requires v2.0.0 or higher"
				echo "  Current version: v$claude_ver"
				echo "  Update with: ./iclaude.sh --update"
			fi
		fi
	else
		print_warning "Claude Code not found"
		echo "  Install with: ./iclaude.sh --isolated-install"
	fi
	echo ""

	# Lockfile Status
	print_info "Lockfile Status:"
	if [[ -f "$ISOLATED_LOCKFILE" ]]; then
		local sandbox_available=$(get_lockfile_field "sandboxAvailable" 2>/dev/null || echo "false")
		[[ "$sandbox_available" == "unknown" ]] && sandbox_available="false"
		if [[ "$sandbox_available" == "true" ]]; then
			print_success "Sandbox marked as available in lockfile"
			local lockfile_platform=$(get_lockfile_field "sandboxPlatform" 2>/dev/null || echo "unknown")
			echo "  Platform: $lockfile_platform"

			local sandbox_installed_at=$(get_lockfile_field "sandboxInstalledAt" 2>/dev/null || echo "unknown")
			if [[ "$sandbox_installed_at" != "unknown" && "$sandbox_installed_at" != "null" ]]; then
				echo "  Verified: $sandbox_installed_at"
			fi
		else
			print_info "Sandbox not marked as available in lockfile"
			echo "  Run ./iclaude.sh --sandbox-install to enable"
		fi
	else
		print_info "No lockfile found"
		echo "  Lockfile will be created after installation"
	fi
	echo ""

	# Configuration Instructions
	print_info "Configuration:"
	echo "  Sandboxing is configured via Claude Code itself"
	echo "  Enable in Claude Code session: /sandbox"
	echo "  Settings stored in: settings.json (sandbox section)"
	echo ""

	# Summary
	local all_ready=true
	if [[ $platform_status -ne 0 ]]; then
		all_ready=false
	elif [[ "$platform" != "macos" ]]; then
		if ! check_sandbox_dependencies &>/dev/null; then
			all_ready=false
		fi
	fi

	if [[ "$all_ready" == "true" ]]; then
		print_success "Sandbox Ready"
		echo "  ✓ Platform supported"
		if [[ "$platform" == "macos" ]]; then
			echo "  ✓ Native Seatbelt available"
		else
			echo "  ✓ Dependencies installed"
		fi
		echo "  ✓ Enable via /sandbox command in Claude Code"
	else
		print_warning "Sandbox Not Ready"
		if [[ $platform_status -ne 0 ]]; then
			echo "  ❌ Platform not supported"
		else
			echo "  ⚠ Dependencies missing"
			echo "  → Run: ./iclaude.sh --sandbox-install"
		fi
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}

#######################################
# Show microVM (Firecracker) status and configuration
# Returns:
#   0 - success
#######################################
check_microvm_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  microVM Sandbox Status (Firecracker)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# KVM support
	print_info "KVM Support:"
	local kvm_reason
	if kvm_reason=$(detect_kvm_support 2>&1); then
		print_success "/dev/kvm available"
	else
		print_error "KVM not available: $kvm_reason"
	fi
	echo ""

	# Firecracker binary
	print_info "Firecracker Binary:"
	local fc_bin
	if fc_bin=$(detect_microvm_binary 2>/dev/null); then
		local fc_ver
		fc_ver=$("$fc_bin" --version 2>/dev/null | head -1 || echo "unknown")
		print_success "$fc_bin ($fc_ver)"
	else
		print_warning "Not installed"
		echo "  Install with: ./iclaude.sh --install-microvm"
	fi
	echo ""

	# Kernel and rootfs
	print_info "Guest Images:"
	local kernel="${MICRO_VM_KERNEL_PATH:-${ISOLATED_CONFIG_DIR}/bin/vmlinux}"
	local rootfs="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
	if [[ -f "$kernel" ]]; then
		local kernel_sz
		kernel_sz=$(du -h "$kernel" 2>/dev/null | cut -f1)
		print_success "vmlinux: $kernel ($kernel_sz)"
	else
		print_warning "vmlinux: not found ($kernel)"
	fi
	if [[ -f "$rootfs" ]]; then
		local rootfs_sz
		rootfs_sz=$(du -h "$rootfs" 2>/dev/null | cut -f1)
		print_success "rootfs.ext4: $rootfs ($rootfs_sz)"
	else
		print_warning "rootfs.ext4: not found ($rootfs)"
	fi
	echo ""

	# virtiofsd
	print_info "virtiofsd (workspace mount):"
	local vfsd
	if vfsd=$(detect_virtiofsd 2>/dev/null); then
		print_success "$vfsd"
	else
		print_warning "Not found — install: sudo apt-get install virtiofsd"
	fi
	echo ""

	# TAP networking
	print_info "TAP Networking:"
	local tap_iface="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
	if ip link show "$tap_iface" &>/dev/null; then
		local tap_ip
		tap_ip=$(ip addr show "$tap_iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)
		print_success "${tap_iface}: up (${tap_ip:-no IP})"
	else
		print_warning "${tap_iface}: not configured"
		echo "  Run --install-microvm to configure TAP networking"
	fi
	echo ""

	# Configuration
	print_info "Configuration:"
	echo "  MICRO_VM_ENABLED:          ${MICRO_VM_ENABLED:-false}"
	echo "  MICRO_VM_VCPU:             ${MICRO_VM_VCPU:-2}"
	echo "  MICRO_VM_MEM_MB:           ${MICRO_VM_MEM_MB:-1024}"
	echo "  MICRO_VM_NET_ENABLED:      ${MICRO_VM_NET_ENABLED:-true}"
	echo "  MICRO_VM_SNAPSHOT_ENABLED: ${MICRO_VM_SNAPSHOT_ENABLED:-false}"
	echo "  MICRO_VM_MOUNT_WORKSPACE:  ${MICRO_VM_MOUNT_WORKSPACE:-true}"
	echo "  MICRO_VM_LOG_LEVEL:        ${MICRO_VM_LOG_LEVEL:-warn}"
	echo ""

	# Snapshots
	print_info "Snapshots:"
	local snap_dir="${MICRO_VM_SNAPSHOT_DIR:-${ISOLATED_CONFIG_DIR}/microvm-snapshots}"
	if [[ -d "$snap_dir" ]]; then
		local snap_count
		snap_count=$(find "$snap_dir" -name "*.snap" 2>/dev/null | wc -l)
		echo "  Directory: $snap_dir"
		echo "  Snapshots: $snap_count"
	else
		echo "  No snapshots directory (created on first --install-microvm)"
	fi
	echo ""

	# Summary
	local all_ready=true
	local missing_items=()

	detect_kvm_support &>/dev/null || { all_ready=false; missing_items+=("KVM"); }
	detect_microvm_binary &>/dev/null || { all_ready=false; missing_items+=("firecracker binary"); }
	[[ -f "${MICRO_VM_KERNEL_PATH:-${ISOLATED_CONFIG_DIR}/bin/vmlinux}" ]] || { all_ready=false; missing_items+=("vmlinux kernel"); }
	[[ -f "${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}" ]] || { all_ready=false; missing_items+=("rootfs.ext4"); }

	if [[ "$all_ready" == "true" ]]; then
		print_success "microVM Ready"
		echo "  ✓ KVM available"
		echo "  ✓ Firecracker installed"
		echo "  ✓ Guest images present"
		echo "  ✓ Enable via: ./iclaude.sh --sandbox-microvm"
		echo "    or add MICRO_VM_ENABLED=true to .claude_config"
	else
		print_warning "microVM Not Ready"
		for item in "${missing_items[@]}"; do
			echo "  ❌ Missing: $item"
		done
		echo ""
		echo "  → Install with: ./iclaude.sh --install-microvm"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}
