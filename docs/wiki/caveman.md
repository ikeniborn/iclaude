# Caveman Module

## Overview

`lib/caveman/install.sh` installs "caveman mode" into the isolated Claude Code environment — a token-compression ruleset that makes Claude reply tersely. It downloads four JS hooks plus a skill file and wires two hook events into the isolated `settings.json` (see [[config]]). Covers installation, hook wiring, activation levels, language preservation, language resolution, and status/removal.

## Installation

`install_caveman()` downloads hook files into `$CLAUDE_CONFIG_DIR/hooks/` and patches `settings.json`. It is idempotent — safe to re-run. Driven from `iclaude.sh` via `--install-caveman` (rejected with `--system`; isolated env only).

The four downloaded hook files (`_CAVEMAN_HOOK_FILES`) are `caveman-activate.js`, `caveman-config.js`, `caveman-mode-tracker.js`, and `caveman-stats.js`, fetched from the upstream `JuliusBrussee/caveman` repo (`_CAVEMAN_HOOKS_BASE`). `SKILL.md` is downloaded into `$CLAUDE_CONFIG_DIR/skills/caveman/`; if one already exists it is saved as `SKILL.md.new` for manual review.

Download strategy is layered for ALT Linux TLS quirks: `curl` (with [[proxy]] args from `.claude_config` — `PROXY_URL`, `PROXY_CA`, `PROXY_INSECURE`) is the fast path; on curl exit 35 it falls back to `GIT_SSL_NO_VERIFY=1 git clone` with `OPENSSL_CONF=/dev/null`, then `_caveman_python_download()` (python3 `urllib` with `ssl.CERT_NONE`) as last resort. The current upstream commit SHA is recorded in `$CLAUDE_CONFIG_DIR/caveman-version` via `git ls-remote`.

## Hooks Installed

`install_caveman()` patches the `hooks` block of the isolated `settings.json`, registering two events. Each entry is `{type: command, timeout: 5, statusMessage}`. The patch first removes any prior caveman entries (matched by filename regex), then appends the canonical form, keeping the file idempotent.

| Event | Command | Purpose |
|-------|---------|---------|
| `SessionStart` | `node "$CLAUDE_CONFIG_DIR/hooks/caveman-activate.js"` | Writes the `.caveman-active` flag, emits the caveman ruleset as session context. |
| `UserPromptSubmit` | `node "$CLAUDE_CONFIG_DIR/hooks/caveman-mode-tracker.js"` | Tracks the active mode per prompt. |

`caveman-activate.js` reads the active level from `caveman-config.js::getDefaultMode()`, then emits the matching ruleset (filtered from `SKILL.md`, with a hardcoded fallback if the skill file is absent). It also writes a symlink-safe flag file at `$CLAUDE_CONFIG_DIR/.caveman-active` that [[statusline]] reads, and nudges setup of a caveman statusline badge if `settings.json` has no `statusLine` key. The other downloaded files are helpers: `caveman-config.js` (mode resolver + symlink-safe flag I/O) and `caveman-stats.js` (usage stats). No `Stop` hook is wired by this install function.

## Activation Levels

The active mode comes from `getDefaultMode()` in `caveman-config.js`, resolved in order: the `CAVEMAN_DEFAULT_MODE` environment variable, then a `caveman/config.json` file (`XDG_CONFIG_HOME` / `~/.config` / `%APPDATA%`), then the default `full`.

Valid modes (`VALID_MODES`): `off`, the three intensity levels `lite`, `full`, `ultra` (terseness increases left to right), the `wenyan-*` variants, and the independent skill-backed modes `commit`, `review`, `compress`. `off` skips activation entirely and removes the flag file. The launcher ([[launcher]]) exports `CAVEMAN_DEFAULT_MODE` to the hook environment when set, so the level is toggled via that env var (or by config file / in-session `/caveman lite|full|ultra`).

## Language Preservation

Caveman compresses words, not language: terse output stays in the conversation's language and never drifts to English just to compress. Documentation, code comments, commit messages, and PRs follow a separate documentation language.

The generic principle lives in three mirrored places so it survives context compaction and competing per-turn style injections: a `## Language` section in `SKILL.md` (the source of truth `caveman-activate.js` filters at runtime), the hardcoded fallback ruleset inside `caveman-activate.js` (used when `SKILL.md` is absent), and the per-turn `additionalContext` reminder emitted by `caveman-mode-tracker.js`.

## Language Resolution

The exact languages are resolved at runtime by `getLanguages(claudeDir)` in `caveman-config.js` and emitted as a concrete `## Resolved Language` block (by `caveman-activate.js` at session start, and inline in the `caveman-mode-tracker.js` per-turn reminder). Resolution order — conversation language: `ICLAUDE_CHAT_LANG` env → `settings.json` `language` field → null (generic "match the user's language"); documentation language: `ICLAUDE_DOC_LANG` env → `English`.

Both vars are set in `.claude_config` (see [[config]]) and exported to the hook environment by `load_claude_config()` in `lib/config/isolated.sh` (added to its export whitelist). Values are sanitized (control chars stripped, capped at 40 chars) before injection into model context. `ICLAUDE_CHAT_LANG` should be kept in sync with the `settings.json` `language` field, but defaults to it when unset, so leaving the var empty causes no drift.

## Status and Removal

`check_caveman()` (`--check-caveman`) reports which of the four hook files and `SKILL.md` are present, the installed `caveman-version`, and the active `CAVEMAN_DEFAULT_MODE`. `remove_caveman()` (`--uninstall-caveman`) deletes the hook files, strips caveman entries from the `SessionStart`/`UserPromptSubmit` blocks of `settings.json` (removing now-empty events), removes `skills/caveman/`, and deletes `caveman-version`.

See also: [[config]], [[launcher]], [[statusline]], [[architecture]]
