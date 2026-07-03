---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-03-loen-prompt-quality-design.md
review:
  plan_hash: 9b9324b712668607
  last_run: 2026-07-03
  runner: "main-session (check-runner protocol)"
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - { id: F-001, phase: coverage, severity: INFO, verdict: wontfix, note: "Task 3 version bump + PR are release-hygiene steps beyond the spec text; included per repo convention (prior loen chains did the same)" }
  verdict: OK
---

# loen Prompt Quality — Surgical Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the form of `plugin/loen`'s six skill prompts toward the functional superpowers skills (short trigger descriptions + Red Flags self-checks), plus one approved behavior addition (test-first in `loop-delivery`).

**Architecture:** Prompt-text edits under `plugin/loen/skills/`. Four change classes: (A) recalibrate all six `description` fields to short trigger-led form; (B) add an additive `## Red Flags — STOP` section to the three discipline loop skills, each bullet restating a rule already in that skill's body (including a VBC evidence-before-done bullet); (C) replace one nuance clause in `loop-autoresearch`; (D) add a test-first sentence to `loop-delivery`'s Act step — the single deliberate behavior change. No sub-agents/scripts/hooks/READMEs touched.

**Tech Stack:** Markdown + YAML front-matter. Verification via `grep`, YAML parse, and `tests/test_loen_plugin.sh`.

## Global Constraints

