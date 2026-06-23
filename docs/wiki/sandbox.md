# microVM Sandbox (Firecracker)

## Overview

Runs Claude Code inside a Firecracker microVM for kernel-level (KVM) isolation. The VM boots an Ubuntu 22.04 rootfs via a custom PID 1 init, attaches the NVM env and workspace as virtio-blk devices, and exposes SSH over a TAP interface. Claude runs in the guest over SSH with workspace sync, multi-slot concurrency, optional snapshots, and orphan cleanup. See [[architecture#Overview]].

## Guest Topology

```
Host                        Guest (slot 0 → 172.16.0.2)
────────────────────        ────────────────────────────────
firecracker (KVM)      →    PID 1: /usr/sbin/iclaude-guest-init
tap-iclaude-1               sshd (pubkey only, iclaude user)
172.16.0.1 (host)           /dev/vda → rootfs (ext4, rw, per-session copy)
                            /dev/vdb → nvm.img (ext4, ro) → /mnt/nvm
                            /dev/vdc → workspace.img (ext4, rw) → /workspace
```

All guest processes run as the non-root `iclaude` user (uid 1000); root SSH login is disabled. KVM hardware virtualization (`/dev/kvm`) is the security boundary, so the `iclaude` user has NOPASSWD sudo inside the VM. Component versions (`lib/sandbox/versions.json`): Firecracker `v1.11.0`, guest kernel `vmlinux 6.1.102`, rootfs `ubuntu-22.04-v1.10`.

## Detection

`lib/sandbox/detect.sh` gates microVM availability. `detect_linux_distro()` reads `/etc/os-release`, normalizes ALT Linux IDs (`alt`/`altlinux`/`altserver`/`altworkstation` → `altlinux`), and returns `distro:version`. `check_distro_microvm_support()` requires Ubuntu ≥ 22, Debian ≥ 10, ALT Linux ≥ 10, and never blocks unknown/other distros. `detect_kvm_support()` requires Linux (rejects WSL1), and a readable `/dev/kvm`. `detect_microvm_binary()` checks `$MICRO_VM_BIN_PATH` (default `$ISOLATED_CONFIG_DIR/bin/firecracker`). `detect_microvm()` (in `microvm.sh`) combines these plus the kernel and rootfs files. The launcher calls this — see [[launcher#Mode Selection]].

## Guest Init

`lib/sandbox/guest-init.sh` is the guest PID 1, injected at `/usr/sbin/iclaude-guest-init` by `_inject_rootfs_guest_init()`. On boot it: mounts kernel filesystems (`proc`, `sysfs`, `devtmpfs`, `devpts`, plus `tmpfs` for `/dev/shm`, `/run`, and `/tmp` at mode 1777 to guarantee a world-writable scratch dir); brings up loopback; writes `/etc/resolv.conf` (`8.8.8.8`, `1.1.1.1`, since the kernel `ip=` cmdline sets routing but not DNS); mounts `/dev/vdb` ro at `/mnt/nvm` and `/dev/vdc` rw at `/workspace`; creates the `iclaude` user (`useradd -M -p '*'`, so pubkey auth is allowed and the pre-seeded `.ssh` survives); sources `/workspace/.iclaude-guest-env.sh`; and starts `sshd` (`UsePAM no`, `PermitRootLogin no`, `AllowUsers iclaude`, pubkey only). A `SIGTERM`/`INT` handler (`_graceful_shutdown`) syncs, remounts rootfs read-only (clears the ext4 dirty flag), and exits PID 1 — causing a kernel panic that ends the Firecracker process. The host polls SSH directly for readiness (no file-based signal).

## Installation

`install_microvm()` in `lib/sandbox/install.sh` downloads three components (URLs + SHA-256 in `versions.json`) into `$ISOLATED_CONFIG_DIR/bin/` (gitignored). It checks KVM and the distro gate early, then fetches the Firecracker binary (`v1.11.0`, ~10 MB tgz), `vmlinux` kernel (`6.1.102`, ~40 MB), and `rootfs.ext4` (`ubuntu-22.04-v1.10`, ~300 MB download). Downloads use `_curl_download()` with proxy support (`PROXY_URL`/`PROXY_CA`/`PROXY_INSECURE`); on TLS exit 35 (old OpenSSL) it retries `--insecure --proxy-insecure` with a warning. SHA-256 is verified when present; if absent and no `MICRO_VM_*_SHA256` override is set, the hash is computed and written back to `versions.json` (Trust-On-First-Use). Sidecar `.version` files skip already-current components; a changed rootfs version wipes the old image and markers to force re-download. `--install-microvm` aborts (or offers to kill) while Firecracker is running, since `debugfs -w` on a live rootfs corrupts ext4.

## Rootfs State Machine

`_inject_rootfs_guest_init()` populates the rootfs offline via `debugfs` (no mount, no loop device) and records progress in `<rootfs>.state`. The current target is **`v7`**, the cumulative result of staged upgrades: `v3` (jq binary + DNS), `v4` (CA-certificate bundle for guest HTTPS), `v5` (`/tmp` tmpfs fix), `v6` (resize via `_resize_rootfs()` with `truncate`+`e2fsck`+`resize2fs` to `MICRO_VM_ROOTFS_SIZE_MB`, default 2048 MB), `v7` (self-contained rsync bundle for delta sync). Re-running `--install-microvm` applies missing upgrades in place without re-downloading; legacy `.vN-ready` touch-file markers are migrated to `rootfs.state`. The injection also bakes `/etc/ssh/sshd_config.d/iclaude.conf`, a NOPASSWD `/etc/sudoers.d/iclaude-vm` drop-in, the SSH `authorized_keys`, and extracts the guest host pubkey for known-hosts pinning. `e2fsck -fy` runs before every `debugfs -w` to clear any dirty/journal state.

## NVM and SSH Keys

The NVM image (`_create_microvm_nvm_image()`) is a pre-built sparse ext4 image of the isolated NVM dir, attached read-only as `/dev/vdb` → `/mnt/nvm` each session — replacing per-session virtiofsd. It is sized from `du` minus host-only dirs (bin/, projects/, venvs) with 20% headroom, populated via `rsync` over a `fuse2fs` (no-root) or privileged loop mount, with a long exclude list (sessions, caches, telemetry, ssh, chrome, etc.). `_priv_run()` escalates via `sudo` or `su` (root or sudo-user) when loop mounting is needed. The SSH key pair (`_generate_microvm_ssh_key()`, ed25519, no passphrase) lives at `$ISOLATED_CONFIG_DIR/ssh/microvm`; the public key is baked into `/home/iclaude/.ssh/authorized_keys` and the guest host pubkey is saved to `microvm_host_key.pub` for per-session known-hosts pinning.

## rsync Bundle (Delta Sync)

`_inject_rootfs_rsync_bundle()` makes workspace delta sync work despite host/guest glibc mismatch (e.g. host Ubuntu 24.04 / glibc 2.39 vs guest Ubuntu 22.04 / glibc 2.35). A bare copy of the host rsync fails in the guest (missing `GLIBC_2.38/2.39` symbols, `libpopt.so.0` → exit 127). Instead a self-contained bundle is injected into `/opt/iclaude-rsync/`: the host `rsync.bin`, its full `ldd` lib closure, AND the host dynamic loader; `/usr/bin/rsync` becomes a wrapper running `rsync.bin` through the bundled loader (`--library-path`), isolated from guest libc. Injection is idempotent (a `<rootfs>.rsync-bundle` marker holds the host rsync's sha256) and is applied to existing v7 images without a state bump. If host rsync is missing or the bundle cannot be built, the launcher falls back to tar-over-SSH — see [[launcher#microVM Workspace Sync]].

## TAP Networking

`_setup_microvm_network_or_instruct()` (install time) creates the slot-0 TAP (`{prefix}-1`, default `tap-iclaude-1`) with host IP derived from `MICRO_VM_NET_SUBNET` (slot-0 host = base+1, default `172.16.0.1/26`), enables `net.ipv4.ip_forward`, and adds an iptables MASQUERADE NAT rule on the default route. It needs `sudo`; if unavailable it prints the manual commands. At runtime `_ensure_slot_tap()` creates/updates the per-slot TAP and FORWARD rules, and a `/32` host route per guest IP keeps concurrent slots from cross-routing. Interface names and IPs are validated before use to prevent injection into `sudo`/`iptables` calls.

## Slot Allocation (Concurrency)

`lib/sandbox/microvm.sh` supports multiple concurrent sessions via a slot model over `MICRO_VM_NET_SUBNET` (default `172.16.0.0/26` → 31 slots). `_alloc_microvm_slot()` atomically claims a free `slot-N.lock` (noclobber, skipping locks held by a live PID) and assigns slot N → host IP base+2N+1, guest IP base+2N+2, TAP `{prefix}-{N+1}`, and a unique MAC `AA:FC:00:00:00:{N+1}`. A legacy mode uses explicit `MICRO_VM_NET_GUEST_IP`/`HOST_IP` (slot 0, /24) when no subnet is set. The lock is updated with the real Firecracker PID (`_claim_microvm_slot`) and released on stop (`_free_microvm_slot`).

## Runtime (start_microvm)

`start_microvm()` allocates a slot, ensures the TAP, creates a mode-700 per-session dir (`microvm-run/<session_id>/`), and makes a per-session sparse copy of the base rootfs (Firecracker opens vda read-write; sharing one file across VMs would corrupt ext4). `_check_and_grow_rootfs()` auto-grows the base rootfs (via `tune2fs` metadata) when free space drops below 30%. It creates a sparse workspace image (`_create_workspace_image()`, `MICRO_VM_WORKSPACE_SIZE_MB`, default 2048 MiB) for `/dev/vdc`, builds `vmconfig.json` (`build_microvm_config()` — JSON-escaped, with the three drives, machine-config, and a validated TAP interface, plus `init=/usr/sbin/iclaude-guest-init` when the base rootfs is provisioned), launches Firecracker with `--config-file`, waits for the API socket (`_wait_firecracker_socket`, 10 s), then polls guest SSH (`_poll_guest_ssh`, 30 s). The guest env file is pushed via SCP; the launcher then execs Claude in the guest over SSH. The PII-proxy DNAT path (below) is set up here, and statusline vars (`ICLAUDE_MICROVM_ACTIVE`, `ICLAUDE_MICROVM_INFO_PATH`) are exported — see [[statusline]].

## Guest Environment & Authentication

`configure_guest_environment()` writes `/workspace/.iclaude-guest-env.sh` (chmod 600, sourced then deleted at launch) with the guest's `ANTHROPIC_BASE_URL`, proxy/`NO_PROXY`, model, router flag, NVM `PATH` (npm-global first), tmpfs npm/XDG caches, and `CLAUDE_CONFIG_DIR=/workspace/.claude-guest`. A Python snippet builds `.claude-guest` by symlinking most subdirs from the read-only NVM image but copying the files Claude writes (`.claude.json`, `.credentials.json`, history) and patching out `skipDangerousModePermissionPrompt`. Authentication is forwarded explicitly: any of `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY` set on the host (typically `CLAUDE_CODE_OAUTH_TOKEN` from `.claude_config`, exported by [[config#Environment Variable Export]]) is escaped and exported into the env file — env-token hosts have no `.credentials.json` to copy, so without this the guest reports `Not logged in`. See [[launcher#microVM Workspace Sync]] for keeping `.claude_config` out of the synced workspace.

## PII Proxy DNAT

When the PII proxy is active (`ICLAUDE_PII_ACTIVE=1`) with networking enabled, `configure_guest_environment()` repoints `ANTHROPIC_BASE_URL` to `http://<host_ip>:<pii_port>` and adds the host IP to `NO_PROXY` (so undici reaches the private TAP address directly). Because the proxy binds only to `127.0.0.1`, `start_microvm()` installs an iptables PREROUTING DNAT rewriting `<host_ip>:<port>` → `127.0.0.1:<port>` plus an INPUT ACCEPT, and sets `route_localnet=1` on the TAP iface (Linux otherwise treats 127/8 as martian). `_pii_dnat_preflight()` checks for passwordless sudo and nat-table access first; `_pii_dnat_sweep_stale()` removes orphaned rules by comment marker (`iclaude-pii-dnat:<tap>`) both before adding and on stop. See [[pii-proxy]].

## Snapshots

When `MICRO_VM_SNAPSHOT_ENABLED=true`, `start_microvm()` offers an interactive restore via `_select_snapshot()` (parsed with a safe non-sourcing reader, `_read_snapshot_meta()`), else cold boots. `_restore_from_snapshot()` overrides network vars from the snapshot's `meta.env` (validated), copies snapshot drives to the session dir, launches Firecracker without `--config-file`, loads the snapshot over the API, PATCHes `/drives` to redirect to the per-session copies (so concurrent restores never share a read-write image), resumes, and re-pushes the guest env. On exit, `stop_microvm()` prompts to save a named snapshot via `_create_named_snapshot()` (pause → copy drives → PATCH drives → `snapshot/create` Full → write `meta.env`). Snapshots live under `MICRO_VM_SNAPSHOT_DIR` (default `$ISOLATED_CONFIG_DIR/microvm-snapshots`).

## Shutdown & Orphan Cleanup

`stop_microvm()` (registered via `setup_microvm_traps()` on EXIT/INT/TERM) optionally snapshots, then SSHes a graceful `sync && mount -o remount,ro / && sudo kill -TERM 1` to trigger the guest's clean shutdown (kernel panic → Firecracker exits), falling back to SIGTERM then SIGKILL on the FC PID. It removes the session dir, API socket, the guest `/32` route, the PII DNAT rules + `route_localnet`, the FORWARD rules, and the TAP interface, then frees the slot. `cleanup_orphaned_microvm_sessions()` runs at launch (before slot allocation) to sweep artifacts from sessions killed without cleanup: stale FC sockets (via `fuser`), session dirs with no live slot lock, and TAP interfaces (`{prefix}-{N}`) whose slot lock is missing or references a dead PID — removing their FORWARD rules and the interface. See [[launcher#microVM Launch Path]].

## Status

`check_microvm_status()` in `lib/sandbox/status.sh` (the `--check-microvm` command) reloads `.claude_config`, then reports: KVM availability, Firecracker binary path + version, `vmlinux` and `rootfs.ext4` paths/sizes, the rootfs state version (warns when below v7), rootfs size vs. `MICRO_VM_ROOTFS_SIZE_MB` (ENOSPC warning below 80%), `nvm.img` presence, the slot-0 TAP IP (warns on multiple/stale IPs), current configuration variables, a RAM warning if `MICRO_VM_MEM_MB` < 2048 (Claude Code RSS ~600 MB), the snapshot directory and count, and a readiness summary. See [[command]] for the CLI dispatch.

```bash
./iclaude.sh --install-microvm   # download + provision (needs jq, curl/wget, sudo)
./iclaude.sh --sandbox-microvm   # launch Claude inside the guest
./iclaude.sh --check-microvm     # status report
```

## Configuration Variables

| Variable | Default | Purpose |
|---|---|---|
| `MICRO_VM_ENABLED` | `false` | Enable microVM on launch |
| `MICRO_VM_VCPU` | `2` | Guest vCPU count (1–128) |
| `MICRO_VM_MEM_MB` | `2048` | Guest RAM in MB (128–65536; ≥ 2048 recommended) |
| `MICRO_VM_NET_ENABLED` | `true` | Enable TAP networking |
| `MICRO_VM_NET_SUBNET` | `172.16.0.0/26` | Subnet pool for slot IP allocation |
| `MICRO_VM_NET_TAP_IFACE` | `tap-iclaude` | TAP interface name prefix (`-{slot+1}` appended) |
| `MICRO_VM_ROOTFS_SIZE_MB` | `2048` | Target rootfs size after resize |
| `MICRO_VM_WORKSPACE_SIZE_MB` | `2048` | Per-session workspace image size (MiB) |
| `MICRO_VM_WORKSPACE_MODE` | `full` | `full` (bidirectional sync) or `isolated` (one-way) |
| `MICRO_VM_WORKSPACE_PATH` | `$PWD` | Workspace source dir override |
| `MICRO_VM_SNAPSHOT_ENABLED` | `false` | Enable interactive Firecracker snapshots |
| `MICRO_VM_MOUNT_WORKSPACE` | `true` | Mount project dir as /workspace |
| `MICRO_VM_LOG_LEVEL` | `warn` | Firecracker VMM log level |
| `MICRO_VM_INSECURE_DOWNLOAD` | `false` | Skip TLS verification on downloads |
| `MICRO_VM_BIN_PATH` | `$ISOLATED_CONFIG_DIR/bin/firecracker` | Firecracker binary path |
| `MICRO_VM_KERNEL_PATH` | `$ISOLATED_CONFIG_DIR/bin/vmlinux` | Kernel image path |
| `MICRO_VM_ROOTFS_PATH` | `$ISOLATED_CONFIG_DIR/bin/rootfs.ext4` | Rootfs image path |
| `MICRO_VM_NVM_IMG` | `$ISOLATED_CONFIG_DIR/bin/nvm.img` | NVM block image path |
| `MICRO_VM_FC_SHA256` / `MICRO_VM_KERNEL_SHA256` / `MICRO_VM_ROOTFS_SHA256` | — | Override/pin component SHA-256 |

Variables are de-prefixed from `ICLAUDE_*` in `.claude_config` by [[config#Environment Variable Export]]. See [[proxy]] for the proxy settings forwarded into the guest.
