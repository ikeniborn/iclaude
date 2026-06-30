---
review:
  spec_hash: 07190e7ba060f69c
  last_run: 2026-07-01
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: INFO
      section: "§7"
      section_hash: ab014600e53bbe38
      fragment: "expected and handled by the user-review gate below."
      text: "Dangling forward reference: §7 'Self-nudge' cited a 'user-review gate below', but no such gate/section followed (§8 is Success criteria, §9 Out of scope). The reader could not resolve it."
      fix: "Drop the trailing clause 'and handled by the user-review gate below', or replace it with a concrete pointer."
      verdict: fixed
      verdict_at: 2026-07-01
chain:
  intent: null
---
# Design: `check-chain` — unified IDD→SDD chain validator

**Date:** 2026-07-01
**Topic:** `check-chain-skill`
**Status:** draft
**Scope:** replace the four slash commands `commands/check-{intent,spec,plan,result}.md` with a single skill `skills/check-chain/SKILL.md`, and consolidate the two hooks `idd-gate.py` + `idd-nudge.py` into a single `hooks/chain-gate.py` (re-wiring `settings.json`).

## 1. Problem

The IDD→SDD chain is validated by four separate slash commands — `/check-intent`,
`/check-spec`, `/check-plan`, `/check-result`. About 80% of each command file is
**identical boilerplate**: the canonical hashing pipeline, the quick-exit by
frontmatter state, scope resolution, `review:` state initialisation, the
finding-handling loop, `<topic>` determination, the chain HTML report, and the
`docs/TODO.md` upsert. Only the per-stage phase checklists differ. This
duplication means every cross-cutting change (e.g. the reports sub-directory
layout, the HTML inline/path convention) has to be applied four times and can
drift between copies.

There is also no single entry point to validate the **whole chain** end to end —
the user must invoke four commands in sequence and remember the order.

The gate side has the same problem: two hooks — `idd-gate.py` (PreToolUse, blocks an
invalid chain transition) and `idd-nudge.py` (PostToolUse, suggests the validator after
an artifact is written) — duplicate their path rules, the `body_hash` pipeline,
frontmatter parsing, the `BLOCK_ON` severity set, and the "is this artifact validated"
predicate.

## 2. Goals / Non-goals

**Goals**
- One source of truth for the shared validator boilerplate.
- Two run modes from one skill: validate the **whole chain** in one invocation, or
  validate a **single stage**.
- One chain-gate hook: merge `idd-gate.py` (PreToolUse block) and `idd-nudge.py`
  (PostToolUse nudge) into a single `hooks/chain-gate.py` that branches on the hook
  event, with the shared helpers written once.
- Preserve every external contract byte-for-byte so the chain-gate hook, the HTML
  chain report, and `docs/TODO.md` keep working.

**Non-goals**
- Changing the phase checklists, severities, or the hashing algorithm.
- Changing the gating / nudge *decisions* — the predicates, severities, candidate
  selection, session ownership, fail-open behaviour, and recency window are preserved
  exactly; only the two hook files are merged into one and the remediation strings
  become `/check-chain <stage>`.
- Rewriting historical artifacts under `docs/superpowers/{intents,specs,plans,reports}/`.

## 3. Architecture

A single skill file `skills/check-chain/SKILL.md` holds:

1. **Shared core** — written once, applied by every stage.
2. **Stage profiles** — the only per-stage difference (directory, glob, hash key,
   state block, phase set + closed checklist).
3. **Two run modes** — whole-chain (sequential gate) and single-stage.

The four command files are deleted. The skill is invoked as `/check-chain`.

### 3.1 Invocation & argument parsing

```
/check-chain                       → whole chain (sequential gate)
/check-chain <stage>               → that stage only       (stage ∈ intent|spec|plan|result)
/check-chain <stage> <path>        → that stage, explicit file
/check-chain <path>                → infer stage from the file's directory, single-stage
```

`$ARGUMENTS` parsing:
- First token equal to one of `intent|spec|plan|result` → the target stage.
- A token that is a path → the explicit artifact file.
- No stage and no path → whole-chain mode.
- A lone path with no stage → resolve the stage from the path's directory
  (`intents/`→intent, `specs/`→spec, `plans/`→plan; `result` is never inferred from a
  path because it shares `plans/` with `plan` — it must be named explicitly).

