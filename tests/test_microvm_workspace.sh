#!/bin/bash
# Integration test: три режима workspace isolation для microVM
# Запускает реальный Firecracker VM, тестирует full/path/isolated sync.
# Требует: /dev/kvm, firecracker binary, rootfs.ext4, nvm.img, vmlinux.
# Usage: bash tests/test_microvm_workspace.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_DIR"

PASS=0; FAIL=0
_pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
_fail() { echo "  ✗ FAIL: $1"; FAIL=$((FAIL+1)); }
_section() { echo ""; echo "── $1 ──────────────────────────────────────────────────────"; }

ISOLATED_CONFIG_DIR="${PROJECT_DIR}/.nvm-isolated/.claude-isolated"
SSH_KEY="${ISOLATED_CONFIG_DIR}/ssh/microvm"
HOST_KEY_PUB="${ISOLATED_CONFIG_DIR}/ssh/microvm_host_key.pub"
FC_BIN="${ISOLATED_CONFIG_DIR}/bin/firecracker"
WORK_DIR="/tmp/iclaude-test-$$"
FC_SOCK="${WORK_DIR}/fc.sock"
FC_LOG="${WORK_DIR}/firecracker.log"
MICRO_VM_PID=""
MICRO_VM_SLOT=""

# Load slot allocation functions from microvm.sh
print_info()    { :; }
print_success() { :; }
print_warning() { :; }
print_error()   { :; }
# init_environment uses SCRIPT_DIR to derive paths; override after to keep PROJECT_DIR as base
SCRIPT_DIR="$PROJECT_DIR"
source "${PROJECT_DIR}/lib/core/init.sh"
init_environment
# Re-pin to project root (init_environment may resolve to tests/ subdir when called from tests/)
ISOLATED_NVM_DIR="${PROJECT_DIR}/.nvm-isolated"
ISOLATED_CONFIG_DIR="${PROJECT_DIR}/.nvm-isolated/.claude-isolated"
export ISOLATED_NVM_DIR ISOLATED_CONFIG_DIR
# Load user config to pick up MICRO_VM_NET_SUBNET and other overrides
[[ -f "${PROJECT_DIR}/.claude_config" ]] && source "${PROJECT_DIR}/.claude_config" 2>/dev/null || true
source "${PROJECT_DIR}/lib/sandbox/microvm.sh"

