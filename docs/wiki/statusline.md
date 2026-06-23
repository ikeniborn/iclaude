# Statusline

## Overview

The statusline module (`lib/statusline/`) installs and configures a custom Claude Code status bar, rendered by the pre-authored `claude-statusline.sh` script. The bar shows dual context tracking, cache hit-rate, cost, model, and OSC 8 hyperlinks, plus live badges for [[router]], [[pii-proxy]], [[security-hooks]], [[caveman]], and [[sandbox]] microVM. A `SessionEnd` hook also emits an end-of-session cache report. See [[ohmyposh]] for git rendering.

## Module Layout

`lib/statusline/` holds three bash files sourced by `iclaude.sh`: `detect.sh` (readiness check), `install.sh` (script + settings wiring), and `status.sh` (diagnostic report). They do NOT generate the render script — `claude-statusline.sh` is shipped pre-authored at `$ISOLATED_CONFIG_DIR/scripts/`. The module's job is to make it executable and register it in `settings.json`.

## Detection

`detect_statusline()` (`lib/statusline/detect.sh`) returns 0 when `$ISOLATED_CONFIG_DIR/scripts/claude-statusline.sh` exists and is executable, 1 otherwise. It first calls `setup_isolated_nvm &>/dev/null` so `ISOLATED_CONFIG_DIR` is resolved before the path check. Used to decide whether the statusline is ready.

## Installation

`install_statusline_script()` (`lib/statusline/install.sh`), triggered by `./iclaude.sh --install-statusline`, sets up the isolated env, ensures `$ISOLATED_CONFIG_DIR/scripts/` exists, then verifies the pre-authored `claude-statusline.sh` is present (it errors out if missing — the script is not generated inline). It chmod +x the file, calls `configure_statusline_in_settings()`, and runs `save_isolated_lockfile` to record the change.

## Settings Wiring

`configure_statusline_in_settings()` merges a `statusLine` block into `$ISOLATED_CONFIG_DIR/settings.json` via `jq` (a required dependency; the function returns 1 if absent), then chmod 600 the file:

```json
{
  "statusLine": {
    "type": "command",
    "command": "$CLAUDE_CONFIG_DIR/scripts/claude-statusline.sh",
    "padding": 1
  }
}
```

The `command` is stored as the literal unexpanded string `$CLAUDE_CONFIG_DIR/scripts/claude-statusline.sh`. `$CLAUDE_CONFIG_DIR` is exported by `iclaude.sh` before launch (see [[launcher]]) and inherited by the statusLine subprocess, so the path resolves regardless of the project working directory. See [[config]] for the `statusLine` settings key.

## Status Check

`check_statusline_status()` (`lib/statusline/status.sh`), triggered by `./iclaude.sh --check-statusline`, reports whether the script exists and is executable, prints the `statusLine.command` and `statusLine.refresh` values read from `settings.json` via `jq`, and lists the script's data sources and capabilities. If `jq` is absent it skips the settings inspection with a note. It is purely diagnostic — it does not modify anything.

## Render Script

`claude-statusline.sh` (shipped at `$ISOLATED_CONFIG_DIR/scripts/`, not in `lib/`) is the actual renderer. It detects its config dir from `BASH_SOURCE` location (since `$CLAUDE_CONFIG_DIR` is unset when Claude Code invokes it), reads Claude Code session JSON from STDIN, and parses all fields in ONE jq call. It requires `jq` (prints a notice and exits 0 if missing, to avoid breaking the UI) and Claude Code v2.1+ (uses the `context_window` object). `DEBUG_STATUSLINE=1` logs to `/tmp/claude-statusline-debug.log`.

## Statusline Caching

To keep render latency near zero, the script caches its output per session at `/tmp/iclaude-sl-cache-<session_id>` with a 3-second TTL. On a cache hit it prints the cached line instantly and spawns a detached background refresh (guarded by a lock `/tmp/iclaude-sl-lock-<session_id>` older than 5s), re-invoking itself with `ICLAUDE_SL_NO_CACHE=1` to prevent recursion. The fresh path writes the cache atomically (tmp + mv). Sessions with an unknown id bypass caching.

## Dual Context Tracking

The bar shows two figures: `Σ <remaining> ↓` (tokens left until the window fills) and `📊 <active> (<pct>%)` (active context = `total_input_tokens`, colored green/yellow/red by percentage of the full window). Reported `context_window_size` is untrusted — `detect_real_context_window()` maps the model name to its true window (Haiku 200K; Opus/Sonnet 4.5–4.8 = 1M; older 4.x = reported) and takes the max. `used_percentage` is parsed but no longer the source of truth (Claude Code saturates it against a stale 200K window). After `/clear`, active context shows 0% until real data arrives. A `⚠️` appears when active tokens exceed the window.

## Cache and Cost

Cache health renders as `📦 <hit>% · R<read>/W<write>`, shown only when total cache tokens exceed zero — replacing the earlier summed token count so prefix reuse vs. rewrite is visible at a glance.

The hit-rate is the per-turn share served from cache — `cache_read / (cache_read + cache_creation + input_tokens)`, integer percent; `R`/`W` are the cache-read and cache-creation token volumes (humanized K for thousands, M for millions). A high `%` means the prompt prefix is being reused; a `W` (cache_creation) spike means it was rewritten. Cost comes from `cost.total_cost_usd`, rendered as `$<n.nn>`. Both come from the one-shot jq parse — which now also extracts `current_usage.input_tokens` for the hit-rate denominator — on the Anthropic fast path, or from the provider adapter otherwise.

## Cache Report Hook

