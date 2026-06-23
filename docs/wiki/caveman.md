# Caveman Module

## Overview

`lib/caveman/install.sh` installs "caveman mode" into the isolated Claude Code environment — a token-compression ruleset that makes Claude reply tersely. It downloads four JS hooks plus a `SKILL.md` and wires two hook events into the isolated `settings.json` (see [[config]]). Covers installation, hook wiring, activation levels, language preservation, language resolution, the statusline badge, and status/removal.

## Installation

`install_caveman()` downloads hook files into `$CLAUDE_CONFIG_DIR/hooks/` and patches `settings.json`. It is idempotent — safe to re-run. Driven from `iclaude.sh` via `--install-caveman` (rejected with `--system`; isolated env only).

The four downloaded hook files (`_CAVEMAN_HOOK_FILES`) are `caveman-activate.js`, `caveman-config.js`, `caveman-mode-tracker.js`, and `caveman-stats.js`, fetched from the upstream `JuliusBrussee/caveman` repo (`_CAVEMAN_HOOKS_BASE`, the `main` branch under `src/hooks`). `SKILL.md` is downloaded into `$CLAUDE_CONFIG_DIR/skills/caveman/`; if one already exists it is saved as `SKILL.md.new` for manual review. The upstream commit SHA is recorded in `$CLAUDE_CONFIG_DIR/caveman-version` via `git ls-remote` (or `unknown` if it fails). After patching, the install prints "Restart iclaude to activate".

Download strategy is layered for ALT Linux TLS quirks: `curl` (with [[proxy]] args from `.claude_config` — `PROXY_URL`, `PROXY_CA`, `PROXY_INSECURE`, loaded via `source_iclaude_config`) is the fast path; on curl exit 35 (ECDSA cert unsupported by OpenSSL on ALT Linux) it falls back to `GIT_SSL_NO_VERIFY=1 git clone` with `OPENSSL_CONF=/dev/null`, then `_caveman_python_download()` (python3 `urllib` with `ssl.CERT_NONE`, picking up `HTTPS_PROXY`) as last resort. If all methods fail, it prints manual `curl` commands and returns 1.

## Hooks Installed

`install_caveman()` patches the `hooks` block of the isolated `settings.json`, registering two events. Each entry is `{type: command, timeout: 5, statusMessage}`. The patch first removes any prior caveman entries (matched by filename regex on `caveman-activate.js`/`caveman-mode-tracker.js`), then appends the canonical form, keeping the file idempotent.

| Event | Command | Purpose |
|-------|---------|---------|
| `SessionStart` | `node "$CLAUDE_CONFIG_DIR/hooks/caveman-activate.js"` | Writes the `.caveman-active` flag, emits the caveman ruleset as session context. |
| `UserPromptSubmit` | `node "$CLAUDE_CONFIG_DIR/hooks/caveman-mode-tracker.js"` | Tracks the active mode per prompt, re-injects the rules every turn. |

`caveman-config.js` is a shared helper (mode resolver, language resolver, symlink-safe flag/history I/O) `require`d by the other hooks — not registered as a hook itself. A fifth file, `caveman-stats-stop.js`, is wired as a `Stop` hook in the repo's `settings.json` but is **not** part of `_CAVEMAN_HOOK_FILES`: `install_caveman()` never downloads it, and `remove_caveman()` never touches the `Stop` event — caveman install manages only `SessionStart` + `UserPromptSubmit`.

## Activation Hook

`caveman-activate.js` (SessionStart) reads the active level from `getDefaultMode()`, writes the symlink-safe flag file `$CLAUDE_CONFIG_DIR/.caveman-active` (that [[statusline]] reads), and emits the matching ruleset as hidden session context. `off` skips activation entirely and unlinks the flag.

The ruleset is the single source of truth filtered at runtime: it reads `../skills/caveman/SKILL.md`, strips frontmatter, and keeps only the active level's intensity-table row and example lines. If `SKILL.md` is absent (standalone hook install without a skills dir), it uses a hardcoded fallback ruleset. Independent modes (`commit`/`review`/`compress`) get only a short activation line that defers to their own skill. It then appends a concrete `## Resolved Language` block (see Language Resolution), and — when `settings.json` has no `statusLine` key — nudges Claude to offer setting up the caveman statusline badge (`caveman-statusline.sh`/`.ps1`).

## Per-Turn Tracker

