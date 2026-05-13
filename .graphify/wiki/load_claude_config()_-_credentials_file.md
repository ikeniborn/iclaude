# load_claude_config() / credentials_file

> 33 nodes · cohesion 0.08

## Key Concepts

- **install_microvm()** (16 connections) — `lib/sandbox/install.sh`
- **ISOLATED_CONFIG_DIR** (10 connections) — `lib/core/init.sh`
- **_curl_download()** (4 connections) — `lib/sandbox/install.sh`
- **check_microvm_status()** (4 connections) — `lib/sandbox/status.sh`
- **load_claude_config()** (3 connections) — `lib/config/isolated.sh`
- **check_distro_microvm_support()** (3 connections) — `lib/sandbox/detect.sh`
- **detect_kvm_support()** (3 connections) — `lib/sandbox/detect.sh`
- **detect_microvm_binary()** (3 connections) — `lib/sandbox/detect.sh`
- **check_microvm_dependencies()** (3 connections) — `lib/sandbox/install.sh`
- **_download_firecracker()** (3 connections) — `lib/sandbox/install.sh`
- **_download_rootfs()** (3 connections) — `lib/sandbox/install.sh`
- **_download_vmlinux()** (3 connections) — `lib/sandbox/install.sh`
- **_inject_rootfs_guest_init()** (3 connections) — `lib/sandbox/install.sh`
- **_verify_sha256()** (3 connections) — `lib/sandbox/install.sh`
- **detect_linux_distro()** (2 connections) — `lib/sandbox/detect.sh`
- **_generate_microvm_ssh_key()** (2 connections) — `lib/sandbox/install.sh`
- **configure_statusline_in_settings()** (2 connections) — `lib/statusline/install.sh`
- **install_statusline_script()** (2 connections) — `lib/statusline/install.sh`
- **CREDENTIALS_FILE** (1 connections) — `lib/core/init.sh`
- **MICRO_VM_ENABLED** (1 connections) — `lib/config/isolated.sh`
- **PROXY_URL** (1 connections) — `lib/sandbox/install.sh`
- **install_plugins_from_manifest()** (1 connections) — `lib/lsp/repair.sh`
- **_claim_microvm_slot()** (1 connections) — `lib/sandbox/microvm.sh`
- **_ensure_slot_tap()** (1 connections) — `lib/sandbox/microvm.sh`
- **_free_microvm_slot()** (1 connections) — `lib/sandbox/microvm.sh`
- *... and 8 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `lib/config/isolated.sh`
- `lib/core/init.sh`
- `lib/lsp/repair.sh`
- `lib/sandbox/detect.sh`
- `lib/sandbox/guest-init.sh`
- `lib/sandbox/install.sh`
- `lib/sandbox/microvm.sh`
- `lib/sandbox/status.sh`
- `lib/statusline/install.sh`
- `lib/statusline/status.sh`

## Audit Trail

- EXTRACTED: 81 (93%)
- INFERRED: 6 (7%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*