---
review:
  plan_hash: dcc50c95954a5769
  last_run: 2026-10-01
  phases:
    structure: { status: passed }
    coverage: { status: passed }
    dependencies: { status: passed }
    verifiability: { status: passed }
    consistency: { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-10-01-per-project-oauth-login-fix-intent.md
  spec: docs/superpowers/specs/2026-10-01-per-project-oauth-login-fix-design.md
---

# Common Project Authorization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution, or superpowers:subagent-driven-development only if separately selected by the user. Steps use checkboxes. User authority overrides automatic commit and delegation instructions.

**Goal:** Make one common native login the default for every isolated project without losing credentials or mixing project settings/history.

**Architecture:** A canonical shared store supplies private project subscription snapshots. Fail-closed locks and baseline compare-and-swap protect credential/account metadata publication; the native launcher supervises project sessions and reconciles after exit. Configuration-directory selection remains separate from authentication policy.

**Tech Stack:** Existing Bash launcher, flock, jq, fixture shell tests; no new runtime dependency.

**Spec:** [Approved design](../specs/2026-10-01-per-project-oauth-login-fix-design.md).

**Status:** proposed; implementation and test results are not yet produced.

## Global Constraints

- Only `ICLAUDE_AUTH_MODE` in `.claude_config` selects `shared` (default) or `project`.
- Config-directory selection does not select auth policy.
- No real credentials, account login, publication, commits, or merge are authorized during development.
- Do not add a new CLI flag, background watcher, external token-refresh request, or custom authentication proxy.
- Settings/history/transcript files remain untouched by authentication reconciliation.
- System-mode credentials are outside the isolated-store migration.
- Native `/login` typed inside an already running project becomes common only after that project process exits and successful publication.

Here, prohibited publication means external delivery and real credential migration; synthetic CAS publication inside disposable tests is necessary to verify R3. Wiki proposal/evidence updates remain authorized.

## File Boundaries and Execution

Modify `lib/config/env-map.sh` for config-only policy; `lib/config/isolated.sh` for the credential exception; `lib/oauth/token.sh` for legacy explicit token behavior; `iclaude.sh` for module loading and removing premature native token materialization; `lib/launcher/launch.sh` for native lifecycle integration; `README.md` for usage.

Create `lib/oauth/persistence.sh` for subscription projection, baselines, locks and reconciliation. Create `tests/test_oauth_policy.sh`, `tests/test_oauth_persistence.sh`, and `tests/test_oauth_launch.sh`. Update `tests/test_shared_asset_links.sh`; extend existing regressions only where their expectation actually changes.

Execute Tasks 1–4 in order. Each task owns its listed files and its failing/passing tests. Parent performs reviews and ledger writes; no delegation assumed. Tasks 1 and 3 use engineering guidance; Task 2 and final authentication/concurrency review use deep guidance. Catalog resolution is unavailable; continue on active parent model.

HUMAN CHECKPOINT: checked plan approval precedes code edits. Commit, external delivery, real login, real credential migration and merge require separate authorization. Existing dirty router/config/gitignore/backup files are excluded.

## Task 1: Config-Only Authentication Policy

**Closes:** R1 policy/source selection; R4 explicit versus automatic setup-token; default common login independent of directory flags.

**Files:** Modify `lib/config/env-map.sh`, `lib/oauth/token.sh`; create `tests/test_oauth_policy.sh`.

**Interfaces:** `source_iclaude_config()` sets shell-local `ICLAUDE_AUTH_MODE` to validated `shared|project` after resetting inherited values. Invalid input returns nonzero. Do not map/export an `AUTH_MODE` alias. Existing explicit `refresh_oauth_token()` remains callable; automatic subscription launch must not invoke it (Task 3).

- [ ] Step 1.1: Write fixture assertions for absent/shared/project/invalid config, inherited values, repeated source, directory flags and legacy setup-token. The test uses a temporary config path and shell-local stubs only.

```bash
export ICLAUDE_AUTH_MODE=project AUTH_MODE=project
CREDENTIALS_FILE="$fixture_dir/empty.conf"
: > "$CREDENTIALS_FILE"
source_iclaude_config
[[ "$ICLAUDE_AUTH_MODE" == shared ]]
```

Run the new test before implementation; expected nonzero because inherited policy currently survives. Record exact assertion, not a missing prerequisite.

```bash
bash tests/test_oauth_policy.sh
```

- [ ] Step 1.2: Reset policy immediately before each config source, validate afterwards, and keep it outside generic de-prefix environment mapping. Preserve existing config mapping and explicit setup-token workflow.

```bash
ICLAUDE_AUTH_MODE=shared
if [[ -f "${CREDENTIALS_FILE:-}" ]]; then
    source "$CREDENTIALS_FILE"
fi
case "$ICLAUDE_AUTH_MODE" in
    shared|project) ;;
    *) print_error "Invalid ICLAUDE_AUTH_MODE: expected shared or project"; return 1 ;;
esac
```

DoD: inherited variables never select policy; project config does; invalid config fails before auth writes. Verify syntax and focused/old mapping tests; expected exit 0.

```bash
bash -n lib/config/env-map.sh lib/oauth/token.sh
bash tests/test_oauth_policy.sh
bash tests/test_env_map.sh
```

## Task 2: Preserved Subscription Snapshots and CAS

**Closes:** R2 snapshot/state separation and all R3 data/concurrency invariants. Depends on Task 1 policy.

**Files:** Create `lib/oauth/persistence.sh`, `tests/test_oauth_persistence.sh`; modify `lib/config/isolated.sh`, `tests/test_shared_asset_links.sh`.

**Interfaces:** `oauth_prepare_home(store, home)` prepares a coherent snapshot under store-then-home exclusive locks; `oauth_reconcile_home(store, home)` publishes only same-account safe changes; both return 0 on success and nonzero on conflict, lock or I/O failure. `oauth_select_source(store, home)` sets the launch environment after the last config reload, preferring persisted native subscription with refresh token over configured environment token. `oauth_run_common(store, command...)` holds exclusive store lock for native setup/login. Functions take explicit directories, never infer real user homes in tests.

Private metadata: `.iclaude-auth-baseline.json` stores version 1, canonical subscription/account projection and fingerprints; `.iclaude-auth-recovery` blocks preparation after unsuccessful rollback. Auth lock paths are outside native JSON files. Backups are mode 0600, unique and retained; snapshots mode 0600. Reject unavailable flock and timeout before mutation.

- [ ] Step 2.1: Create synthetic store/home helpers and a preservation matrix. Inputs include subscription A/B, unrelated `mcpOAuth`, account A/B, onboarding metadata, custom config keys, settings and history. Hash preservation-sensitive fixture files before/after operations.

```bash
oauth_prepare_home "$store" "$home"
[[ ! -L "$home/.credentials.json" ]]
[[ "$(jq -r '.claudeAiOauth.accessToken' "$home/.credentials.json")" == fixture-A ]]
[[ "$(jq -r '.mcpOAuth.local' "$home/.credentials.json")" == preserved ]]
cmp "$fixture_dir/settings.before" "$home/settings.json"
cmp "$fixture_dir/history.before" "$home/history.jsonl"
```

Before implementation expect a failing missing persistence function. Extend assertions to common MCP secrets never copied, independent conflict files byte-identical, known credential symlink backed up/detached, unknown target rejected, equal independent credentials baselined without rewriting, and project-mode detachment without common publication.

```bash
bash tests/test_oauth_persistence.sh
```

- [ ] Step 2.2: Remove only `.credentials.json` from `_ICLAUDE_SHARED_LINK_ENTRIES`. Build subscription projection from `claudeAiOauth`, and authentication metadata from native account/onboarding keys present in the fixtures; preserve unrelated home JSON values. Baseline must include actual account identity and metadata, not just token text. Never create synthetic completion metadata in runtime code.

The credential merge expression is subscription-only:

```bash
jq -s '.[0] as $home | .[1] as $store | $home + {claudeAiOauth: $store.claudeAiOauth}' "$home_credentials" "$store_credentials"
```

Execute this only after validation/locks/backups, write to a private staged file, and preserve original files until successful pair replacement. Missing optional home file starts with an empty object. Invalid JSON, missing identity or incompatible independent state returns conflict; never silently guesses an account.

DoD: snapshot and preservation matrix passes; updated asset test asserts credentials are not disposable shared links while all other asset links retain behavior.

```bash
bash -n lib/oauth/persistence.sh lib/config/isolated.sh
bash tests/test_oauth_persistence.sh
bash tests/test_shared_asset_links.sh
bash tests/test_home_migration.sh
```

- [ ] Step 2.3: Add and implement the baseline decision matrix under fail-closed locks. Pair comparisons use canonical JSON projections; preserve byte backups separately.

```text
home == baseline, store != baseline -> refresh home
home != baseline, store == baseline, same identity -> publish home
home == store -> record baseline
otherwise -> conflict, preserve both
deleted/logout/different identity/unknown baseline -> conflict, no resurrection
```

Snapshot replacement requires an exclusive home lock; active native sessions share its reader lock. Ordinary model sessions do not hold store lock. Stage credentials plus metadata, backup old pair, replace while store lock held, rollback both on failure. Failed rollback writes recovery marker and blocks next preparation.

Add two concurrent publishers from one baseline, simultaneous unchanged readers, exclusive writer timeout, missing flock, failed second replacement, rollback failure, deletion and different-account cases. Fixture wrappers inject write failure without changing runtime API or exposing tokens. Assert at most one divergent publisher succeeds, losers preserve their own artifacts, and recovery marker prevents any later native invocation.

```bash
bash tests/test_oauth_persistence.sh
bash tests/test_lock_safety.sh
```

DoD: all matrix/failure/concurrency assertions exit 0; no unlocked-write fallback and no auth secret in captured diagnostics.

## Task 3: Native Setup, Source Selection and Session Supervision

**Closes:** R1 automatic common setup/login; R3 native publication/signals; R4 failures; R5 launcher/provider boundaries. Depends on Tasks 1–2.

**Files:** Modify `iclaude.sh`, `lib/launcher/launch.sh`, `lib/oauth/token.sh`; extend `lib/oauth/persistence.sh`; create `tests/test_oauth_launch.sh`.

**Interfaces:** `oauth_run_session(store, home, command...)` prepares/auth-selects, holds shared home lock during native child, forwards signals, releases reader lock before `oauth_reconcile_home`, and returns native nonzero status unchanged. Native success plus reconciliation failure returns 73. `oauth_run_common` handles shared-mode execution and native auth login/setup under exclusive store lock. Temporary environment suppression is launch-local; config-file tokens remain unchanged.

- [ ] Step 3.1: Build fake-native scripts that log non-secret invocation metadata, create only fixture account files, fail with configured codes or wait for signals. Assert missing setup invokes common directory, existing setup invokes project directory, cancellation stops, noninteractive setup fails, explicit auth login invokes common without directory flag, configured stale token is absent for native interactive credentials, and legacy token remains selected when no canonical interactive login exists. Expect failure before wiring.

```bash
oauth_run_session "$store" "$home" "$fake_native"
[[ "$(< "$fixture_dir/invoked-config-dir")" == "$home" ]]
[[ "$(< "$fixture_dir/invoked-env-token-present")" == no ]]
```

```bash
bash tests/test_oauth_launch.sh
```

- [ ] Step 3.2: Load persistence module before native launch, not inside generic asset repair. Remove premature native environment-token stub materialization; after final config reload, validate common real metadata/login or perform native interactive setup under lock. Verify persisted files after setup; missing state/cancellation never continues. Noninteractive missing state provides actionable setup instruction without opening browser. Explicit login suppresses configured env token even for an access-only stub.

Use the actual resolved native command array and existing flags/environment; never reconstruct from a string. Standard and proxy native branches call the same supervisor. The supervisor's control flow is:

```text
prepare/select -> acquire home reader lock -> spawn native child
forward TERM/INT/HUP and wait -> release reader lock -> reconcile
native failure: preserve failure status; successful native + failed reconcile: 73
```

Preserve existing proxy cleanup traps. Do not introduce automatic setup-token/browser retries. Project policy routes native login locally and disables distribution/publication; shared config uses canonical auth lock; system mode stays outside migration. Router/API flows retain behavior; unsupported subscription microVM/router combinations fail before mutation instead of choosing another source.

DoD: fake login, same/other project relaunch, shared/project modes, native revoked code, publication code 73 and signal assertions all pass; fake-native invocation trace contains no token values and zero automatic setup-token calls.

```bash
bash -n iclaude.sh lib/launcher/launch.sh lib/oauth/token.sh lib/oauth/persistence.sh
bash tests/test_oauth_launch.sh
bash tests/test_launch_wiring_home_state.sh
bash tests/test_langfuse_capture_launch_unit.sh
bash tests/test_per_project_home.sh
bash tests/test_settings_managed_region.sh
bash tests/test_ihar_migration_lock.sh
```

## Task 4: Contract Documentation and Final Evidence

**Closes:** R5 documentation/GWT and intent health metrics; depends on Tasks 1–3.

**Files:** Modify `README.md`; update remote iwiki `architecture/per-project-homes`, `specification/shared-asset-symlink-layer` and task/history pages through MCP CAS writes only. Record final verification evidence in this plan's result metadata, not as premature checked boxes.

- [ ] Step 4.1: Document exact default/opt-out and migration-conflict behavior, source precedence, native slash-command delay, unsupported combinations and blocked live validation. README configuration example:

```bash
ICLAUDE_AUTH_MODE=shared
```

Explain absent value is identical; `project` is config-file-only opt-out, not an environment/CLI selector. Read current wiki pages/scenario context before modification. HUMAN CHECKPOINT: review the proposed replacement credential scenario contract and bindings before mutating its specification page; preserve unaffected scenario IDs. Use only canonical GWT grammar obtained through `wiki_spec_context`. Link implemented/test selectors to the actual functions; no invented schema.

DoD: local docs match passing fixtures; remote CAS writes succeed; wiki lint has no current-task/specification errors. Existing unrelated domain lint findings remain reported, not silently repaired. Graph unavailable/stale evidence never claims resolved bindings; rebuild local graph only where checkout available, and obey separate external publication authority.

- [ ] Step 4.2: Freeze relevant runtime/test inputs and record Git revision plus changed-file hashes. Run focused tests first, then applicable full fixture-safe suite once on that unchanged state. Full-suite inventory is every repository shell/Python test, classified before execution by fixture safety and explicit external prerequisites. Run safe entries in a disposable repository copy with temporary HOME/config/store and stub native CLI; never point regression-phase0 at this live checkout. Do not copy real credentials, `.claude_config*`, `.claude-homes`, `.claude-isolated`, router secrets or user histories into the sandbox. Tests requiring installed binaries, microVM, root networking, service access or real account access are recorded blocked unless satisfied without touching real state. Do not equate focused passes with repository full-suite completion.

Focused command set includes all Task 1–3 commands. Inventory command:

```bash
rg --files tests | sort
```

For shell entries use `bash <inventory-path>`; for standalone unittest Python entries use `python3 <inventory-path>`; inspect entry headers to choose existing pytest runners where required. Record each exact executed command, working sandbox, exit status and input fingerprint. Missing prerequisites are blocked, not pass. Avoid adding an unrequested permanent suite runner. If a required applicable check remains blocked, retain completion-pending and report limitation rather than asserting full pass.

DoD: syntax/focused/regression evidence matches final fingerprint; full inventory has explicit pass/fail/blocked outcomes and no real credential writes. If code changes after failure, invalidate affected evidence, diagnose narrowly, and run full suite only after focused recovery.

- [ ] Step 4.3: Run `$check-chain result` against this plan, reconcile all commitments with actual diff/evidence, and record task lifecycle through MCP. No commit/publication/merge follows automatically. DoD: result is OK only when executable claims, documentation and durable ledger agree; otherwise report needs_work or completion-pending with exact remaining item.

## Coverage, Dependencies and Expected Delivery

R1 -> Tasks 1 and 3; R2 -> Task 2; R3 -> Tasks 2 and 3; R4 -> Tasks 1 and 3; R5 -> Tasks 3 and 4. Dependency order: policy -> snapshots/CAS -> native wiring -> docs/final evidence. No task assumes implementation from a later task.

Expected delivery: shared authorization by default, explicit config-file project opt-out, preserved conflicts, isolated project state and tested concurrency/error handling. Not promised: account unblocking, live token acceptance, instantaneous publication of in-session slash login, automatic migration of different real accounts, external infrastructure readiness or unapproved delivery. All checks above describe expected outcomes, not current passing results.
