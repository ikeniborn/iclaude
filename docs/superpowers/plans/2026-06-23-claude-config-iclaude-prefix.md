---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-23-claude-config-iclaude-prefix-design.md
review:
  plan_hash: 7efc12df3f37aa4a
  spec_hash: 8e2bd687864e8c3d
  last_run: 2026-06-23
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
---

# ICLAUDE_ Prefix Unification for `.claude_config` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every variable in `.claude_config` use a single `ICLAUDE_` prefix with no `export`, while built-in tools keep receiving their canonical environment-variable names.

**Architecture:** A new `lib/config/env-map.sh` module is the single config-load chokepoint. `source_iclaude_config()` sources the file then `apply_iclaude_env_map()` de-prefixes every `ICLAUDE_X` to `export X` (except an exact-name native denylist). `migrate_legacy_config()` rewrites a legacy file in place once (with `.bak`). All 9 raw `source "$CREDENTIALS_FILE"` sites and the parse-time `grep` block in `iclaude.sh` are pointed at the new names.

**Tech Stack:** Bash (POSIX-ish + `awk`), existing `lib/core/logging.sh` print helpers, standalone `tests/*.sh` harness style (PASS/FAIL counters, nonzero exit on failure).

**Spec:** `docs/superpowers/specs/2026-06-23-claude-config-iclaude-prefix-design.md`

---

## File Structure

- **Create** `lib/config/env-map.sh` — translation + migration functions (`_in_list`, `apply_iclaude_env_map`, `source_iclaude_config`, `_config_is_legacy`, `migrate_legacy_config`, plus the `ICLAUDE_NATIVE` / `ICLAUDE_ALLOW_EMPTY` arrays). One responsibility: the config name-mapping layer.
- **Create** `tests/test_env_map.sh` — unit tests for `apply_iclaude_env_map` + `_in_list`.
- **Create** `tests/test_config_migration.sh` — unit tests for `_config_is_legacy` + `migrate_legacy_config`.
- **Modify** `iclaude.sh` — source `env-map.sh` in Phase 0; call `migrate_legacy_config` after `init_environment`; rename the 5 grep patterns; repoint the 4 in-file `source` sites.
- **Modify** `lib/proxy/credentials.sh`, `lib/proxy/configure.sh`, `lib/nvm/install.sh`, `lib/caveman/install.sh` — repoint their `source` sites.
- **Modify** `lib/config/isolated.sh` — `load_claude_config()` becomes a thin wrapper over `source_iclaude_config`.
- **Modify** `.claude_config.example` — full rename to `ICLAUDE_*`, drop `export`.
- **Modify** doc/hint strings: `lib/command/usage.sh`, `lib/pii-proxy/install.sh`, `lib/sandbox/install.sh`, `lib/sandbox/status.sh`, `lib/iwiki/install.sh`, `docs/CONFIGURATION.md`, `docs/PII_MASKING.md`, `docs/MICROVM.md`, `docs/ROUTER.md`, `CLAUDE.md`.
- **Modify** `.gitignore` — ignore `.claude_config.bak`.

---

## Task 1: Translation layer module + unit tests (`lib/config/env-map.sh`)

**Files:**
- Create: `lib/config/env-map.sh`
- Test: `tests/test_env_map.sh`

- [ ] **Step 1: Write the failing test** — `tests/test_env_map.sh`

