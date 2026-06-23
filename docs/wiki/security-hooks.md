# Security Hooks

## Overview

Two PreToolUse hooks guard secrets before file/Bash tools run, wired in `settings.json` under `$CLAUDE_CONFIG_DIR`. `block-secrets.py` denies access to sensitive paths (exit 2); `redact-secrets.py` masks secret-shaped content via `toolInputOverride`. Both fail open, exclude their own hook dirs, and write a status-line event. See [[architecture]], [[statusline]], [[oauth]].

## Wiring in settings.json

Both hooks register as `PreToolUse` command hooks in `$CLAUDE_CONFIG_DIR/settings.json`, run as `python3 "$CLAUDE_CONFIG_DIR/hooks/<hook>.py"`. `block-secrets.py` matches `Read|Edit|Write|MultiEdit|Bash`; `redact-secrets.py` matches `Write|Edit|MultiEdit|Bash` (no `Read` — it rewrites content, not reads). A third `idd-gate.py` shares the section but is unrelated; see [[gsd]]. `$CLAUDE_CONFIG_DIR` is set by the isolated env in [[core]] and [[nvm]].

## block-secrets.py

First layer: blocks access to sensitive files rather than masking. Reads the tool JSON from stdin; for `Read`/`Edit`/`Write`/`MultiEdit` it checks `file_path`, for `Bash` it scans `command` tokens. On a match it prints the reason to stderr, emits `{"reason": ...}` JSON, writes a status-line flag, and exits `2` — which fails the tool with an error but does not end the session. Exit `0` allows; unreadable/invalid stdin exits `0` (fail open).

## Sensitive path matching

`SENSITIVE_PATH_PATTERNS` are matched as a case-insensitive substring of the full lowercased path: `.env`, `.pem`, `.key`, `.pfx`, `.p12`, `credentials`, `secret`, `.ssh`, `.aws`, `.gnupg`, `.kube`, `id_rsa`, `id_ed25519`, `id_ecdsa`, `private_key`, `.netrc`, `.pgpass`. Because these are substrings, any path component triggers a block (e.g. a file inside a `.ssh/` dir).

## Token filename matching

To avoid false positives on source like `lib/oauth/token.sh` or `token_manager.py`, `TOKEN_FILENAME_PATTERNS` match only the filename (last path segment): `.token`, `token.json`, `token.txt`, `token.yaml`, `token.yml`, `token.xml`, `access_token`, `refresh_token`, `oauth_token`, `auth_token`, `api_token`, `id_token`. So `access_token.json` is blocked while `token.sh` is allowed. These protect the token-storage paths described in [[oauth]].

## Bash path scanning

For `Bash` the command is split with `shlex` (falling back to `str.split` on a quoting error), and only tokens that look like filesystem paths are checked — those starting with `/`, `~/`, `./`, `../`, or `$HOME`. This avoids false positives on command names, flags, and inline code strings while still catching `cat ~/.ssh/id_rsa`. Matched tokens run through the same path/token rules and block on a hit.

## Exclusions and safe templates

`EXCLUDE_DIRS` (`.claude-isolated/hooks`, `.claude/hooks`) are skipped entirely so the hooks never block their own files — this self-exclusion is why reading these `.py` hooks is allowed. `SAFE_SUFFIXES` (`.example`, `.sample`, `.template`, `.dist`, `.defaults`, `.placeholder`) mark template files as non-secret by filename suffix, so `.env.example` is allowed while `.env` is blocked.

## redact-secrets.py

Second layer: complements blocking by masking secret-shaped content inside tool arguments instead of denying the tool. Handles `Write`, `Edit`, `MultiEdit`, `Bash`. On a match it prints a stderr summary, writes a status-line flag, and emits `{"hookSpecificOutput": {"toolInputOverride": ...}}` (Claude Code v2.0.10+) carrying the redacted arguments, then exits `0`. No match → silent exit `0`; parse error → exit `0` (fail open, exit 2 is never used). Files under `EXCLUDE_DIRS` are skipped.

## Redacted content fields

Only specific text fields are scanned: `Write.content`, `Edit.new_string`, `Bash.command`, and each `MultiEdit` edit's `new_string`. `Edit.old_string` is deliberately NOT redacted — it is a search pattern, and masking it would make the Edit fail to find its target. The same rule applies inside `MultiEdit.edits`: only `new_string` is rewritten.

## Redaction patterns

`REDACT_PATTERNS` is an ordered list (specific before generic); each match replaces in place: Anthropic/OpenAI keys `sk-(ant-api03-|ant-|proj-|or-v1-)?…` → `[API_KEY_REDACTED]`; `AKIA…` → `[AWS_ACCESS_KEY_ID]`; AWS secret key (keeps var name) → `[AWS_SECRET_KEY_REDACTED]`; PEM private-key blocks (RSA/EC/DSA/OPENSSH/ENCRYPTED/PGP) → `[PRIVATE_KEY_REDACTED]`; GitHub `gh[pousr]_…` and `github_pat_…` → `[GITHUB_TOKEN]`; Google `AIzaSy…` → `[GOOGLE_API_KEY]`; Stripe `(sk|pk)_(live|test)_…` → `[STRIPE_API_KEY]`; HuggingFace `hf_…` → `[HUGGINGFACE_TOKEN]`; Groq `gsk_…` → `[GROQ_API_KEY]`; URL credentials `scheme://user:pass@` → `scheme://[CREDENTIALS]@`; config passwords → `[PASSWORD_REDACTED]`; generic secret/key/token assignments → `[SECRET_REDACTED]`; JWTs `eyJ….….…` → `[JWT_REDACTED]`; card numbers → `[CARD_NUMBER_REDACTED]`; `.env`-style `VAR…=value` → `[REDACTED]`.

## Placeholder-aware redaction

Several patterns avoid double-masking and breaking env substitution. Password and `.env` patterns use negative lookaheads to skip `${VAR}` placeholders (they resolve from the environment) and already-masked `[...]` values, so re-running the hook is idempotent. Generic-secret and `.env` matches require a minimum value length (16 / 20 chars) to dodge false positives on short test values. The card pattern matches IIN ranges without a Luhn check, so numeric IDs may occasionally be redacted.

## Status-line integration

Both hooks call `write_security_flag(...)`, writing `/tmp/iclaude-security-event.json` with `{type, detail, ts, ttl}` (`type` is `block` or `redact`, `ttl` 30s). The status-line script (`scripts/claude-statusline.sh`) reads this file to surface a recent block/redaction indicator. Writing the flag is best-effort — `OSError` is swallowed so a flag-write failure never affects the tool decision. See [[statusline]].
