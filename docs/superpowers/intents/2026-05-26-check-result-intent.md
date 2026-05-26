# Intent: check-result command + IDD→SDD chain navigation

**Date:** 2026-05-26
**Status:** draft

## Objective

No command exists to verify final execution results against the full IDD→SDD chain (intent → spec → plan → git diff). After a plan is executed, there is no way to confirm that what was built matches what was intended. Chain is also broken: check-spec and check-plan do not reference their upstream documents, so passing a single file to check-result requires manual lookup of related docs.

## Desired Outcomes

- `/check-result <plan>` reads the plan, discovers linked intent and spec from plan frontmatter, loads all three, compares against `git diff` — outputs report of what was done, what was missed, what is excess
- `check-plan.md` stores links to both intent and spec in its frontmatter, so `check-result` can resolve full chain from a single plan path
- `check-spec.md` stores link to intent doc in its frontmatter
- Each command's report footer shows "Previous step: `<path>`" so the user can navigate the chain

## Health Metrics

- `check-spec` phase model (structure / coverage / clarity / consistency) unchanged
- `check-plan` phase model (structure / coverage / dependencies / verifiability / consistency) unchanged
- Frontmatter hash logic in both commands unchanged
- `verify.md` fully replaced by `check-result.md` — old code-review behavior discarded

## Strategic Context

- Interacts with: `check-spec.md`, `check-plan.md`, `idd` skill, `brainstorm` skill, executing-plans skill
- Chain: `/idd` → `/brainstorm` → `/check-spec` → `/check-plan` → [execution] → `/check-result`
- Priority trade-off: correctness over speed — report must cite specific findings, not summarize vaguely

## Constraints

### Steering (behavioral guidance)

- `check-result` receives path to plan; all other paths resolved from plan frontmatter — user passes one argument
- If intent or spec path missing from plan frontmatter, fall back to auto-discovery in `docs/superpowers/` by name match
- Report format: CRITICAL / WARNING / INFO severity, same as check-spec/check-plan findings
- Each finding includes: what was in the plan vs what git diff shows, and concrete correction options

### Hard (architectural enforcement)

- `check-result` does NOT run code review (no syntax checks, no security scan) — that remains in `verify.md` which is being repurposed, not kept alongside
- `check-result` reads git diff as source of truth for "what was actually done"
- `check-plan` and `check-spec` frontmatter extensions (adding `intent_path`, `spec_path`) must not break existing phase model or hash logic

## Autonomy Zones

- Full autonomy (reversible, low risk): reading files, computing diffs, generating report text
- Guarded (log + confidence threshold): writing to frontmatter of plan/spec files
- Proposal-first (needs approval): changes to phase model structure in check-spec or check-plan
- No autonomy (human only): marking a finding as `wontfix`

## Stop Rules

- Halt if: plan file not found and auto-discovery fails — report error, ask for explicit path
- Escalate if: intent or spec missing from both frontmatter and auto-discovery — warn user, proceed with available docs
- Done when: report produced with all findings categorized (CRITICAL / WARNING / INFO), each finding has description + plan text + actual diff + correction options
