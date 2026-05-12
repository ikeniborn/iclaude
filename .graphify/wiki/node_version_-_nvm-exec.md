# node_version / nvm-exec

> 14 nodes · cohesion 0.18

## Key Concepts

- **check_oauth_token()** (7 connections) — `lib/oauth/token.sh`
- **ISOLATED_NVM_DIR** (4 connections) — `lib/oauth/token.sh`
- **refresh_oauth_token()** (4 connections) — `lib/oauth/token.sh`
- **check_token_expiration()** (3 connections) — `lib/oauth/token.sh`
- **nvm-exec** (2 connections) — `.nvm-isolated/nvm-exec`
- **nvm.sh** (2 connections) — `.nvm-isolated/nvm.sh`
- **.credentials.json** (2 connections) — `lib/oauth/token.sh`
- **validate_jq_installed()** (2 connections) — `lib/oauth/token.sh`
- **NODE_VERSION** (1 connections) — `.nvm-isolated/nvm-exec`
- **CLAUDE_CODE_OAUTH_TOKEN** (1 connections) — `lib/oauth/token.sh`
- **detect_nvm()** (1 connections) — `lib/oauth/token.sh`
- **get_nvm_claude_path()** (1 connections) — `lib/oauth/token.sh`
- **TOKEN_REFRESH_THRESHOLD** (1 connections) — `lib/oauth/token.sh`
- **validate_dependency()** (1 connections) — `lib/oauth/token.sh`

## Relationships

- No strong cross-community connections detected

## Source Files

- `.nvm-isolated/nvm-exec`
- `.nvm-isolated/nvm.sh`
- `lib/oauth/token.sh`

## Audit Trail

- EXTRACTED: 28 (88%)
- INFERRED: 4 (12%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*