cleanup() {
    [[ -n "$MICRO_VM_PID" ]] && {
        kill "$MICRO_VM_PID" 2>/dev/null
        sleep 0.5
        kill -9 "$MICRO_VM_PID" 2>/dev/null || true
    }
    _free_microvm_slot 2>/dev/null || true
    rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

ssh_exec() {
    local kh_opts=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null")
    [[ -f "${WORK_DIR}/known_hosts" ]] && \
        kh_opts=("-o" "StrictHostKeyChecking=yes" "-o" "UserKnownHostsFile=${WORK_DIR}/known_hosts")
    ssh -T -i "$SSH_KEY" "${kh_opts[@]}" \
        -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR \
        "root@${MICRO_VM_NET_GUEST_IP}" "$@"
}

# ── pre-checks ─────────────────────────────────────────────────────────────────
_section "Pre-flight checks"
[[ -r /dev/kvm ]] && _pass "/dev/kvm доступен" || { _fail "/dev/kvm недоступен"; exit 1; }
[[ -x "$FC_BIN" ]] && _pass "firecracker binary" || { _fail "firecracker не найден"; exit 1; }
[[ -f "$SSH_KEY" ]] && _pass "SSH private key"   || { _fail "SSH ключ отсутствует"; exit 1; }
[[ -f "${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4" ]] && _pass "rootfs.ext4" || { _fail "rootfs нет"; exit 1; }
[[ -f "${ISOLATED_CONFIG_DIR}/bin/nvm.img" ]]     && _pass "nvm.img"     || { _fail "nvm.img нет"; exit 1; }
[[ -f "${ISOLATED_CONFIG_DIR}/bin/vmlinux" ]]     && _pass "vmlinux"     || { _fail "vmlinux нет"; exit 1; }

# ── slot allocation ─────────────────────────────────────────────────────────────
_section "Slot allocation"
if ! _alloc_microvm_slot 2>/dev/null; then
    _fail "Не удалось выделить slot (все заняты?)"; exit 1
fi
_pass "Slot ${MICRO_VM_SLOT} выделен: host=${MICRO_VM_NET_HOST_IP} guest=${MICRO_VM_NET_GUEST_IP} tap=${MICRO_VM_NET_TAP_IFACE}"

# Verify TAP interface exists with correct IP
if ! ip addr show "${MICRO_VM_NET_TAP_IFACE}" 2>/dev/null | grep -q "${MICRO_VM_NET_HOST_IP}"; then
    _fail "TAP ${MICRO_VM_NET_TAP_IFACE} не найден или IP не совпадает (ожидался ${MICRO_VM_NET_HOST_IP})"
    _fail "Запустите: ./iclaude.sh --install-microvm"
    exit 1
fi
_pass "TAP ${MICRO_VM_NET_TAP_IFACE} с IP ${MICRO_VM_NET_HOST_IP} готов"

# ── known_hosts ────────────────────────────────────────────────────────────────
_section "SSH host key pinning"
mkdir -p "$WORK_DIR"
if [[ -f "$HOST_KEY_PUB" ]]; then
    { printf '%s ' "$MICRO_VM_NET_GUEST_IP"; cat "$HOST_KEY_PUB"; } > "${WORK_DIR}/known_hosts"
    chmod 600 "${WORK_DIR}/known_hosts"
    _pass "known_hosts создан (StrictHostKeyChecking=yes)"
else
    _pass "microvm_host_key.pub нет → fallback no-verify"
fi

# ── start VM ───────────────────────────────────────────────────────────────────
_section "Запуск Firecracker VM (slot ${MICRO_VM_SLOT})"

ROOTFS="${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4"
NVM_IMG="${ISOLATED_CONFIG_DIR}/bin/nvm.img"
VMLINUX="${ISOLATED_CONFIG_DIR}/bin/vmlinux"
WORKSPACE_IMG="${WORK_DIR}/workspace.img"

dd if=/dev/zero of="$WORKSPACE_IMG" bs=1M count=0 seek=512 2>/dev/null
mkfs.ext4 -q -F "$WORKSPACE_IMG" 2>/dev/null
_pass "workspace.img создан"

# Per-slot MAC: AA:FC:00:00:00:<slot+1>
_slot_mac=$(printf "AA:FC:00:00:00:%02X" $((MICRO_VM_SLOT + 1)))
BOOT_ARGS="console=ttyS0 reboot=k panic=1 pci=off nomodules ip=${MICRO_VM_NET_GUEST_IP}::${MICRO_VM_NET_HOST_IP}:${MICRO_VM_NET_MASK}::eth0:off init=/usr/sbin/iclaude-guest-init"

cat > "${WORK_DIR}/vmconfig.json" <<EOF
{
  "boot-source": {"kernel_image_path": "${VMLINUX}", "boot_args": "${BOOT_ARGS}"},
  "drives": [
    {"drive_id":"rootfs","path_on_host":"${ROOTFS}","is_root_device":true,"is_read_only":false},
    {"drive_id":"nvm","path_on_host":"${NVM_IMG}","is_root_device":false,"is_read_only":true},
    {"drive_id":"workspace","path_on_host":"${WORKSPACE_IMG}","is_root_device":false,"is_read_only":false}
  ],
  "machine-config": {"vcpu_count":1,"mem_size_mib":512},
  "network-interfaces": [{"iface_id":"eth0","guest_mac":"${_slot_mac}","host_dev_name":"${MICRO_VM_NET_TAP_IFACE}"}]
}
EOF

rm -f "$FC_SOCK" 2>/dev/null || true
# FC требует чтобы log-файл существовал заранее
touch "$FC_LOG"
"$FC_BIN" --api-sock "$FC_SOCK" --config-file "${WORK_DIR}/vmconfig.json" \
    --log-path "$FC_LOG" --level Info &>/dev/null &
MICRO_VM_PID=$!
MICRO_VM_SLOT="${MICRO_VM_SLOT}"  # ensure var is set for _claim_microvm_slot
_claim_microvm_slot 2>/dev/null

ticks=0
while [[ $ticks -lt 40 ]]; do
    [[ -S "$FC_SOCK" ]] && break
    kill -0 "$MICRO_VM_PID" 2>/dev/null || { _fail "Firecracker упал: $(tail -5 "$FC_LOG" 2>/dev/null)"; exit 1; }
    sleep 0.25; ticks=$((ticks+1))
done
[[ -S "$FC_SOCK" ]] && _pass "Firecracker API socket готов" || { _fail "FC socket timeout"; exit 1; }

ssh_ready=false
for i in $(seq 1 60); do
    ssh_exec 'exit 0' 2>/dev/null && ssh_ready=true && break
    kill -0 "$MICRO_VM_PID" 2>/dev/null || { _fail "Firecracker упал"; exit 1; }
    sleep 0.5
done
[[ "$ssh_ready" == "true" ]] && _pass "Guest SSH готов" || { _fail "SSH timeout (30s)"; tail -10 "$FC_LOG" 2>/dev/null || true; exit 1; }

# ── MODE: isolated ──────────────────────────────────────────────────────────────
_section "Режим: isolated"

ws_count=$(ssh_exec 'find /workspace -mindepth 1 -maxdepth 1 ! -name lost+found 2>/dev/null | wc -l' 2>/dev/null || echo ERR)
[[ "$ws_count" == "0" ]] \
    && _pass "isolated: /workspace пуст" \
    || _fail "isolated: /workspace содержит ${ws_count} файлов, ожидался 0"

ssh_exec 'echo "from-guest-isolated" > /workspace/isolated-marker.txt' 2>/dev/null \
    && _pass "isolated: запись в /workspace работает" \
    || _fail "isolated: запись в /workspace не работает"

[[ ! -f "${PROJECT_DIR}/isolated-marker.txt" ]] \
    && _pass "isolated: файл из guest не попал на хост (sync-back не запускался)" \
    || _fail "isolated: файл из guest оказался на хосте без sync-back!"

# ── MODE: full ──────────────────────────────────────────────────────────────────
_section "Режим: full"

SYNC_EXCLUDES=(
    "--exclude=./.nvm-isolated" "--exclude=./.git"
    "--exclude=./.claude_config" "--exclude=./.claude_proxy_credentials"
    "--exclude=./.iclaude-guest-env.sh" "--exclude=./.iclaude-ssh"
)
FULL_MARKER=".iclaude-test-full-$$"
echo "full-sync-marker-$$" > "${PROJECT_DIR}/${FULL_MARKER}"

ssh_exec 'rm -rf /workspace/* /workspace/.[!.]* 2>/dev/null; true' 2>/dev/null || true

tar -czf - -C "$PROJECT_DIR" "${SYNC_EXCLUDES[@]}" . 2>/dev/null \
    | ssh_exec 'tar -xzf - -C /workspace 2>/dev/null'
_pass "full: host→guest sync выполнен"

ssh_exec "test -f /workspace/${FULL_MARKER}" 2>/dev/null \
    && _pass "full: тестовый файл найден в /workspace" \
    || _fail "full: тестовый файл НЕ найден в /workspace"

ssh_exec 'test ! -f /workspace/.claude_config' 2>/dev/null \
    && _pass "full: .claude_config исключён" \
    || _fail "full: .claude_config ПОПАЛ в guest (нарушение безопасности!)"
ssh_exec 'test ! -d /workspace/.nvm-isolated' 2>/dev/null \
    && _pass "full: .nvm-isolated исключён" \
    || _fail "full: .nvm-isolated ПОПАЛ в guest"
ssh_exec 'test ! -d /workspace/.git' 2>/dev/null \
    && _pass "full: .git исключён" \
    || _fail "full: .git ПОПАЛ в guest"
ssh_exec 'test ! -d /workspace/.iclaude-ssh' 2>/dev/null \
    && _pass "full: .iclaude-ssh исключён" \
    || _fail "full: .iclaude-ssh ПОПАЛ в guest"

SYNCBACK_MARKER=".iclaude-test-syncback-$$"
ssh_exec "echo 'syncback' > /workspace/${SYNCBACK_MARKER}" 2>/dev/null
SYNCBACK_DIR="/tmp/iclaude-syncback-$$"
mkdir -p "$SYNCBACK_DIR"
ssh_exec 'tar -czf - -C /workspace --exclude=./lost+found --exclude=./.iclaude-guest-env.sh . 2>/dev/null' 2>/dev/null \
    | tar -xzf - -C "$SYNCBACK_DIR" 2>/dev/null

[[ -f "${SYNCBACK_DIR}/${SYNCBACK_MARKER}" ]] \
    && _pass "full: файл из guest попал в sync-back" \
    || _fail "full: файл из guest НЕ найден в sync-back"
[[ ! -f "${SYNCBACK_DIR}/.iclaude-guest-env.sh" ]] \
    && _pass "full: .iclaude-guest-env.sh исключён из sync-back" \
    || _fail "full: .iclaude-guest-env.sh ПОПАЛ в sync-back!"

rm -rf "$SYNCBACK_DIR" "${PROJECT_DIR}/${FULL_MARKER}" 2>/dev/null || true

# ── MODE: path ─────────────────────────────────────────────────────────────────
_section "Режим: path"

PATH_DIR="/tmp/iclaude-path-$$"
mkdir -p "${PATH_DIR}/subdir"
echo "path-file-1-$$" > "${PATH_DIR}/file1.txt"
echo "path-file-2-$$" > "${PATH_DIR}/file2.txt"
echo "path-subfile-$$" > "${PATH_DIR}/subdir/sub.txt"

ssh_exec 'rm -rf /workspace/* /workspace/.[!.]* 2>/dev/null; true' 2>/dev/null || true

tar -czf - -C "$PATH_DIR" . 2>/dev/null \
    | ssh_exec 'tar -xzf - -C /workspace 2>/dev/null'
_pass "path: tar sync выполнен"

ssh_exec 'test -f /workspace/file1.txt && test -f /workspace/file2.txt' 2>/dev/null \
    && _pass "path: файлы из PATH_DIR найдены в /workspace" \
    || _fail "path: файлы НЕ найдены в /workspace"
ssh_exec 'test -f /workspace/subdir/sub.txt' 2>/dev/null \
    && _pass "path: поддиректория синхронизирована" \
    || _fail "path: поддиректория НЕ синхронизирована"
ssh_exec 'test ! -f /workspace/README.md' 2>/dev/null \
    && _pass "path: файлы проекта отсутствуют (только PATH_DIR)" \
    || _fail "path: README.md из project root попал в path-mode workspace"

rm -rf "$PATH_DIR" 2>/dev/null || true

# ── block devices ──────────────────────────────────────────────────────────────
_section "Блочные устройства в guest"

ssh_exec 'test -d /mnt/nvm && ls /mnt/nvm 2>/dev/null | grep -q "."' 2>/dev/null \
    && _pass "/mnt/nvm смонтирован (nvm.img → /dev/vdb)" \
    || _fail "/mnt/nvm не смонтирован или пуст"
ssh_exec 'test -d /workspace' 2>/dev/null \
    && _pass "/workspace существует (workspace.img → /dev/vdc)" \
    || _fail "/workspace не существует"
CLAUDE_PATH=$(ssh_exec 'ls /mnt/nvm/npm-global/bin/claude 2>/dev/null || echo ""' 2>/dev/null || echo "")
[[ -n "$CLAUDE_PATH" ]] \
    && _pass "claude binary найден: ${CLAUDE_PATH}" \
    || _fail "claude binary НЕ найден в /mnt/nvm/npm-global/bin/"

# ── summary ────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
printf "  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo "══════════════════════════════════════════════════════"
echo ""
[[ $FAIL -eq 0 ]]
