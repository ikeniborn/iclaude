---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-30-iwiki-engine-entrypoint-design.md
review:
  plan_hash: 8931665f8544a760
  spec_hash: 1efb6dc46e3e1509
  last_run: 2026-06-30
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
---

# iwiki Engine Entrypoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every iwiki skill invoke the engine reliably by exporting a canonical `IWIKI_ENGINE_DIR` at launch, giving each skill one fail-loud invocation recipe, and hardening install with a health + parameter preflight.

**Architecture:** A new shell resolver in `lib/iwiki/detect.sh` computes the engine project dir (in-repo → newest cached) and exports `IWIKI_ENGINE_DIR`; the single config chokepoint (`source_iclaude_config` in `lib/config/env-map.sh`) calls it on every launch so the variable is present in the Bash tool environment in any project. The four `SKILL.md` files gain a top "Engine invocation" block that reads `IWIKI_ENGINE_DIR` (with the existing fallback chain) and tells the model the engine is a Python module, never a `PATH` binary. `install_iwiki` runs a post-sync `status` health check and a `Config.load()` parameter probe with per-variable warnings.

**Tech Stack:** Bash (lib + skills shell snippets), Python 3.12 engine (`uv run -m iwiki_engine`), Markdown skills/docs, shell test harness under `tests/`.

## Global Constraints

- Documentation, code comments, and commit messages: **English**.
- Commit messages: Conventional Commits, ending with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Branch `dev-iwiki-engine-entrypoint`, based on `dev`; PR target `dev`. No worktree.
- The engine package (`plugin/iwiki/engine/iwiki_engine/*`) and its CLI surface (`index | search | related | status | lint | validate`) are **not** modified.
- All new install checks are **non-fatal**: install still completes; checks only warn.
- Skill page structure rule is unchanged: wiki pages use `##`-only sections, `# Title` + first `## Overview`.
- No new `PATH` shim and no static `ICLAUDE_IWIKI_ENGINE_DIR` in `.claude_config` (rejected in the spec).
- Engine facts (verified): `status` / `lint` / `validate` do NOT call `Config.load()` and never `HALT:`. `Config.load()` raises `ConfigError` (process exit 2) when `IWIKI_LLM_BASE_URL` or `IWIKI_LLM_KEY` is empty/unset; `IWIKI_EMBED_MODEL` defaults to `text-embedding-3-small`.

---

## File Structure

- `lib/iwiki/detect.sh` — add `iwiki_export_engine_dir()` (reuses `_iwiki_engine_dir`). Responsibility: single source of truth for resolving + exporting the engine dir.
- `lib/config/env-map.sh` — call `iwiki_export_engine_dir` from `source_iclaude_config` so the export happens on every launch, config file present or not.
- `lib/iwiki/install.sh` — add `_iwiki_postsync_check()` (health + param probe + per-var warnings + print resolved dir); call it from `install_iwiki`; drop the generic "Configure ICLAUDE_IWIKI_LLM_*" one-liner.
- `plugin/iwiki/skills/iwiki-init/SKILL.md`, `plugin/iwiki/skills/iwiki-ingest/SKILL.md`, `plugin/iwiki/skills/iwiki-query/SKILL.md`, `plugin/iwiki/skills/iwiki-lint/SKILL.md` — add the top "Engine invocation" block, fix the binary-implying prose, point step bodies at `$ENG` / `$UV`.
- `docs/wiki/iwiki.md` — document the canonical entrypoint + resolution order.
- `tests/test_iwiki_engine_entrypoint.sh` — new shell test: resolver, env-map wiring, install preflight, skill regression.

---

## Task 1: Engine-dir resolver + env-map wiring

**Files:**
- Modify: `lib/iwiki/detect.sh` (add `iwiki_export_engine_dir` after `_iwiki_engine_dir`)
- Modify: `lib/config/env-map.sh` (`source_iclaude_config`)
- Test: `tests/test_iwiki_engine_entrypoint.sh` (create)

**Interfaces:**
- Consumes: `_iwiki_engine_dir()` (existing, echoes `${SCRIPT_DIR}/plugin/iwiki/engine`); env vars `SCRIPT_DIR`, `CLAUDE_CONFIG_DIR`.
- Produces: `iwiki_export_engine_dir()` — sets and `export`s `IWIKI_ENGINE_DIR` to the first dir containing `pyproject.toml` (in-repo, then newest cached); no-op if neither exists. Reused by Task 2.

