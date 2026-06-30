---
chain:
  intent: null
review:
  spec_hash: f13fca9147a8661a
  last_run: 2026-06-30
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings: []
---

# Stable iwiki engine entrypoint: canonical `IWIKI_ENGINE_DIR`

**Date:** 2026-06-30
**Status:** approved (design)
**Scope:** `plugin/iwiki/skills/*`, `lib/iwiki/`, the config chokepoint in `lib/config/env-map.sh` + `iclaude.sh`, the iwiki page under `docs/wiki/`, and `tests/`.

## Problem

When a skill invokes the iwiki engine, the model frequently fails to run it and
burns turns on a dead end. Observed failure (real transcript):

```
Bash(... command -v iwiki_engine; which iwiki_engine ...)  → not found
Bash(iwiki_engine --help ...)                              → command not found
```

The model concluded "iwiki_engine не в PATH", misidentified the host project,
and started spelunking the source tree instead of running the engine.

Root cause is **not** the environment — `uv` is present, every cached engine has
a synced `.venv` + `uv.lock`, and `CLAUDE_CONFIG_DIR` / `UV_BIN` / `IWIKI_LLM_*`
are all exported into the Bash tool. The root cause is the skills' UX:

- `iwiki_engine` is a **Python module**, run via
  `uv run --project <engine-dir> python3 -m iwiki_engine <cmd>`. It is **never** a
  binary on `PATH`. Nothing tells the model this up front.
- The run recipe and its engine-resolution chain are buried inside step 4 of each
  `SKILL.md` ("Build the index"). A model that wants to "verify the engine first"
  never reaches step 4 — it probes `command -v iwiki_engine` and gives up.
