#!/usr/bin/env bash
# loen isolated verify flow (verifier_isolation: microvm). Runs the loen verifier as a
# headless Claude Code session inside an iclaude Firecracker microVM against a disposable
# snapshot of the tree — the judge is read-only by construction: the guest only ever sees
# a throwaway copy, and MICRO_VM_WORKSPACE_MODE=isolated has no sync-back channel.
#
# Subcommands:
#   preflight [loop.yaml]                       validate verifier_isolation + host capability
#   snapshot  <repo-root> <run-dir> <out-dir>   build the disposable tree snapshot
#   extract   <log-file>                        print the LOEN_VERIFIER_BEGIN/END block
#   check     <run-dir> <iter-NN> [checklist-file]  full isolated verify; writes verifier.md
#
# Exit codes: 0 ok / verdict produced; 1 usage, contract or preflight failure;
#             2 launch or isolation failure (silent host fallback, missing boot marker,
#               missing sentinel block or VERDICT line); 3 host tree changed (tripwire).
#
# Env knobs: LOEN_KVM_DEV (default /dev/kvm), LOEN_ICLAUDE_SH (default $SCRIPT_DIR/iclaude.sh),
#            ISOLATED_CONFIG_DIR (default ./.nvm-isolated/.claude-isolated),
#            LOEN_VERIFY_TIMEOUT (seconds, default 1800), LOEN_VERIFY_KEEP_SNAPSHOT=1 (debug).
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

# Echo the contract's verifier_isolation value ('subagent' when absent/empty).
_read_isolation() {
    local contract="$1" line isolation
    line=$(grep -E '^verifier_isolation:' "$contract" | head -1 || true)
    line="${line%%#*}"
    isolation="${line#verifier_isolation:}"
    isolation="${isolation//[[:space:]]/}"
    isolation="${isolation//\"/}"
    isolation="${isolation//\'/}"
    [[ -z "$isolation" ]] && isolation="subagent"
    printf '%s' "$isolation"
}

# Host capability for microvm mode: KVM + firecracker + images + launcher.
_capability_check() {
    local cfg="${ISOLATED_CONFIG_DIR:-$PWD/.nvm-isolated/.claude-isolated}"
    local kvm="${LOEN_KVM_DEV:-/dev/kvm}"
    local iclaude_sh="${LOEN_ICLAUDE_SH:-${SCRIPT_DIR:-.}/iclaude.sh}"
    local missing=()
    [[ -r "$kvm" ]]                    || missing+=("KVM (${kvm} not readable)")
    [[ -x "${cfg}/bin/firecracker" ]]  || missing+=("firecracker binary (${cfg}/bin/firecracker)")
    [[ -f "${cfg}/bin/vmlinux" ]]      || missing+=("vmlinux kernel image")
    [[ -f "${cfg}/bin/rootfs.ext4" ]]  || missing+=("rootfs.ext4 guest image")
    [[ -f "${cfg}/bin/nvm.img" ]]      || missing+=("nvm.img (Node.js + claude for the guest)")
    [[ -x "$iclaude_sh" ]]             || missing+=("iclaude.sh launcher (${iclaude_sh})")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "verify_microvm: 'verifier_isolation: microvm' is not available on this host:" >&2
        printf '  - missing: %s\n' "${missing[@]}" >&2
        echo "  install microVM support (./iclaude.sh --install-microvm) or drop the contract to 'verifier_isolation: subagent'" >&2
        return 1
    fi
}

# Build the disposable tree copy the guest will judge. Content contract (spec §5.1):
# HEAD + tracked staged+unstaged changes + the run's evidence artifacts; untracked files
# and everything outside the repo are excluded. out_dir must be OUTSIDE any git repo.
_snapshot() {
    local repo="$1" run_dir="$2" out="$3"
    git -C "$repo" rev-parse --show-toplevel >/dev/null 2>&1 || {
        echo "verify_microvm: not a git repo: ${repo}" >&2; return 1; }
    [[ -f "$run_dir/loop.yaml" ]] || {
        echo "verify_microvm: run dir has no loop.yaml: ${run_dir}" >&2; return 1; }
    mkdir -p "$out"

    # 1. Tracked tree at HEAD.
    git -C "$repo" archive --format=tar HEAD | tar -xf - -C "$out"

    # 2. Tracked staged+unstaged changes on top (binary-safe). Untracked excluded.
    local patch
    patch=$(mktemp /tmp/loen-verify-XXXXXX.patch)
    git -C "$repo" diff HEAD --binary --no-color > "$patch"
    if [[ -s "$patch" ]]; then
        git -C "$out" apply --whitespace=nowarn "$patch"
    fi
    rm -f "$patch"

    # 3. The run's evidence artifacts + the current symlink the verifier body expects.
    local run_id iter_dir f dest
    run_id=$(basename "$run_dir")
    dest="$out/docs/loen/$run_id"
    mkdir -p "$dest"
    cp "$run_dir/loop.yaml" "$dest/loop.yaml"
    for iter_dir in "$run_dir"/iterations/iter-[0-9][0-9]; do
        [[ -d "$iter_dir" ]] || continue
        mkdir -p "$dest/iterations/$(basename "$iter_dir")"
        for f in diff.patch gates.log metrics.jsonl; do
            if [[ -f "$iter_dir/$f" ]]; then
                cp "$iter_dir/$f" "$dest/iterations/$(basename "$iter_dir")/$f"
            fi
        done
    done
    if [[ -f "$run_dir/experiments.jsonl" ]]; then
        cp "$run_dir/experiments.jsonl" "$dest/experiments.jsonl"
    fi
    ln -sfn "$run_id" "$out/docs/loen/current"
    echo "verify_microvm: snapshot ready at ${out}"
}

cmd_preflight() {
    local contract="${1:-}" isolation="subagent"
    if [[ -n "$contract" ]]; then
        [[ -f "$contract" ]] || { echo "verify_microvm: contract not found: ${contract}" >&2; return 1; }
        isolation=$(_read_isolation "$contract")
    fi
    case "$isolation" in
        subagent)
            echo "verify_microvm: preflight OK (verifier_isolation: subagent — nothing to check)"
            ;;
        microvm)
            _capability_check || return 1
            echo "verify_microvm: preflight OK (microvm available)"
            ;;
        *)
            echo "verify_microvm: invalid verifier_isolation '${isolation}' — must be 'subagent' or 'microvm'" >&2
            return 1
            ;;
    esac
}

# Print the report between the sentinel lines (markers excluded).
cmd_extract() {
    local log="${1:-}"
    [[ -f "$log" ]] || { echo "verify_microvm: log not found: ${log}" >&2; return 1; }
    awk '/^LOEN_VERIFIER_END$/{f=0} f{print} /^LOEN_VERIFIER_BEGIN$/{f=1}' "$log"
}

case "${1:-}" in
    preflight) shift; cmd_preflight "$@" ;;
    snapshot)  shift; [[ $# -eq 3 ]] || usage; _snapshot "$@" ;;
    extract)   shift; cmd_extract "$@" ;;
    *) usage ;;
esac
