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
# Read a value from lib/sandbox/versions.json via jq.
# Arguments:
#   $1 - jq expression (e.g. '.firecracker.version')
# Prints value to stdout (empty string if not found).
# Returns 1 if versions.json not found or jq unavailable.
#######################################
_versions_read() {
	local expr="$1"
	local versions_file="${BASH_SOURCE[0]%/*}/versions.json"
	[[ -f "$versions_file" ]] || return 1
	jq -r "${expr} // empty" "$versions_file" 2>/dev/null
}

#######################################
# Write a SHA-256 hash for a component back into versions.json (TOFU save).
# Uses atomic write: jq → tmp file → mv.
# Arguments:
#   $1 - jq_set_expr: full jq assignment expression, e.g. '.firecracker.x86_64.sha256 = $h'
#   $2 - hash:        SHA-256 hex string to write
# Returns:
#   0 - success
#   1 - failure (versions.json missing, jq error, or no sha256sum)
#######################################
_versions_write_sha256() {
	local jq_set_expr="$1"
	local hash="$2"
	local versions_file="${BASH_SOURCE[0]%/*}/versions.json"
	[[ -f "$versions_file" ]] || return 1
	[[ -n "$hash" ]] || return 1
	local tmp; tmp=$(mktemp "${versions_file}.tmp.XXXXXX")
	if jq --arg h "$hash" "$jq_set_expr" "$versions_file" > "$tmp" 2>/dev/null; then
		mv "$tmp" "$versions_file"
		return 0
	fi
	rm -f "$tmp"
	return 1
}

#######################################
# Compute SHA-256 of a file and return hex string.
# Arguments:
#   $1 - file: path to file
# Prints hash to stdout; returns 1 if sha256sum unavailable or file missing.
#######################################
_compute_sha256() {
	local file="$1"
	[[ -f "$file" ]] || return 1
	command -v sha256sum &>/dev/null || return 1
	sha256sum "$file" | cut -d' ' -f1
}

# Cached escalation user for su fallback (set once per install session by _priv_run).
_PRIV_RUN_USER=""

#######################################
# Run a command with root privileges.
# Tries sudo first (if current user is in wheel/sudo group); otherwise escalates via su.
# Supported modes (chosen once per session):
#   "root"      → su root -c "cmd"          (one prompt: root password)
#   "<user>"    → su <user> -c "sudo cmd"   (two prompts: user's password + sudo password)
# sudo inside "su -c" accesses /dev/tty directly, so password prompts work interactively.
#
# Arguments:
#   $@ - command and arguments to run as root
# Returns:
#   exit code of the executed command
#######################################
_priv_run() {
	# Already root — run directly (e.g. launched via "sudo bash iclaude.sh").
	if [[ $(id -u) -eq 0 ]]; then
		"$@"
		return
	fi

	# Use sudo only if the binary exists AND the current user is in wheel/sudo group.
	# If sudo is installed but user is not in sudoers, "sudo cmd" exits non-zero and the
	# su fallback below is never reached — so we guard with a group membership check first.
	if [[ -x /usr/bin/sudo ]] && id -nG 2>/dev/null | grep -qwE 'wheel|sudo'; then
		sudo "$@"
		return
	fi

	# No direct sudo — escalate via su. Ask once, cache for subsequent calls.
	if [[ -z "${_PRIV_RUN_USER:-}" ]]; then
		echo ""
		print_warning "sudo недоступен для текущего пользователя. Нужна эскалация привилегий."
		echo "  Варианты:"
		echo "  • Нажмите Enter или введите 'root'  → su root (один пароль: пароль root)"
		echo "  • Введите имя sudo-пользователя     → su <user> + sudo (два пароля)"
		echo ""
		local _input _valid=false _attempt
		for _attempt in 1 2 3; do
			read -r -p "  Пользователь [root]: " _input < /dev/tty || true
			_input="${_input:-root}"
			if id "$_input" &>/dev/null 2>&1; then
				_valid=true
				break
			fi
			print_warning "  Пользователь '$_input' не найден в системе. Попробуйте снова."
		done
		if [[ "$_valid" != "true" ]]; then
			print_error "Не удалось выбрать пользователя для эскалации"
			return 1
		fi
		_PRIV_RUN_USER="$_input"
		echo ""
	fi

	# Write command to a temp script — avoids su -c quoting issues with complex arg lists
	# (e.g., rsync with many --exclude flags containing special characters).
	# "sh FILE" not "exec FILE": bypasses noexec on /tmp (sh reads file as data, not exec).
	# Security: mktemp creates file mode 0600 (owner-only). Content is written while 0600.
	# chmod is applied AFTER write to minimise the window where content is world-readable.
	# For root path: no chmod needed — root bypasses DAC and reads 0600 files regardless.
	# For sudo-user path: chmod 644 after write so the escalation user can read the script.
	local tmp_sh; tmp_sh=$(mktemp /tmp/.iclaude-priv-XXXXXX)

	# sh-safe single-quote escaping for each argument (POSIX-compatible, works with dash/sh)
	local cmd="" arg
	for arg in "$@"; do
		cmd+="'${arg//\'/\'\\\'\'}' "
	done
	# Include standard system PATH — needed when su doesn't start a login shell.
	# Split printf: $cmd goes as '%s' argument (not in format string) to avoid
	# format-specifier injection if paths contain '%s', '%n', etc.
	printf '#!/bin/sh\nPATH=/sbin:/usr/sbin:/bin:/usr/bin\nexec ' > "$tmp_sh"
	printf '%s\n' "$cmd" >> "$tmp_sh"
	# Open to sudo-user AFTER content is written (minimise world-readable window).
	[[ "$_PRIV_RUN_USER" != "root" ]] && chmod 644 "$tmp_sh"

	local rc=0
	# Unset BASH_ENV/ENV before su: prevents su's bash from sourcing the current user's
	# .bashrc (may be on a restricted network FS → EACCES warnings).
	local _saved_bash_env="${BASH_ENV:-}" _saved_env="${ENV:-}"
	unset BASH_ENV ENV
	if [[ "$_PRIV_RUN_USER" == "root" ]]; then
		# Direct root: one password prompt. Root bypasses DAC — no chmod needed.
		su root -c "sh '$tmp_sh'" || { rc=$?; _PRIV_RUN_USER=""; }
	else
		# Sudo-user path: su authenticates as <user>, then sudo elevates to root.
		# sudo opens /dev/tty directly for password — works inside su -c.
		# Two prompts: su password (user's Unix/LDAP password) + sudo password.
		su "$_PRIV_RUN_USER" -c "sudo sh '$tmp_sh'" || { rc=$?; _PRIV_RUN_USER=""; }
	fi
	[[ -n "$_saved_bash_env" ]] && export BASH_ENV="$_saved_bash_env"
	[[ -n "$_saved_env" ]] && export ENV="$_saved_env"
	rm -f "$tmp_sh"
	return $rc
}