This keeps backward compatibility with the old per-command `$ARGUMENTS` (a bare path),
and gives the check-runner subagent a deterministic call form `/check-chain <stage> <path>`.

### 3.2 Shared core (single source of truth)

Carried over once, identical to the current commands:

- **Canonical hashing** — body hash `awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16`; section hash per `##`/`###` heading; whole-file hash when frontmatter is absent. Run via the Bash tool, never "in your head".
- **Step 0 — quick exit** by frontmatter: body hash matches the stored stage hash AND every phase `passed` AND no `CRITICAL` finding with `verdict: open` → `OK (cached, hash match)`.
- **Scope resolution** — locate the stage artifact by explicit path, by `<topic>`, or the most-recently-modified file in the stage directory.
- **State init** — scaffold the `review:` block when absent; recompute section hashes; reset any finding whose `section_hash` changed to `verdict: open`; update the stage hash + `last_run`; maintain the `chain:` block (downstream stages only).
- **Finding-handling loop** — monotonic `F-NNN` ids; dedupe by `section + text + section_hash`; verdict request (CRITICAL mandatory `accepted|wontfix|fixed`, WARNING desirable, INFO optional); phase passes only when it has no open CRITICAL; phases run strictly sequentially.
- **`<topic>` determination** — basename minus `.md`, strip the `^YYYY-MM-DD-` date prefix, strip a trailing `-intent`/`-design`/`-plan` suffix if present; fallback to the bare basename. The shared chain key all stages converge on.
- **HTML report** — invoke the `html-report` skill, `mode: chain`, `tab: <stage>`, output `docs/superpowers/reports/<topic>-results.html` (one file, four tabs; the called stage updates only its own tab, preserving the others; data passed inline; Russian text).
- **`docs/TODO.md` upsert** — one row per `<topic>`; lifecycle per the Task Log convention in `CLAUDE.md`.
- **Rules / Prohibited** — closed checklists (no extending); never invent requirements absent from the source; never edit the artifact body (frontmatter only); every finding carries a textual anchor.

### 3.3 Stage profiles (the only per-stage difference)

| stage | dir | glob | hash key | state block | phases | upstream |
|---|---|---|---|---|---|---|
| `intent` | `intents/` | `*-intent.md` | `intent_hash` | `review` | structure, completeness, clarity, consistency, **alignment** (advisory) | — (chain root) |
| `spec` | `specs/` | `*-design.md` | `spec_hash` | `review` | structure, coverage, clarity, consistency | intent |
| `plan` | `plans/` | `*.md` | `plan_hash` | `review` | structure, coverage, dependencies, verifiability, consistency | spec (+ intent) |
| `result` | `plans/` | `*.md` | `plan_hash` | **`result_check`** | non-phased: `git diff` reconciliation (DONE / PARTIAL / MISSING / EXCESS) | intent + spec + plan |

Each stage's **closed checklist is preserved verbatim** from its current command file
(`commands/check-{intent,spec,plan,result}.md` at the time of implementation). The
implementation carries these checklists over unchanged — this design does not alter
their content. Stage specifics that must survive:

- `intent` writes no `chain:` block (it is the root) and its report footer points
  forward (`Next step: superpowers:brainstorming`). The `alignment` phase is advisory:
  it never emits CRITICAL, never gates a phase transition or the final verdict, and is
  not recomputed on a hash-match quick-exit. Its template requires all 7 sections,
  the steering/hard constraint binding, the four autonomy zones, etc.
- `spec` writes `chain.intent`; `plan` writes `chain.intent` + `chain.spec`.
- `result` is structurally different: it reconciles the plan steps against `git diff`
  (`git diff HEAD`, or `git diff <ref>` with `--since=<ref>`), classifies each step
  DONE / PARTIAL / MISSING / EXCESS, checks intent Desired Outcomes and spec
  Success Criteria coverage, and stamps `result_check: { verdict, plan_hash, last_run }`
  into the **plan** frontmatter (never `review:`, never the plan body). Severity:
  CRITICAL = a step entirely absent from the diff; WARNING = partial / excess; INFO =
  semantic discrepancy.

