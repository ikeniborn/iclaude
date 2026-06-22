# Security Hooks

PreToolUse hooks guard secret material before file/Bash tools run, configured in `settings.json` under `$CLAUDE_CONFIG_DIR`. Two layers: `block-secrets.py` denies access to sensitive paths, and a companion `redact-secrets.py` masks secret-shaped content. See [[architecture#Isolated Environment]] for how `CLAUDE_CONFIG_DIR` wires hooks into the isolated config.

## block-secrets.py

Intercepts `Read`/`Edit`/`Write`/`MultiEdit` and `Bash`, exiting `2` to block access to a sensitive file without ending the session (`0` allows, `2` blocks). Paths match `SENSITIVE_PATH_PATTERNS` (`.env`, `.pem`, `.key`, `.ssh`, `.aws`, `.gnupg`, `credentials`, `secret`, …) as a substring of the full path; `TOKEN_FILENAME_PATTERNS` (`access_token`, `refresh_token`, `token.json`, …) match the filename only, so source like `lib/oauth/token.sh` stays allowed while `access_token.json` is blocked. Bash commands are scanned only on tokens that look like paths (`/`, `~/`, `./`, `../`, `$HOME`). On a block it writes a status-line flag to `/tmp/iclaude-security-event.json`; it fails open on unreadable input. See [[oauth]] for the token-storage paths this protects.

## Exclusions and safe templates

`EXCLUDE_DIRS` holds path fragments skipped entirely: the hook directories themselves (`.claude-isolated/hooks`, `.claude/hooks`) so the hooks never block their own files, plus project sources/tests that legitimately carry secret-like names (`paw/security/secrets.py`, `tests/unit/test_secrets.py`). `SAFE_SUFFIXES` (`.example`, `.sample`, `.template`, `.dist`, `.defaults`, `.placeholder`) mark template files as non-secret — so `.env.example` is allowed while `.env` is blocked.
