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

# Source environment written by host before VM start (via workspace block device)
[ -f /workspace/.iclaude-guest-env.sh ] && . /workspace/.iclaude-guest-env.sh && log "env sourced"

# SSH authorized_keys from workspace (dynamic per-session, written by start_microvm)
if [ -f /workspace/.iclaude-ssh/authorized_keys ]; then
    mkdir -p /root/.ssh
    cp /workspace/.iclaude-ssh/authorized_keys /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    log "SSH authorized_keys installed"
fi

# Start OpenSSH daemon (no PAM, pubkey only)
mkdir -p /run/sshd
/usr/sbin/sshd \
    -o "UsePAM no" \
    -o "PermitRootLogin yes" \
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
