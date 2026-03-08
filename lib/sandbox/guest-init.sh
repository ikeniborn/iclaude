#!/bin/sh
# iclaude guest PID 1 init — Firecracker microVM
# Mounts kernel FSes, virtio-blk block devices, starts SSH, signals readiness.
# Injected into rootfs at /usr/sbin/iclaude-guest-init by _inject_rootfs_guest_init().
#
# Block device layout (virtio-blk order):
#   /dev/vda — rootfs (index 0, is_root_device: true)
#   /dev/vdb — nvm image (index 1, read-only, contains .nvm-isolated)
#   /dev/vdc — workspace image (index 2, read-write, project directory)

log() { echo "[iclaude-init] $*" > /dev/kmsg 2>/dev/null || echo "[iclaude-init] $*"; }
log "Starting..."

# Kernel filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true  # may already be mounted
mkdir -p /dev/pts /dev/shm /run
mount -t devpts devpts /dev/pts 2>/dev/null || true
mount -t tmpfs tmpfs /dev/shm
mount -t tmpfs tmpfs /run

# Loopback
ip link set lo up 2>/dev/null || true

# Mount block devices (virtio-blk, no virtiofs needed)
# /dev/vdb = nvm image (pre-built, contains .nvm-isolated)
# /dev/vdc = workspace image (per-session, populated via SSH rsync by host)
mkdir -p /mnt/nvm /workspace

if [ -b /dev/vdb ]; then
    mount -o ro /dev/vdb /mnt/nvm && log "/mnt/nvm OK (vdb)" || log "WARN: /mnt/nvm mount failed"
else
    log "WARN: /dev/vdb not present — /mnt/nvm will be empty"
fi

if [ -b /dev/vdc ]; then
    mount /dev/vdc /workspace && log "/workspace OK (vdc)" || log "WARN: /workspace mount failed"
else
    log "WARN: /dev/vdc not present — /workspace will be empty"
fi

# Create iclaude user (uid=1000) if not present.
# authorized_keys are pre-seeded in /home/iclaude/.ssh/ by _inject_rootfs_guest_init() at install
# time; useradd -M avoids overwriting the pre-seeded .ssh directory with an empty home skeleton.
if ! id iclaude >/dev/null 2>&1; then
    useradd -M -u 1000 -s /bin/sh -d /home/iclaude iclaude && log "iclaude user created" || log "WARN: useradd failed"
fi

# Ensure /home/iclaude/.ssh ownership is correct (uid/gid 1000) so sshd can read authorized_keys.
chown -R iclaude:iclaude /home/iclaude/.ssh 2>/dev/null || true
chmod 700 /home/iclaude/.ssh 2>/dev/null || true
chmod 600 /home/iclaude/.ssh/authorized_keys 2>/dev/null || true

# Transfer workspace ownership to iclaude so it can receive tar sync and write files.
chown iclaude:iclaude /workspace 2>/dev/null || true
chmod 755 /workspace 2>/dev/null || true

# Source environment written by host before VM start (via workspace block device)
[ -f /workspace/.iclaude-guest-env.sh ] && . /workspace/.iclaude-guest-env.sh && log "env sourced"

# After env is sourced, CLAUDE_CONFIG_DIR points to /workspace/.claude-guest.
# Ensure iclaude owns that directory so Claude Code can read/write its config.
chown -R iclaude:iclaude /workspace/.claude-guest 2>/dev/null || true

# Start OpenSSH daemon (no PAM, pubkey only, iclaude user only).
# PermitRootLogin no — root SSH is disabled; KVM isolation is the security boundary.
# AllowUsers iclaude — only the dedicated non-root user may connect.
mkdir -p /run/sshd
/usr/sbin/sshd \
    -o "UsePAM no" \
    -o "PermitRootLogin no" \
    -o "AllowUsers iclaude" \
    -o "PubkeyAuthentication yes" \
    -o "PasswordAuthentication no" \
    -o "ChallengeResponseAuthentication no" && log "sshd started" || log "ERROR: sshd failed"

# Signal readiness to host (written to workspace block device, polled by start_microvm via SSH)
# Note: host polls SSH connectivity directly (no file-based polling needed for readiness).
log "Guest ready. SSH on 172.16.0.2:22"

# PID 1 must not exit — zombie-reaping loop
while true; do
    wait
    sleep 60
done
