---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-verifier-microvm-design.md
review:
  spec_hash: 15b9355fe75ce029
  last_run: 2026-07-02
  runner: "clean-context subagent (check-runner protocol)"
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings:
    - { id: F-001, phase: structure, severity: WARNING, verdict: fixed, note: "§10 cited nonexistent '§5.2' → '§5 step 2 (Provision)'" }
    - { id: F-002, phase: clarity, severity: INFO, verdict: fixed, note: "snapshot content pinned: tracked staged+unstaged, untracked excluded (§5.1 + §8)" }
    - { id: F-003, phase: consistency, severity: INFO, verdict: fixed, note: "opus-vs-parent-§5.3-sonnet drift made explicit ('superseded by spec 2 §7')" }
  verdict: OK
---
# loen backlog step 3 — verifier microVM isolation — Design Spec

- **Topic:** `loen-verifier-microvm`
- **Date:** 2026-07-02
- **Status:** design draft — defaults chosen during brainstorming (user AFK on the option
  poll; every default is explicitly overridable at spec review / plan time)
- **Parent spec:** `docs/superpowers/specs/2026-07-01-loen-loop-engineering-plugin-design.md` §15
  ("microVM hard FS-isolation for verifier — optional hardening, noted, not default")
- **Source infra:** `docs/functions/MICROVM.md` (Firecracker v2: per-session rootfs +
  shared nvm.img + per-session workspace.img; guest user `iclaude`; SSH exec from host;
  KVM required), `docs/SANDBOX_ANALYSIS.md` (threat model)
- **Scope:** loen backlog step 3 only — an OPT-IN hardening mode that runs the loen
  `verifier` inside an iclaude Firecracker microVM against a disposable snapshot of the
  work tree. Default dispatch (in-session subagent) stays unchanged. Backlog steps 2 and 4
  are separate specs.

---

## 1. Summary

Backlog step 3 adds an OPT-IN `verifier_isolation: microvm` mode to the loen contract:
when enabled, `loen:audit check` runs the verifier as a headless Claude Code session
inside an iclaude Firecracker microVM against a disposable snapshot of the tree, making
the judge read-only by construction instead of by convention. One new orchestration
script, one new contract key, isolation-aware audit dispatch — everything else (agent
bodies, artifact layout, hook, default behavior) stays exactly as shipped.

## 2. Threat model and goal

The MVP verifier is "read-only" by convention: its agent body says "you edit nothing",
its tool list has Bash. Convention is not a guarantee — a prompt-injected repo (test
fixture, README, gate output) can steer the verifier's Bash into mutating the tree or
exfiltrating beyond it, and the verifier judges exactly the diff most likely to carry
injected content. Goal: make verifier read-only **by construction** — its entire
execution (LLM turns + every Bash command it runs) happens inside a guest VM that holds
only a disposable copy of the tree, so no host mutation is possible regardless of what
the verifier is tricked into running. This is methodology-aligned hardening for the
"worker ≠ judge" boundary: the judge cannot touch the worker's tree at all.

## 3. Design decision (default, overridable)

**Whole verifier as a headless Claude Code run inside the microVM** — chosen over:

- (a) *gates-only in VM* (verifier subagent stays in-session, only its commands SSH-exec
  into the guest): cheaper, but the LLM judge itself keeps host Bash — the injection
  surface this step exists to close stays open;
- (b) *lightweight RO sandbox (bwrap/RO-bind, no VM)*: minimal cost but no kernel
  isolation — contradicts the step's premise and iclaude already ships the stronger
  primitive.

Cost acknowledged: VM boot + snapshot provisioning adds seconds-to-tens-of-seconds per
check iteration; that is why the mode is opt-in per contract, not the default.

## 4. Contract and dispatch changes

- **`loop.yaml` gains optional key `verifier_isolation`** (string): `subagent` (default,
  MVP behavior) | `microvm`. Template gets the key with a trailing comment (NOT commented
  out — template must keep parsing; same rule as `eval_command` in spec 2).
- **`loen:audit check` dispatch becomes isolation-aware.** It reads `verifier_isolation`
  from the active contract:
  - `subagent` → exactly today's path (dispatch the `verifier` subagent).
  - `microvm` → run the **isolated verify flow** (§5) instead of the subagent; the
    returned text is written to `iterations/iter-NN/verifier.md` unchanged, so every
    downstream consumer (stages, report, PR summary) is agnostic to where the verdict
    was produced.
- **`loen:audit plan`** (all modes): `verifier_isolation`, when present, MUST be
  `subagent` or `microvm`; `microvm` on a host without KVM/Firecracker (per the
  MICROVM.md requirements table) → plan verdict `needs_work` with the explicit hint to
  either install microVM support or drop to `subagent`. No silent downgrade at plan time.

## 5. Isolated verify flow (new script `plugin/loen/scripts/verify_microvm.sh`)

Deterministic orchestration, one entry point invoked by `loen:audit check`:

1. **Snapshot.** Build a disposable tree copy: `git archive HEAD` of the repo plus the
   tracked staged+unstaged changes applied on top (untracked files are EXCLUDED), plus
   the current run's `docs/loen/<run-id>/` artifacts (`loop.yaml`,
   `iterations/iter-NN/{diff.patch,gates.log}` — the evidence the verifier judges).
   Nothing else from the host is included; secrets outside the repo never enter the
   snapshot.