```bash
#!/usr/bin/env bash
# Unit tests for apply_iclaude_env_map + _in_list (lib/config/env-map.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Stub print_* so the module has no hard dependency on lib/core/logging.sh.
print_info()    { echo "INFO: $*"; }
print_warning() { echo "WARN: $*"; }
print_error()   { echo "ERR: $*"; }

source "$ROOT/lib/config/env-map.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }

# Run apply_iclaude_env_map in a subshell with a controlled ICLAUDE_ environment,
# then print the canonical name's value (or the literal "<unset>").
probe() {  # $1=var-to-print  $2..=NAME=VALUE assignments to set first
  local want="$1"; shift
  bash -c '
    print_info(){ :; }; print_warning(){ :; }; print_error(){ :; }
    source "'"$ROOT"'/lib/config/env-map.sh"
    for kv in "$@"; do export "$kv"; done
    apply_iclaude_env_map
    if [[ -n ${'"$want"'+x} ]]; then printf "%s" "${'"$want"'}"; else printf "<unset>"; fi
  ' _ "$@"
}

# Passthrough: de-prefix + export canonical name.
assert_eq "$(probe ANTHROPIC_API_KEY ICLAUDE_ANTHROPIC_API_KEY=sk-x)" "sk-x" "passthrough de-prefix"
# Internal: same de-prefix rule.
assert_eq "$(probe PROXY_URL ICLAUDE_PROXY_URL=https://h:8118)" "https://h:8118" "internal de-prefix"
# Native denylist: must NOT create the de-prefixed name.
assert_eq "$(probe CHAT_LANG ICLAUDE_CHAT_LANG=Russian)" "<unset>" "native not de-prefixed"
# Native denylist: the ICLAUDE_ name itself is still exported.
assert_eq "$(probe ICLAUDE_CHAT_LANG ICLAUDE_CHAT_LANG=Russian)" "Russian" "native kept verbatim"
# Empty (unset-or-empty) value is ignored.
assert_eq "$(probe ANTHROPIC_MODEL ICLAUDE_ANTHROPIC_MODEL=)" "<unset>" "empty ignored"
# Allow-empty var: set-but-empty IS exported.
assert_eq "$(probe PII_PROXY_MASK_TOKEN ICLAUDE_PII_PROXY_MASK_TOKEN=)" "" "allow-empty set-but-empty exported"

# _in_list direct checks
_in_list ICLAUDE_CHAT_LANG "${ICLAUDE_NATIVE[@]}" && r=0 || r=1
assert_eq "$r" "0" "_in_list hit"
_in_list ICLAUDE_PROXY_URL "${ICLAUDE_NATIVE[@]}" && r=0 || r=1
assert_eq "$r" "1" "_in_list miss"

echo "env-map: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_env_map.sh`
Expected: FAIL — `lib/config/env-map.sh` does not exist (`source: No such file`), nonzero exit.

- [ ] **Step 3: Create the module** — `lib/config/env-map.sh`

