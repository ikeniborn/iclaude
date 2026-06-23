---
chain:
  intent: null
review:
  spec_hash: 8e2bd687864e8c3d
  last_run: 2026-06-23
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: CRITICAL
      section: Single load chokepoint
      section_hash: 408f9ac7958bb17e
      text: >-
        Spec claims "all 5 direct source sites" but the repo has 9 `source
        "$CREDENTIALS_FILE"` sites. The 4 sites in iclaude.sh itself
        (lines 506 --install-iwiki, 519 --install-gsd, 557 --install-microvm,
        574 --install-caveman) are not enumerated and will keep calling raw
        `source` instead of `source_iclaude_config`, so legacy/un-translated
        names are loaded on those paths. iclaude.sh is never listed among the
        files to touch.
      verdict: fixed
      verdict_at: 2026-06-23
    - id: F-002
      phase: coverage
      severity: CRITICAL
      section: Single load chokepoint
      section_hash: 408f9ac7958bb17e
      text: >-
        Persistent-settings block in iclaude.sh (lines ~227-259) reads the
        config via grep on hardcoded LEGACY var names (USE_PII_PROXY,
        MICRO_VM_ENABLED, NO_ATTRIBUTION_HEADER, USE_CHROME,
        CLAUDE_CODE_SKIP_PERMISSIONS). After renaming to ICLAUDE_*, these grep
        patterns silently stop matching, so --no-export/--pii/microVM/chrome/
        skip-permissions persistent toggles break. Spec does not address these
        grep readers (only the source sites).
      verdict: fixed
      verdict_at: 2026-06-23
    - id: F-003
      phase: coverage
      severity: WARNING
      section: Variable taxonomy
      section_hash: 9282df778db138f1
      text: >-
        Taxonomy table omits 3 internal vars that ARE consumed from the config
        by iclaude.sh's grep block: NO_ATTRIBUTION_HEADER, USE_CHROME,
        CLAUDE_CODE_SKIP_PERMISSIONS. Their target ICLAUDE_* names and the
        grep-reader update are unspecified.
      verdict: fixed
      verdict_at: 2026-06-23
    - id: F-004
      phase: clarity
      severity: WARNING
      section: New module:`lib/config/env-map.sh`
      section_hash: a9cd4002b13fe20c
      text: >-
        `_in_list` helper is used (apply_iclaude_env_map, lines 73 and 78) but
        never defined in the module sketch and is not a bash builtin. The DoD
        for env-map.sh is incomplete without its definition/semantics.
      verdict: fixed
      verdict_at: 2026-06-23
    - id: F-005
      phase: clarity
      severity: INFO
      section: Problem
      section_hash: c273131533ef79e3
      text: >-
        "38 export lines" does not match the active .claude_config.example,
        which has 7 active `export` lines (38 only when commented-out `# export`
        examples are counted). The framing "38 export lines, the rest bare
        assignments" is misleading about the active set.
      verdict: fixed
      verdict_at: 2026-06-23
---

# Design: Unify `.claude_config` under the `ICLAUDE_` prefix without `export`

- **Date:** 2026-06-23
- **Status:** draft
- **Topic:** claude-config-iclaude-prefix

## Problem

`.claude_config.example` mixes variable prefixes (`ANTHROPIC_*`, `CLAUDE_CODE_*`,
`PROXY_*`, `MICRO_VM_*`, `IWIKI_*`, `PII_PROXY_*`, provider `*_API_KEY`, a few
`ICLAUDE_*`) and inconsistently uses `export` (7 active `export` lines plus ~31
commented-out `# export` examples; the remaining active vars are bare assignments).
Two goals:

1. **Single namespace.** Every variable declared in `.claude_config` uses the unique
   `ICLAUDE_` prefix.
2. **No `export`.** Every variable is a bare assignment, regardless of how the
   underlying built-in tool consumes it.

The constraint that makes this non-trivial: many variables are **passthrough** —
built-in tools (Claude Code binary, Claude Code Router via `${VAR}` substitution in
`router.json`, the iwiki Python engine, Node.js, OpenTelemetry) read them from the
process environment under their **canonical** names. Renaming them to `ICLAUDE_*` and
dropping `export` would make those tools blind to them. Therefore a **translation
layer** is required: read the `ICLAUDE_*` names from the sourced config and export the
canonical names the tools expect, just before launch.

