# Sandbox

Firecracker microVM kernel-level isolation for Claude Code. Activated via `--sandbox-microvm` flag or `USE_MICRO_VM_FLAG=true`. Claude runs as `iclaude` user (uid=1000) inside the guest VM, never as root.

## Why microVM

KVM hardware isolation ensures Claude's bash tool commands cannot escape to the host filesystem. bubblewrap (bwrap) was removed in 2026-03 — it created 0-byte read-only stub files in `.claude/` of other open projects.

## Guest Topology

```
Host                          Guest VM (172.16.0.2)
iclaude.sh                    /mnt/nvm  ← .nvm-isolated/ (virtio-blk vdb, RO)
  ├── Firecracker              /workspace ← rsync'd copy of LAUNCH_DIR
  ├── PII proxy (:PORT)        claude binary (/mnt/nvm/npm-global/bin/claude)
  └── CCR (:3456)             ENV from /workspace/.iclaude-guest-env.sh
```

TAP interface `tap-iclaude`: host `172.16.0.1` ↔ guest `172.16.0.2`.

## Workspace Sync

`[[lib/launcher/launch.sh#launch_claude]]` syncs workspace before and after Claude runs:

| Direction | When | Method |
|-----------|------|--------|
| host → guest | Before Claude starts | rsync (v7+ rootfs) or tar-over-SSH |
| guest → host | After Claude exits (full mode) | rsync or tar-over-SSH |
| periodic | Every `MICRO_VM_SYNC_INTERVAL` seconds (if >0) | Background loop, overlap-protected |

`isolated` workspace mode (`MICRO_VM_WORKSPACE_MODE=isolated`) skips guest→host sync — host files remain unchanged.

Excluded from sync: `.nvm-isolated/`, `.git/`, `.claude_config`, `.claude_proxy_credentials`, `.iclaude-guest-env.sh`, `.iclaude-ssh/`.

## SSH ControlMaster

A persistent mux connection is established before Claude starts. Reduces per-op SSH overhead from ~200ms to ~5ms. `ControlPersist=60` auto-closes orphaned connections.

## Configuration Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `MICRO_VM_VCPU` | 2 | vCPU count |
| `MICRO_VM_MEM_MB` | 1024 | Guest RAM |
| `MICRO_VM_NET_HOST_IP` | 172.16.0.1 | Host TAP IP |
| `MICRO_VM_NET_GUEST_IP` | 172.16.0.2 | Guest IP |
| `MICRO_VM_SNAPSHOT_ENABLED` | false | VM snapshot support |
| `MICRO_VM_WORKSPACE_MODE` | full | `full` or `isolated` |
| `MICRO_VM_SYNC_INTERVAL` | 0 | Periodic sync interval (seconds, 0=off) |
| `MICRO_VM_SYNC_EXCLUDE` | — | Colon-separated extra excludes |

## Host Key Pinning

`start_microvm()` extracts the guest SSH host key on first boot and saves it to `MICRO_VM_KNOWN_HOSTS`. Subsequent connections use `StrictHostKeyChecking=yes`. Falls back to `StrictHostKeyChecking=no` for pre-pinning installs (with warning).

## Flags Stripped Before Guest

`--chrome` and `--ide` are stripped from args forwarded into the guest VM — both features require host-side IPC that the VM cannot reach.