### 3.4 Chain-gate hook (`hooks/chain-gate.py`)

`idd-gate.py` (PreToolUse on `Skill|Write|Edit|MultiEdit`, blocks an invalid transition
with exit 2) and `idd-nudge.py` (PostToolUse on `Write`, suggests the validator via
`additionalContext`) duplicate their path rules, the `body_hash` pipeline, frontmatter
parsing, `BLOCK_ON`, and the "is this artifact validated" predicate. They are merged into
one module `hooks/chain-gate.py`:

- **One set of shared helpers**, written once: the artifact RULES (dir, glob, state
  block, hash key, `fix` command), `body_hash`, frontmatter parsing, the validation
  predicate (a `gate_reason(path, rule)` that returns `None` when the gate is open — i.e.
  the artifact is validated — else a reason string; the nudge's "validated" is simply
  `gate_reason(...) is None`), the session-ownership ledger, candidate resolution, and
  the recency window.
- **`main()` branches on `hook_event_name`** from the payload:
  - `PreToolUse` → the gate: record ownership, then block (exit 2) on a `Skill` chain
    transition or a `Write`/`Edit` write-trigger when the relevant upstream artifact is
    not validated. Decisions identical to today's `idd-gate.py`.
  - `PostToolUse` → the nudge: on a `Write` that produced an intent / spec / plan
    artifact not yet validated for its current body, emit the `additionalContext`
    suggestion (exit 0). Identical to today's `idd-nudge.py` (still does **not** nudge
    `result` — it needs a diff + a plan path and runs at branch finish).
- **Fail-open** preserved on both paths (any internal error → exit 0; the gate must never
  break a real tool call).
- Every `fix` string lives in the single RULES table and reads `/check-chain <stage>`.

`settings.json` is re-wired so both the PreToolUse (`Skill|Write|Edit|MultiEdit`) and the
PostToolUse (`Write`) entries call `chain-gate.py`; `idd-gate.py` and `idd-nudge.py` are
deleted.

## 4. Run modes

### 4.1 Whole-chain mode — sequential gate

1. Resolve `<topic>` from the argument or the most-recently-modified artifact, then
   locate every existing stage file for that topic.
2. Confirm the resolved set once: «Проверю chain `<topic>`: intent=…, spec=…, plan=…. Верно?»
3. For each stage in order `[intent, spec, plan, result]`:
   - **artifact absent** → record it (`Intent: n/a` etc.) and continue;
   - **quick-exit passes** → `✓ cached`, continue immediately;
   - otherwise → run the stage's full interactive validation (findings → verdicts →
     frontmatter → HTML tab → TODO cell);
   - **stage ends `needs_work`** (an open CRITICAL remains) → **STOP**: report «chain
     остановлен на `<stage>`, почини и перезапусти». Downstream stages are not run.
4. **`result`** needs a `git diff`. If reached with an empty diff → emit an INFO
   («result pending implementation»), set the chain verdict to «OK up to plan», and
   leave the TODO `Result` cell `–` (the chain is **not** marked `done`). With a
   non-empty diff → reconcile; on verdict OK close the TODO row.
5. Print the chain summary and the path to the HTML report.

### 4.2 Single-stage mode

Run step 3 above for exactly one stage. This reproduces the behaviour of the
corresponding deleted command 1:1 (same confirmation, findings, verdicts, frontmatter
writes, HTML tab, TODO cell, footer).

## 5. Preserved contracts

- **`review:` frontmatter** — keys `intent_hash` / `spec_hash` / `plan_hash`,
  `phases.<name>.status`, `findings[].{severity,verdict,...}`. Read by `chain-gate.py`
  on both paths (the PreToolUse review gate and the PostToolUse nudge predicate).
- **`result_check:` frontmatter** — `verdict` + `plan_hash`. Read by `chain-gate.py`
  (PreToolUse `finishing-a-development-branch` gate).
- **Body hash pipeline** — identical between the skill and the hook, so gate/nudge hash
  comparisons match.
- **HTML chain report** — `docs/superpowers/reports/<topic>-results.html`, four tabs.
- **`docs/TODO.md`** — one row per `<topic>`.
- **Gating logic** — `check-chain` is not a gate-map key, so invoking it is never gated;
  frontmatter edits under `docs/superpowers/` pass the write-trigger path via its final
  `exit 0`, exactly as the current commands' edits do.