## Variable taxonomy

| Class | Examples | Consumed by | Action |
|-------|----------|-------------|--------|
| Passthrough | `ANTHROPIC_API_KEY`, `CLAUDE_CODE_MODEL`, `DEEPSEEK_API_KEY`, `IWIKI_LLM_KEY`, `LANGFUSE_*`, `NODE_EXTRA_CA_CERTS`, `OTEL_*` | Claude Code / CCR / iwiki / Node | Rename to `ICLAUDE_*`, translate back to canonical name + `export` at load |
| Internal iclaude (sourced) | `PROXY_URL`, `PROXY_CA`, `PROXY_INSECURE`, `NO_PROXY`, `USE_PII_PROXY`, `PII_PROXY_*`, `MICRO_VM_*`, `USE_LANGFUSE_CAPTURE`, `TOKEN_REFRESH_THRESHOLD`, `DEBUG_LAUNCH` | iclaude bash modules (after `source`) | Rename to `ICLAUDE_*`, translate back to the same canonical name (lib consumers unchanged) |
| Internal iclaude (grep-read) | `USE_PII_PROXY`, `MICRO_VM_ENABLED`, `NO_ATTRIBUTION_HEADER`, `USE_CHROME`, `CLAUDE_CODE_SKIP_PERMISSIONS` | `iclaude.sh` persistent-settings block (`grep` at parse time, **before** `source`) | Rename to `ICLAUDE_*`; the 5 `grep` patterns must be updated to the `ICLAUDE_`-prefixed names (translation does not help — grep reads raw file text) |
| Native `ICLAUDE_*` | `ICLAUDE_CHAT_LANG`, `ICLAUDE_DOC_LANG`, `ICLAUDE_NO_TELEMETRY`, `ICLAUDE_NO_AUTO_UPDATE`; runtime `ICLAUDE_PII_ACTIVE`, `ICLAUDE_PII_MASKING_LEVEL`, `ICLAUDE_PII_ACTIVE_PORT`, `ICLAUDE_PII_LOG_PATH` | caveman hooks / statusline (under the `ICLAUDE_` name) | Keep name verbatim; **do not** de-prefix |

> Note: `USE_PII_PROXY` and `MICRO_VM_ENABLED` appear in **both** the sourced and
> grep-read rows — `iclaude.sh` greps them at parse time to set CLI-equivalent flags,
> and the lib modules also read them after `source`. Both readers must move to the
> `ICLAUDE_` name.

## Decisions (resolved during brainstorming)

1. **Naming scheme — mechanical full prefix.** `ICLAUDE_<ORIGINAL_NAME>` verbatim. The
   inverse (translation) is a pure prefix strip. Reversible, collision-free, no manual
   mapping table. (Internal vars carry no vendor prefix, so the "hybrid" framing
   collapses to this single rule.)
2. **Backward compatibility — auto-migration on launch.** Detect a legacy
   `.claude_config`, rewrite it in place once (with a `.bak` backup), then only
   `ICLAUDE_*` is recognized.
3. **Translation mechanism — convention + denylist.** Rule: any `ICLAUDE_X` →
   `export X` (strip prefix), **except** a small exact-name denylist of native
   `ICLAUDE_*` vars. New passthrough vars work with zero table edits.

Rejected alternative: an explicit `declare -A` allowlist (~95 entries). More verbose,
requires a table edit for every new variable, no benefit over the convention given the
mechanical naming.

## Architecture

### New module: `lib/config/env-map.sh`

Pure functions, no side effects at source time. Sourced in **Phase 0** (with the
`core/*` modules) so it is available before `lib/proxy/credentials.sh` (the first call
site that sources the config, at boot line ~49).

