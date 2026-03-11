#!/bin/bash
# Sandbox status module
# Provides functions for checking microVM (Firecracker) status

#######################################
# Show microVM (Firecracker) status and configuration
# Returns:
#   0 - success
#######################################
check_microvm_status() {
	# Load .claude_config to get actual configured values (not stale shell env vars).
	# --check-microvm is called directly during arg-parsing, before setup_isolated_nvm()
	# which is the only place load_claude_config() is normally invoked.
	if declare -f load_claude_config &>/dev/null && [[ -f "${CREDENTIALS_FILE:-}" ]]; then
		load_claude_config 2>/dev/null || true
	fi

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
		local rootfs_state; rootfs_state=$(cat "${rootfs%.ext4}.state" 2>/dev/null || echo "")
		if [[ "$rootfs_state" == "v7" ]]; then
			print_success "rootfs.ext4: $rootfs ($rootfs_sz) [v7: guest-init + jq + rsync (delta sync)]"
		elif [[ "$rootfs_state" == "v6" ]]; then
			print_warning "rootfs.ext4: $rootfs ($rootfs_sz) [v6: upgrade available → v7 adds rsync delta sync]"
			echo "  → Run: ./iclaude.sh --install-microvm"
		elif [[ "$rootfs_state" == "v5" ]]; then
			print_warning "rootfs.ext4: $rootfs ($rootfs_sz) [v5: needs upgrade to v7]"
			echo "  → Run: ./iclaude.sh --install-microvm"
		elif [[ "$rootfs_state" == "v4" || "$rootfs_state" == "v3" ]]; then
			print_warning "rootfs.ext4: $rootfs ($rootfs_sz) [${rootfs_state}: needs upgrade to v7]"
			echo "  → Run: ./iclaude.sh --install-microvm"
		else
			print_warning "rootfs.ext4: $rootfs ($rootfs_sz) [state unknown — needs full upgrade]"
			echo "  → Run: ./iclaude.sh --install-microvm"
		fi
		# Warn if rootfs is smaller than MICRO_VM_ROOTFS_SIZE_MB (configurable, default 2048MB)
		local rootfs_bytes; rootfs_bytes=$(stat -c%s "$rootfs" 2>/dev/null || echo 0)
		local rootfs_mb=$(( rootfs_bytes / 1048576 ))
		local _target_mb="${MICRO_VM_ROOTFS_SIZE_MB:-2048}"
		local _warn_threshold=$(( _target_mb * 80 / 100 ))
		if [[ $rootfs_mb -lt $_warn_threshold ]]; then
			print_warning "  ⚠ rootfs size: ${rootfs_mb}MB < ${_target_mb}MB (MICRO_VM_ROOTFS_SIZE_MB) — ENOSPC risk"
			echo "    → Run: ./iclaude.sh --install-microvm  (resize to ${_target_mb}MB, no re-download)"
		else
			print_success "  rootfs size: ${rootfs_mb}MB (MICRO_VM_ROOTFS_SIZE_MB=${_target_mb}MB)"
		fi
	else
		print_warning "rootfs.ext4: not found ($rootfs)"
	fi
	local nvm_img="${MICRO_VM_NVM_IMG:-${ISOLATED_CONFIG_DIR}/bin/nvm.img}"
	if [[ -f "$nvm_img" ]]; then
		local nvm_sz; nvm_sz=$(du -h "$nvm_img" 2>/dev/null | cut -f1)
		print_success "nvm.img: $nvm_img ($nvm_sz)"
	else
		print_warning "nvm.img: not found — claude will not run in guest"
		echo "  → Run: ./iclaude.sh --install-microvm (requires root password)"
	fi
	echo ""

	# TAP networking — MICRO_VM_NET_TAP_IFACE is a prefix; slot-0 TAP = prefix + "-1"
	print_info "TAP Networking:"
	local tap_prefix="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
	local tap_iface="${tap_prefix}-1"
	if ip link show "$tap_iface" &>/dev/null; then
		local tap_ips
		mapfile -t tap_ips < <(ip addr show "$tap_iface" 2>/dev/null | awk '/inet / {print $2}')
		if [[ ${#tap_ips[@]} -gt 1 ]]; then
			print_warning "${tap_iface}: up but has ${#tap_ips[@]} IPs — stale addresses present"
			echo "  IPs: ${tap_ips[*]}"
			echo "  Fix: sudo ip addr flush dev ${tap_iface} && iclaude --install-microvm"
		else
			print_success "${tap_iface}: up (${tap_ips[0]:-no IP})"
		fi
	else
		print_warning "${tap_iface}: not configured"
		echo "  Run --install-microvm to configure TAP networking"
	fi
	echo ""

	# Configuration
	print_info "Configuration:"
	echo "  MICRO_VM_ENABLED:          ${MICRO_VM_ENABLED:-false}"
	echo "  MICRO_VM_VCPU:             ${MICRO_VM_VCPU:-2}"
	echo "  MICRO_VM_MEM_MB:           ${MICRO_VM_MEM_MB:-2048}"
	echo "  MICRO_VM_NET_ENABLED:      ${MICRO_VM_NET_ENABLED:-true}"
	echo "  MICRO_VM_SNAPSHOT_ENABLED: ${MICRO_VM_SNAPSHOT_ENABLED:-false}"
	echo "  MICRO_VM_MOUNT_WORKSPACE:  ${MICRO_VM_MOUNT_WORKSPACE:-true}"
	echo "  MICRO_VM_LOG_LEVEL:        ${MICRO_VM_LOG_LEVEL:-warn}"
	echo ""

	# Warnings: RAM check
	local _mem_mb="${MICRO_VM_MEM_MB:-2048}"
	if [[ $_mem_mb -lt 2048 ]]; then
		print_warning "⚠ RAM: ${_mem_mb}MB < 2048MB — Claude Code (~600MB RSS) may be killed by OOM"
		echo "  → Set MICRO_VM_MEM_MB=2048 in .claude_config"
		echo ""
	fi

	# Snapshots
	print_info "Snapshots:"
	local snap_dir="${MICRO_VM_SNAPSHOT_DIR:-${ISOLATED_CONFIG_DIR}/microvm-snapshots}"
	if [[ -d "$snap_dir" ]]; then
		local snap_count
		snap_count=$(find "$snap_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
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
	local _rootfs_sum="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
	[[ -f "$_rootfs_sum" ]] || { all_ready=false; missing_items+=("rootfs.ext4"); }
	local _state_val; _state_val=$(cat "${_rootfs_sum%.ext4}.state" 2>/dev/null || echo "")
	[[ ! -f "$_rootfs_sum" || "$_state_val" == "v7" ]] || { all_ready=false; missing_items+=("rootfs v7 upgrade needed → run --install-microvm"); }
	local _nvm_img_sum="${MICRO_VM_NVM_IMG:-${ISOLATED_CONFIG_DIR}/bin/nvm.img}"
	[[ -f "$_nvm_img_sum" ]] || { all_ready=false; missing_items+=("nvm.img (NVM block image) → run --install-microvm"); }

	if [[ "$all_ready" == "true" ]]; then
		print_success "microVM Ready"
		echo "  ✓ KVM available"
		echo "  ✓ Firecracker installed"
		echo "  ✓ Guest images present (rootfs + nvm.img)"
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