#######################################
# Check if a component sidecar .version file matches the desired version.
# Arguments:
#   $1 - version_file: path to sidecar .version file
#   $2 - desired:      expected version string
# Returns:
#   0 - file exists and version matches (component is current)
#   1 - file missing or version differs (re-download needed)
#######################################
_component_is_current() {
	local version_file="$1"
	local desired="$2"
	[[ -f "$version_file" ]] && [[ "$(cat "$version_file" 2>/dev/null)" == "$desired" ]]
}

#######################################
# Download a file via curl with TLS fallback for old OpenSSL (exit 35).
# When TLS handshake fails due to unsupported certificate algorithm (common on
# AltLinux/RHEL with OpenSSL < 3.x), retries with --insecure and warns user.
# Set MICRO_VM_INSECURE_DOWNLOAD=true to skip TLS verification unconditionally.
# Arguments:
#   $1 - url:    source URL
#   $2 - output: destination file path
# Returns:
#   0 - success
#   1 - failure
#######################################
_curl_download() {
	local url="$1"
	local output="$2"
	local curl_exit

	# Build proxy args from PROXY_URL / PROXY_CA / PROXY_INSECURE (set by .claude_config)
	local proxy_args=()
	if [[ -n "${PROXY_URL:-}" ]]; then
		proxy_args+=("--proxy" "$PROXY_URL")
		[[ -n "${PROXY_CA:-}" ]] && proxy_args+=("--proxy-cacert" "$PROXY_CA")
		[[ "${PROXY_INSECURE:-false}" == "true" ]] && proxy_args+=("--proxy-insecure")
	fi

	if [[ "${MICRO_VM_INSECURE_DOWNLOAD:-false}" == "true" ]]; then
		curl -fsSLk --proxy-insecure --progress-bar "${proxy_args[@]}" -o "$output" "$url"
		return
	fi

	curl -fsSL --progress-bar "${proxy_args[@]}" -o "$output" "$url"
	curl_exit=$?

	if [[ $curl_exit -eq 35 ]]; then
		echo ""
		print_warning "TLS error (exit 35): OpenSSL cannot verify a certificate in the chain."
		print_warning "Retrying with --insecure --proxy-insecure (TLS verification disabled)."
		print_warning "IMPORTANT: set MICRO_VM_FC_SHA256 / MICRO_VM_KERNEL_SHA256 / MICRO_VM_ROOTFS_SHA256"
		print_warning "  to verify file integrity — without TLS and SHA-256 downloads are unverified."
		print_warning "Set MICRO_VM_INSECURE_DOWNLOAD=true to skip TLS and suppress this warning."
		echo ""
		rm -f "$output"
		# --proxy-insecure: skip TLS verification for the proxy itself (e.g. ECDSA proxy cert on old OpenSSL).
		# -k / --insecure: skip TLS verification for the target server.
		curl -fsSLk --proxy-insecure --progress-bar "${proxy_args[@]}" -o "$output" "$url"
		return
	fi

	return $curl_exit
}