`caveman-mode-tracker.js` (UserPromptSubmit) keeps caveman in attention every turn, since competing per-turn style injections erode the once-emitted SessionStart rules. It updates `.caveman-active` from the prompt: bare `/caveman` → configured default; `/caveman lite|full|ultra|wenyan-*` → that level; `/caveman off|stop|disable` → unlink flag; `/caveman-commit|-review|-compress` → independent modes. It also matches natural-language activation ("activate/enable/turn on/start/talk like … caveman") and deactivation ("stop/disable/normal mode"). `/caveman-stats [--share|--all|--since]` is intercepted: the prompt is blocked and the output of `caveman-stats.js` (run against `transcript_path`) is returned as the block reason. On every turn where the flag is a valid mode, it emits an `additionalContext` reminder (rules + resolved language) via `readFlag` (symlink-safe, size-capped, whitelist-validated).

## Activation Levels

The active mode comes from `getDefaultMode()` in `caveman-config.js`, resolved in order: the `CAVEMAN_DEFAULT_MODE` environment variable (case-insensitive), then a `caveman/config.json` `defaultMode` field (`$XDG_CONFIG_HOME` / `~/.config` / `%APPDATA%`), then the default `full`.

Valid modes (`VALID_MODES`): `off`, the three intensity levels `lite` < `full` < `ultra` (terseness increases left to right), the classical-Chinese `wenyan` variants (`wenyan-lite`, `wenyan`/`wenyan-full`, `wenyan-ultra`), and the independent skill-backed modes `commit`, `review`, `compress`. `off` skips activation and removes the flag file. The launcher ([[launcher#Final Exec]]) exports `CAVEMAN_DEFAULT_MODE` to the hook environment when set, so the level is toggled via that env var, the config file, or in-session `/caveman <level>`.

## Language Preservation

Caveman compresses words, not language: terse output stays in the conversation's language and never drifts to English just to compress. Documentation, code comments, commit messages, and PRs follow a separate documentation language.

The generic principle lives in three mirrored places so it survives context compaction and competing per-turn style injections: a `## Language` section in `SKILL.md` (the source of truth `caveman-activate.js` filters at runtime), the hardcoded fallback ruleset inside `caveman-activate.js` (used when `SKILL.md` is absent), and the per-turn `additionalContext` reminder emitted by `caveman-mode-tracker.js`.

## Language Resolution

The exact languages are resolved at runtime by `getLanguages(claudeDir)` in `caveman-config.js` and emitted as a concrete `## Resolved Language` block (by `caveman-activate.js` at session start, and inline in the `caveman-mode-tracker.js` per-turn reminder). Resolution order — conversation language: `ICLAUDE_CHAT_LANG` env → `settings.json` `language` field → null (generic "match the user's language"); documentation language: `ICLAUDE_DOC_LANG` env → `English`.

Both vars are set in `.claude_config` (see [[config]]) and exported verbatim to the hook environment by the env-map chokepoint ([[config#Environment Variable Export]]): they sit in the `_ICLAUDE_NATIVE_LIST` denylist in `lib/config/env-map.sh`, so `apply_iclaude_env_map()` exports them under their native `ICLAUDE_*` names rather than de-prefixing. Values are sanitized (control chars stripped, capped at 40 chars) before injection into model context. `ICLAUDE_CHAT_LANG` should be kept in sync with the `settings.json` `language` field, but defaults to it when unset, so leaving the var empty causes no drift.

## Statusline Badge

The [[statusline#Security, Caveman, PII, microVM Badges]] render script shows a caveman badge (`⛏ <count>`) when `$CLAUDE_CONFIG_DIR/.caveman-active` exists. The suffix text is read from `.caveman-statusline-suffix`, written by `caveman-stats.js`. The badge survives the [[statusline#Adaptive Display Modes]] compact tier (dropped only in minimal). When no `statusLine` key is present in `settings.json`, the activation hook injects a one-time setup nudge pointing at `caveman-statusline.sh` (or `.ps1` on Windows).

## Status and Removal

`check_caveman()` (`--check-caveman`) reports which of the four hook files and `SKILL.md` are present (plus a `[PENDING]` note if a `SKILL.md.new` awaits review), the installed `caveman-version`, and the active `CAVEMAN_DEFAULT_MODE` (`full (default)` when unset). `remove_caveman()` (`--uninstall-caveman`) deletes the four hook files, strips caveman entries from the `SessionStart`/`UserPromptSubmit` blocks of `settings.json` (removing now-empty events), removes `skills/caveman/`, and deletes `caveman-version`. It does not touch the `Stop` hook or `caveman-stats-stop.js`.

See also: [[config]], [[launcher]], [[statusline]], [[architecture]]