- [ ] **Step 1: Write the failing test**

Create `tests/test_iwiki_engine_entrypoint.sh`:

```bash
#!/bin/bash
# Tests for the iwiki engine entrypoint: IWIKI_ENGINE_DIR resolver, env-map
# wiring, install preflight, and skill regression. No bats — plain asserts.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails+1)); }
assert_eq() { [[ "$2" == "$3" ]] && pass "$1" || fail "$1 (got '$2', want '$3')"; }
assert_contains() { case "$2" in *"$3"*) pass "$1";; *) fail "$1 (missing '$3')";; esac; }
assert_not_contains() { case "$2" in *"$3"*) fail "$1 (found '$3')";; *) pass "$1";; esac; }

# ---- Task 1: resolver ----
make_engine() { mkdir -p "$1"; printf '[project]\nname="x"\n' > "$1/pyproject.toml"; }

test_resolver_prefers_in_repo() {
    local t; t="$(mktemp -d)"
    make_engine "$t/plugin/iwiki/engine"
    ( set -e
      SCRIPT_DIR="$t"; CLAUDE_CONFIG_DIR="$t/nope"
      source "$REPO/lib/iwiki/detect.sh"
      unset IWIKI_ENGINE_DIR
      iwiki_export_engine_dir
      [[ "$IWIKI_ENGINE_DIR" == "$t/plugin/iwiki/engine" ]] )
    assert_eq "resolver prefers in-repo engine" "$?" "0"
    rm -rf "$t"
}

test_resolver_falls_back_to_newest_cache() {
    local t; t="$(mktemp -d)"
    make_engine "$t/cfg/plugins/cache/iclaude/iwiki/0.6.3/engine"
    make_engine "$t/cfg/plugins/cache/iclaude/iwiki/0.6.4/engine"
    local got
    got="$(
      SCRIPT_DIR="$t/no-repo"; CLAUDE_CONFIG_DIR="$t/cfg"
      source "$REPO/lib/iwiki/detect.sh"
      unset IWIKI_ENGINE_DIR
      iwiki_export_engine_dir
      echo "$IWIKI_ENGINE_DIR" )"
    assert_eq "resolver picks newest cached engine" \
      "$got" "$t/cfg/plugins/cache/iclaude/iwiki/0.6.4/engine"
    rm -rf "$t"
}

# ---- Task 1: env-map wiring ----
test_envmap_exports_engine_dir() {
    local t; t="$(mktemp -d)"
    make_engine "$t/plugin/iwiki/engine"
    local got
    got="$(
      SCRIPT_DIR="$t"; CLAUDE_CONFIG_DIR="$t/nope"; CREDENTIALS_FILE="$t/nofile"
      source "$REPO/lib/iwiki/detect.sh"
      source "$REPO/lib/config/env-map.sh"
      unset IWIKI_ENGINE_DIR
      source_iclaude_config
      echo "$IWIKI_ENGINE_DIR" )"
    assert_eq "source_iclaude_config exports IWIKI_ENGINE_DIR (no config file)" \
      "$got" "$t/plugin/iwiki/engine"
    rm -rf "$t"
}

test_resolver_prefers_in_repo
test_resolver_falls_back_to_newest_cache
test_envmap_exports_engine_dir

echo "----"
[[ "$fails" -eq 0 ]] && { echo "ALL PASS"; exit 0; } || { echo "$fails FAILED"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_iwiki_engine_entrypoint.sh`
Expected: FAIL — `iwiki_export_engine_dir: command not found` (function not defined yet), non-zero exit.

- [ ] **Step 3: Add the resolver to `lib/iwiki/detect.sh`**

Insert immediately after the `_iwiki_engine_dir()` function:

```bash
# Resolve the engine project once and export IWIKI_ENGINE_DIR — the canonical
# entrypoint the iwiki skills read. Preference: the in-repo engine (always
# uv-synced by install_iwiki and reachable from any project, since SCRIPT_DIR is
# the iclaude install) -> newest cached plugin engine. No-op if neither exists.
iwiki_export_engine_dir() {
    local dir; dir="$(_iwiki_engine_dir)"
    if [[ ! -f "$dir/pyproject.toml" ]]; then
        dir="$(ls -d "${CLAUDE_CONFIG_DIR:-}"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
    fi
    [[ -f "$dir/pyproject.toml" ]] && export IWIKI_ENGINE_DIR="$dir"
}
```