#######################################
# Download Firecracker binary from GitHub releases, extract from tgz, verify.
# Arguments:
#   $1 - bin_dir:    destination directory for the binary
#   $2 - arch:       target architecture (x86_64 or aarch64)
#   $3 - fc_version: Firecracker version string (e.g. "v1.11.0")
#   $4 - fc_url:     full download URL for the tgz archive
#   $5 - sha256:     expected SHA-256 hash (empty = skip verification)
# Returns:
#   0 - success; binary installed at $bin_dir/firecracker
#   1 - failure
#######################################
_download_firecracker() {
	local bin_dir="$1"
	local arch="$2"
	local fc_version="$3"
	local fc_url="$4"
	local sha256="$5"

	local fc_bin="${bin_dir}/firecracker"

	print_info "Downloading Firecracker ${fc_version} (${arch})..."
	echo "  Source: $fc_url"
	echo ""

	local tmp_tgz="${bin_dir}/firecracker.tgz.tmp"
	if command -v curl &>/dev/null; then
		if ! _curl_download "$fc_url" "$tmp_tgz"; then
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
#   $2 - url:         full download URL
#   $3 - sha256:      expected SHA-256 hash (empty = skip verification)
# Returns:
#   0 - success
#   1 - failure
#######################################
_download_vmlinux() {
	local kernel_path="$1"
	local kernel_url="$2"
	local sha256="$3"

	print_info "Downloading Linux kernel (vmlinux, ~40MB)..."
	echo "  Source: $kernel_url"
	echo ""

	if command -v curl &>/dev/null; then
		if ! _curl_download "$kernel_url" "$kernel_path"; then
			print_error "Failed to download vmlinux kernel"
			rm -f "$kernel_path"
			return 1
		fi
	else
		if ! wget -q --show-progress -O "$kernel_path" "$kernel_url"; then
			print_error "Failed to download vmlinux kernel"
			rm -f "$kernel_path"
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
	local target_mb="${2:-2048}"

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
#   $2 - url:         full download URL
#   $3 - sha256:      expected SHA-256 hash (empty = skip verification)
# Returns:
#   0 - success
#   1 - failure
#######################################
_download_rootfs() {
	local rootfs_path="$1"
	local rootfs_url="$2"
	local sha256="$3"

	print_info "Downloading rootfs image (~300MB)..."
	echo "  Source: $rootfs_url"
	echo ""

	if command -v curl &>/dev/null; then
		if ! _curl_download "$rootfs_url" "$rootfs_path"; then
			print_error "Failed to download rootfs image"
			rm -f "$rootfs_path"
			return 1
		fi
	else
		if ! wget -q --show-progress -O "$rootfs_path" "$rootfs_url"; then
			print_error "Failed to download rootfs image"
			rm -f "$rootfs_path"
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
	local _state_file="${_rootfs%.ext4}.state"
	local _ssh_key="${ISOLATED_CONFIG_DIR}/ssh/microvm"

	local _nvm_img="${MICRO_VM_NVM_IMG:-${_bin_dir}/nvm.img}"

	# Load rootfs version early to detect if re-download is needed (bypasses fast-path if changed).
	local _desired_rootfs_ver=""
	if command -v jq &>/dev/null; then
		local _vf="${BASH_SOURCE[0]%/*}/versions.json"
		[[ -f "$_vf" ]] && _desired_rootfs_ver=$(jq -r '.rootfs.version // empty' "$_vf" 2>/dev/null) || true
	fi
	local _rootfs_ver_file="${_rootfs%.ext4}.version"

	# If rootfs version changed, clear old files to bypass the fast-path and force re-download.
	if [[ -n "$_desired_rootfs_ver" && -f "$_rootfs" ]] && \
	   ! { [[ -f "$_rootfs_ver_file" ]] && [[ "$(cat "$_rootfs_ver_file" 2>/dev/null)" == "$_desired_rootfs_ver" ]]; }; then
		print_info "Rootfs version changed → ${_desired_rootfs_ver}. Removing old rootfs and markers..."
		rm -f "$_rootfs" "$_rootfs_ver_file"
		rm -f "${_rootfs%.ext4}".v{2,3,4,5,6,7}-ready "${_rootfs%.ext4}.state"
	fi

	# One-time migration: convert legacy v2-v7 touch-file markers to rootfs.state.
	if [[ ! -f "$_state_file" && -f "$_rootfs" ]]; then
		if [[ -f "${_rootfs%.ext4}.v7-ready" ]]; then
			printf 'v7' > "$_state_file"
			rm -f "${_rootfs%.ext4}".v{2,3,4,5,6,7}-ready
			print_info "Migrated legacy markers → rootfs.state (v7)"
		elif [[ -f "${_rootfs%.ext4}.v6-ready" ]]; then
			printf 'v6' > "$_state_file"
			rm -f "${_rootfs%.ext4}".v{2,3,4,5,6}-ready
		elif [[ -f "${_rootfs%.ext4}.v5-ready" ]]; then
			printf 'v5' > "$_state_file"
			rm -f "${_rootfs%.ext4}".v{2,3,4,5}-ready
		elif [[ -f "${_rootfs%.ext4}.v4-ready" ]]; then
			printf 'v4' > "$_state_file"
			rm -f "${_rootfs%.ext4}".v{2,3,4}-ready
		elif [[ -f "${_rootfs%.ext4}.v3-ready" ]]; then
			printf 'v3' > "$_state_file"
			rm -f "${_rootfs%.ext4}".v{2,3}-ready
		elif [[ -f "${_rootfs%.ext4}.v2-ready" ]]; then
			printf 'v2' > "$_state_file"
			rm -f "${_rootfs%.ext4}.v2-ready"
		fi
	fi

	local _skip_upgrade_paths=false
	if [[ -f "$_rootfs" ]]; then
		if [[ "$(cat "$_state_file" 2>/dev/null)" == "v7" && -f "$_ssh_key" && -f "$_nvm_img" ]]; then
			# Check if actual rootfs size matches MICRO_VM_ROOTFS_SIZE_MB; resize if smaller.
			local _configured_mb="${MICRO_VM_ROOTFS_SIZE_MB:-2048}"
			local _actual_bytes; _actual_bytes=$(stat -c%s "$_rootfs" 2>/dev/null || echo 0)
			local _actual_mb=$(( _actual_bytes / 1048576 ))
			if [[ $_actual_mb -lt $_configured_mb ]]; then
				print_warning "Rootfs: ${_actual_mb}MB < MICRO_VM_ROOTFS_SIZE_MB=${_configured_mb}MB"
				local _confirm
				read -r -p "  Resize rootfs to ${_configured_mb}MB? [Y/n] " _confirm
				if [[ -z "$_confirm" || "$_confirm" =~ ^[Yy]$ ]]; then
					# Guard: debugfs/resize2fs on a live rootfs causes ext4 corruption.
					local _fc_running; _fc_running=$(pgrep -x firecracker 2>/dev/null || true)
					if [[ -n "$_fc_running" ]]; then
						print_error "Cannot resize: Firecracker is running (PID: $(echo "$_fc_running" | tr '\n' ' ' | sed 's/ $//'))."
						print_error "Stop all microVM sessions first, then retry --install-microvm."
						return 1
					fi
					_resize_rootfs "$_rootfs" "$_configured_mb"
					_actual_mb="$_configured_mb"
				fi
			fi
			print_success "microVM already installed and up-to-date (v7)"
			print_info "Rootfs: $_rootfs (${_actual_mb}MB)"
			print_info "NVM image: $_nvm_img"
			echo ""
			local _reinstall
			read -r -p "  Reinstall from scratch? Deletes rootfs + NVM image [y/N] " _reinstall
			if [[ "$_reinstall" =~ ^[Yy]$ ]]; then
				local _fc_running; _fc_running=$(pgrep -x firecracker 2>/dev/null || true)
				if [[ -n "$_fc_running" ]]; then
					print_error "Cannot reinstall: Firecracker is running (PID: $(echo "$_fc_running" | tr '\n' ' ' | sed 's/ $//'))."
					print_error "Stop all microVM sessions first, then retry --install-microvm."
					return 1
				fi
				print_info "Removing rootfs and NVM image..."
				rm -f "$_rootfs" "$_state_file" "$_nvm_img" "${_rootfs%.ext4}".v*-ready 2>/dev/null || true
				print_info "Re-running installation..."
				_skip_upgrade_paths=true
				# Fall through to full install below (files removed, state cleared)
			else
				return 0
			fi
		fi

		# Safety check: abort if any Firecracker process is running.
		# debugfs -w on a rootfs actively mounted by a live VM causes ext4 corruption
		# (multiply-claimed blocks) because debugfs ignores the kernel VFS cache.
		local _fc_pids; _fc_pids=$(pgrep -x firecracker 2>/dev/null || true)
		if [[ -n "$_fc_pids" ]]; then
			local _fc_pids_line; _fc_pids_line=$(echo "$_fc_pids" | tr '\n' ' ' | sed 's/ $//')
			print_warning "Active Firecracker process(es) detected (PID: $_fc_pids_line)"
			print_warning "debugfs -w on a live rootfs can corrupt ext4 (multiply-claimed blocks)."
			local _confirm
			read -r -p "  Kill all Firecracker processes and continue installation? [y/N] " _confirm
			if [[ "$_confirm" =~ ^[Yy]$ ]]; then
				# shellcheck disable=SC2086
				kill $_fc_pids 2>/dev/null || true
				sleep 1
				local _still; _still=$(pgrep -x firecracker 2>/dev/null || true)
				if [[ -n "$_still" ]]; then
					local _still_line; _still_line=$(echo "$_still" | tr '\n' ' ' | sed 's/ $//')
					print_error "Processes still running (PID: $_still_line). Use 'kill -9 $_still_line' manually, then retry."
					return 1
				fi
				print_info "All Firecracker processes stopped. Continuing installation..."
			else
				print_error "Installation cancelled."
				print_error "  If using --sandbox-microvm: exit Claude Code, then retry."
				print_error "  Or manually: kill $_fc_pids_line"
				return 1
			fi
		fi

		# Fast-path v6→v7: inject rsync for delta sync (ControlMaster + rsync).
		# Requires rsync on host (sudo apt-get install rsync).
		if [[ "$_skip_upgrade_paths" != true ]] && [[ "$(cat "$_state_file" 2>/dev/null)" == "v6" ]]; then
			print_info "Existing rootfs found — upgrading to v7 (inject rsync for delta sync)..."
			local _rsync_host; _rsync_host=$(command -v rsync 2>/dev/null || true)
			if [[ -n "$_rsync_host" && -f "$_rsync_host" ]]; then
				e2fsck -fy "$_rootfs" &>/dev/null || true
				debugfs -w "$_rootfs" <<EOF 2>/dev/null
rm /usr/bin/rsync
write ${_rsync_host} /usr/bin/rsync
set_inode_field /usr/bin/rsync mode 0100755
EOF
				local _v7_dbg_rc=$?
				if [[ $_v7_dbg_rc -eq 0 ]]; then
					printf 'v7' > "$_state_file"
					print_success "rootfs upgraded to v7 (rsync injected — delta sync enabled)"
				else
					print_warning "rsync injection failed (debugfs rc=${_v7_dbg_rc}) — state NOT updated to v7, will retry on next --install-microvm"
				fi
			else
				print_warning "rsync not found on host — v7 upgrade skipped (install: sudo apt-get install rsync)"
				print_warning "Periodic sync will fall back to tar-over-SSH"
			fi
			return 0
		fi

		# Fast-path v5→v6 upgrade: only resize needed, no re-injection.
		# v6 adds: rootfs resized (see MICRO_VM_ROOTFS_SIZE_MB, default 2048MB) for headroom (avoids ENOSPC in npm/node on rootfs).
		if [[ "$_skip_upgrade_paths" != true ]] && [[ "$(cat "$_state_file" 2>/dev/null)" == "v5" ]]; then
			print_info "Existing rootfs found — upgrading to v6 (resize to 500MB for headroom)..."
			echo ""
			_resize_rootfs "$_rootfs" "${MICRO_VM_ROOTFS_SIZE_MB:-2048}"
			printf 'v6' > "$_state_file"
			echo ""
			print_success "microVM v7 upgrade complete"
			print_info "Verify: ./iclaude.sh --check-microvm"
			return 0
		fi

		# Rootfs exists but v5/v6 not applied — upgrade without re-downloading.
		# v6 adds: rootfs resized (see MICRO_VM_ROOTFS_SIZE_MB, default 2048MB) for headroom (avoids ENOSPC for npm/node writes on rootfs).
		# v5 adds: /tmp mounted as tmpfs in guest-init (world-writable, fixes Bash tool access).
		# v4 adds: CA certificate bundle (/etc/ssl/certs/ca-certificates.crt) for HTTPS in guest.
		# v3 adds: jq binary in guest (/usr/bin/jq for statusline), DNS configuration in guest-init.
		if [[ "$_skip_upgrade_paths" != true ]]; then
			local _cur_state; _cur_state=$(cat "$_state_file" 2>/dev/null || echo "")
			if [[ "$_cur_state" == "v4" ]]; then
				print_info "Existing rootfs found — upgrading to v7 (fix /tmp permissions + resize + rsync)..."
			elif [[ "$_cur_state" == "v3" ]]; then
				print_info "Existing rootfs found — upgrading to v7 (CA bundle + /tmp fix + resize + rsync)..."
			else
				print_info "Existing rootfs found — upgrading to v7 (jq + DNS + SSH keys + CA bundle + /tmp fix + resize + rsync)..."
			fi
			echo ""
			_resize_rootfs "$_rootfs" "${MICRO_VM_ROOTFS_SIZE_MB:-2048}"
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
			print_success "microVM v7 upgrade complete"
			print_info "Verify: ./iclaude.sh --sandbox-microvm (Bash tool + no ENOSPC in npm)"
			return 0
		fi
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

	# Load component versions and URLs from versions.json.
	# Env vars MICRO_VM_FC_SHA256 / MICRO_VM_KERNEL_SHA256 / MICRO_VM_ROOTFS_SHA256 override sha256 from file.
	if ! command -v jq &>/dev/null; then
		print_error "jq required for --install-microvm (install: sudo apt-get install jq)"
		return 1
	fi
	local fc_version;       fc_version=$(_versions_read '.firecracker.version')
	local fc_url;           fc_url=$(_versions_read ".firecracker.${arch}.url")
	local vmlinux_version;  vmlinux_version=$(_versions_read '.vmlinux.version')
	local vmlinux_url;      vmlinux_url=$(_versions_read ".vmlinux.${arch}.url")
	local rootfs_version;   rootfs_version=$(_versions_read '.rootfs.version')
	local rootfs_url;       rootfs_url=$(_versions_read ".rootfs.${arch}.url")

	# Fallback to hardcoded defaults if versions.json is missing or incomplete
	fc_version="${fc_version:-v1.11.0}"
	fc_url="${fc_url:-https://github.com/firecracker-microvm/firecracker/releases/download/v1.11.0/firecracker-v1.11.0-${arch}.tgz}"
	vmlinux_version="${vmlinux_version:-6.1.102}"
	vmlinux_url="${vmlinux_url:-https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/${arch}/vmlinux-6.1.102}"
	rootfs_version="${rootfs_version:-ubuntu-22.04-v1.10}"
	rootfs_url="${rootfs_url:-https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/${arch}/ubuntu-22.04.ext4}"

	# Read SHA-256 from versions.json separately from env var overrides.
	# This lets us distinguish "hash came from JSON" vs "hash came from env var" for TOFU logic:
	# - JSON hash present  → verify after download (no save needed, already in file)
	# - env var set        → verify after download (user-provided, no save to file)
	# - both empty         → compute after download and save to versions.json (TOFU)
	local fc_sha256_json;     fc_sha256_json=$(_versions_read ".firecracker.${arch}.sha256")
	local kernel_sha256_json; kernel_sha256_json=$(_versions_read ".vmlinux.${arch}.sha256")
	local rootfs_sha256_json; rootfs_sha256_json=$(_versions_read ".rootfs.${arch}.sha256")

	local fc_sha256="${MICRO_VM_FC_SHA256:-$fc_sha256_json}"
	local kernel_sha256="${MICRO_VM_KERNEL_SHA256:-$kernel_sha256_json}"
	local rootfs_sha256="${MICRO_VM_ROOTFS_SHA256:-$rootfs_sha256_json}"

	# TOFU flags: true when hash was absent from both versions.json and env var.
	# || true: guard against set -e — [[ ]] exits 1 (false) when hashes ARE present,
	# which would kill the script under iclaude.sh's "set -euo pipefail".
	local fc_tofu=false;      [[ -z "$fc_sha256_json"     && -z "${MICRO_VM_FC_SHA256:-}"     ]] && fc_tofu=true     || true
	local vmlinux_tofu=false; [[ -z "$kernel_sha256_json" && -z "${MICRO_VM_KERNEL_SHA256:-}" ]] && vmlinux_tofu=true || true
	local rootfs_tofu=false;  [[ -z "$rootfs_sha256_json" && -z "${MICRO_VM_ROOTFS_SHA256:-}" ]] && rootfs_tofu=true  || true

	local fc_bin="${bin_dir}/firecracker"
	local kernel_path="${MICRO_VM_KERNEL_PATH:-${bin_dir}/vmlinux}"
	local rootfs_path="${MICRO_VM_ROOTFS_PATH:-${bin_dir}/rootfs.ext4}"

	# Sidecar version files — track which version is currently installed
	local fc_version_file="${bin_dir}/firecracker.version"
	local vmlinux_version_file="${bin_dir}/vmlinux.version"
	local rootfs_version_file="${bin_dir}/rootfs.version"

	# If rootfs version changed, clear old rootfs and all upgrade markers to force full re-download.
	if [[ -f "$rootfs_path" ]] && ! _component_is_current "$rootfs_version_file" "$rootfs_version"; then
		print_info "Rootfs version changed → ${rootfs_version}. Removing old rootfs and markers..."
		rm -f "$rootfs_path" "$rootfs_version_file"
		rm -f "${rootfs_path%.ext4}".v{2,3,4,5,6,7}-ready "${rootfs_path%.ext4}.state"
	fi

	# Download Firecracker (skip if already at desired version)
	if _component_is_current "$fc_version_file" "$fc_version" && [[ -x "$fc_bin" ]]; then
		print_info "Firecracker ${fc_version} — already installed, skipping download"
	else
		_download_firecracker "$bin_dir" "$arch" "$fc_version" "$fc_url" "$fc_sha256" || return 1
		echo "$fc_version" > "$fc_version_file"
		if [[ "$fc_tofu" == true ]]; then
			local _fc_hash; _fc_hash=$(_compute_sha256 "$fc_bin") || true
			if _versions_write_sha256 ".firecracker.${arch}.sha256 = \$h" "$_fc_hash"; then
				print_info "SHA-256 saved to versions.json (firecracker ${arch}): ${_fc_hash}"
				print_info "  Pin: export MICRO_VM_FC_SHA256=${_fc_hash}  # add to .claude_config"
			fi
		fi
	fi

	# Download vmlinux kernel (skip if already at desired version)
	if _component_is_current "$vmlinux_version_file" "$vmlinux_version" && [[ -f "$kernel_path" ]]; then
		print_info "vmlinux ${vmlinux_version} — already installed, skipping download"
	else
		_download_vmlinux "$kernel_path" "$vmlinux_url" "$kernel_sha256" || return 1
		echo "$vmlinux_version" > "$vmlinux_version_file"
		if [[ "$vmlinux_tofu" == true ]]; then
			local _vmlinux_hash; _vmlinux_hash=$(_compute_sha256 "$kernel_path") || true
			if _versions_write_sha256 ".vmlinux.${arch}.sha256 = \$h" "$_vmlinux_hash"; then
				print_info "SHA-256 saved to versions.json (vmlinux ${arch}): ${_vmlinux_hash}"
				print_info "  Pin: export MICRO_VM_KERNEL_SHA256=${_vmlinux_hash}  # add to .claude_config"
			fi
		fi
	fi

	# Download rootfs (skip if already at desired version)
	if _component_is_current "$rootfs_version_file" "$rootfs_version" && [[ -f "$rootfs_path" ]]; then
		print_info "Rootfs ${rootfs_version} — already installed, skipping download"
	else
		_download_rootfs "$rootfs_path" "$rootfs_url" "$rootfs_sha256" || return 1
		echo "$rootfs_version" > "$rootfs_version_file"
		if [[ "$rootfs_tofu" == true ]]; then
			local _rootfs_hash; _rootfs_hash=$(_compute_sha256 "$rootfs_path") || true
			if _versions_write_sha256 ".rootfs.${arch}.sha256 = \$h" "$_rootfs_hash"; then
				print_info "SHA-256 saved to versions.json (rootfs ${arch}): ${_rootfs_hash}"
				print_info "  Pin: export MICRO_VM_ROOTFS_SHA256=${_rootfs_hash}  # add to .claude_config"
			fi
		fi
	fi

	# Resize rootfs to MICRO_VM_ROOTFS_SIZE_MB (default 2048MB) for headroom (downloaded image ~265MB used space)
	_resize_rootfs "$rootfs_path" "${MICRO_VM_ROOTFS_SIZE_MB:-2048}"

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
	local _nvm_ok=true
	_create_microvm_nvm_image || { print_warning "NVM block image creation failed — claude unavailable in guest"; _nvm_ok=false; }

	echo ""
	if [[ "$_nvm_ok" == "true" ]]; then
		print_success "microVM installed successfully!"
	else
		print_warning "microVM installed (incomplete): NVM block image missing — claude will not run in guest"
		echo ""
		echo "  Re-run: ./iclaude.sh --install-microvm (enter sudo password when prompted)"
	fi
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
		# Collect ALL inet addresses on the interface
		local tap_ips
		mapfile -t tap_ips < <(ip addr show "$tap_iface" 2>/dev/null | awk '/inet / {print $2}')
		# Check: exactly one IP and it matches expected
		if [[ ${#tap_ips[@]} -eq 1 ]] && [[ "${tap_ips[0]}" == "${host_ip}/${prefix}" ]]; then
			print_success "TAP interface ${tap_iface} already configured (${host_ip}/${prefix})"
			return 0
		fi
		local tap_ips_str="${tap_ips[*]:-none}"
		print_warning "TAP ${tap_iface} has IP(s) [${tap_ips_str}], expected ${host_ip}/${prefix} — updating"
		if sudo -n true 2>/dev/null; then
			# Flush ALL addresses to avoid stale IPs accumulating
			sudo ip addr flush dev "$tap_iface" 2>/dev/null || true
			sudo ip addr add "${host_ip}/${prefix}" dev "$tap_iface" 2>/dev/null && \
			sudo ip link set "$tap_iface" up 2>/dev/null && \
			print_success "TAP ${tap_iface} IP updated → ${host_ip}/${prefix}" || \
			print_warning "TAP IP update failed — routing may not work"
		else
			print_warning "Cannot update TAP IP (sudo unavailable) — routing may fail"
			print_info "  Fix: sudo ip addr flush dev ${tap_iface} && sudo ip addr add ${host_ip}/${prefix} dev ${tap_iface}"
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

	# Loop mount requires root — sudo will prompt for password if needed.

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

	# loop device requires the backing file to be on a local filesystem —
	# NFS/CIFS/SMB backing files are rejected by the kernel with ELOOP/EPERM.
	# Detect whether nvm_img lives on a network FS; if so, build tmp_img in /var/tmp (local).
	local tmp_img
	local _nvm_fstype; _nvm_fstype=$(df -T "$(dirname "$nvm_img")" 2>/dev/null | awk 'NR==2{print $2}')
	case "${_nvm_fstype:-}" in
		nfs*|cifs|smb*|afs|9p|virtiofs|fuse.*)
			# Network FS detected — find a local directory for the loop-backing file.
			local _local_dir=""
			for _d in "/var/tmp" "/tmp"; do
				local _fst; _fst=$(df -T "$_d" 2>/dev/null | awk 'NR==2{print $2}')
				case "${_fst:-}" in
					nfs*|cifs|smb*|afs|9p|virtiofs|fuse.*) continue ;;
					*) _local_dir="$_d"; break ;;
				esac
			done
			_local_dir="${_local_dir:-/tmp}"
			tmp_img="${_local_dir}/.iclaude-nvm-$$.img.tmp"
			print_info "microVM: NVM image target is on network FS (${_nvm_fstype}) — building on local FS (${_local_dir})..."
			;;
		*)
			tmp_img="${nvm_img}.tmp"
			;;
	esac

	# Create sparse ext4 image
	if ! dd if=/dev/zero of="$tmp_img" bs=1M count=0 seek="$nvm_size_mb" 2>/dev/null; then
		print_error "microVM: failed to create NVM image at ${tmp_img}"
		rm -f "$tmp_img"; return 1
	fi
	if ! mkfs.ext4 -F -q -L iclaude-nvm "$tmp_img" 2>/dev/null; then
		print_error "microVM: failed to format NVM image (mkfs.ext4)"
		rm -f "$tmp_img"; return 1
	fi

	# Mount and populate via rsync.
	# Try fuse2fs (no root) first; fall back to sudo/su loop mount.
	# Exclude host-specific dirs not needed in guest: microVM binaries, session history,
	# Python venvs, SSH keys, logs, caches, and other runtime-only data.

	# Use explicit /tmp path so the mount point is in world-accessible /tmp,
	# not in $TMPDIR (/tmp/.private/$USER, mode 1700) which root can traverse but is non-standard.
	local mnt_tmp; mnt_tmp=$(mktemp -d /tmp/.iclaude-mnt-XXXXXX)
	local _use_fuse=false
	if command -v fuse2fs &>/dev/null; then
		print_info "microVM: mounting NVM image via fuse2fs (no root required)..."
		if fuse2fs "$tmp_img" "$mnt_tmp" -o fakeroot,rw 2>/dev/null; then
			_use_fuse=true
		else
			print_warning "microVM: fuse2fs failed — falling back to privileged mount..."
		fi
	fi
	if [[ "$_use_fuse" == "false" ]]; then
		if ! _priv_run mount -o loop "$tmp_img" "$mnt_tmp"; then
			print_error "microVM: failed to mount NVM image (loop device)"
			rm -f "$tmp_img"; rmdir "$mnt_tmp" 2>/dev/null; return 1
		fi
		# Restrict mount point: loop mount exposes ext4 root inode (mode 0755 by default),
		# making it world-readable. chmod 700 limits access to root only during rsync.
		_priv_run chmod 700 "$mnt_tmp" 2>/dev/null || true
	fi

	print_info "microVM: populating NVM image via rsync..."
	local _rsync_excludes=(
		--exclude='.claude-isolated/bin/'
		--exclude='.claude-isolated/projects/'
		--exclude='.claude-isolated/pii-proxy-venv/'
		--exclude='.claude-isolated/pii-proxy*'
		--exclude='.claude-isolated/debug/'
		--exclude='.claude-isolated/file-history/'
		--exclude='.claude-isolated/todos/'
		--exclude='.claude-isolated/paste-cache/'
		--exclude='.claude-isolated/tasks/'
		--exclude='.claude-isolated/telemetry/'
		--exclude='.claude-isolated/session-env/'
		--exclude='.claude-isolated/cache/'
		--exclude='.claude-isolated/shell-snapshots/'
		--exclude='.claude-isolated/plans/'
		--exclude='.claude-isolated/statsig/'
		--exclude='.claude-isolated/ssh/'
		--exclude='.claude-isolated/chrome/'
		--exclude='.claude-isolated/microvm-run/'
		--exclude='.claude-isolated/microvm-snapshots/'
		--exclude='.claude-isolated/backups/'
		--exclude='versions/node/*/include/'
		--exclude='versions/node/*/.npm/'
		--exclude='.npm/'
	)
	if [[ "$_use_fuse" == "true" ]]; then
		# fuse2fs with fakeroot: rsync runs as current user, no privilege needed
		if ! rsync -a --delete --info=progress2 "${_rsync_excludes[@]}" "$nvm_src/" "$mnt_tmp/"; then
			print_warning "microVM: rsync had errors — NVM image may be incomplete"
		fi
		fusermount -u "$mnt_tmp" 2>/dev/null \
			|| fusermount3 -u "$mnt_tmp" 2>/dev/null \
			|| true
	else
		# Suppress rsync stderr (goes through su/sudo; error noise from shell init is expected).
		# stdout (--info=progress2) is piped through su and visible to the user.
		if ! _priv_run rsync -a --delete --info=progress2 "${_rsync_excludes[@]}" "$nvm_src/" "$mnt_tmp/" 2>/dev/null; then
			print_warning "microVM: rsync had errors — NVM image may be incomplete"
		fi
		_priv_run umount "$mnt_tmp" || true
	fi
	rmdir "$mnt_tmp" 2>/dev/null || true

	# Move completed image to final location (mv handles cross-FS via copy+delete).
	if [[ "$tmp_img" != "${nvm_img}.tmp" ]]; then
		print_info "microVM: moving NVM image to final location..."
	fi
	if ! mv "$tmp_img" "$nvm_img" 2>/dev/null; then
		print_error "microVM: failed to move NVM image to ${nvm_img}"
		rm -f "$tmp_img"; return 1
	fi
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
	# Search order covers major distro layouts:
	#   Debian/Ubuntu  → /etc/ssl/certs/ca-certificates.crt  (pkg: ca-certificates)
	#   ALT Linux      → /etc/pki/tls/certs/ca-bundle.crt    (pkg: ca-trust)
	#   RHEL/CentOS    → /etc/pki/tls/certs/ca-bundle.crt    (pkg: ca-certificates)
	#   openSUSE       → /etc/ssl/ca-bundle.pem               (pkg: ca-certificates)
	local ca_bundle="" _ca_candidate
	for _ca_candidate in \
		/etc/ssl/certs/ca-certificates.crt \
		/etc/pki/tls/certs/ca-bundle.crt \
		/etc/ssl/ca-bundle.pem \
		/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; do
		if [[ -f "$_ca_candidate" ]]; then
			ca_bundle="$_ca_candidate"
			break
		fi
	done
	if [[ -n "$ca_bundle" ]]; then
		debugfs -w "$rootfs" <<EOF 2>/dev/null
mkdir /etc/ssl
mkdir /etc/ssl/certs
rm /etc/ssl/certs/ca-certificates.crt
write ${ca_bundle} /etc/ssl/certs/ca-certificates.crt
set_inode_field /etc/ssl/certs/ca-certificates.crt mode 0100644
EOF
		local _ca_rc=$?
		if [[ $_ca_rc -eq 0 ]]; then
			print_success "CA bundle injected into guest rootfs (source: ${ca_bundle})"
		else
			print_warning "CA bundle injection failed (debugfs rc=${_ca_rc}) — HTTPS will fail in guest"
		fi
	else
		print_warning "CA bundle not found on host — HTTPS will fail in guest"
		print_warning "  Debian/Ubuntu: sudo apt install ca-certificates"
		print_warning "  ALT Linux:     sudo apt-get install ca-trust"
		print_warning "  RHEL/Fedora:   sudo dnf install ca-certificates"
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

	# Write state marker: rootfs has guest-init + jq + SSH keys + CA bundle + /tmp fix + resize + rsync.
	printf 'v7' > "${rootfs%.ext4}.state"
	# Remove legacy per-version marker files if present (migration from v2–v7 touch files).
	rm -f "${rootfs%.ext4}".v{2,3,4,5,6,7}-ready
	print_success "Guest init injected (rootfs ready for v7)"
	return 0
}
