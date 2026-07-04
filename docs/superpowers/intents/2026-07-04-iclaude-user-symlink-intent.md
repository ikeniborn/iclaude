# Intent: iclaude user-space symlink

**Date:** 2026-07-04
**Status:** approved

## Objective
Make `iclaude` install a user-space launcher like `icodex`, so users can run `iclaude` from any directory without typing the full path to `iclaude.sh`.

The current `iclaude --create-symlink` path differs from `icodex`: it targets `/usr/local/bin/iclaude`, requires `sudo`, and checks for the legacy Claude Code `cli.js` file. Current isolated installs can use the native `bin/claude.exe` plus `.nvm-isolated/npm-global/bin/claude`, so the legacy check can reject a working install.

## Desired Outcomes
- After `./iclaude.sh --isolated-install`, the user can run `iclaude` from any directory without a full script path.
- The launcher symlink is created at `~/.local/bin/iclaude` by default, or at `$ICLAUDE_LINK_DIR/iclaude` when configured.
- Repeated install/update runs do not duplicate shell profile PATH entries and repair stale `iclaude` symlinks.
- An existing non-symlink file named `iclaude` at the target path is left untouched.

## Health Metrics
- Direct repository launch through `./iclaude.sh` continues to work.
- `--repair-isolated` continues to repair internal npm, Node.js, and Claude Code symlinks.
- Any existing `/usr/local/bin/iclaude` launcher is not removed automatically.
- The default user-space install path does not require `sudo`.
- Launching through the symlink still resolves repository-local `lib/` and `.nvm-isolated/` paths correctly.
- Integrated libraries and features keep their behavior: launcher, NVM install/repair, lockfile install, config isolation, router, PII proxy, statusline, LSP, oh-my-posh, GSD, sandbox/microVM, OAuth, Chrome integration, and command dispatch.

## Strategic Context
- Interacts with: `iclaude.sh` CLI dispatch, `lib/core/remaining.sh` legacy install/symlink functions, `lib/nvm/install.sh`, `lib/nvm/repair.sh`, launcher path resolution, README/docs, shell profiles, and the existing `icodex` symlink model.
- Priority trade-off: trust.

## Constraints
### Steering (behavioral guidance)
- Follow the `icodex` launcher UX where practical.
- Keep the change surgical; avoid a broad parser or installer refactor.
- Keep documentation and code comments in English.
- Prefer idempotent behavior and conservative file handling over shorter code.

### Hard (architectural enforcement)
- The default launcher target directory is `~/.local/bin`.
- `$ICLAUDE_LINK_DIR` overrides the default launcher target directory, including leading `~/` expansion.
- The default user-space launcher path must not require `sudo`.
- The symlink target must resolve to the repository `iclaude.sh`.
- Existing non-symlink files at the launcher target must be left untouched.
- Binary health checks must accept current native Claude Code installs (`bin/claude.exe` and/or `.nvm-isolated/npm-global/bin/claude`), not only legacy `cli.js`.
- Do not automatically delete existing user or system symlinks.

## Autonomy Zones
- Full autonomy (reversible, low risk): inspect code, write the intent/spec, and propose design options.
- Guarded (log + confidence threshold): update docs/spec files after user approval.
- Proposal-first (needs approval): changes to install behavior, shell profile PATH edits, and legacy `/usr/local/bin` behavior.
- No autonomy (human only): deleting existing user/system symlinks or modifying `.nvm-isolated` contents outside an explicit install/repair command.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: the design would require replacing the current `iclaude.sh` argument parser or restructuring unrelated install modules.
- Halt if: regression checks show launcher changes break integrated feature wiring.
- Escalate if: user-space launcher behavior conflicts with an existing `/usr/local/bin/iclaude` installation.
- Done when: an approved design specifies user-space `iclaude` launcher behavior, idempotent PATH handling, native Claude Code binary detection, legacy compatibility, and a regression-check matrix covering integrated libraries and features.