```bash
#!/bin/bash

#######################################
# Config Env-Map Module
# Description: Single chokepoint that loads .claude_config (ICLAUDE_*-only,
#              no `export`) and translates each ICLAUDE_X back to the canonical
#              environment variable X that built-in tools read. Plus one-time
#              legacy auto-migration.
#######################################

# Native ICLAUDE_* names consumed verbatim (caveman hooks / statusline / runtime).
# These must NOT be de-prefixed.
ICLAUDE_NATIVE=(
    ICLAUDE_CHAT_LANG ICLAUDE_DOC_LANG ICLAUDE_NO_TELEMETRY ICLAUDE_NO_AUTO_UPDATE
    ICLAUDE_PII_ACTIVE ICLAUDE_PII_MASKING_LEVEL ICLAUDE_PII_ACTIVE_PORT ICLAUDE_PII_LOG_PATH
)

# Translated vars where an empty-but-set value is meaningful (default skips empties).
ICLAUDE_ALLOW_EMPTY=( ICLAUDE_PII_PROXY_MASK_TOKEN )

# Membership test: is $1 present among the remaining args?
_in_list() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
    return 1
}

#######################################
# Translate every set ICLAUDE_* var into the canonical name the tools expect.
# - Native names (denylist): exported verbatim, never de-prefixed.
# - Allow-empty names: exported even when set-but-empty.
# - All others: exported under the de-prefixed name when non-empty.
#######################################
apply_iclaude_env_map() {
    local v name
    for v in ${!ICLAUDE_@}; do
        if _in_list "$v" "${ICLAUDE_NATIVE[@]}"; then
            [[ -n ${!v:-} ]] && export "$v"
            continue
        fi
        name=${v#ICLAUDE_}
        if _in_list "$v" "${ICLAUDE_ALLOW_EMPTY[@]}"; then
            [[ -n ${!v+x} ]] && export "$name=${!v}"
        else
            [[ -n ${!v:-} ]] && export "$name=${!v}"
        fi
    done
}

#######################################
# The ONLY place that loads the config: source then translate.
# Safe to call multiple times (idempotent re-export).
#######################################
source_iclaude_config() {
    [[ -f "$CREDENTIALS_FILE" ]] || return 0
    source "$CREDENTIALS_FILE"
    apply_iclaude_env_map
}

#######################################
# Detect a legacy config: any `export ` line, or any active assignment whose
# variable name does not start with ICLAUDE_.
# Returns 0 (legacy) / 1 (already migrated or empty).
#######################################
_config_is_legacy() {
    local f="$1"
    [[ -f "$f" ]] || return 1
    grep -qE '^[[:space:]]*export[[:space:]]' "$f" && return 0
    grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$f" 2>/dev/null \
        | grep -qvE '^[[:space:]]*ICLAUDE_' && return 0
    return 1
}

#######################################
# One-time migration: rename active assignments to ICLAUDE_*, strip `export`.
# Comments and prose are left untouched. Writes a chmod-600 .bak first, rewrites
# via temp + mv. Idempotent (legacy markers vanish after a successful run).
#######################################
migrate_legacy_config() {
    local f="$CREDENTIALS_FILE"
    [[ -f "$f" ]] || return 0
    _config_is_legacy "$f" || return 0

    local bak="${f}.bak" tmp="${f}.tmp.$$"
    if ! cp -p "$f" "$bak" 2>/dev/null; then
        print_warning "Could not back up $f; skipping ICLAUDE_ migration (file left as-is)"
        return 0
    fi
    chmod 600 "$bak" 2>/dev/null || true

    if awk '
        {
            if ($0 ~ /^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/) {
                match($0, /^[[:space:]]*/); indent = substr($0, 1, RLENGTH)
                rest = substr($0, RLENGTH + 1)
                sub(/^export[[:space:]]+/, "", rest)
                eq = index(rest, "=")
                name = substr(rest, 1, eq - 1)
                val  = substr(rest, eq)
                if (name !~ /^ICLAUDE_/) name = "ICLAUDE_" name
                print indent name val
            } else {
                print
            }
        }
    ' "$f" > "$tmp" 2>/dev/null && mv "$tmp" "$f"; then
        chmod 600 "$f" 2>/dev/null || true
        print_info "Migrated .claude_config → ICLAUDE_* (backup: $(basename "$bak"))"
    else
        rm -f "$tmp"
        print_warning "ICLAUDE_ migration failed; original left intact (backup: $(basename "$bak"))"
    fi
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_env_map.sh`
Expected: PASS — `env-map: PASS=8 FAIL=0`, exit 0.

- [ ] **Step 5: Syntax-check the module**

Run: `bash -n lib/config/env-map.sh && echo OK`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add lib/config/env-map.sh tests/test_env_map.sh
git commit -m "feat(config): add ICLAUDE_ env-map translation layer"
```

---

## Task 2: Migration function tests + `.gitignore`

**Files:**
- Test: `tests/test_config_migration.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing test** — `tests/test_config_migration.sh`