A `SessionEnd` hook, `cache-report.py`, writes a cumulative prompt-cache summary for the whole session — pairing the statusline's per-turn view with an end-of-session total.

It reads the session transcript `.jsonl` (path from the hook's stdin), sums `cache_read_input_tokens`, `cache_creation_input_tokens`, `input_tokens`, and `output_tokens` across every `assistant` turn, and computes the cumulative hit-rate `read / (read + creation + input)`. The report — raw integer token counts plus turn count — is written to `$CLAUDE_CONFIG_DIR/logs/cache-report-<session_id>.txt` and best-effort echoed to `/dev/tty` as the session closes. It is Python-stdlib-only and fail-soft: a missing, empty, or malformed transcript, a non-dict payload, or a bad usage value yields exit 0 with no report, never breaking session teardown. Registered under `hooks.SessionEnd` in `settings.json`. See [[security-hooks]] for the PreToolUse hooks.

## Provider Adapters

When session data is not Anthropic-native, the script sources `scripts/lib/provider-adapter.sh` (if present) and calls `parse_with_adapter` to handle Gemini, OpenAI, and Ollama (routed via CCR). Each provider gets an icon (`🤖` OpenAI, `🦙` Ollama, `✨` Gemini, `❓` unknown; none for native Anthropic). The Anthropic fast path skips the adapter entirely for speed. If the adapter is unavailable and data is non-Anthropic, the bar prints an "awaiting session data" placeholder.

## Router Badge

When `ICLAUDE_ROUTER_ACTIVE=1` (exported by [[launcher]] for `--router`), the script queries the CCR API at `127.0.0.1:<port>/api/config` (port from `router.json` `PORT`, default 3456) with a 30s TTL cache, and reads `.Router.default`. If CCR is live it shows `🔀` and overrides the displayed model with the actual routed model (`format_ccr_model` maps `provider,model` to an emoji + short name). If CCR is down it falls back to reading `router.json` directly. See [[router]].

## Rate Limit Badge

For Anthropic native sessions only (no router), the script sources `scripts/lib/rate-limit.sh` (if present), triggers an async background fetch via `trigger_rate_limit_fetch`, and reads the cached display via `get_rate_limit_display` (60s TTL). The result is appended to the bar. Suppressed when `ICLAUDE_ROUTER_ACTIVE=1` since rate limits do not apply to routed providers.

## Security, Caveman, PII, microVM Badges

These badges reflect signals written by hooks and [[launcher]]:

- Security `🔒` (block) / `⚠️` (redact) — read from `/tmp/iclaude-security-event.json`, written by `block-secrets.py` / `redact-secrets.py` ([[security-hooks]]), shown for the event's TTL then the flag is cleaned up.
- Caveman `⛏ <count>` — shown when `$CLAUDE_CONFIG_DIR/.caveman-active` exists; the suffix text comes from `.caveman-statusline-suffix` written by `caveman-stats.js` ([[caveman]]).
- PII `🛡 <count>` — shown when `ICLAUDE_PII_ACTIVE=1` and `ICLAUDE_PII_ACTIVE_PORT` are set ([[launcher]] PII lifecycle). It fetches `masked_items_total` from the proxy's `/api/metrics` (30s TTL cache) and wraps the icon in an OSC 8 hyperlink to `ICLAUDE_PII_LOG_PATH` when that file exists. See [[pii-proxy]].
- microVM `⚡` (full sync) / `⚡🔐` (isolated, sealed) — shown when `ICLAUDE_MICROVM_ACTIVE=1`, hyperlinked to `ICLAUDE_MICROVM_INFO_PATH` (host-side vm-info). See [[sandbox]].

## OSC 8 Hyperlinks

The bar embeds clickable OSC 8 escape sequences: `📄` links to the session JSONL transcript (`transcript_path`), `🧠` links to the project `MEMORY.md` (derived from the transcript path's project key), the git branch links to its remote `tree/<branch>` URL (GitHub/GitLab, derived from `git remote get-url origin`), and the PII / microVM icons link to their respective log/info files. Links render only when the target exists.

## Git Info

When inside a git work tree, the script prefers `oh-my-posh print primary` with the theme at `$CLAUDE_CONFIG_DIR/themes/claude-statusline.omp.json` (validated as JSON, run under a 2s timeout, ANSI stripped). If Oh My Posh is unavailable or fails, it falls back to plain `git`: `🔱 <branch>` plus `●<n>` uncommitted changes and `↑<n>` commits ahead of upstream, with full and compact (8-char abbreviated) branch variants. See [[ohmyposh]].

## Adaptive Display Modes

`get_terminal_width()` (tput → stty → 80 fallback) feeds `get_display_mode()`, which selects: **full** (≥80 cols) — every component; **compact** (40–79) — tokens, cache, model, cost, rate limit, microVM, PII, security, caveman, memory link (drops router, proxy, session link, git); **minimal** (<40) — tokens, cache, model, cost plus PII/microVM/security shields only. Set `STATUSLINE_ADAPTIVE=0` to force full mode. Color of the cumulative figure is green/yellow/red by billing-token percentage.

## Startup Guard

For brand-new sessions (`TOTAL_TOKENS == 0`) younger than 30 seconds, the script exits silently so the bar appears only after system messages (npm notices, etc.) have cleared — start time is tracked per session in `/tmp/claude-statusline-start-time-<session_id>`. After 30s or the first user message it renders normally. Final output is cleaned of embedded newlines, written to the cache, and printed. See [[architecture]] for the module load order that guarantees `ISOLATED_CONFIG_DIR` is set before these functions run.