- [ ] **Step 4: Wire the resolver into the config chokepoint**

In `lib/config/env-map.sh`, replace the body of `source_iclaude_config` so the
export runs whether or not a config file is present:

```bash
source_iclaude_config() {
    if [[ -f "${CREDENTIALS_FILE:-}" ]]; then
        source "$CREDENTIALS_FILE"
        apply_iclaude_env_map
    fi
    # Export the canonical iwiki engine dir on every launch (function lives in
    # lib/iwiki/detect.sh; absent when iwiki is not installed -> silently skip).
    command -v iwiki_export_engine_dir >/dev/null 2>&1 && iwiki_export_engine_dir
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test_iwiki_engine_entrypoint.sh`
Expected: PASS — all three Task-1 cases pass, exit 0.

- [ ] **Step 6: Verify the existing env-map test still passes**

Run: `bash tests/test_env_map.sh`
Expected: PASS (the `command -v` guard makes the new call a no-op when `detect.sh` is not sourced).

- [ ] **Step 7: Commit**

```bash
git add lib/iwiki/detect.sh lib/config/env-map.sh tests/test_iwiki_engine_entrypoint.sh
git commit -m "feat(iwiki): export canonical IWIKI_ENGINE_DIR at launch

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Install-time health + parameter preflight

**Files:**
- Modify: `lib/iwiki/install.sh` (add `_iwiki_postsync_check`; call from `install_iwiki`; remove the generic config one-liner)
- Test: `tests/test_iwiki_engine_entrypoint.sh` (append cases)

**Interfaces:**
- Consumes: `iwiki_export_engine_dir` (Task 1); `print_info` / `print_warning` / `print_success` (iclaude UI helpers); resolved `uv` path; the synced in-repo engine dir.
- Produces: `_iwiki_postsync_check(engine_dir, uv)` — runs `status` (health), probes `Config.load()` (params), prints per-variable warnings for missing `IWIKI_LLM_BASE_URL` / `IWIKI_LLM_KEY` (required) and a note for `IWIKI_EMBED_MODEL` (optional), prints the resolved `IWIKI_ENGINE_DIR`. Always returns 0.

- [ ] **Step 1: Write the failing tests (append to the test file)**

In `tests/test_iwiki_engine_entrypoint.sh`, insert the two functions below
*before* the final block that starts with `test_resolver_prefers_in_repo`
(i.e. before the invocation list and the `echo "----"` summary):

```bash
# ---- Task 2: install preflight ----
# Resolve uv the same way install does.
_uv() { [[ -x "${UV_BIN:-}" ]] && { echo "$UV_BIN"; return; }; command -v uv; }

# Stub the iclaude UI helpers to echo so we can assert on output.
_with_stubs() {
    print_info() { echo "INFO: $*"; }
    print_warning() { echo "WARN: $*"; }
    print_success() { echo "OK: $*"; }
    print_error() { echo "ERR: $*"; }
    source "$REPO/lib/iwiki/detect.sh"
    source "$REPO/lib/iwiki/install.sh"
}

test_postsync_params_present() {
    local uv; uv="$(_uv)"
    [[ -z "$uv" || ! -f "$REPO/plugin/iwiki/engine/.venv/pyvenv.cfg" ]] && { echo "SKIP: postsync(params present) — no uv/synced engine"; return; }
    local out
    out="$( cd "$(mktemp -d)" && SCRIPT_DIR="$REPO" \
            IWIKI_LLM_BASE_URL="http://x/v1" IWIKI_LLM_KEY="k" \
            bash -c "$(declare -f); _with_stubs; _iwiki_postsync_check '$REPO/plugin/iwiki/engine' '$uv'" 2>&1 )"
    assert_contains "postsync prints engine health OK" "$out" "OK:"
    assert_not_contains "postsync: no param warning when set" "$out" "params missing"
    assert_contains "postsync prints resolved engine dir" "$out" "plugin/iwiki/engine"
}