```bash
#!/usr/bin/env bash
# Unit tests for _config_is_legacy + migrate_legacy_config (lib/config/env-map.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
print_info()    { echo "INFO: $*"; }
print_warning() { echo "WARN: $*"; }
source "$ROOT/lib/config/env-map.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_file_contains() { if grep -qF "$2" "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: '$2' not in $1"; fi; }
assert_file_missing_line() { if grep -qF "$2" "$1"; then FAIL=$((FAIL+1)); echo "FAIL [$3]: unexpected '$2' in $1"; else PASS=$((PASS+1)); fi; }

TD=$(mktemp -d)

# --- legacy file with export + bare + a comment + an already-prefixed var ---
cat > "$TD/.claude_config" <<'EOF'
# a comment with FOO=bar inside prose
export DEEPSEEK_API_KEY=sk-123
PROXY_URL=https://h:8118
ICLAUDE_CHAT_LANG=Russian
EOF

CREDENTIALS_FILE="$TD/.claude_config"
_config_is_legacy "$CREDENTIALS_FILE" && r=0 || r=1
assert_eq "$r" "0" "detect: legacy true"

migrate_legacy_config
assert_file_contains "$TD/.claude_config" "ICLAUDE_DEEPSEEK_API_KEY=sk-123" "migrate: export renamed + de-exported"
assert_file_missing_line "$TD/.claude_config" "export DEEPSEEK_API_KEY" "migrate: export keyword gone"
assert_file_contains "$TD/.claude_config" "ICLAUDE_PROXY_URL=https://h:8118" "migrate: bare renamed"
assert_file_contains "$TD/.claude_config" "ICLAUDE_CHAT_LANG=Russian" "migrate: already-prefixed kept"
assert_file_missing_line "$TD/.claude_config" "ICLAUDE_ICLAUDE_CHAT_LANG" "migrate: no double prefix"
assert_file_contains "$TD/.claude_config" "# a comment with FOO=bar inside prose" "migrate: comment untouched"
assert_eq "$(test -f "$TD/.claude_config.bak" && echo yes)" "yes" "migrate: .bak created"

# --- idempotency: second run is a no-op ---
_config_is_legacy "$CREDENTIALS_FILE" && r=0 || r=1
assert_eq "$r" "1" "detect: migrated file not legacy"
cp "$TD/.claude_config" "$TD/snapshot"
migrate_legacy_config
assert_eq "$(diff -q "$TD/.claude_config" "$TD/snapshot" >/dev/null && echo same)" "same" "migrate: idempotent no-op"

rm -rf "$TD"
echo "migration: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

- [ ] **Step 2: Run the test to verify it passes** (the functions already exist from Task 1)

Run: `bash tests/test_config_migration.sh`
Expected: PASS — `migration: PASS=10 FAIL=0`, exit 0.
(If it fails, fix `migrate_legacy_config` / `_config_is_legacy` in `lib/config/env-map.sh` until green — this test is the authority on their behavior.)

- [ ] **Step 3: Ignore the backup file** — add to `.gitignore`

Add this line to `.gitignore` (next to the existing `.claude_config` entry):

```
.claude_config.bak
```

- [ ] **Step 4: Verify the ignore rule**

Run: `git check-ignore .claude_config.bak && echo IGNORED`
Expected: `IGNORED`

- [ ] **Step 5: Commit**

```bash
git add tests/test_config_migration.sh .gitignore
git commit -m "test(config): migration unit tests; ignore .claude_config.bak"
```

---

## Task 3: Wire env-map into boot + rename parse-time grep readers (`iclaude.sh`)

**Files:**
- Modify: `iclaude.sh:38` (Phase 0 source), `iclaude.sh:42` (migrate call), `iclaude.sh:227-259` (grep patterns)

- [ ] **Step 1: Source the module in Phase 0**

In `iclaude.sh`, after `source "${LIB_DIR}/core/remaining.sh"` (line 37) and before the `# Initialize environment` block, add:

```bash
source "${LIB_DIR}/config/env-map.sh"
```

- [ ] **Step 2: Call migration right after `init_environment`**

In `iclaude.sh`, immediately after the `init_environment` call (line 42), add:

```bash

# One-time migration of a legacy .claude_config to the ICLAUDE_ namespace.
# Must run before BOTH the parse-time grep block and any config source.
migrate_legacy_config
```

- [ ] **Step 3: Rename the 5 grep patterns (and their `# Match:` comments)**

In the persistent-settings block (`iclaude.sh` ~227-259), update each variable name to its `ICLAUDE_` form. The `(export[[:space:]]+)?` optional group stays. Make these 5 replacements:

| Old pattern fragment | New pattern fragment |
|----------------------|----------------------|
| `?USE_PII_PROXY[[:space:]]*=` | `?ICLAUDE_USE_PII_PROXY[[:space:]]*=` |
| `?MICRO_VM_ENABLED[[:space:]]*=` | `?ICLAUDE_MICRO_VM_ENABLED[[:space:]]*=` |
| `?NO_ATTRIBUTION_HEADER[[:space:]]*=` | `?ICLAUDE_NO_ATTRIBUTION_HEADER[[:space:]]*=` |
| `?USE_CHROME[[:space:]]*=` | `?ICLAUDE_USE_CHROME[[:space:]]*=` |
| `?CLAUDE_CODE_SKIP_PERMISSIONS[[:space:]]*=` | `?ICLAUDE_CLAUDE_CODE_SKIP_PERMISSIONS[[:space:]]*=` |

Also update each preceding `# Match: …` comment to the `ICLAUDE_`-prefixed example (e.g. `# Match: ICLAUDE_USE_PII_PROXY=true …`).

- [ ] **Step 4: Write a behavioral test for the grep toggles** — append to `tests/test_config_migration.sh` (or create `tests/test_persistent_toggles.sh`)

