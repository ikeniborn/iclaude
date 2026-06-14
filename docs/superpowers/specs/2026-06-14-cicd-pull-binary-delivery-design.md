---
review:
  spec_hash: a1ff07f9d0b0c609
  last_run: 2026-06-14
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-06-14-cicd-pull-binary-delivery-intent.md
---

# Design: CI/CD auto-update — deliver new Claude Code binary via `git pull`

**Date:** 2026-06-14
**Status:** approved
**Intent:** [2026-06-14-cicd-pull-binary-delivery-intent.md](../intents/2026-06-14-cicd-pull-binary-delivery-intent.md)

## Problem (root cause)

The scheduled workflow `auto-update-claude.yml` works: it bumps `claudeCodeVersion`
in `package.json` + `.nvm-isolated-lockfile.json` and commits the **6 git-tracked
metadata files** to `dev`. But since **v2.1.114** Claude Code ships as a native
binary `bin/claude.exe` (~250MB), which is **gitignored** (`.gitignore:153`, `:191`)
— it exceeds GitHub's 100MB limit. So `git pull` delivers the version-number bump
but **not the executable**; the on-disk binary stays old until a manual
`iclaude --update`.

Two code-level findings sharpen this:

1. **Latent false-negative in `check_lockfile_changes()`** (`lib/lockfile/save.sh:343-364`).
   After a pull it detects the lockfile changed, then compares the lockfile version
   against `node_modules/@anthropic-ai/claude-code/package.json` `.version`. But
   `package.json` is one of the 6 tracked files — `git pull` already updated it to
   the new version, while the real binary is still old. The check therefore reports
   "up to date" and silently skips the refresh. Even launching iclaude after a pull
   never fixes the binary.

2. **`.githooks/` already exists** and `core.hooksPath=.githooks` is already set by
   `configure_git_hooks()` during `--repair-isolated` (`lib/nvm/repair.sh:319-354`).
   A tracked `.githooks/post-merge` is therefore auto-active with no new install path.

## Acceptance (from intent)

Desired Outcomes (FIXED):
- After `git pull` on `dev`, when the pulled commit bumped `claudeCodeVersion`, the
  on-disk `claude.exe` is brought to match the lockfile version — no manual
  `iclaude --update` required (one `y` keystroke at the prompt is acceptable).
- `claude --version` after a pull reports the version recorded in the lockfile.
- `git pull` itself always succeeds, including offline / no network — the binary
  refresh degrades gracefully.

Done when:
- On a machine carrying an old `claude.exe`, a `git pull` of a `dev` commit that
  bumped `claudeCodeVersion` results in the on-disk binary version automatically
  matching the lockfile (after the y/N prompt), with no manual `iclaude --update`.
- `git pull` still completes when offline (hook degrades gracefully).
- `auto-update-claude.yml` is unaffected.

## Architecture

Two surgical pieces. Both compare the lockfile `claudeCodeVersion` against the
**actual binary** version (`claude --version` — authoritative, not the tracked
`package.json`), both prompt `y/N`, both reuse the existing `--install-from-lockfile`
path.

- **Component A (new): `.githooks/post-merge`** — proactive, fires right after
  `git pull` / merge.
- **Component B (fix): `check_lockfile_changes()`** — reactive safety net at iclaude
  launch, for pulls that bypass git hooks (GUI clients, opt-out, fresh clone before
  `--repair-isolated`).

The shared refresh action is `iclaude.sh --install-from-lockfile`
(`iclaude.sh:393-402` → `install_from_lockfile`, early-exit, no proxy/launch). It
installs `@anthropic-ai/claude-code@<lockfile version>` (deterministic to the pulled
state, not npm-latest), whose postinstall fetches the native binary, then calls
`update_lockfile_hash` — which also prevents a duplicate launch-time prompt.

## Component A — `.githooks/post-merge`

Self-contained bash (no sourcing of `lib/` modules; jq-free). Runs with CWD at repo
root; resolves `REPO_ROOT="$(git rev-parse --show-toplevel)"` like the existing
`.githooks/pre-push`.

Logic:

1. **Opt-out:** `[[ "${ICLAUDE_NO_AUTO_UPDATE:-}" == "1" ]]` → `exit 0`.
2. **Cheap guard:** if `.nvm-isolated-lockfile.json` is not in
   `git diff --name-only ORIG_HEAD HEAD` → `exit 0`. Avoids spawning the 250MB
   binary on every unrelated pull. (`ORIG_HEAD` is set by merge/fast-forward pull;
   if absent, fall back to comparing `@{1}..HEAD`, and on any failure skip the guard
   and proceed to the version check.)
3. **lockver:** `grep -oP '"claudeCodeVersion":\s*"\K[^"]+'` on the lockfile
   (grep, not jq — keep the hook dependency-light, matching `install.sh:30`).
4. **binver:** run `"$REPO_ROOT/.nvm-isolated/npm-global/bin/claude" --version`
   `| grep -oP '\d+\.\d+\.\d+'`. If the binary is missing or unrunnable → `binver=""`.