```bash
# Exact native names that must NOT be de-prefixed (kept verbatim).
ICLAUDE_NATIVE=(
  ICLAUDE_CHAT_LANG ICLAUDE_DOC_LANG ICLAUDE_NO_TELEMETRY ICLAUDE_NO_AUTO_UPDATE
  ICLAUDE_PII_ACTIVE ICLAUDE_PII_MASKING_LEVEL ICLAUDE_PII_ACTIVE_PORT ICLAUDE_PII_LOG_PATH
)
# Translated vars where an empty-but-set value is meaningful (default skips empties).
ICLAUDE_ALLOW_EMPTY=( ICLAUDE_PII_PROXY_MASK_TOKEN )

# Membership test: is $1 present in the remaining args?
_in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

apply_iclaude_env_map() {
  local v name
  for v in ${!ICLAUDE_@}; do
    # Native: export under its own ICLAUDE_ name, never de-prefix.
    if _in_list "$v" "${ICLAUDE_NATIVE[@]}"; then
      [[ -n ${!v:-} ]] && export "$v"
      continue
    fi
    name=${v#ICLAUDE_}
    if _in_list "$v" "${ICLAUDE_ALLOW_EMPTY[@]}"; then
      [[ -n ${!v+x} ]] && export "$name=${!v}"      # set-but-empty is significant
    else
      [[ -n ${!v:-} ]] && export "$name=${!v}"      # empty = ignored (current behavior)
    fi
  done
}

source_iclaude_config() {            # the ONLY place that loads the config
  [[ -f "$CREDENTIALS_FILE" ]] || return 0
  source "$CREDENTIALS_FILE"
  apply_iclaude_env_map
}
```

### Single load chokepoint

Replace all **9** direct `source "$CREDENTIALS_FILE"` sites with `source_iclaude_config`.
Five in `lib/`:

- `lib/caveman/install.sh:119`
- `lib/nvm/install.sh:33`
- `lib/proxy/credentials.sh:129`
- `lib/proxy/configure.sh:28`
- `lib/config/isolated.sh:89` — `load_claude_config()` becomes a thin wrapper that
  delegates to `source_iclaude_config` (its hand-written export block, lines ~92–139,
  is deleted — the generic loop subsumes it).

Four in `iclaude.sh` itself (install command paths — easy to miss, **`iclaude.sh` is in
scope**):

- `iclaude.sh:506` (`--install-iwiki`)
- `iclaude.sh:519` (`--install-gsd`)
- `iclaude.sh:557` (`--install-microvm`)
- `iclaude.sh:574` (`--install-caveman`)

(Line numbers are pre-change anchors; the implementation matches by context, not by
number.)

**Internal lib references stay unchanged.** Modules keep reading `PROXY_URL`,
`MICRO_VM_*`, etc.; the translation layer re-creates those canonical names from the
`ICLAUDE_*` source. Net diff in consumers: zero. This is the core advantage of the
convention approach.

### Parse-time grep readers (`iclaude.sh` persistent-settings block)

`iclaude.sh` (~lines 227–259) reads the config **before** any `source`, by `grep`-ing
the raw file for five toggles to seed CLI-equivalent flags: `USE_PII_PROXY`,
`MICRO_VM_ENABLED`, `NO_ATTRIBUTION_HEADER`, `USE_CHROME`, `CLAUDE_CODE_SKIP_PERMISSIONS`.
Because this path never sources the file, the translation layer cannot help it — the
`grep` patterns themselves must be updated to the `ICLAUDE_`-prefixed names
(`ICLAUDE_USE_PII_PROXY`, `ICLAUDE_MICRO_VM_ENABLED`, `ICLAUDE_NO_ATTRIBUTION_HEADER`,
`ICLAUDE_USE_CHROME`, `ICLAUDE_CLAUDE_CODE_SKIP_PERMISSIONS`). The existing
`(export[[:space:]]+)?` optional-prefix part of each pattern is kept (harmless; matches
either form during the transition window). **Ordering:** `migrate_legacy_config()` must
run before this grep block so a legacy file is already rewritten to `ICLAUDE_*` names by
the time the toggles are scanned.

### Auto-migration: `migrate_legacy_config()`

Runs once at boot, after `lib/core/init.sh` sets `CREDENTIALS_FILE`, and **before both**
the parse-time grep block (`iclaude.sh` ~227–259) and the first `source_iclaude_config`.
It is the earliest config consumer, so it must be the first thing `main()` does after
init.

- **Detect legacy:** the file contains a line matching `^[[:space:]]*export ` **or** an
  active assignment whose LHS does not start with `ICLAUDE_`.
- **Transform (awk), active assignments only:** strip a leading `export `; if the name
  lacks the `ICLAUDE_` prefix, add it; names already `ICLAUDE_*` are left as is.
  **Comments and prose are untouched** (the per-user file's comments are template
  copy; mangling them is not worth it).
