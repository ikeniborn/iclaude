# Intent: startup lockfile core sync

**Date:** 2026-07-06
**Status:** approved

## Objective
Fix the startup lockfile update flow so accepting the "lockfile changed" prompt synchronizes the core isolated environment without unexpectedly restoring LSP servers or Claude Code LSP plugins.

The current prompt says to run `--install-from-lockfile` when `.nvm-isolated-lockfile.json` changes. That path performs a broad restore: Node.js, Claude Code, optional tools, LSP servers, and plugins. In practice, a user can accept the prompt to refresh Claude Code and then be kept waiting at "Installing LSP servers from lockfile..." even though the startup need was only to bring the core environment back in sync after a pull.

## Desired Outcomes
- When the user accepts the startup lockfile prompt, the core isolated environment is synchronized and launch continues without running LSP server or plugin restore.
- After a successful startup core sync, the stored lockfile hash is updated so the next launch does not ask the same prompt again.
- LSP restore remains available through an explicit user action, and only applies to LSP servers or plugins that are already represented in the lockfile and/or Claude Code project state.

## Health Metrics
- Reproducibility does not regress: a manual full lockfile restore can still reproduce the lockfile contents, including LSP entries.
- Startup UX does not regress: ordinary launch should not block on npm/plugin installation for LSP components.
- Compatibility does not regress: existing command names, tests, and lockfile JSON shape keep working unless the later design explicitly proposes a compatible extension.
- Existing LSP capabilities are not removed.

## Strategic Context
- Interacts with: `check_lockfile_changes()` in `lib/lockfile/save.sh`, `install_from_lockfile()` in `lib/lockfile/install.sh`, `save_isolated_lockfile()` in `lib/lockfile/save.sh`, `lib/lsp/*`, Claude Code plugin commands, `.nvm-isolated-lockfile.json`, and startup launch flow in `iclaude.sh`.
- Priority trade-off: trust.

## Constraints
### Steering (behavioral guidance)
- The startup prompt should accurately describe the scope it applies: core isolated environment sync, not a full lockfile restore.
- Keep the fix surgical and aligned with existing shell module boundaries.
- Prefer explicit user intent over implicit package installation.
- Keep documentation and code comments in English.

### Hard (architectural enforcement)
- Automatic startup lockfile handling must not run npm or Claude Code plugin install for LSP components without separate explicit consent or a flag.
- Full restore from the lockfile must remain available manually so reproducibility is preserved.
- Do not remove existing LSP install, restore, or lockfile capture capabilities.
- Do not change the lockfile schema unless the design first proves that an interpretation-only or flag-based approach cannot meet the outcomes.

## Autonomy Zones
- Full autonomy (reversible, low risk): inspect shell modules, write intent/spec artifacts, propose design options, and add tests around lockfile prompt behavior.
- Guarded (log + confidence threshold): adjust prompt/help text and choose a small flag name if the approved design needs one.
- Proposal-first (needs approval): lockfile schema changes, command semantics changes visible to users, or any change that narrows full restore behavior.
- No autonomy (human only): deleting existing LSP functionality or removing the ability to restore LSP from the lockfile.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: the design depends on reliably detecting Claude Code plugin installed/enabled state and the current CLI/API cannot provide that signal.
- Halt if: preserving both core-only startup sync and manual full restore would require a broad rewrite of unrelated launch or parser modules.
- Escalate if: a proposed flag or command name would be ambiguous with existing `--install-from-lockfile` behavior.
- Done when: tests or executable shell checks show that the startup lockfile prompt performs core sync without LSP restore, manual full restore can still restore LSP entries, and successful core sync prevents the same lockfile prompt from repeating on the next startup.