test_postsync_params_missing() {
    local uv; uv="$(_uv)"
    [[ -z "$uv" || ! -f "$REPO/plugin/iwiki/engine/.venv/pyvenv.cfg" ]] && { echo "SKIP: postsync(params missing) — no uv/synced engine"; return; }
    local out
    out="$( cd "$(mktemp -d)" && SCRIPT_DIR="$REPO" \
            bash -c "$(declare -f); _with_stubs; \
                     unset IWIKI_LLM_BASE_URL IWIKI_LLM_KEY; \
                     _iwiki_postsync_check '$REPO/plugin/iwiki/engine' '$uv'; echo RC=\$?" 2>&1 )"
    assert_contains "postsync warns params missing" "$out" "params missing"
    assert_contains "postsync names ICLAUDE_IWIKI_LLM_BASE_URL" "$out" "ICLAUDE_IWIKI_LLM_BASE_URL"
    assert_contains "postsync names ICLAUDE_IWIKI_LLM_KEY" "$out" "ICLAUDE_IWIKI_LLM_KEY"
    assert_contains "postsync stays non-fatal (RC=0)" "$out" "RC=0"
}
```

Add the two invocations to the invocation list (next to the Task-1 ones):

```bash
test_postsync_params_present
test_postsync_params_missing
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test_iwiki_engine_entrypoint.sh`
Expected: FAIL — `_iwiki_postsync_check: command not found` (in this repo the engine is synced, so the cases run rather than SKIP).

- [ ] **Step 3: Add `_iwiki_postsync_check` to `lib/iwiki/install.sh`**

Insert this function just above `install_iwiki()`:

```bash
# Post-sync preflight (non-fatal). $1=engine dir, $2=uv path.
# 1) Engine health via `status` (no config, no network) — a clean run proves the
#    venv synced and the module imports. status/lint/validate never call
#    Config.load(), so they cannot HALT on missing params.
# 2) Parameter probe via Config.load() — raises (exit 2) when LLM params absent.
# 3) Print the engine dir the skills will use.
_iwiki_postsync_check() {
    local dir="$1" uv="$2"
    if "$uv" run --project "$dir" python3 -m iwiki_engine status >/dev/null 2>&1; then
        print_success "iwiki engine OK (module imports, venv synced)."
    else
        print_warning "iwiki engine health check failed — re-run ./iclaude.sh --install-iwiki."
    fi
    if ! "$uv" run --project "$dir" python3 -c "from iwiki_engine.config import Config; Config.load()" >/dev/null 2>&1; then
        print_warning "iwiki LLM params missing — set in .claude_config:"
        [[ -z "${IWIKI_LLM_BASE_URL:-}" ]] && print_warning "  ICLAUDE_IWIKI_LLM_BASE_URL (required)"
        [[ -z "${IWIKI_LLM_KEY:-}" ]]      && print_warning "  ICLAUDE_IWIKI_LLM_KEY (required)"
        [[ -z "${IWIKI_EMBED_MODEL:-}" ]]  && print_info    "  ICLAUDE_IWIKI_EMBED_MODEL (optional; default text-embedding-3-small)"
    fi
    iwiki_export_engine_dir
    print_info "iwiki engine: ${IWIKI_ENGINE_DIR:-$dir}"
    return 0
}
```

- [ ] **Step 4: Call it from `install_iwiki` and drop the generic line**

In `install_iwiki()`, after the `( cd "$dir" && "$uv" sync ) || { ... }` line, add the preflight call; and replace the trailing generic `print_info "iwiki installed. Configure ICLAUDE_IWIKI_LLM_* ..."` with a plain completion line. Result:

```bash
    print_info "Syncing iwiki engine (uv) at $dir ..."
    ( cd "$dir" && "$uv" sync ) || { print_error "uv sync failed"; return 1; }

    _iwiki_postsync_check "$dir" "$uv"

    _iwiki_register_plugin
    _iwiki_seed_ignore
    print_info "iwiki installed."
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test_iwiki_engine_entrypoint.sh`
Expected: PASS for `test_postsync_params_present` and `test_postsync_params_missing` (plus the Task-1 cases), exit 0.

- [ ] **Step 6: Commit**

```bash
git add lib/iwiki/install.sh tests/test_iwiki_engine_entrypoint.sh
git commit -m "feat(iwiki): post-sync health + LLM-param preflight on install

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Canonical "Engine invocation" block in all four skills

