---
review:
  spec_hash: 1464fb23089ef8c9
  last_run: 2026-07-04
  phases:
    structure: { status: passed }
    coverage: { status: passed }
    clarity: { status: passed }
    consistency: { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-07-04-iclaude-user-symlink-intent.md
---
# Design: iclaude user-space symlink

## Acceptance (from intent)
- After `./iclaude.sh --isolated-install`, the user can run `iclaude` from any directory without a full script path.
- The launcher symlink is created at `~/.local/bin/iclaude` by default, or at `$ICLAUDE_LINK_DIR/iclaude` when configured.
- Repeated install/update runs do not duplicate shell profile PATH entries and repair stale `iclaude` symlinks.
- An existing non-symlink file named `iclaude` at the target path is left untouched.
- Done when: an approved design specifies user-space `iclaude` launcher behavior, idempotent PATH handling, native Claude Code binary detection, legacy compatibility, and a regression-check matrix covering integrated libraries and features.

## 1. Context
`iclaude` currently exposes `--create-symlink`, but the implementation is system-scoped:

- it targets `/usr/local/bin/iclaude`;
- it requires `sudo`;
- it validates the isolated install through the legacy Claude Code `cli.js` path.

Current Claude Code installs can use the native package layout: `@anthropic-ai/claude-code/bin/claude.exe` plus `.nvm-isolated/npm-global/bin/claude`. On such installs, the current `--create-symlink` check can reject a working isolated environment.

`icodex` already has the desired model: a user-space launcher in `~/.local/bin`, an override variable for the link directory, conservative non-clobber behavior, and append-only PATH setup.

## 2. Requirements
1. `iclaude` must create a user-space launcher at `~/.local/bin/iclaude` by default.
2. `ICLAUDE_LINK_DIR` must override the launcher directory and expand a leading `~/`.
3. The default launcher path must not require `sudo`.
4. The launcher symlink target must be the repository `iclaude.sh`.
5. Existing non-symlink files at the launcher target must not be overwritten.
6. Existing symlinks at the launcher target may be repaired only when they are symlinks.
7. PATH setup must be idempotent and append-only for bash, zsh, and fish profiles.
8. Isolated install validation must accept native Claude Code layout, npm-global `claude`, and legacy `cli.js`.
9. Existing `/usr/local/bin/iclaude` launchers must not be deleted automatically.
10. Existing direct launch through `./iclaude.sh` and integrated feature wiring must continue to work.

## 3. Architecture
Add `lib/symlink/symlink.sh` as a focused launcher module. It should mirror the `icodex` pattern while using `iclaude` naming and logging helpers.

Functions:

- `iclaude_link_dir`: returns `${ICLAUDE_LINK_DIR:-$HOME/.local/bin}` with leading `~/` expanded.
- `detect_iclaude_isolated_launcher`: returns success when the isolated Claude Code install is usable through any supported layout:
  - executable or symlink `.nvm-isolated/npm-global/bin/claude`;
  - native binary `@anthropic-ai/claude-code/bin/claude.exe`;
  - legacy `@anthropic-ai/claude-code/cli.js`.
- `install_iclaude_symlink`: creates or repairs `<link-dir>/iclaude -> $SCRIPT_DIR/iclaude.sh`. It creates the directory, updates stale symlinks, and leaves existing non-symlink files untouched.
- `ensure_iclaude_path_entry`: checks whether the link directory is already on `PATH`; if not, appends a shell-specific PATH entry with an `iclaude` marker unless the profile already references that directory.
- `uninstall_iclaude_symlink`: removes only the user-space symlink when it points to the current repository `iclaude.sh`; otherwise it warns and leaves the file untouched.

`iclaude.sh` sources this module after core/NVM modules are available and before command dispatch executes symlink commands.

## 4. Command Flow
### 4.1 `--isolated-install`
After successful `install_isolated_nvm`, `install_isolated_nodejs`, and `install_isolated_claude`, call:

1. `install_iclaude_symlink`
2. `ensure_iclaude_path_entry`

The command fails if the isolated installation fails. A symlink/PATH failure should be reported clearly and return non-zero only when the launcher cannot be created; PATH profile write failures should warn with a manual instruction because the launcher itself can still exist.

### 4.2 `--isolated-update`
After a successful isolated update and any existing symlink repair, call:

1. `install_iclaude_symlink`
2. `ensure_iclaude_path_entry`

### 4.3 `--install-from-lockfile`
After a successful lockfile install, call:

1. `install_iclaude_symlink`
2. `ensure_iclaude_path_entry`

### 4.4 `--create-symlink`
Change this flag to the user-space launcher flow:

1. validate the isolated install with `detect_iclaude_isolated_launcher`;
2. create or repair the user-space symlink;
3. ensure PATH.

It must not require `sudo` and must honor `ICLAUDE_LINK_DIR`.

### 4.5 `--uninstall-symlink`
Change this flag to remove only the user-space symlink for the current repository. It must not require `sudo`, must honor `ICLAUDE_LINK_DIR`, and must not remove a non-symlink or a symlink pointing elsewhere.

### 4.6 Legacy System Install
Keep `--install` and `--uninstall` as the legacy `/usr/local/bin` path for this change. Documentation should steer normal isolated users toward `--isolated-install` and `--create-symlink`.

## 5. Data Flow
1. User runs an install/update command.
2. Existing installer creates or updates `.nvm-isolated`.
3. `detect_iclaude_isolated_launcher` confirms that Claude Code is present in a supported layout.
4. `install_iclaude_symlink` writes `<link-dir>/iclaude -> <repo>/iclaude.sh`.
5. `ensure_iclaude_path_entry` makes the launcher directory discoverable in future shells.
6. User runs `iclaude` from another directory.
7. `iclaude.sh` resolves the symlink through its existing `BASH_SOURCE`/`readlink` logic and loads repository-local `lib/` and `.nvm-isolated/`.

## 6. Error Handling
- Missing isolated environment: print a clear instruction to run `./iclaude.sh --isolated-install`.
- Missing Claude Code binary/layout: print a clear instruction to run `./iclaude.sh --repair-isolated` or `./iclaude.sh --isolated-install`.
- Target directory creation failure: return non-zero.
- Existing non-symlink at target: warn, leave untouched, return success to avoid destructive behavior.
- Existing symlink to another target: replace it with the current repository launcher and report the repair.
- Shell profile path is not writable: warn with the directory to add manually, but keep the created symlink.
- Unknown shell: warn with the directory to add manually.

## 7. Testing
Add focused shell tests for `lib/symlink/symlink.sh` using temporary `$HOME`, `ICLAUDE_LINK_DIR`, fake `SCRIPT_DIR`, and fake `.nvm-isolated`.

Required cases:

1. creates `~/.local/bin/iclaude`;
2. repairs a stale symlink;
3. does not overwrite an existing non-symlink;
4. expands `~/custom-bin`;
5. appends PATH once for bash;
6. appends PATH once for zsh;
7. appends PATH once for fish;
8. accepts native `bin/claude.exe`;
9. accepts npm-global `bin/claude`;
10. accepts legacy `cli.js`;
11. fails with a clear message when the isolated environment is missing;
12. `uninstall_iclaude_symlink` removes only a symlink that points to the current repository.

Required syntax/integration checks:

1. `bash -n iclaude.sh` and `bash -n` for changed shell modules and tests.
2. Static check that `--isolated-install`, `--isolated-update`, `--install-from-lockfile`, `--create-symlink`, and `--uninstall-symlink` call the expected symlink helpers.
3. Symlink launch smoke test from another directory using a temporary link dir and a harmless command such as `--help` or `--version`, if available without network or mutating `.nvm-isolated`.

## 8. Integrated Feature Regression Matrix
The implementation plan must include a no-regression pass for these surfaces:

| Surface | Check |
|---|---|
| Direct launch | `./iclaude.sh` still resolves `SCRIPT_DIR` and loads `lib/`. |
| Symlink launch | `iclaude` via temporary link dir resolves repository `lib/` and config paths. |
| NVM install/repair | `--repair-isolated` still manages internal npm, Node.js, and Claude Code symlinks. |
| Lockfile install | `--install-from-lockfile` keeps existing install semantics and then installs the user launcher. |
| Config isolation | `CLAUDE_CONFIG_DIR` remains `.nvm-isolated/.claude-isolated` by default. |
| Router | Router install/status/launch flags remain routed through existing modules. |
| PII proxy | PII install/status/launch flags remain routed through existing modules. |
| Statusline | Statusline install/status module sourcing remains unchanged. |
| LSP | LSP install/repair/status module sourcing remains unchanged. |
| oh-my-posh | Posh install/status module sourcing remains unchanged. |
| GSD | GSD install/status module sourcing remains unchanged. |
| Sandbox/microVM | Sandbox and microVM flags remain routed through existing modules. |
| OAuth | Token refresh path still runs before launch. |
| Chrome | Chrome flags remain parsed and passed through existing launch logic. |
| Command dispatch | Existing pass-through argument behavior remains unchanged. |

## 9. Documentation Updates
Update user-facing docs to show:

- `./iclaude.sh --isolated-install` creates or repairs the user launcher;
- `iclaude` can be run after `~/.local/bin` is on `PATH`;
- `ICLAUDE_LINK_DIR` customizes the launcher directory;
- `--create-symlink` and `--uninstall-symlink` no longer require `sudo`;
- `/usr/local/bin` is legacy system install behavior for `--install`/`--uninstall`.

## 10. Non-Goals
- Do not refactor the entire `iclaude.sh` parser.
- Do not remove `/usr/local/bin` legacy support in this change.
- Do not modify `.nvm-isolated` contents except through existing install/update/repair commands.
- Do not change router, PII, statusline, LSP, oh-my-posh, GSD, sandbox, OAuth, Chrome, or pass-through argument behavior.
