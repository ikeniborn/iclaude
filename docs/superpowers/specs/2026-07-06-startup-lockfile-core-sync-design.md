---
review:
  spec_hash: e85969ccc00c8ada
  last_run: 2026-07-06
  phases:
    structure: { status: passed }
    coverage: { status: passed }
    clarity: { status: passed }
    consistency: { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-07-06-startup-lockfile-core-sync-intent.md
---
# Design: startup lockfile core sync

## Acceptance (from intent)
- When the user accepts the startup lockfile prompt, the core isolated environment is synchronized and launch continues without running LSP server or plugin restore.
- After a successful startup core sync, the stored lockfile hash is updated so the next launch does not ask the same prompt again.
- LSP restore remains available through an explicit user action, and only applies to LSP servers or plugins that are already represented in the lockfile and/or Claude Code project state.
- Done when: tests or executable shell checks show that the startup lockfile prompt performs core sync without LSP restore, manual full restore can still restore LSP entries, and successful core sync prevents the same lockfile prompt from repeating on the next startup.

## 1. Context
`check_lockfile_changes()` detects when `.nvm-isolated-lockfile.json` differs from the last applied hash. In an interactive shell it currently offers to run `--install-from-lockfile` immediately.

`install_from_lockfile()` is a full reproducibility restore. It installs Node.js, Claude Code, optional router/GSD packages, LSP servers, and LSP plugins from the lockfile. That is the right behavior for a manual restore, but too broad for a startup prompt whose practical purpose is to keep the core isolated Claude Code runtime in sync after a pull.

The trust issue is scope mismatch: the prompt looks like a routine environment sync, but accepting it can trigger optional LSP npm/plugin installation.

## 2. Requirements
1. Startup lockfile handling must call a core-only restore path when the user accepts the prompt.
2. The core-only restore path must install or activate only `nodeVersion` and `claudeCodeVersion` from `.nvm-isolated-lockfile.json`.
3. A successful core-only restore must update the stored lockfile hash so the same prompt does not repeat on the next launch.
4. A failed core-only restore must not update the stored lockfile hash.
5. Startup lockfile handling must not fall back to full restore when the core-only function is missing or fails.
6. The interactive prompt text must describe core isolated environment sync, not full lockfile restore.
7. Non-interactive startup behavior must remain warning-only and must not prompt.
8. Declining the prompt must continue launch without updating the stored hash.
9. Manual `--install-from-lockfile` behavior must remain full restore, including LSP server and plugin restore.
10. The lockfile JSON schema must not change.

## 3. Architecture
Add `install_core_from_lockfile()` to `lib/lockfile/install.sh`.

The new function is an internal startup-sync helper. It uses the same lockfile fields and setup primitives as `install_from_lockfile()`:

- read `nodeVersion` with the current fallback to `22`;
- read `claudeCodeVersion` with the current fallback to latest when empty or `unknown`;
- ensure isolated NVM exists;
- call `setup_isolated_nvm`;
- install/use the lockfile Node.js version, including the existing Node TLS fallback path;
- install pinned Claude Code, or latest when no known pinned version exists.

The function must not read or apply:

- `routerVersion`;
- `gsdVersion`;
- `lspServers`;
- `lspPlugins`.

Keep `install_from_lockfile()` as the public full restore orchestration. It can keep its current broad behavior and remain the implementation behind the manual `--install-from-lockfile` command.

## 4. Startup Flow
`check_lockfile_changes()` keeps its existing detection sequence:

1. skip when no lockfile exists;
2. compute current hash;
3. initialize hash silently on first run;
4. return when current hash matches stored hash;
5. fast-pass when the installed Claude Code binary already matches the lockfile version;
6. otherwise warn and, if interactive, ask the user.

Only the accepted-prompt branch changes:

1. print that the core isolated environment will be updated from the lockfile;
2. require `install_core_from_lockfile` to exist;
3. call `install_core_from_lockfile`;
4. on success, call `update_lockfile_hash` and print success;
5. on failure, warn and leave the hash unchanged.

There is no fallback from `install_core_from_lockfile` to `install_from_lockfile` in this startup branch. Falling back would silently reintroduce the LSP restore behavior the design removes.

## 5. Data Flow
1. User pulls a changed `.nvm-isolated-lockfile.json`.
2. Next interactive `iclaude` launch runs `check_lockfile_changes()`.
3. The function detects hash mismatch and compares the installed Claude Code version to the lockfile version.
4. If the installed version differs, the user sees a core-sync prompt.
5. If the user accepts, `install_core_from_lockfile()` reads `nodeVersion` and `claudeCodeVersion`.
6. Node.js and Claude Code are installed or activated.
7. `update_lockfile_hash()` records the applied lockfile hash.
8. Launch continues. LSP restore is untouched.

Manual full restore keeps this data flow:

1. User runs `./iclaude.sh --install-from-lockfile`.
2. `install_from_lockfile()` reads the full lockfile.
3. Node.js, Claude Code, optional packages, LSP servers, and LSP plugins are restored as before.
4. The stored lockfile hash is updated after success.

## 6. Error Handling
- Missing lockfile in `install_core_from_lockfile`: print the same clear lockfile-not-found error style as `install_from_lockfile` and return non-zero.
- Missing isolated NVM: install it using the existing `install_isolated_nvm` path; return non-zero if that fails.
- Node install/use failure: try the existing Node TLS fallback; return non-zero if fallback fails.
- Claude Code install failure: return non-zero.
- Missing `install_core_from_lockfile` in startup prompt branch: warn that core sync is unavailable, leave the stored hash unchanged, and continue launch.
- User declines prompt: continue launch and leave the stored hash unchanged.
- Non-interactive mode: keep warning-only behavior and tell the user to run manual restore or launch interactively.

## 7. Testing
Add focused shell tests around lockfile startup behavior. Existing tests can be extended if they already isolate `check_lockfile_changes()`.

Required cases:

1. Accepted startup prompt calls `install_core_from_lockfile`, does not call `install_from_lockfile`, and updates the stored hash on success.
2. Accepted startup prompt does not update the stored hash when `install_core_from_lockfile` fails.
3. Accepted startup prompt does not fall back to `install_from_lockfile` when the core function is unavailable.
4. Declined startup prompt does not call either restore function and does not update the stored hash.
5. Non-interactive mode does not call either restore function and does not prompt.
6. Manual `install_from_lockfile()` still contains or exercises the LSP restore path for `lspServers` and `lspPlugins`.
7. `install_core_from_lockfile()` ignores lockfile `lspServers` and `lspPlugins`.

Required syntax checks:

1. `bash -n iclaude.sh`
2. `bash -n lib/lockfile/install.sh`
3. `bash -n lib/lockfile/save.sh`
4. `bash -n` for any changed test files

## 8. Non-Goals
- Do not change the public meaning of `--install-from-lockfile`.
- Do not add or change lockfile JSON fields.
- Do not remove LSP install, restore, status, or plugin behavior.
- Do not refactor the full lockfile installer into a phase framework unless tests prove the small helper design cannot meet the requirements.
- Do not change router, GSD, statusline, symlink, config isolation, sandbox, OAuth, or launch argument behavior.