2. **Provision.** Start (or reuse, if iclaude exposes a warm slot) a microVM session via
   the existing `iclaude.sh` microVM entry points; transfer the snapshot into the guest
   `/workspace` over the session's SSH channel (the same host→guest exec/copy mechanism
   MICROVM.md documents; the exact iclaude.sh flag/function set is resolved by the
   explorer at plan time — this spec fixes the contract, not the flag names).
3. **Verify headless.** Inside the guest, run Claude Code in print mode with the
   verifier's instructions: the prompt is built from `agents/verifier.md` body plus the
   mode-specific checklist that `audit/SKILL.md` already carries (spec 2 §5.5) plus the
   snapshot-relative paths. The guest session has no host credentials beyond what the
   iclaude microVM baseline provides.
4. **Collect.** Capture the guest run's final text; host writes it to
   `iterations/iter-NN/verifier.md`. Exit code of `verify_microvm.sh` = 0 iff a verdict
   line (`VERDICT: APPROVE|REJECT`) was produced; the verdict content itself is judged by
   the audit stage exactly as today.
5. **Teardown.** Destroy the VM workspace (per-session images are disposable by design);
   the snapshot never syncs back — **there is no channel by which the isolated verifier
   can mutate the host tree**, which is the guarantee this step ships.
- **Research-mode note:** the spec-2 requirement that the verifier re-runs `eval_command`
  for `keep` decisions works unchanged inside the guest — the eval script and dataset are
  part of the snapshot, `LOEN_METRICS_PATH` points into the guest's throwaway workspace.
- **Failure handling:** VM boot/provision/exec failure → `verify_microvm.sh` exits
  non-zero; `loen:audit check` reports `needs_work` with the failure log and does NOT
  silently fall back to the in-session subagent (a silent downgrade would fake the
  guarantee the contract asked for). The human may edit the contract to `subagent` to
  proceed un-isolated.

## 6. What does NOT change

- `agents/verifier.md` body and model stay as shipped (opus per spec 2 §7, which
  superseded the parent spec §5.3 roster's sonnet) — the same instructions run in either
  dispatch mode.
- Artifact layout: no new canonical paths (`verifier.md` lands exactly where it always
  did); the loop-guard hook and `check_layout.sh` are untouched.
- Default behavior: contracts without `verifier_isolation` behave byte-for-byte as MVP.

## 7. Delivery model

- Same plugin `plugin/loen/`; **minor version bump** in both manifests (exact number
  resolved at implementation time — steps 2–4 have no fixed merge order; sync enforced by
  `check-plugin-version-sync.sh`).
- New file: `scripts/verify_microvm.sh`. Modified: `skills/audit/SKILL.md` (isolation-
  aware dispatch + plan check), `skills/loop-delivery/assets/loop.template.yaml`
  (+`verifier_isolation` key). Zero new hard dependencies for users who never enable the
  mode; the mode itself requires the iclaude microVM install (KVM, Firecracker, images)
  exactly as MICROVM.md documents.

## 8. Testing

- **`tests/test_loen_verify_microvm.sh` (new):**
  - unit (no KVM needed): snapshot builder produces a tree containing HEAD + tracked
    staged+unstaged changes + the run's artifacts (untracked files absent) and nothing
    outside the repo; missing prerequisites (no KVM / no
    firecracker binary) → script exits non-zero with the "install or drop to subagent"
    message; contract with `verifier_isolation: bogus` → plan-check helper rejects.
  - integration (auto-SKIP when `/dev/kvm` absent — repo convention for microVM suites):
    end-to-end verify of a toy run inside a real guest; asserts `verifier.md` written and
    host tree hash unchanged before/after.
- `tests/test_loen_templates.sh` — template parses with `verifier_isolation` present.
- `tests/test_loen_plugin.sh` — version sync after the bump.

## 9. Process obligations (per CLAUDE.md, at implementation time)

- `docs/functions/LOEN.md` (contract table + a hardening subsection) and
  `docs/functions/MICROVM.md` (a "loen verifier" use-case pointer), `plugin/loen/README.md`,
  root `README.md` (RU), iwiki `iclaude/loen-plugin` (Components, loop.yaml contract,
  Roadmap) — updated in the same increment; `docs/TODO.md` row `loen-verifier-microvm`
  driven by `/check-chain`.

## 10. Out of scope

- Making microVM the default verifier dispatch (cost profile forbids it).
- Isolating the `planner`/`explorer` subagents (read-only tool lists, no Bash — the
  attack surface this step closes is verifier-specific).
- Network egress policy inside the guest beyond the iclaude microVM baseline.
- Warm-pool/VM-reuse optimizations — allowed by the §5 step 2 (Provision) "or reuse"
  wording but not required.

## 11. Resolved decisions log

1. Isolation unit: **whole verifier as headless CC in the guest** (default chosen with
   user AFK; gates-only and bwrap alternatives recorded in §3 and reversible at review).
2. Opt-in via `loop.yaml` `verifier_isolation: subagent|microvm`, default `subagent`;
   plan stage validates the key and host capability (§4).
3. Snapshot semantics: HEAD + working diff + current run artifacts; no sync-back channel;
   disposable guest workspace (§5).
4. No silent fallback on VM failure — explicit `needs_work`, human decides (§5).
5. Verifier agent body/model unchanged; downstream artifact contract unchanged (§6).
6. Integration tests SKIP without KVM, unit tests always run (§8).