## 6. Migration / change-set

| File | Action |
|---|---|
| `skills/check-chain/SKILL.md` | **create** — shared core + 4 stage profiles + 2 run modes + arg parsing |
| `.nvm-isolated/.claude-isolated/hooks/chain-gate.py` | **create** — merged gate + nudge: shared helpers once, `main()` branches on `hook_event_name` (PreToolUse block / PostToolUse nudge); RULES `fix` strings → `/check-chain <stage>` |
| `.nvm-isolated/.claude-isolated/hooks/idd-gate.py` | **delete** (logic folded into `chain-gate.py`) |
| `.nvm-isolated/.claude-isolated/hooks/idd-nudge.py` | **delete** (logic folded into `chain-gate.py`) |
| `.nvm-isolated/.claude-isolated/settings.json` | edit — point the PreToolUse (`Skill|Write|Edit|MultiEdit`) and PostToolUse (`Write`) hook entries at `chain-gate.py` |
| `.nvm-isolated/.claude-isolated/commands/check-intent.md` | **delete** |
| `.nvm-isolated/.claude-isolated/commands/check-spec.md` | **delete** |
| `.nvm-isolated/.claude-isolated/commands/check-plan.md` | **delete** |
| `.nvm-isolated/.claude-isolated/commands/check-result.md` | **delete** |
| `.nvm-isolated/.claude-isolated/CLAUDE.md` | sync the Task Log prose (lines ~42, 49–51, 53) that names `/check-intent` etc. to `/check-chain <stage>` — this is the **global** instructions file |

The gate/nudge *decisions* do not change — the predicates, candidate selection, session
ownership, recency window, fail-open, and the PostToolUse `result` exclusion all carry
over verbatim into `chain-gate.py`. Only the two files collapse into one and the
remediation strings become `/check-chain <stage>`.

## 7. Edge cases / decisions

- **Missing upstream** (spec without intent): the chain proceeds; the missing stage is
  `n/a` in TODO — matches the existing «spec opens the chain» behaviour.
- **`result` with an empty diff** in whole-chain mode is **not** a failure (INFO, chain
  not marked `done`). Rationale: a pre-implementation whole-chain run would otherwise
  always fail at `result`.
- **Backward compatibility**: a bare path argument still works (single-stage, stage
  inferred from the directory).
- **Self-nudge**: writing this spec triggers the PostToolUse nudge to suggest validating
  it — expected; the spec is validated via the check-runner before the plan is written.

## 8. Success criteria

1. `/check-chain intent|spec|plan|result <path>` reproduces the current per-command
   behaviour (same findings, verdicts, frontmatter writes, HTML tab, TODO cell, footer).
2. `/check-chain` with no argument walks intent→spec→plan→result, skips cached-passed
   stages instantly, and stops at the first stage that needs work.
3. `grep -rn '/check-intent\|/check-spec\|/check-plan\|/check-result'` over the **live**
   config (`hooks/`, `commands/`, `skills/`, `CLAUDE.md`) returns nothing — every live
   reference now points at `/check-chain <stage>`.
4. `chain-gate.py` parses, handles **both** events — PreToolUse (block, exit 2) and
   PostToolUse (nudge, exit 0) — on the same predicates as the two old hooks, and its
   block / nudge messages name `/check-chain <stage>`.
5. The four `commands/check-*.md` files are gone; no skill, hook, or agent references them.
6. Historical artifacts under `docs/superpowers/{intents,specs,plans,reports}/` are
   untouched.
7. `idd-gate.py` and `idd-nudge.py` are gone; `settings.json` points both hook events at
   `chain-gate.py`; the gate still blocks an unvalidated transition and the nudge still
   fires after an unvalidated artifact write (verifiable by feeding each hook a crafted
   payload on stdin and checking the exit code / stdout).

## 9. Out of scope

- Rewriting historical chain documents (they record past runs verbatim).
- Any change to the phase checklists, severities, hashing, or the gate / nudge
  *decisions* (predicates, candidate selection, ownership, recency window, fail-open) —
  these carry over verbatim; only the two hook files merge into one.
