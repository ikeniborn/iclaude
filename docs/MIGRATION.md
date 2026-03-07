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

## microVM: Full In-Guest Execution (Firecracker v2)

**Status:** v2 implemented (virtio-blk + SSH exec, коммит d73e3e5)

### Текущая архитектура (v2 — CURRENT)

```
Host OS (Linux + KVM)
├── iclaude.sh              ← управляет lifecycle VM
├── Firecracker VMM         ← запускает guest, virtio-blk devices
│   ├── /dev/vda  (rw)      ← rootfs (Ubuntu 22.04, guest PID 1: iclaude-guest-init)
│   ├── /dev/vdb  (ro)      ← nvm.img (~1GB, Node.js + claude binary)
│   └── /dev/vdc  (rw)      ← workspace.img (per-session sparse ext4)
└── Guest VM
    ├── iclaude-guest-init  ← PID 1: монтирует vdb/vdc, стартует sshd
    └── claude              ← выполняется ВНУТРИ GUEST по SSH
```

Host управляет только lifecycle VM. Claude Code, Node.js и все tool calls выполняются
внутри гостевой ВМ с отдельным Linux ядром. Синхронизация workspace — tar-over-SSH.

**Реализовано в v2:**
- Full in-guest execution — claude и все subprocess внутри guest kernel (KVM boundary)
- virtio-blk block devices вместо virtiofs: vdb=nvm.img (RO), vdc=workspace.img (RW, per-session)
- SSH exec: `ssh root@guest_ip "source /workspace/.iclaude-guest-env.sh && exec claude"`
- tar-over-SSH sync: двунаправленная синхронизация (full/path/isolated режимы)
- IP-пул слотов: `MICRO_VM_NET_SUBNET=172.16.0.0/26`, до 31 concurrent сессий
- Совместимость с `--pii-proxy`, `--router`, `--pii-proxy --router` (цепочка на host)
- OS matrix: Ubuntu 22+, Debian 10+, ALT Linux 10+, WSL2 (nested virt)

**Ключевые файлы:**
- `lib/sandbox/microvm.sh` — `start_microvm()`: slot alloc, FC spawn, SSH poll, tar sync
- `lib/sandbox/install.sh` — `install_microvm()`: Firecracker v1.11, vmlinux, rootfs, nvm.img
- `lib/sandbox/guest-init.sh` — guest PID 1: монтирует блочные устройства, стартует sshd
- `lib/launcher/launch.sh` — tar-sync exclusions (исключает secrets из синхронизации)

**Полная документация:** [docs/MICROVM.md](MICROVM.md) · [Architecture diagram](architecture/diagrams/data-flow-microvm-launch.md)

### История: v1 (virtiofs, не смержено в master)

v1 была прототипом с virtiofs-монтированием и host-side claude. Реализация v1 **не была
смержена в master** — ветка была переработана напрямую в v2 (virtio-blk + full in-guest).

### Security note

В v2 kernel isolation полная: claude process и все его subprocess выполняются внутри
guest VM с отдельным Linux ядром. Prompt injection → kernel exploit затрагивает только
guest kernel — host kernel защищён KVM boundary. Это максимально доступный уровень
защиты от AI-directed arbitrary code execution.

See `docs/SANDBOX_ANALYSIS.md` for the complete threat model.