**Files:**
- Modify: `plugin/iwiki/skills/iwiki-init/SKILL.md`
- Modify: `plugin/iwiki/skills/iwiki-ingest/SKILL.md`
- Modify: `plugin/iwiki/skills/iwiki-query/SKILL.md`
- Modify: `plugin/iwiki/skills/iwiki-lint/SKILL.md`
- Test: `tests/test_iwiki_engine_entrypoint.sh` (append regression cases)

**Interfaces:**
- Consumes: `IWIKI_ENGINE_DIR` (Task 1), `UV_BIN`, `CLAUDE_CONFIG_DIR` at skill run time.
- Produces: a uniform top block defining `$ENG` and `$UV` reused by each skill's steps.

- [ ] **Step 1: Write the failing regression test (append)**

In `tests/test_iwiki_engine_entrypoint.sh`, add this function before the
invocation list:

```bash
# ---- Task 3: skill regression ----
test_skills_canonical_block() {
    local s f body
    for s in iwiki-init iwiki-ingest iwiki-query iwiki-lint; do
        f="$REPO/plugin/iwiki/skills/$s/SKILL.md"
        body="$(cat "$f")"
        assert_not_contains "$s: no 'command -v iwiki_engine'" "$body" "command -v iwiki_engine"
        assert_not_contains "$s: no 'iwiki_engine --help'"     "$body" "iwiki_engine --help"
        assert_contains     "$s: reads IWIKI_ENGINE_DIR"       "$body" "IWIKI_ENGINE_DIR"
        assert_contains     "$s: has fail-loud line"           "$body" "engine not found — run ./iclaude.sh --install-iwiki"
    done
}
```

And add the invocation:

```bash
test_skills_canonical_block
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_iwiki_engine_entrypoint.sh`
Expected: FAIL — skills do not yet reference `IWIKI_ENGINE_DIR` or the fail-loud line.

- [ ] **Step 3: Add the top block to each skill**

In each of the four `SKILL.md`, insert this section immediately after the `# <title>` H1 and its first descriptive paragraph, before `## Guardrails` / `## Steps`:

````markdown
## Engine invocation (read first)

The engine is a **Python module, not a binary on `PATH`** — never run
`command -v iwiki_engine` or `iwiki_engine --help` (they will fail with
"command not found"). The launcher exports `IWIKI_ENGINE_DIR`; resolve `$ENG` /
`$UV` once with the block below (it falls back to the in-repo / newest-cached
engine and exits loud if none is found), then reuse them in the steps:

```bash
ENG="${IWIKI_ENGINE_DIR:-}"
[ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
[ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
[ -f "$ENG/pyproject.toml" ] || { echo "iwiki: engine not found — run ./iclaude.sh --install-iwiki" >&2; exit 1; }
UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
# Run from the project root (relative --wiki-dir resolves against it):
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki <cmd>
```
````

- [ ] **Step 4: Fix the binary-implying prose**

In `iwiki-init/SKILL.md` and `iwiki-ingest/SKILL.md`, replace the phrase
``the engine ships with this plugin (`${CLAUDE_PLUGIN_ROOT}/engine`)`` with
``the engine ships with this plugin (resolved via `IWIKI_ENGINE_DIR` — see **Engine invocation** above)``.

In `iwiki-query/SKILL.md`, replace the step-1 resolution snippet (the
`ENG="${CLAUDE_PLUGIN_ROOT:+...}"` … `UV=…` … `"$UV" run … search "<the user's question>"`
block) with a reference + the run line only:

```bash
[ -d docs/wiki ] || { echo "iwiki: no docs/wiki/ here — run /iwiki-init to create one."; exit 0; }
# $ENG / $UV from "Engine invocation" above:
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki search "<the user's question>"
```

In `iwiki-lint/SKILL.md`, replace the step-1 resolution snippet with:

```bash
# $ENG / $UV from "Engine invocation" above:
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki lint
```

- [ ] **Step 5: De-duplicate the in-step resolution in `iwiki-init` / `iwiki-ingest`**

In `iwiki-init/SKILL.md` step 4 ("Build the index") and the matching index step
in `iwiki-ingest/SKILL.md`, remove the duplicated `ENG=…` / `UV=…` resolution
lines, keeping only the run line prefixed with a reference comment:

```bash
# $ENG / $UV from "Engine invocation" above:
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki index
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bash tests/test_iwiki_engine_entrypoint.sh`
Expected: PASS — all four skills pass the four regression assertions, exit 0.

- [ ] **Step 7: Sanity-check the skill snippet actually runs here**

