#!/bin/bash
# Sandbox detection module
# Provides functions for detecting sandbox platform and microVM support
#
# microVM (Firecracker) OS support matrix:
#   Ubuntu 22.04+   — virtiofsd in universe repo (apt-get install virtiofsd)
#   Debian 11+      — virtiofsd in main repo     (apt-get install virtiofsd)
#   Debian 10       — virtiofsd NOT in repos; build from source required
#   ALT Linux 10+   — virtiofsd in Sisyphus/p10  (apt-get install virtiofsd)
#   WSL2            — KVM available if host has nested virt enabled
#   macOS           — NOT supported (KVM is Linux-only)

#######################################
# Detect platform for sandboxing support
# Returns:
#   0 - platform supported (macos, linux, wsl2)
#   1 - platform not supported (wsl1, windows, unknown)
# Output: platform name (macos|linux|wsl2|wsl1|windows|unsupported)
#######################################
detect_sandbox_platform() {
	case $(uname -s) in
		Darwin)
			echo "macos"
			return 0
			;;
		Linux)
			if grep -qE "(Microsoft|WSL)" /proc/version 2>/dev/null; then
				if grep -q "WSL2" /proc/version 2>/dev/null; then
					echo "wsl2"
					return 0
				else
					echo "wsl1"
					return 1
				fi
			fi
			echo "linux"
			return 0
			;;
		MINGW*|MSYS*|CYGWIN*)
			echo "windows"
			return 1
			;;
		*)
			echo "unsupported"
			return 1
			;;
	esac
}

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
# Return virtiofsd install instruction for the current Linux distro.
# Output: install command string (stdout)
#######################################
_virtiofsd_install_hint() {
	local distro_ver; distro_ver=$(detect_linux_distro 2>/dev/null || echo "unknown:0")
	local distro="${distro_ver%%:*}"
	local ver="${distro_ver##*:}"
	local ver_major="${ver%%.*}"

	case "$distro" in
		ubuntu)
			if [[ "${ver_major:-0}" -ge 22 ]]; then
				echo "sudo apt-get install virtiofsd"
			else
				echo "# Ubuntu ${ver} не поддерживается (требуется 22.04+)"
			fi
			;;
		debian)
			if [[ "${ver_major:-0}" -ge 11 ]]; then
				echo "sudo apt-get install virtiofsd"
			elif [[ "${ver_major:-0}" -ge 10 ]]; then
				echo "# Debian 10: virtiofsd отсутствует в репозиториях — будет установлен из исходников"
				echo "# Запустите: ./iclaude.sh --install-microvm  (cargo install virtiofsd)"
			else
				echo "# Debian ${ver} не поддерживается (требуется Debian 10+)"
			fi
			;;
		altlinux)
			if [[ "${ver_major:-0}" -ge 10 ]]; then
				echo "sudo apt-get install virtiofsd"
			else
				echo "# ALT Linux ${ver} не поддерживается (требуется 10+)"
			fi
			;;
		*)
			echo "# Установите virtiofsd из репозиториев вашего дистрибутива"
			echo "# https://gitlab.com/virtio-fs/virtiofsd/-/releases"
			;;
	esac
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
			echo "Ubuntu ${ver} не поддерживается (требуется 22.04+)"
			return 1
			;;
		debian)
			if [[ "${ver_major:-0}" -ge 10 ]]; then return 0; fi
			echo "Debian ${ver} не поддерживается (требуется 10+)"
			return 1
			;;
		altlinux)
			if [[ "${ver_major:-0}" -ge 10 ]]; then return 0; fi
			echo "ALT Linux ${ver} не поддерживается (требуется 10+)"
			return 1
			;;
		unknown)
			# Не блокируем — пользователь мог установить virtiofsd вручную
			return 0
			;;
		*)
			# Другие дистрибутивы Linux разрешаем (Fedora, Arch и т.д.)
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

#######################################
# Detect virtiofsd daemon binary
# Returns:
#   0 - found
#   1 - not found
# Output: path to virtiofsd binary
#######################################
detect_virtiofsd() {
	# Common locations — including iclaude isolated bin (cargo-built for Debian 10)
	local candidates=(
		"${ISOLATED_CONFIG_DIR:-}/bin/virtiofsd"
		"/usr/lib/virtiofsd"
		"/usr/lib/qemu/virtiofsd"
		"/usr/libexec/virtiofsd"
		"/usr/bin/virtiofsd"
	)
	for p in "${candidates[@]}"; do
		if [[ -x "$p" ]]; then
			echo "$p"
			return 0
		fi
	done
	# Also check PATH
	if command -v virtiofsd &>/dev/null; then
		command -v virtiofsd
		return 0
	fi
	return 1
}