- Every `description` starts with `Use when`; concise (≤ 35 whitespace tokens, ~half the 40–60-token originals; em-dashes count as tokens); sibling loops named as anti-triggers; no workflow enumeration.
- Every Red-Flags bullet maps to a rule in the same skill's body — an existing rule (A/B/C) or, for `loop-delivery`'s first bullet, Change D's new Act-step rule.
- **Change D is the ONE approved behavior change** (test-first mandate in `loop-delivery`'s Act step). Everywhere else only `description:` fields, additive `## Red Flags — STOP` sections, and the single F5 clause change — no other existing rule line altered.
- **loen stays self-contained** — Change D encodes test-first in loen's own words; do NOT add a cross-plugin dependency on `superpowers:test-driven-development`.
- Front-matter valid YAML, under 1024 chars.
- `tests/test_loen_plugin.sh` PASS after every task that touches a skill file.
- Branch: `dev-loen-prompt-hardening` (worktree `wk-dev-loen-prompt-hardening`); PR target `dev`. Never commit to `dev`/`master` directly.

---

## File Structure

- `plugin/loen/skills/loop-delivery/SKILL.md` — description (L3) + Act-step test-first sentence (Step 5, Change D) + append `## Red Flags — STOP`
- `plugin/loen/skills/loop-repair/SKILL.md` — description (L3) + append `## Red Flags — STOP`
- `plugin/loen/skills/loop-autoresearch/SKILL.md` — description (L3) + F5 clause (L99) + append `## Red Flags — STOP`
- `plugin/loen/skills/audit/SKILL.md` — description (L3) only
- `plugin/loen/skills/governance/SKILL.md` — description (L3) only
- `plugin/loen/skills/loop-goal/SKILL.md` — description (L3) only
- `plugin/loen/.claude-plugin/plugin.json` — patch version bump (L4)
- `.claude-plugin/marketplace.json` — patch version bump for loen (L18), keep synced

Not touched: `## Steps` of skills other than `loop-delivery`'s Act step; `plugin/loen/agents/*`; `plugin/loen/scripts/*`; `plugin/loen/hooks/*`; `plugin/loen/README*.md`; root `README.md`; `docs/functions/LOEN.md` (none quote the skill descriptions).

---

## Task 1: Change A — recalibrate the six descriptions

**Files:**
- Modify: `plugin/loen/skills/loop-delivery/SKILL.md:3`, `plugin/loen/skills/loop-repair/SKILL.md:3`, `plugin/loen/skills/loop-autoresearch/SKILL.md:3`, `plugin/loen/skills/audit/SKILL.md:3`, `plugin/loen/skills/governance/SKILL.md:3`, `plugin/loen/skills/loop-goal/SKILL.md:3`

- [ ] **Step 1: Replace each `description:` line (Edit, exact string swap)**

`loop-delivery/SKILL.md` — replace:
```
description: Execute one delivery task as a controlled loop — plan, act (smallest diff), check (gates + independent verifier), report — writing all artifacts under docs/loen/<run-id>/. Independent of the IDD→SDD chain; works in any repo.
```
with:
```
description: Use when delivering ONE bounded change — a feature, refactor, or chore — as a controlled, audited loop in any repo. Not for a failing test (use loop-repair) or a numeric metric (use loop-autoresearch).
```

`loop-repair/SKILL.md` — replace:
```
description: Fix one failing test / CI job / regression as a controlled loop — reproduce first, isolate, minimal fix, regression test — reusing the loen loop machinery; artifacts under docs/loen/<run-id>/.
```
with:
```
description: Use when a specific test, CI job, or regression is failing and must be fixed under a reproduce-first controlled loop with proven regression coverage. Not for open-ended work (use loop-delivery) or metrics (use loop-autoresearch).
```

`loop-autoresearch/SKILL.md` — replace:
```
description: Improve one numeric metric as a controlled research loop — baseline, hypothesis, one bounded change, fixed eval, compare, keep/revert — logging every experiment as JSONL events; reuses the loen loop machinery.
```
with:
```
description: Use when improving ONE numeric metric under a controlled research loop with a fixed eval and kept/reverted experiments. Not for a feature (use loop-delivery) or a failing test (use loop-repair).
```

`audit/SKILL.md` — replace:
```
description: Validate a loen loop stage (plan|act|check|result), gate progression, and regenerate the human-readable docs/loen/<run-id>/report.html via the html-report skill. Mode-aware — extra checks for repair and research contracts. Mirrors check-chain for the execution loop.
```
with:
```
description: Use when a loen loop stage — plan, act, check, or result — must be validated and gated before the next one. Mode-aware for delivery/repair/research; the execution-loop analog of check-chain.
```

`governance/SKILL.md` — replace:
```
description: Cross-run governance over docs/loen/ — run the deterministic loen_stats.py aggregator (offline, stdlib-only, no LLM) and render the docs/loen/governance.html dashboard via the html-report skill. --triage additionally turns failing runs into proposed next actions for the human — proposals only, never launches loops, never edits runs.
```
with:
```
description: Use when you need a cross-run dashboard over all docs/loen/ runs, or --triage to turn failing runs into proposed next actions (proposals only; never launches loops or edits runs).
```

`loop-goal/SKILL.md` — replace:
```
description: OPTIONAL accelerator — wrap the active, human-approved loen run in Claude's native /goal condition (generated deterministically from loop.yaml by scripts/make_goal.py), plus a session-scoped /loop polling recipe for long-running gates. Validates run state, briefs the evidence-first /goal mechanics, never bootstraps a run, never submits /goal itself.
```
with:
```
description: Use when an active, human-approved loen run should keep going multi-turn on its own — wraps it in Claude's native /goal from loop.yaml. Optional; never bootstraps a run or submits /goal itself.
```

- [ ] **Step 2: Verify each description starts with `Use when` and is 22–30 words**

Run:
```bash
cd plugin/loen/skills
for s in loop-delivery loop-repair loop-autoresearch audit governance loop-goal; do
  line=$(grep -m1 '^description:' $s/SKILL.md)
  wc=$(echo "$line" | sed 's/^description: //' | wc -w)
  echo "$s: words=$wc | ${line:0:22}"
done
```
Expected: every line prints `| description: Use when` and `words=` ≤ 35 (well under the original 40–60).

- [ ] **Step 3: Verify front-matter parses as YAML and is < 1024 chars**

Run:
```bash
cd plugin/loen/skills
for s in loop-delivery loop-repair loop-autoresearch audit governance loop-goal; do
  python3 -c "import yaml; fm=open('$s/SKILL.md').read().split('---')[1]; d=yaml.safe_load(fm); assert d['description'].startswith('Use when'); assert len(fm)<1024; print('$s OK', len(fm))"
done
```
Expected: six `… OK <n>` lines, every `<n>` < 1024, no assertion error.

- [ ] **Step 4: Run the plugin frontmatter lint**

Run:
```bash
bash tests/test_loen_plugin.sh
```
Expected: `PASS test_loen_plugin.sh`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/skills/*/SKILL.md
git commit -m "feat(loen): recalibrate skill descriptions to short trigger form"
```

---

## Task 2: Change D + B + C — test-first in loop-delivery, Red Flags on the three loops, F5

**Files:**
- Modify: `plugin/loen/skills/loop-delivery/SKILL.md` (Act-step insertion in Step 5 + append `## Red Flags — STOP`)
- Modify: `plugin/loen/skills/loop-repair/SKILL.md` (append `## Red Flags — STOP`)
- Modify: `plugin/loen/skills/loop-autoresearch/SKILL.md` (F5 clause at L99 + append `## Red Flags — STOP`)

- [ ] **Step 1: Change D — insert the test-first sentence into `loop-delivery`'s Act step**

In `loop-delivery/SKILL.md`, Step 5 currently reads (first sentence): `Make the smallest diff toward the objective. Stay in `mutable_scope` (the hook blocks otherwise).` Replace:
```
Make the smallest diff toward the objective. Stay in `mutable_scope` (the hook blocks otherwise).
```
with:
```
Make the smallest diff toward the objective. When the change adds or alters behavior, work test-first: add a failing test that pins the objective, confirm it fails for the right reason, then write the smallest code that makes it pass. A pure refactor keeps the existing tests green; config/chore work with no behavioral surface is exempt. Stay in `mutable_scope` (the hook blocks otherwise).
```

- [ ] **Step 2: Append the Red Flags block to `loop-delivery/SKILL.md`**

The file ends with the `## Stop conditions` list; its last line is `  hard stop, ask the human. Never auto-merge.`. Append AFTER it (blank line, then the section — the first bullet is the Change D test-first self-check, the fifth is the VBC evidence-before-done bullet):
```markdown

## Red Flags — STOP

- Writing production code for a behavior change before a failing test exists → delete it; restart test-first.
- Editing a `protected_scope` path → stop; the scope IS the contract.
- Weakening or skipping a `quality_gate` to go green → never; fix the code.
- Editing the diff you are verifying, or rubber-stamping your own work → the verifier is independent.
- Reporting the task done without green gates AND a verifier APPROVE for the final iteration → not done; re-run, don't claim.
- Auto-merging, or proceeding past a `handoff_conditions` trigger (schema / PII / license / architecture / prod-creds) → hard stop, ask the human.
- Continuing past `budget` → stop; report the best result and the blocker.
```

- [ ] **Step 3: Append the Red Flags block to `loop-repair/SKILL.md`**

The file ends with the paragraph whose last line is `hook allows them, no audit stage requires or reads them.`. Append AFTER it (blank line, then the section — the fifth bullet is the VBC evidence bullet):
```markdown

## Red Flags — STOP

- "Fixing" a failure you have not reproduced → stop; no reproduction, no fix.
- A non-test hunk not required for the failing command to pass → out of scope, drop it.
- Changing tests beyond ADDING the regression test → not allowed.
- Claiming regression coverage without logged inversion evidence (stash → FAIL → pop → PASS) → not proven.
- Reporting the failure fixed without the originally-failing command exiting 0 in the final `gates.log` → not fixed.
- Auto-merge, or past a `handoff_conditions` trigger, or past `budget.max_iterations` → hard stop.
```

- [ ] **Step 4: Edit `loop-autoresearch/SKILL.md` — F5 clause (L99) then append Red Flags**

4a. Replace the F5 line:
```
- Keep seed, model version, eval command, and dataset fixed when possible.
```
with:
```
- Keep seed, model version, eval command, and dataset fixed across experiments; if any must change, log the deviation in the experiment record.
```

4b. The file ends (under `## Error handling`) with the line `- Any `handoff_conditions` trigger → hard stop, ask the human. Never auto-merge.`. Append AFTER it (blank line, then the section — the fifth bullet is the VBC evidence bullet):
```markdown

## Red Flags — STOP

- Improving the metric by weakening validation, eval data, or the eval script → never (unless eval design IS the objective).
- More than one main variable changed in an experiment → not isolatable; one variable per experiment.
- Hand-editing `metrics.jsonl` / `experiments.jsonl` → never; append via `log_experiment.py`.
- Treating a tie on the primary as progress → a tie is not an improvement; revert.
- Keeping a change on a claimed metric delta the verifier did not re-confirm → not kept.
- Two consecutive eval failures, or past `budget.max_experiments`, or a `handoff_conditions` trigger → stop.
```

- [ ] **Step 5: Verify each Red-Flags bullet traces to a source rule (no un-grounded rule except Change D)**

Run:
```bash
cd plugin/loen/skills
echo "-- loop-delivery Act step mentions test-first (Change D source for bullet 1):"; grep -n 'test-first' loop-delivery/SKILL.md
for s in loop-delivery loop-repair loop-autoresearch; do
  echo "=== $s Red Flags bullets ==="; awk '/^## Red Flags/{f=1;next} f&&/^## /{f=0} f&&/^- /{print}' $s/SKILL.md
  echo "-- pre-existing rule keywords in body:"; grep -nE "protected_scope|quality_gate|Never edit|verifier|handoff_conditions|budget|reproduce|regression|inversion|gates.log exit|exits 0|max_iterations|max_experiments|one main variable|log_experiment|weakening validation|tie|RE-RUNS|APPROVE" $s/SKILL.md | grep -v '## Red Flags' | head -20
done
```
Expected: `loop-delivery` prints two `test-first` hits (Act step + Red-Flags bullet 1); every other bullet's subject appears as a pre-existing keyword in the same file (delivery bullets 2–7 → protected_scope/quality_gate/verifier/APPROVE/handoff/budget; repair → reproduce/regression/inversion/exits 0/handoff/max_iterations; autoresearch → weakening validation/one variable/log_experiment/tie/RE-RUNS/max_experiments).

- [ ] **Step 6: Verify the diff changed only the sanctioned lines**

Run:
```bash
git diff --unified=0 plugin/loen/skills/loop-delivery/SKILL.md plugin/loen/skills/loop-repair/SKILL.md plugin/loen/skills/loop-autoresearch/SKILL.md | grep '^[-][^-]'
```
Expected: exactly ONE removal line — the loop-autoresearch F5 line `- Keep seed … fixed when possible.`. The loop-delivery Act-step change is an in-place sentence insertion (its `-`/`+` pair is the only altered existing line, permitted as Change D). No other `-` line — every Red-Flags block is a pure addition.

- [ ] **Step 7: Run the plugin frontmatter lint**

Run:
```bash
bash tests/test_loen_plugin.sh
```
Expected: `PASS test_loen_plugin.sh`.

- [ ] **Step 8: Commit**

```bash
git add plugin/loen/skills/loop-delivery/SKILL.md plugin/loen/skills/loop-repair/SKILL.md plugin/loen/skills/loop-autoresearch/SKILL.md
git commit -m "feat(loen): Red Flags self-checks + test-first Act mandate (Change D) + F5 fix"
```

---

## Task 3: Version bump, full verification sweep, PR prep

**Files:**
- Modify: `plugin/loen/.claude-plugin/plugin.json:4`
- Modify: `.claude-plugin/marketplace.json:18`

- [ ] **Step 1: Patch-bump the plugin version**

In `plugin/loen/.claude-plugin/plugin.json` replace `"version": "0.5.0"` with `"version": "0.5.1"`.
In `.claude-plugin/marketplace.json`, the loen entry (block with `"name": "loen"`) replace its `"version": "0.5.0"` with `"version": "0.5.1"`.

- [ ] **Step 2: Verify version sync**

Run:
```bash
bash scripts/check-plugin-version-sync.sh
```
Expected: exit 0, no mismatch for loen (both manifests now 0.5.1).

- [ ] **Step 3: Full loen suite regression**

Run:
```bash
bash tests/test_loen_plugin.sh && bash tests/test_loen_templates.sh && bash tests/test_loen_guard.sh
```
Expected: each ends with its `PASS …` line.

- [ ] **Step 4: Confirm no doc drift (descriptions are not quoted anywhere)**

Run:
```bash
grep -rn "Execute one delivery task\|Fix one failing test / CI job\|Improve one numeric metric as a controlled\|Validate a loen loop stage\|Cross-run governance over\|OPTIONAL accelerator — wrap" docs/ plugin/loen/README.md plugin/loen/README.ru.md README.md || echo "NO stale quotes — no doc sync needed"
```
Expected: `NO stale quotes — no doc sync needed`. If any hit appears, update that line to the new description in the same task.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(loen): bump plugin to 0.5.1 (prompt-quality hardening)"
```

- [ ] **Step 6: iwiki + PR (human-facing, run last)**

```bash
git log --oneline dev..HEAD
```
Then: if the iwiki MCP server reports a loen domain bound to this project (`wiki_status`), check whether any wiki page quotes the old descriptions or documents `loop-delivery`'s method; update only where the text is now stale (Change D adds test-first to the delivery method — a wiki "Components/Method" page, if present, should reflect it). Open the PR into `dev` with `gh` (title `feat(loen): prompt hardening — trigger descriptions, Red Flags, test-first Act`, body summarizing Changes A/B/C/D and noting D is the one approved behavior change). Then run `/check-chain result` to reconcile the diff against this plan.

---

## Self-Review

**1. Spec coverage:**
- Change A (6 short descriptions) → Task 1. ✓
- Change B (Red Flags + VBC evidence bullets on 3 loop skills) → Task 2 Steps 2–4. ✓
- Change C (F5 clause) → Task 2 Step 4a. ✓
- Change D (test-first in loop-delivery Act step) → Task 2 Step 1 (Act sentence) + Step 2 (Red-Flags bullet 1). ✓
- Invariant "each bullet traces to a source rule (D for delivery bullet 1)" → Task 2 Step 5. ✓
- Invariant "only Change D alters an existing behavior line" → Task 2 Step 6 (diff check). ✓
- Invariant "loen self-contained, no superpowers:TDD dep" → Change D text is loen-native (no cross-ref); confirmed by Task 2 Step 1 wording.
- Invariant "YAML < 1024, Use when" → Task 1 Steps 2–3. ✓
- Verification `test_loen_plugin.sh` → Task 1 Step 4, Task 2 Step 7, Task 3 Step 3. ✓
- No spec requirement left without a task.

**2. Placeholder scan:** No `TBD`/`TODO`/"handle edge cases"/"similar to Task N". Every edit shows exact before/after; every verify shows the command + expected output.

**3. Type consistency:** N/A (no code types). Description, Red-Flags, and Change-D strings are identical between this plan and the spec (verbatim). Version `0.5.1` used consistently in Task 3 Steps 1–2.
