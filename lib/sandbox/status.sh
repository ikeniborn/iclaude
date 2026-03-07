#!/bin/bash
# Sandbox status module
# Provides functions for checking microVM (Firecracker) status

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