Create `tests/test_persistent_toggles.sh`:

```bash
#!/usr/bin/env bash
# Verifies the iclaude.sh persistent-settings grep block fires on ICLAUDE_* names,
# and still fires for a legacy file once migrate_legacy_config has run first.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
print_info(){ :; }; print_warning(){ :; }
source "$ROOT/lib/config/env-map.sh"

PASS=0; FAIL=0
assert_eq(){ if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }

# Replicate the grep used by iclaude.sh for one toggle.
toggle_on() {  # $1=config-file $2=ICLAUDE_name
  grep -qE "^[[:space:]]*(export[[:space:]]+)?$2[[:space:]]*=[[:space:]]*[\"']?true[\"']?" "$1" && echo true || echo false
}

TD=$(mktemp -d)

# ICLAUDE_-named file → toggle matches.
printf 'ICLAUDE_USE_PII_PROXY=true\n' > "$TD/.claude_config"
assert_eq "$(toggle_on "$TD/.claude_config" ICLAUDE_USE_PII_PROXY)" "true" "ICLAUDE_ toggle matches"

# Legacy file → does NOT match ICLAUDE_ pattern until migrated...
printf 'USE_PII_PROXY=true\n' > "$TD/.claude_config"
assert_eq "$(toggle_on "$TD/.claude_config" ICLAUDE_USE_PII_PROXY)" "false" "legacy not matched pre-migration"
# ...then migrate, then it matches (ordering guarantee).
CREDENTIALS_FILE="$TD/.claude_config" migrate_legacy_config
assert_eq "$(toggle_on "$TD/.claude_config" ICLAUDE_USE_PII_PROXY)" "true" "matches after migration"

rm -rf "$TD"
echo "toggles: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

- [ ] **Step 5: Run the toggle test + syntax check**

Run: `bash tests/test_persistent_toggles.sh && bash -n iclaude.sh && echo OK`
Expected: `toggles: PASS=3 FAIL=0` then `OK`.

- [ ] **Step 6: Commit**

```bash
git add iclaude.sh tests/test_persistent_toggles.sh
git commit -m "feat(config): migrate at boot; ICLAUDE_ parse-time grep readers"
```

---

## Task 4: Repoint the 9 `source` sites onto `source_iclaude_config`

**Files:**
- Modify: `lib/proxy/credentials.sh:129`, `lib/proxy/configure.sh:28`, `lib/nvm/install.sh:33`, `lib/caveman/install.sh:119`, `lib/config/isolated.sh:89-142`, `iclaude.sh:506,519,557,574`

- [ ] **Step 1: Replace the 4 lib/ module source sites**

Make each of these edits (the guard is now inside `source_iclaude_config`, so drop the `[[ -f ... ]] &&` prefix where present):

- `lib/proxy/credentials.sh:129` — replace `source "$CREDENTIALS_FILE"` with `source_iclaude_config`
- `lib/proxy/configure.sh:28` — replace `source "$CREDENTIALS_FILE"` with `source_iclaude_config`
- `lib/nvm/install.sh:33` — replace `source "$CREDENTIALS_FILE"` with `source_iclaude_config`
- `lib/caveman/install.sh:119` — replace `[[ -f "${CREDENTIALS_FILE:-}" ]] && source "$CREDENTIALS_FILE"` with `source_iclaude_config`

- [ ] **Step 2: Replace the 4 iclaude.sh install-path source sites**

In `iclaude.sh`, at lines 506, 519, 557, 574, replace each
`[[ -f "$CREDENTIALS_FILE" ]] && source "$CREDENTIALS_FILE"`
with
`source_iclaude_config`

- [ ] **Step 3: Convert `load_claude_config()` to a thin wrapper** — `lib/config/isolated.sh`

Replace the entire body of `load_claude_config()` (lines ~83-142, the `source` + the hand-written `[[ -n … ]] && export …` block) with:

```bash
load_claude_config() {
    # Delegates to the env-map chokepoint; the generic loop subsumes the old
    # per-variable export block. Kept as a named wrapper for existing callers
    # (lib/nvm/setup.sh, lib/sandbox/status.sh).
    source_iclaude_config
}
```

Leave `setup_isolated_config()` and `disable_auto_updates()` in the file unchanged.

- [ ] **Step 4: Verify no raw config-source sites remain**

Run:
```bash
grep -rn 'source "\$CREDENTIALS_FILE"\|source "\${CREDENTIALS_FILE}"' iclaude.sh lib/
```
Expected: **no output** (every site now goes through `source_iclaude_config`).

- [ ] **Step 5: Syntax-check every touched module**

Run:
```bash
for f in iclaude.sh lib/proxy/credentials.sh lib/proxy/configure.sh lib/nvm/install.sh lib/caveman/install.sh lib/config/isolated.sh; do bash -n "$f" || echo "SYNTAX FAIL: $f"; done; echo done
```
Expected: `done` with no `SYNTAX FAIL` lines.

- [ ] **Step 6: Re-run the full bash test suite touched so far**

Run: `bash tests/test_env_map.sh && bash tests/test_config_migration.sh && bash tests/test_persistent_toggles.sh`
Expected: all three print `PASS=N FAIL=0`.

- [ ] **Step 7: Commit**

```bash
git add iclaude.sh lib/proxy/credentials.sh lib/proxy/configure.sh lib/nvm/install.sh lib/caveman/install.sh lib/config/isolated.sh
git commit -m "refactor(config): route all 9 source sites through source_iclaude_config"
```

---

## Task 5: Rewrite `.claude_config.example`

**Files:**
- Modify: `.claude_config.example`

- [ ] **Step 1: Apply the rename transform (active + commented examples)**

Run this `sed` pipeline (GNU sed) to a temp file, then review before replacing:

```bash
sed -E \
  -e 's/^([[:space:]]*#?[[:space:]]*)export[[:space:]]+/\1/' \
  -e 's/^([[:space:]]*#?[[:space:]]*)([A-Za-z_][A-Za-z0-9_]*=)/\1ICLAUDE_\2/' \
  -e 's/ICLAUDE_ICLAUDE_/ICLAUDE_/' \
  .claude_config.example > .claude_config.example.new
