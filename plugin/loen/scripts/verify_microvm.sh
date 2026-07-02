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

# Fingerprint of the host tree (tracked diff + full status incl. untracked). Any change
# during the isolated verify means isolation was breached or something else wrote to the
# tree mid-run — either way the verdict is not trustworthy.
_tree_fingerprint() {
    local repo="$1"
    {
        git -C "$repo" status --porcelain=v1 --untracked-files=all
        git -C "$repo" diff HEAD --binary --no-color | sha256sum
    } | sha256sum | awk '{print $1}'
}

cmd_check() {
    local run_dir="${1:-}" iter="${2:-}" checklist_file="${3:-}"
    [[ -n "$run_dir" && -n "$iter" ]] || usage
    [[ -f "$run_dir/loop.yaml" ]] || { echo "verify_microvm: no loop.yaml in ${run_dir}" >&2; return 1; }
    [[ -d "$run_dir/iterations/$iter" ]] || { echo "verify_microvm: no iteration dir ${run_dir}/iterations/${iter}" >&2; return 1; }

    # Guard against dispatch bugs: this flow is ONLY for microvm contracts.
    local isolation
    isolation=$(_read_isolation "$run_dir/loop.yaml")
    if [[ "$isolation" != "microvm" ]]; then
        echo "verify_microvm: check called for verifier_isolation '${isolation}' — use the subagent dispatch instead" >&2
        return 1
    fi
    _capability_check || return 1

    local iclaude_sh="${LOEN_ICLAUDE_SH:-${SCRIPT_DIR:-.}/iclaude.sh}"
    local repo_root run_id
    repo_root=$(git rev-parse --show-toplevel)
    run_id=$(basename "$(cd "$run_dir" && pwd)")

    # Tripwire baseline: the host tree must be bit-identical after the isolated run.
    local pre_fp
    pre_fp=$(_tree_fingerprint "$repo_root")

    # Disposable snapshot (under /tmp — outside any repo, required by _snapshot).
    local snap log
    snap=$(mktemp -d /tmp/loen-verify-snap-XXXXXX)
    log="/tmp/loen-verify-$$.log"
    # Keep the log always (audit reports needs_work with it); snapshot is disposable.
    trap '[[ "${LOEN_VERIFY_KEEP_SNAPSHOT:-0}" == "1" ]] || rm -rf "$snap"' RETURN

    _snapshot "$repo_root" "$run_dir" "$snap" >&2

    # The full prompt travels INSIDE the snapshot: the guest shell is dash and printf %q
    # would $'…'-quote a multiline -p argument, which dash mangles. The -p arg stays
    # one line and just points at the file.
    local agent_body
    agent_body=$(awk 'f==2{print} /^---$/{f++}' "${PLUGIN_DIR}/agents/verifier.md")
    local checklist="(no mode-specific checklist provided)"
    if [[ -n "$checklist_file" && -f "$checklist_file" ]]; then
        checklist=$(cat "$checklist_file")
    fi
    cat > "$snap/.loen-verifier-prompt.md" <<PROMPT
You are the loen verifier running in an ISOLATED microVM against a disposable snapshot
of the work tree (cwd = /workspace = repo root). Nothing you do here can reach the real
tree. Follow these instructions exactly:

${agent_body}

Mode-specific checklist:
${checklist}

Inputs (snapshot-relative, cwd = /workspace):
- contract: docs/loen/${run_id}/loop.yaml (also docs/loen/current/loop.yaml)
- iteration under review: docs/loen/${run_id}/iterations/${iter}/ (diff.patch, gates.log)

Print your ENTIRE final report between a line containing exactly LOEN_VERIFIER_BEGIN and
a line containing exactly LOEN_VERIFIER_END. The report MUST contain a line
'VERDICT: APPROVE' or 'VERDICT: REJECT'.
PROMPT

    # Launch headless. Env overrides are set BOTH bare and ICLAUDE_-prefixed because the
    # child sources .claude_config (ICLAUDE_* wins over inherited env for config'd keys).
    # ICLAUDE_SESSION_ID must be unique — it names the FC socket and the session dir the
    # child's stop_microvm will rm -rf.
    local timeout_s="${LOEN_VERIFY_TIMEOUT:-1800}"
    local rc=0
    (
        cd "$repo_root"
        env \
            ICLAUDE_SESSION_ID="loen-verify-$$" \
            MICRO_VM_WORKSPACE_MODE=isolated  ICLAUDE_MICRO_VM_WORKSPACE_MODE=isolated \
            MICRO_VM_WORKSPACE_PATH="$snap"   ICLAUDE_MICRO_VM_WORKSPACE_PATH="$snap" \
            MICRO_VM_SNAPSHOT_ENABLED=false   ICLAUDE_MICRO_VM_SNAPSHOT_ENABLED=false \
            MICRO_VM_SYNC_INTERVAL=0          ICLAUDE_MICRO_VM_SYNC_INTERVAL=0 \
            timeout -k 30 "$timeout_s" \
            "$iclaude_sh" --sandbox-microvm -- \
                --model opus --dangerously-skip-permissions \
                -p "Read the file .loen-verifier-prompt.md in the workspace root and follow its instructions exactly."
    ) </dev/null >"$log" 2>&1 || rc=$?

    # Tripwire 1: iclaude.sh silently downgrades to a HOST launch when microVM is
    # unavailable (lib/launcher/launch.sh) — that verdict would be un-isolated. Refuse.
    if grep -q "Continuing without microVM isolation" "$log"; then
        echo "verify_microvm: launcher fell back to a HOST run — verdict refused (log: ${log})" >&2
        return 2
    fi
    # Tripwire 2: require positive evidence the VM actually booted.
    if ! grep -qE "microVM: (Firecracker started|resumed from snapshot)" "$log"; then
        echo "verify_microvm: no evidence the microVM started (exit ${rc}; log: ${log})" >&2
        return 2
    fi
    # Tripwire 3: host tree must be unchanged (checked BEFORE writing verifier.md).
    local post_fp
    post_fp=$(_tree_fingerprint "$repo_root")
    if [[ "$pre_fp" != "$post_fp" ]]; then
        echo "verify_microvm: HOST TREE CHANGED during isolated verify — verdict refused (log: ${log})" >&2
        return 3
    fi

    local report
    report=$(cmd_extract "$log")
    if [[ -z "$report" ]]; then
        echo "verify_microvm: no LOEN_VERIFIER_BEGIN/END block in output (exit ${rc}; log: ${log})" >&2
        return 2
    fi
    if ! grep -qE '^VERDICT: (APPROVE|REJECT)$' <<<"$report"; then
        echo "verify_microvm: report has no VERDICT line (log: ${log})" >&2
        return 2
    fi

    printf '%s\n' "$report" > "$run_dir/iterations/$iter/verifier.md"
    echo "verify_microvm: verdict written to ${run_dir}/iterations/${iter}/verifier.md (log: ${log})"
}

case "${1:-}" in
    preflight) shift; cmd_preflight "$@" ;;
    snapshot)  shift; [[ $# -eq 3 ]] || usage; _snapshot "$@" ;;
    extract)   shift; cmd_extract "$@" ;;
    check)     shift; cmd_check "$@" ;;
    *) usage ;;
esac