Run (from repo root, mimics a skill):
```bash
ENG="${IWIKI_ENGINE_DIR:-}"; [ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki status
```
Expected: a JSON line like `{"chunks": <n>, "files": <n>, "bytes": <n>, "over_cap": false}`.

- [ ] **Step 8: Commit**

```bash
git add plugin/iwiki/skills/*/SKILL.md tests/test_iwiki_engine_entrypoint.sh
git commit -m "docs(iwiki): canonical engine-invocation block in all skills

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Document the entrypoint in the wiki (keep-current)

**Files:**
- Modify: `docs/wiki/iwiki.md`
- Test: manual lint via the iwiki engine

**Interfaces:**
- Consumes: the running engine (`$ENG` / `$UV` resolution from Task 3).
- Produces: a documented `## Engine invocation` concept on the iwiki page.

- [ ] **Step 1: Add an "Engine invocation" section to `docs/wiki/iwiki.md`**

Add a `##` section (keep to `##`-only, ≤250-char lead paragraph) covering: the
engine is a Python module run via `uv run --project <dir> python3 -m iwiki_engine`,
never a `PATH` binary; `IWIKI_ENGINE_DIR` is the canonical entrypoint exported at
launch by `source_iclaude_config` (`lib/config/env-map.sh`) via
`iwiki_export_engine_dir` (`lib/iwiki/detect.sh`); resolution order is in-repo
`plugin/iwiki/engine` → newest `$CLAUDE_CONFIG_DIR/plugins/cache/*/iwiki/*/engine`;
install runs a `status` health check + `Config.load()` parameter preflight.
Cross-link existing sections with `[[iwiki#<Heading>]]` where relevant.

- [ ] **Step 2: Refresh the index and lint**

Invoke the `iwiki:iwiki-ingest` skill on the changed source (`lib/iwiki`) to
regenerate/refresh `docs/wiki/iwiki.md`, then invoke `iwiki:iwiki-lint`.

Run (engine lint, direct check):
```bash
ENG="${IWIKI_ENGINE_DIR:-plugin/iwiki/engine}"; UV="${UV_BIN:-$(command -v uv)}"
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki lint
```
Expected: JSON with no `broken` entries for `iwiki.md` and `iwiki.md` not in `stale`.

- [ ] **Step 3: Verify the page documents the entrypoint**

Run: `grep -c "IWIKI_ENGINE_DIR" docs/wiki/iwiki.md`
Expected: `>= 1`.

- [ ] **Step 4: Commit**

```bash
git add docs/wiki/iwiki.md docs/wiki/.iwiki/
git commit -m "docs(wiki): document IWIKI_ENGINE_DIR canonical entrypoint

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] **Run the full new test file**

Run: `bash tests/test_iwiki_engine_entrypoint.sh`
Expected: `ALL PASS`, exit 0.

- [ ] **Run the related existing tests**

Run: `bash tests/test_env_map.sh && python3 -m pytest tests/test_iwiki_lint.py -q`
Expected: both green (no regressions in the env-map chokepoint or engine lint).

- [ ] **Confirm the regression that started this work is gone**

Run: `grep -rn 'command -v iwiki_engine\|iwiki_engine --help' plugin/iwiki/skills`
Expected: no matches.

---

## Self-Review

**Spec coverage:**
- §A canonical `IWIKI_ENGINE_DIR` auto-resolved at launch → Task 1.
- §B top invocation block + prose fix + de-dup across 4 skills → Task 3.
- §C install health smoke + `Config.load()` param probe + per-var warnings + print dir → Task 2.
- §D tests (resolver, cache fallback, install preflight, skill regression, no-`command -v` regression) → Tasks 1–3 + Final verification.
- §E document on `docs/wiki/iwiki.md` + ingest + lint → Task 4.

**Placeholder scan:** the only `<…>` tokens (`<cmd>`, `<the user's question>`, `<top result id>`, `<title>`, `<Heading>`) are literal skill-template / doc tokens that ship in the skills and wiki, not plan TBDs. No "TODO/handle edge cases" steps; every code step shows code.

**Type/name consistency:** `iwiki_export_engine_dir` and `_iwiki_postsync_check(dir, uv)` are referenced with the same names/signatures in Tasks 1, 2, and the env-map call. `$ENG` / `$UV` variable names are uniform across the skill block and step references.
