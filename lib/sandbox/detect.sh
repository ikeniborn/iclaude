#!/bin/bash
# Sandbox detection module
# Provides functions for detecting microVM (Firecracker) support
#
# microVM (Firecracker) OS support matrix:
#   Ubuntu 22.04+   — full support
#   Debian 11+      — full support
#   ALT Linux 10+   — full support
#   WSL2            — KVM available if host has nested virt enabled
#   macOS           — NOT supported (KVM is Linux-only)

#######################################
# Detect Linux distribution and version from /etc/os-release.
# Returns:
#   0 - recognized distro
#   1 - unknown/non-Linux
# Output: "distro:version" string, e.g. "ubuntu:22.04", "debian:11", "altlinux:10"
#######################################
detect_linux_distro() {
	[[ "$(uname -s)" == "Linux" ]] || { echo "unknown:0"; return 1; }

	local id="" version_id=""
	if [[ -f /etc/os-release ]]; then
		# shellcheck source=/dev/null
		id=$(grep -E "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
		version_id=$(grep -E "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
	fi

	# Normalize ALT Linux IDs (alt, altlinux, altserver, altworkstation → altlinux)
	case "$id" in
		alt|altlinux|altserver|altworkstation|"alt linux") id="altlinux" ;;
	esac

	[[ -n "$id" ]] && echo "${id}:${version_id}" || { echo "unknown:0"; return 1; }
}

#######################################
# Check if current distro/version is supported for microVM.
# Returns:
#   0 - supported
#   1 - not supported or unknown
# Output: human-readable reason on failure
#######################################
check_distro_microvm_support() {
	local distro_ver; distro_ver=$(detect_linux_distro 2>/dev/null || echo "unknown:0")
	local distro="${distro_ver%%:*}"
	local ver="${distro_ver##*:}"
	local ver_major="${ver%%.*}"

	case "$distro" in
		ubuntu)
			if [[ "${ver_major:-0}" -ge 22 ]]; then return 0; fi
			echo "Ubuntu ${ver} is not supported (requires 22.04+)"
			return 1
			;;
		debian)
			if [[ "${ver_major:-0}" -ge 10 ]]; then return 0; fi
			echo "Debian ${ver} is not supported (requires 10+)"
			return 1
			;;
		altlinux)
			if [[ "${ver_major:-0}" -ge 10 ]]; then return 0; fi
			echo "ALT Linux ${ver} is not supported (requires 10+)"
			return 1
			;;
		unknown)
			# Do not block — user may have installed virtiofsd manually
			return 0
			;;
		*)
			# Allow other Linux distributions (Fedora, Arch, etc.)
			return 0
			;;
	esac
}

#######################################
# Detect KVM hardware virtualization support
# Returns:
#   0 - KVM available (/dev/kvm readable)
#   1 - KVM not available
# Output: reason string on failure
#######################################
detect_kvm_support() {
	# Check OS — KVM is Linux only
	if [[ "$(uname -s)" != "Linux" ]]; then
		echo "KVM requires Linux"
		return 1
	fi

	# WSL1 does not support KVM
	if grep -qE "(Microsoft|WSL)" /proc/version 2>/dev/null; then
		if ! grep -q "WSL2" /proc/version 2>/dev/null; then
			echo "WSL1 does not support KVM (upgrade to WSL2)"
			return 1
		fi
	fi

	# Check /dev/kvm device
	if [[ ! -e /dev/kvm ]]; then
		echo "/dev/kvm not found (enable VT-x/AMD-V in BIOS and load kvm module)"
		return 1
	fi

	if [[ ! -r /dev/kvm ]]; then
		echo "/dev/kvm not readable (add user to 'kvm' group: sudo usermod -aG kvm \$USER)"
		return 1
	fi

	return 0
}

#######################################
# Detect firecracker binary in isolated environment
# Returns:
#   0 - binary found and executable
#   1 - not found
# Output: path to binary on success
#######################################
detect_microvm_binary() {
	local bin_path="${MICRO_VM_BIN_PATH:-${ISOLATED_CONFIG_DIR}/bin/firecracker}"
	if [[ -x "$bin_path" ]]; then
		echo "$bin_path"
		return 0
	fi
	return 1
}