- **Safety:** write `.claude_config.bak` (chmod 600) first, then rewrite via temp file
  + `mv`. Idempotent: after migration the legacy markers are gone, so it never fires
  again. Emits `ℹ Migrated .claude_config → ICLAUDE_* (backup: .claude_config.bak)`.

## Template rewrite

`.claude_config.example` is **hand-rewritten in full** (not run through the migrator):
all ~100 documented variables — active and commented-out advanced examples alike — are
renamed to `ICLAUDE_*` and stripped of `export`. Rationale: a half-migrated template
(only the ~32 active vars) would teach users the wrong names via the commented
examples. The header comment is updated to state the single-prefix / no-`export`
convention and to mention auto-migration.

## Docs and hint strings

Update every user-facing reference to a legacy config var name:

- `lib/command/usage.sh` (e.g. `USE_PII_PROXY=true` → `ICLAUDE_USE_PII_PROXY=true`,
  `MICRO_VM_ENABLED=true` → `ICLAUDE_MICRO_VM_ENABLED=true`).
- `*/install.sh` and `*/status.sh` "add X to .claude_config" hints (sandbox, pii-proxy,
  iwiki, statusline).
- `docs/CONFIGURATION.md`, `docs/PII_MASKING.md`, `docs/MICROVM.md`, `docs/ROUTER.md`.
- `CLAUDE.md` mentions (`MICRO_VM_ENABLED`, `USE_PII_PROXY`, router API-key examples,
  iwiki `IWIKI_*` block).

## Error handling

- Missing config file → `source_iclaude_config` returns 0 (no-op), unchanged from today.
- Migration backup write fails → abort migration, leave the original untouched, warn;
  boot continues reading the legacy file via a one-time compatibility note (do **not**
  half-rewrite).
- A translated name collides with an existing environment value → the config value wins
  (config is the source of truth), matching current `export`-on-load semantics.

## Testing / success criteria

`tests/` (bash, sourced units):

1. `apply_iclaude_env_map`:
   - `ICLAUDE_ANTHROPIC_API_KEY=x` ⇒ `ANTHROPIC_API_KEY=x` exported.
   - `ICLAUDE_PROXY_URL=u` ⇒ `PROXY_URL=u` exported.
   - `ICLAUDE_CHAT_LANG=Russian` ⇒ stays `ICLAUDE_CHAT_LANG`, no `CHAT_LANG`.
   - `ICLAUDE_PII_PROXY_MASK_TOKEN=` (empty, set) ⇒ `PII_PROXY_MASK_TOKEN=` exported.
   - `ICLAUDE_ANTHROPIC_MODEL=` (empty) ⇒ not exported.
2. `migrate_legacy_config`:
   - legacy file with `export FOO=1` + `BAR=2` ⇒ `ICLAUDE_FOO=1`, `ICLAUDE_BAR=2`, no
     `export`; `.bak` created.
   - already-migrated file ⇒ unchanged (idempotent), no second `.bak` churn.
   - comment lines preserved verbatim.
3. `iclaude.sh` parse-time grep toggles after rename:
   - config with `ICLAUDE_USE_PII_PROXY=true` ⇒ `USE_PII_PROXY_FLAG=true`; same for
     `ICLAUDE_MICRO_VM_ENABLED`, `ICLAUDE_NO_ATTRIBUTION_HEADER`, `ICLAUDE_USE_CHROME`,
     `ICLAUDE_CLAUDE_CODE_SKIP_PERMISSIONS`.
   - a legacy file (pre-migration names) passed through `migrate_legacy_config` first
     ⇒ toggles still fire (ordering guarantee).
4. `bash -n` on every touched file, including `iclaude.sh`.
5. End-to-end smoke: `./iclaude.sh --test` and `./iclaude.sh --check-isolated` still
   resolve proxy/config correctly after migration.

## Out of scope

- No change to which variables exist or their semantics — pure rename + load-path
  refactor.
- No change to `router.json` / `router.json.example` (`${DEEPSEEK_API_KEY}`
  placeholders keep working because the canonical name is exported by translation).
- Runtime `ICLAUDE_PII_*` variables set by `launch.sh` are unaffected (already
  `ICLAUDE_`-named, in the native denylist).