5. **In sync:** `[[ -n "$lockver" && "$lockver" == "$binver" ]]` → `exit 0`.
6. **Non-interactive:** if no usable `/dev/tty` (CI, piped, GUI background) → print a
   one-line warning + manual hint (`Run: ./iclaude.sh --install-from-lockfile`) and
   `exit 0`. Never prompt, never block.
7. **Prompt:** read `y/N` from `/dev/tty` (`mismatch: <binver> → <lockver>`).
8. **Apply:** on `y` → `"$REPO_ROOT/iclaude.sh" --install-from-lockfile`. On `n` →
   print the manual hint.

Every branch is fail-soft; the script always exits 0 (post-merge exit code is ignored
by git regardless, but explicit 0 documents intent). The file is committed with the
executable bit set.

## Component B — fix `check_lockfile_changes()`

In `lib/lockfile/save.sh`, the installed-version probe (currently lines 350-355,
reading `package.json` `.version`) is replaced with a probe of the **real binary**:

- Run the isolated `claude --version` (path
  `${ISOLATED_NVM_DIR}/npm-global/bin/claude`, falling back to the `bin/claude.exe`
  inside the package dir), extract `\d+\.\d+\.\d+`.
- If the binary is absent/unrunnable → `installed_claude_ver=""`, which falls through
  to the existing "lockfile changed and version differs" warn + y/N prompt (correct:
  a missing/old binary needs an install).

Everything else in the function is untouched: the hash short-circuit, the
non-interactive guard (`[[ ! -t 0 ]]`), the `read -p` prompt, and the
`install_from_lockfile` + `update_lockfile_hash` on `y`. Only the *source of truth*
for "what is installed" changes from the tracked `package.json` to the actual binary.

## Data flow

```
git pull
  └─ .githooks/post-merge
       ├─ opt-out? ──────────────── exit 0
       ├─ lockfile unchanged? ───── exit 0
       ├─ lockver == binver? ────── exit 0
       ├─ no TTY? ── warn + hint ── exit 0
       └─ prompt y/N
            └─ y → iclaude.sh --install-from-lockfile
                     └─ npm i -g @anthropic-ai/claude-code@<lockver>
                          └─ postinstall → fetch native binary (~250MB)
                               └─ update_lockfile_hash

(fallback, if hook skipped)
iclaude launch
  └─ check_lockfile_changes  (now compares lockver vs real binary)
       └─ mismatch → same y/N → install_from_lockfile → update_lockfile_hash
```

## Error handling

| Condition | Behavior |
|-----------|----------|
| `jq` absent | Hook uses `grep` for lockver — no hard jq dependency |
| Binary absent / unrunnable | `binver=""` → treated as mismatch → prompt to install |
| Offline / npm failure during refresh | `install_from_lockfile` returns non-zero; hook prints "run manually"; pull already completed (post-merge) |
| Non-interactive (CI, piped, GUI) | Warn-only, never prompt, never block |
| Opt-out `ICLAUDE_NO_AUTO_UPDATE=1` | Silent `exit 0` |
| `ORIG_HEAD` missing | Fall back to `@{1}..HEAD`; on failure, skip guard and run version check anyway |

## Testing

- `bash -n .githooks/post-merge` and `bash -n lib/lockfile/save.sh` — syntax.
- **Mismatch path:** set lockfile `claudeCodeVersion` to a value ≠ `claude --version`,
  invoke `.githooks/post-merge` with `ORIG_HEAD` set so the lockfile shows as changed;
  assert the y/N prompt appears and `n` leaves the environment untouched with a hint.
- **In-sync path:** equal versions → hook exits 0 silently (no prompt).
- **Non-TTY path:** `echo | .githooks/post-merge` (or run with stdin/`/dev/tty`
  unavailable) → warn-only, exit 0.
- **Opt-out:** `ICLAUDE_NO_AUTO_UPDATE=1 .githooks/post-merge` → silent exit 0.
- **Component B regression:** with binary == lockfile, `check_lockfile_changes` still
  no-ops; with binary != lockfile (simulated), it now reaches the warn + prompt.
- **CI unaffected:** `auto-update-claude.yml` uses checkout + push (no merge into a
  working tree → post-merge does not fire) and runs non-TTY anyway.

## Files touched

- `.githooks/post-merge` — new, executable, ~40 lines.
- `lib/lockfile/save.sh` — `check_lockfile_changes()` version probe (~6 lines).
- Docs: a note in `CLAUDE.md` (Native Binary section) + lat.md update describing the
  pull-time refresh and the `ICLAUDE_NO_AUTO_UPDATE` opt-out.

## Out of scope

- master ↔ dev divergence (separate concern; user pulls `dev`).
- iclaude's own VERSION bump flow (`.githooks/pre-push`) — unrelated to Claude Code
  dependency delivery.
- Putting the binary into git via LFS / GitHub Releases — rejected by the intent's
  hard constraint (binary stays out of git, delivered via npm).
