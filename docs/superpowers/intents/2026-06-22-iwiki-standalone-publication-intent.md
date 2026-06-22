# Intent: iwiki standalone decoupling + official-marketplace publication (Phase C)

**Date:** 2026-06-22
**Status:** approved

## Objective

Decouple the iwiki plugin from the iclaude repository and publish it standalone to the
official Anthropic claude-code marketplace. Two drivers carry equal weight: (1) **sharing**
— let other projects and people install iwiki directly from the official marketplace; and
(2) **decoupling** — stop iclaude from bundling the plugin's source, consuming it as an
external dependency instead. Now is the time because Phase A+B
(spec/plan `2026-06-22-iwiki-evaluation-improvements`, PR #54) matured the plugin: it now
has a green engine test suite, robustness hardening, and version 0.6.0 — it is ready to
stand on its own.

## Desired Outcomes

- A standalone iwiki repository (separate from iclaude) builds and runs the engine pytest
  suite green in its own CI.
- In a fresh project with **no iclaude present**, `plugin marketplace add <repo>` +
  `plugin install` works end-to-end: the engine self-bootstraps `uv` and the `/iwiki-*`
  skills/commands function.
- The plugin is accepted in the official Anthropic marketplace (submission PR merged /
  listing live). *(External factor — depends on the maintainers; see Stop Rules.)*
- iclaude no longer bundles iwiki's source; it consumes the published plugin from the
  marketplace.

## Health Metrics

- iwiki continues to work inside iclaude exactly as before (docs/wiki/, `/iwiki-*`, the four
  automation hooks) — no regressions during or after the transition.
- The Phase-B engine pytest suite (27 tests) stays green in the new repo/CI.
- Engine and hook behavior is identical: `search`/`index`/`lint`/`related` and the
  recall/sync/reindex/bootstrap hooks behave exactly as today (no behavioral drift from
  decoupling).
- Existing `iwiki@iclaude` installations keep working, or there is an explicit, documented
  migration path.

## Strategic Context

- Interacts with: iclaude (`lib/iwiki/` install + plugin registration, `plugin/iwiki/`
  source), the Claude Code plugin system, the official Anthropic marketplace
  (maintainers + submission review), `uv`/astral-sh (bootstrap dependency), and end users in
  foreign projects.
- Priority trade-off: **trust**. Correctness above all — do not break iclaude's iwiki,
  produce a clean decoupling, and meet the marketplace bar. Slower-but-reliable beats
  fast-but-fragile.

## Constraints

### Steering (behavioral guidance)
- Follow official Anthropic marketplace conventions (manifest schema, README/LICENSE
  layout, contributor/disclosure expectations) rather than inventing structure.
- Keep the standalone repo's demo/example content generic — not iclaude-specific
  (the existing demo wiki's `[[core]]/[[nvm]]/[[launcher]]` refs are iclaude content).
- Decouple surgically: move/package, do not rewrite. Prefer the smallest change that
  achieves a self-contained plugin.

### Hard (architectural enforcement)
- **Zero dependency on iclaude.** The plugin must operate without any iclaude code
  (`lib/`, `.claude_config`); all configuration comes from environment variables only.
- **Engine behavior unchanged.** Decoupling is packaging-only — no logic changes to the
  engine or hooks (`search`/`index`/`lint`/`related` results identical).
- **Runtime stays `httpx`-only.** No new runtime dependencies; `pytest` remains dev-only.
- **MIT license preserved** and the official marketplace's submission rules satisfied
  (manifest, structure, authoring disclosure).

## Autonomy Zones

- **Full autonomy (reversible, low risk):** drafting the standalone repo's files locally on
  a branch/worktree — `README`, `LICENSE`, marketplace manifest, CI config, `CHANGELOG`,
  packaging scaffolding.
- **Guarded (log + verify):** implementing the self-contained `uv` bootstrap inside the
  plugin and the packaging that makes it installable without iclaude; each step verified
  against the health metrics (engine behavior + 27 tests).
- **Proposal-first (needs approval):** the repo structure/strategy decision
  (new repo vs split-with-history, migration path) and **removing the bundled iwiki source
  from iclaude** to consume it externally.
- **No autonomy (human only):** creating the public GitHub repository, and any
  PR/submission to the official Anthropic marketplace (push-to-public + irreversible
  listing + disclosure).

> These zones OVERRIDE subagent-driven-development's "continuous execution, don't pause"
> default. Any task touching proposal-first / no-go decisions is marked HUMAN CHECKPOINT in
> the plan.

## Stop Rules

- **Halt if:** a decoupling step would change engine/hook behavior, add a runtime
  dependency, or break iclaude's own iwiki usage.
- **Escalate if:** an outward-facing or structural action is reached — creating the public
  repo, submitting to the marketplace, removing the iclaude bundle, or choosing the repo
  structure/strategy.
- **Done when:** (observable) the standalone repo's CI runs the engine suite green; a
  fresh-project install with **no iclaude** has working `/iwiki-*` via a self-bootstrapped
  `uv`; the official-marketplace submission is opened (and, dependent on maintainers,
  accepted); iclaude consumes the external plugin without bundling its source; and iclaude's
  own iwiki plus the 27 tests still pass.
