# Migration Roadmap

This document tracks planned architectural migrations and known limitations.

---

## npm → Native Installer

**Status:** Planned

Claude Code is currently installed via NVM + npm into `.nvm-isolated/`. The upstream team
is working on a native binary installer. When available, iclaude will migrate the
`--isolated-install` path to use the native installer while keeping the same CLI surface.

**Impact:** `lib/nvm/install.sh`, `lib/lockfile/`, `lib/update/`

---

## microVM: Host-launch → Full In-Guest Execution

**Status:** v1 shipped (host-launch with virtiofs isolation); v2 planned (full in-guest)

### Current architecture (v1)

```
Host OS
├── iclaude.sh          ← manages VM lifecycle
├── virtiofsd           ← FUSE daemon: mounts NVM dir and $PWD into guest
├── firecracker         ← VMM: guest kernel runs in isolation
│   ├── /mnt/nvm  (ro) ← host ISOLATED_NVM_DIR (Node.js, claude binary)
│   └── /workspace (rw) ← host $PWD (project files)
└── claude (host)       ← still executes on host with env from microVM guest
```

The v1 implementation starts Firecracker (providing kernel isolation via KVM) and
mounts the workspace and NVM directory via virtiofs. Claude Code itself still runs on
the host process, with filesystem access restricted to the virtiofs-mounted paths.
Guest environment variables (ANTHROPIC_BASE_URL, CLAUDE_CONFIG_DIR, proxy settings)
are written to `.iclaude-guest-env.sh` in the workspace root and sourced by the guest
init (when full in-guest execution is enabled).

**Achieved in v1:**
- Guest kernel isolated from host kernel (KVM boundary)
- Filesystem access via virtiofs mounts (NVM ro, workspace rw)
- Environment propagation via workspace-mounted env file
- TAP networking with iptables NAT
- Compatibility with --pii-proxy and --router

### Target architecture (v2)

```
Host OS
├── iclaude.sh
├── virtiofsd
└── firecracker
    └── Guest VM
        ├── Node.js (from /mnt/nvm virtiofs)
        └── claude (spawned by guest init script)  ← full isolation
```

**Required for v2:**
1. Guest init script in `rootfs.ext4` that sources `/workspace/.iclaude-guest-env.sh`
   and then execs `node /mnt/nvm/…/claude`
2. `lib/sandbox/microvm.sh::start_microvm()` must wait for guest claude to finish
   (via vsock handshake or serial console) rather than running host claude
3. Exit code propagation from guest to host (vsock or virtio-serial)

**Files to change for v2:** `lib/sandbox/microvm.sh`, `lib/launcher/launch.sh`,
and a new `lib/sandbox/microvm-rootfs/init.sh` guest init script baked into rootfs.

### Security note

Until v2 is implemented, kernel isolation applies to tool calls executed by the AI
inside the VM filesystem boundary. The claude process itself and Node.js runtime
still run on the host kernel. This is a meaningful reduction in attack surface
(virtiofs limits filesystem access) but is not full kernel isolation for the AI process.
See `docs/SANDBOX_ANALYSIS.md` for the complete threat model.