- The top-of-skill prose ("the engine ships with this plugin
  (`${CLAUDE_PLUGIN_ROOT}/engine`)") reads like there is an `engine` executable,
  reinforcing the wrong instinct.
- There is no single canonical entrypoint. The 4 skills each duplicate a 4-line
  resolution chain whose branch 2 (`plugin/iwiki/engine`) only exists inside the
  iclaude repo, and whose branch 3 depends on `CLAUDE_CONFIG_DIR` being set in the
  Bash tool — fragile and easy to get wrong.

## Goal

A single, robust, project-agnostic way to invoke the engine that the model cannot
misread, plus an install step that pre-syncs the engine, validates the required
parameters, and reports problems loudly instead of at first skill use.

## Design

### A. Launcher exports a canonical `IWIKI_ENGINE_DIR` (auto-resolved every launch)

Add a resolver to `lib/iwiki/detect.sh`, e.g. `iwiki_export_engine_dir()`, that
sets and exports `IWIKI_ENGINE_DIR` to the first path that exists and contains a
`pyproject.toml`:

1. `${SCRIPT_DIR}/plugin/iwiki/engine` — the in-repo engine. The launcher is
   always the iclaude install, so `SCRIPT_DIR` is the iclaude repo regardless of
   which project the user is working in; `install_iwiki` always `uv sync`s this
   dir. This makes it the most stable, always-fresh target.
2. else newest `${CLAUDE_CONFIG_DIR}/plugins/cache/*/iwiki/*/engine`
   (`ls -d ... | sort -V | tail -1`).

Reuse the existing `_iwiki_engine_dir` helper for branch 1. Call the exporter from
inside `source_iclaude_config` in `lib/config/env-map.sh` — the single config
chokepoint, invoked at launch and idempotently re-applied, so every call site
(load_credentials / configure) gets `IWIKI_ENGINE_DIR` for free. This is a plain
`export` of a **computed** value, not an `ICLAUDE_*` de-prefix, so it must NOT go
through the `${!ICLAUDE_@}` sweep in `apply_iclaude_env_map`; it is a separate call
after `apply_iclaude_env_map` returns.

Result: `IWIKI_ENGINE_DIR` is present in the Bash tool environment on every
launch, in every project, always pointing at a synced engine, version-agnostic
(no stale path baked into `.claude_config`).

### B. One canonical invocation block at the top of all 4 skills

In `plugin/iwiki/skills/{iwiki-init,iwiki-ingest,iwiki-query,iwiki-lint}/SKILL.md`,
add an **"Engine invocation"** block before the numbered steps that:

- States plainly: the engine is a **Python module, not a `PATH` binary** — never
  run `command -v iwiki_engine` or `iwiki_engine --help`.
- Gives the one canonical command, `IWIKI_ENGINE_DIR` first, the existing chain as
  fallback, and a **fail-loud** exit when nothing resolves:

```bash
ENG="${IWIKI_ENGINE_DIR:-}"
[ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
[ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
[ -f "$ENG/pyproject.toml" ] || { echo "iwiki: engine not found — run ./iclaude.sh --install-iwiki" >&2; exit 1; }
UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki <cmd>
```

- Fix the top-of-skill prose to drop the "`${CLAUDE_PLUGIN_ROOT}/engine`" wording
  that implies a binary, and point at the new block instead.
- The buried step-4 resolution snippet becomes a reference to the top block (no
  duplicated chain within the same file). `--wiki-dir docs/wiki` is relative and
  resolves against the project root (the caller's CWD), as today.

### C. Install hardening (correct parameters + preflight)

In `lib/iwiki/install.sh`, `install_iwiki()` after `uv sync`:

- Run a smoke test: `"$uv" run --project "$dir" python3 -m iwiki_engine status`.
  If the engine prints `HALT:` (missing `IWIKI_LLM_*` or unreachable backend),
  surface it loudly — the engine imports but is not yet usable.
- Replace the single generic "Configure ICLAUDE_IWIKI_LLM_* ..." line with a
  per-variable warning for each of `ICLAUDE_IWIKI_LLM_BASE_URL`,
  `ICLAUDE_IWIKI_LLM_KEY`, `ICLAUDE_IWIKI_EMBED_MODEL` that is unset.
- Call the resolver from (A) and print the final `IWIKI_ENGINE_DIR` so the user
  sees which engine the skills will use.

All of this is non-fatal (install still completes) but visible.

### D. Verification / tests

- `lib/iwiki/detect.sh` resolver: returns the in-repo dir in this repo; returns
  the newest cached dir when the in-repo path is temporarily hidden. Shell test
  under `tests/`.
- Skill smoke: from a scratch dir with no `plugin/iwiki/engine`, the canonical
  block resolves via the cache glob and `... status` runs.
- Install smoke: with `IWIKI_LLM_*` unset, the install smoke test surfaces
  `HALT:` and the per-variable warnings fire.
- Regression: `command -v iwiki_engine` / `iwiki_engine --help` are not
  instructed anywhere — `grep -rn 'command -v iwiki_engine\|iwiki_engine --help' plugin/iwiki/skills`
  returns nothing.

### E. Docs (iwiki keep-current)

Update the iwiki page under `docs/wiki/` to record: the engine is a module
(not a `PATH` binary), `IWIKI_ENGINE_DIR` is the canonical entrypoint exported at
launch, and the resolution order (in-repo → newest cached). Then run
`iwiki:iwiki-ingest` on the changed source and `/iwiki-lint`.

## Files changed

- `lib/iwiki/detect.sh` — add `iwiki_export_engine_dir()` (reuse `_iwiki_engine_dir`).
- `lib/config/env-map.sh` — call the exporter inside `source_iclaude_config` (the
  config chokepoint) so `IWIKI_ENGINE_DIR` is set on every launch.
- `lib/iwiki/install.sh` — post-sync smoke test, per-variable warnings, print the
  resolved `IWIKI_ENGINE_DIR`.
- `plugin/iwiki/skills/iwiki-init/SKILL.md`
- `plugin/iwiki/skills/iwiki-ingest/SKILL.md`
- `plugin/iwiki/skills/iwiki-query/SKILL.md`
- `plugin/iwiki/skills/iwiki-lint/SKILL.md` — add the top "Engine invocation"
  block, fix prose, de-duplicate the in-step chain.
- `docs/wiki/iwiki.md` — record the canonical entrypoint.
- `tests/` — resolver + skill-smoke + install-smoke checks.

## Explicitly NOT touched

- The engine package itself (`plugin/iwiki/engine/iwiki_engine/*`) — no CLI
  surface change; the subcommands (`index | search | related | status | lint |
  validate`) stay as-is.
- No new `PATH` shim / launcher binary (rejected in favor of `IWIKI_ENGINE_DIR`).
- No static `ICLAUDE_IWIKI_ENGINE_DIR` written to `.claude_config` (rejected in
  favor of auto-resolve; would go stale on plugin update).
- The `ICLAUDE_*` → canonical de-prefix mechanism in `apply_iclaude_env_map` — the
  new export is a separate computed value, the sweep is unchanged.
- No unrelated refactor of the skills or installer.

## Out of scope

- Reworking how `IWIKI_LLM_*` parameters are sourced — install only validates and
  reports them; it does not change the config schema.
- The Stop-hook nag / content-hash freshness logic (separate, already shipped).

## Workflow note

Branch `dev-iwiki-engine-entrypoint`, based on `dev`, PR into `dev`. No worktree
(working in place). Per the iwiki keep-current rule, regenerate the affected
`docs/wiki/` page and lint before the work is reported done.