```

Pass 1 strips `export` (active and `# export` examples). Pass 2 prefixes every
`NAME=` (active and `# NAME=` examples). Pass 3 collapses the accidental double
prefix on names that were already `ICLAUDE_*`.

- [ ] **Step 2: Review the diff for false matches**

Run: `diff -u .claude_config.example .claude_config.example.new | less`
Check specifically:
- No prose line (one that isn't a real variable example) got an `ICLAUDE_` prefix.
- Native vars are exactly `ICLAUDE_CHAT_LANG`, `ICLAUDE_DOC_LANG` (not doubled, not de-prefixed).
- Provider keys became `ICLAUDE_DEEPSEEK_API_KEY` etc.
- No `export` keyword remains: `grep -nE '^[[:space:]]*#?[[:space:]]*export ' .claude_config.example.new` → no output.

Hand-fix any false match directly in `.claude_config.example.new`.

- [ ] **Step 3: Update the header comment block**

In `.claude_config.example.new`, update the top doc comment to state the new convention. Replace the line:

```
# Формат: bash-переменные (KEY=value или export KEY=value)
```

with:

```
# Формат: bash-переменные с префиксом ICLAUDE_ (ICLAUDE_KEY=value), без export.
# Слой трансляции (lib/config/env-map.sh) снимает префикс и экспортирует
# каноническое имя, которое читают встроенные инструменты.
# Старый .claude_config (без префикса / с export) мигрируется автоматически
# при первом запуске (создаётся резервная копия .claude_config.bak).
```

- [ ] **Step 4: Promote the new file and sanity-check it sources cleanly**

```bash
mv .claude_config.example.new .claude_config.example
bash -n .claude_config.example && echo "SYNTAX OK"
# Confirm every active assignment is ICLAUDE_-prefixed (no active non-prefixed assignment):
grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' .claude_config.example | grep -vE '^[[:space:]]*ICLAUDE_' && echo "LEAK ↑" || echo "ALL PREFIXED"
```
Expected: `SYNTAX OK` then `ALL PREFIXED`.

- [ ] **Step 5: End-to-end translation check using the example as a config**

```bash
CREDENTIALS_FILE="$(pwd)/.claude_config.example" bash -c '
  print_info(){ :; }; print_warning(){ :; }; print_error(){ :; }
  source lib/config/env-map.sh
  # Set one representative value, then translate.
  ICLAUDE_DEEPSEEK_API_KEY=sk-demo; ICLAUDE_PROXY_URL=https://h:8118
  apply_iclaude_env_map
  [[ "${DEEPSEEK_API_KEY:-}" == "sk-demo" && "${PROXY_URL:-}" == "https://h:8118" ]] && echo "TRANSLATE OK" || echo "TRANSLATE FAIL"
'
```
Expected: `TRANSLATE OK`.

- [ ] **Step 6: Commit**

```bash
git add .claude_config.example
git commit -m "docs(config): rewrite .claude_config.example under ICLAUDE_ prefix"
```

---

## Task 6: Update doc/hint strings

**Files:**
- Modify: `lib/command/usage.sh`, `lib/pii-proxy/install.sh`, `lib/sandbox/install.sh`, `lib/sandbox/status.sh`, `lib/iwiki/install.sh`, `docs/CONFIGURATION.md`, `docs/PII_MASKING.md`, `docs/MICROVM.md`, `docs/ROUTER.md`, `CLAUDE.md`

- [ ] **Step 1: Update hint strings in lib/**

Apply these renames in the user-facing hint strings (search-and-replace each, verifying context):

- `lib/command/usage.sh`: `USE_PII_PROXY=true` → `ICLAUDE_USE_PII_PROXY=true`; `MICRO_VM_ENABLED=true` → `ICLAUDE_MICRO_VM_ENABLED=true`.
- `lib/pii-proxy/install.sh`: `add USE_PII_PROXY=true to .claude_config` → `add ICLAUDE_USE_PII_PROXY=true to .claude_config`.
- `lib/sandbox/status.sh`: `Set MICRO_VM_MEM_MB=2048` → `Set ICLAUDE_MICRO_VM_MEM_MB=2048`; `add MICRO_VM_ENABLED=true` → `add ICLAUDE_MICRO_VM_ENABLED=true`.
- `lib/sandbox/install.sh`: the three `Pin: export MICRO_VM_*_SHA256=… # add to .claude_config` hints → drop `export`, prefix the var (`Pin: ICLAUDE_MICRO_VM_FC_SHA256=… # add to .claude_config`, and the KERNEL / ROOTFS equivalents); `add MICRO_VM_ENABLED=true` → `add ICLAUDE_MICRO_VM_ENABLED=true`.
- `lib/iwiki/install.sh`: `Configure IWIKI_LLM_BASE_URL / IWIKI_LLM_KEY / IWIKI_EMBED_MODEL in .claude_config` → `Configure ICLAUDE_IWIKI_LLM_BASE_URL / ICLAUDE_IWIKI_LLM_KEY / ICLAUDE_IWIKI_EMBED_MODEL in .claude_config`.

- [ ] **Step 2: Find any remaining legacy hint strings**

Run:
```bash
grep -rnE '(export[[:space:]]+)?(USE_PII_PROXY|MICRO_VM_[A-Z_]+|USE_LANGFUSE_CAPTURE|IWIKI_[A-Z_]+|DEEPSEEK_API_KEY|USE_CHROME|NO_ATTRIBUTION_HEADER)[[:space:]]*=' lib/ docs/ CLAUDE.md \
  | grep -i '\.claude_config\|add \|set \|export ' | grep -v 'ICLAUDE_'
```
Review each remaining hit; rename to the `ICLAUDE_` form where it is a `.claude_config` instruction. (Pattern-matching `grep -E` lines inside `iclaude.sh`/hooks that parse env are NOT hint strings — skip those.)

- [ ] **Step 3: Update `docs/` and `CLAUDE.md` config examples**

In `docs/CONFIGURATION.md`, `docs/PII_MASKING.md`, `docs/MICROVM.md`, `docs/ROUTER.md`, and the `CLAUDE.md` mentions, rename every `.claude_config` variable example to `ICLAUDE_*` and drop `export` (e.g. the iwiki block `export IWIKI_LLM_BASE_URL=…` → `ICLAUDE_IWIKI_LLM_BASE_URL=…`, the router `export DEEPSEEK_API_KEY=…` → `ICLAUDE_DEEPSEEK_API_KEY=…`, `USE_PII_PROXY=true` → `ICLAUDE_USE_PII_PROXY=true`). Add a one-line note in `docs/CONFIGURATION.md` that the prefix is mandatory and legacy files auto-migrate.

- [ ] **Step 4: Verify no stray launch-affecting legacy names remain in docs**

Run:
```bash
grep -rn 'export ' docs/CONFIGURATION.md docs/ROUTER.md docs/PII_MASKING.md docs/MICROVM.md | grep -iE 'API_KEY|IWIKI_|MICRO_VM_|PROXY|PII_'
```
Expected: no output (all config examples are now bare `ICLAUDE_*`).

- [ ] **Step 5: Commit**

```bash
git add lib/ docs/ CLAUDE.md
git commit -m "docs(config): ICLAUDE_ prefix in hint strings and docs"
```

---

## Task 7: Final verification + iwiki refresh

**Files:** none (verification + docs/wiki)

- [ ] **Step 1: Syntax-check the whole tree**

Run:
```bash
bash -n iclaude.sh && for f in lib/**/*.sh; do bash -n "$f" || echo "FAIL $f"; done; echo "syntax done"
```
Expected: `syntax done`, no `FAIL` lines. (If `**` globbing is off, use `find lib -name '*.sh' -exec bash -n {} \;`.)

- [ ] **Step 2: Run all new bash unit tests**

Run:
```bash
bash tests/test_env_map.sh && bash tests/test_config_migration.sh && bash tests/test_persistent_toggles.sh && echo "UNIT OK"
```
Expected: each prints `FAIL=0`, then `UNIT OK`.

- [ ] **Step 3: Smoke-test launch paths**

Run:
```bash
./iclaude.sh --check-isolated; echo "exit: $?"
./iclaude.sh --test; echo "exit: $?"
```
Expected: both run without "variable not set"/config-resolution errors. Proxy/isolation status reflects the current `.claude_config` (translated `ICLAUDE_*` values). Note: `--test` requires a configured proxy; absence of a proxy is an acceptable, clearly-reported outcome, not a regression.

- [ ] **Step 4: Manual migration smoke (disposable copy)**

Run:
```bash
tmp=$(mktemp -d); cp -r . "$tmp/repo" 2>/dev/null
printf 'export DEEPSEEK_API_KEY=sk-x\nUSE_PII_PROXY=true\n' > "$tmp/repo/.claude_config"
( cd "$tmp/repo" && ./iclaude.sh --check-isolated >/dev/null 2>&1; \
  grep -q 'ICLAUDE_DEEPSEEK_API_KEY=sk-x' .claude_config && grep -q 'ICLAUDE_USE_PII_PROXY=true' .claude_config \
  && test -f .claude_config.bak && echo "MIGRATE SMOKE OK" || echo "MIGRATE SMOKE FAIL" )
rm -rf "$tmp"
```
Expected: `MIGRATE SMOKE OK`.

- [ ] **Step 5: iwiki refresh (project post-task checklist)**

Run the iwiki ingest for the changed config surface, then lint:
```bash
# via skills: iwiki:iwiki-ingest on lib/config/env-map.sh and .claude_config.example
```
Then `/iwiki-lint` — expect no broken `[[refs]]`, no orphan/stale pages. (Skip only if `docs/wiki/` is not present.)

- [ ] **Step 6: Final commit (if iwiki produced changes)**

```bash
git add docs/wiki/
git commit -m "docs(wiki): ingest ICLAUDE_ config env-map"
```

---

## Self-Review notes (author)

- **Spec coverage:** taxonomy (T1 module arrays), translation convention+denylist (T1), allow-empty `PII_PROXY_MASK_TOKEN` (T1 test), auto-migration + `.bak` + idempotency (T2), Phase-0 source + migrate-before-grep ordering (T3), 5 grep readers (T3), all 9 source sites + `load_claude_config` wrapper (T4), example full rewrite (T5), docs/hints (T6), tests + smoke + iwiki (T7). No spec section left without a task.
- **Naming consistency:** `source_iclaude_config`, `apply_iclaude_env_map`, `migrate_legacy_config`, `_config_is_legacy`, `_in_list`, `ICLAUDE_NATIVE`, `ICLAUDE_ALLOW_EMPTY` used identically across T1, T3, T4 tests and call sites.
- **Line-number anchors are pre-change** (506/519/557/574, 227-259, etc.); implementers match by context, since earlier edits shift later numbers within `iclaude.sh`.
