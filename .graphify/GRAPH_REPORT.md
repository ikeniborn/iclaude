# Graph Report - .  (2026-05-12)

## Corpus Check
- 76 files · ~83,212 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 469 nodes · 607 edges · 54 communities (37 shown, 17 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 16 edges (avg confidence: 0.85)
- Token cost: 18,500 input · 4,200 output

## Graph Freshness
- Built from commit: `9f8b0319`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_dispatch_command()  detect_graphify()|dispatch_command() / detect_graphify()]]
- [[_COMMUNITY_anthropic_base_url|anthropic_base_url]]
- [[_COMMUNITY_load_claude_config()  credentials_file|load_claude_config() / credentials_file]]
- [[_COMMUNITY__get_http_session()  piiproxyhandler|_get_http_session() / piiproxyhandler]]
- [[_COMMUNITY_cluster_4|cluster_4]]
- [[_COMMUNITY_should  with|should / with]]
- [[_COMMUNITY_vendored  graphify|vendored / graphify]]
- [[_COMMUNITY_configure_git_hooks()  create_claude_symlink()|configure_git_hooks() / create_claude_symlink()]]
- [[_COMMUNITY_setup_isolated_config()  check_isolated_status()|setup_isolated_config() / check_isolated_status()]]
- [[_COMMUNITY_should  redacted|should / redacted]]
- [[_COMMUNITY_should|should]]
- [[_COMMUNITY_mask_token|mask_token]]
- [[_COMMUNITY_документирует|документирует]]
- [[_COMMUNITY_hook  token|hook / token]]
- [[_COMMUNITY_test  suite|test / suite]]
- [[_COMMUNITY_should  string|should / string]]
- [[_COMMUNITY_isolated_config_dir|isolated_config_dir]]
- [[_COMMUNITY_redacted  should|redacted / should]]
- [[_COMMUNITY_module  core|module / core]]
- [[_COMMUNITY_hook  block-secrets.py|hook / block-secrets.py]]
- [[_COMMUNITY_create_test_chrome_dir()  test_chromium_browser()|create_test_chrome_dir() / test_chromium_browser()]]
- [[_COMMUNITY__alloc_microvm_slot()  _microvm_ip_at()|_alloc_microvm_slot() / _microvm_ip_at()]]
- [[_COMMUNITY_check_dependencies()  install_claude_code()|check_dependencies() / install_claude_code()]]
- [[_COMMUNITY_is_chrome_running()  is_claude_chrome_extension_installed()|is_chrome_running() / is_claude_chrome_extension_installed()]]
- [[_COMMUNITY_ccr_host  ccr_port|ccr_host / ccr_port]]
- [[_COMMUNITY_private  keys|private / keys]]
- [[_COMMUNITY_github  tokens|github / tokens]]
- [[_COMMUNITY_long  .env|long / .env]]
- [[_COMMUNITY_secret  access|secret / access]]
- [[_COMMUNITY_groq  keys|groq / keys]]
- [[_COMMUNITY_passwords  config|passwords / config]]
- [[_COMMUNITY_tokens  should|tokens / should]]
- [[_COMMUNITY_graphify  patch|graphify / patch]]
- [[_COMMUNITY_is_claude_chrome_extension_installed()  chrome|is_claude_chrome_extension_installed() / chrome]]
- [[_COMMUNITY_libcavemaninstall.sh|lib/caveman/install.sh]]
- [[_COMMUNITY_caveman  install|caveman / install]]
- [[_COMMUNITY_libpii-proxyserver.py|lib/pii-proxy/server.py]]
- [[_COMMUNITY_core  initialization|core / initialization]]
- [[_COMMUNITY_oauth  token|oauth / token]]

## God Nodes (most connected - your core abstractions)
1. `iclaude.sh (main entry point)` - 28 edges
2. `TestShouldRedact` - 21 edges
3. `PIIProxyHandler` - 20 edges
4. `install_microvm()` - 16 edges
5. `launch_claude()` - 15 edges
6. `microVM unit test suite` - 14 edges
7. `iclaude` - 13 edges
8. `ISOLATED_NVM_DIR` - 13 edges
9. `TestFalsePositives` - 10 edges
10. `TestMaskToken` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Graphify Patches Tests` --references--> `Graphify Patch Applier`  [EXTRACTED]
  tests/test_graphify_patches.py → lib/graphify/apply_patches.sh
- `test-redact-hook.sh test suite` --references--> `redact-secrets.py hook`  [EXTRACTED]
  tests/test-redact-hook.sh → .nvm-isolated/.claude-isolated/hooks/redact-secrets.py
- `test-redact-hook.sh test suite` --references--> `block-secrets.py hook`  [EXTRACTED]
  tests/test-redact-hook.sh → .nvm-isolated/.claude-isolated/hooks/block-secrets.py
- `run_hook()` --calls--> `redact-secrets.py hook`  [EXTRACTED]
  tests/test-redact-hook.sh → .nvm-isolated/.claude-isolated/hooks/redact-secrets.py
- `iclaude.sh (main entry point)` --calls--> `install_isolated_pii_proxy()`  [EXTRACTED]
  iclaude.sh → lib/pii-proxy/install.sh

## Communities (54 total, 17 thin omitted)

### Community 0 - "dispatch_command() / detect_graphify()"
Cohesion: 0.07
Nodes (43): detect_graphify(), install_graphify(), _patch_graphify_watch(), _graphify_rebuild_graph(), _graphify_resolve_proxy(), _graphify_resolve_uv(), check_graphify_status(), iclaude.sh (main entry point) (+35 more)

### Community 1 - "anthropic_base_url"
Cohesion: 0.07
Nodes (19): ANTHROPIC_BASE_URL env var, ICLAUDE_PII_ACTIVE env var, MICRO_VM_ENABLED env var, MICRO_VM_NET_SUBNET env var, init_environment(), start_pii_proxy_server(), _alloc_microvm_slot(), _claim_microvm_slot() (+11 more)

### Community 2 - "load_claude_config() / credentials_file"
Cohesion: 0.08
Nodes (22): load_claude_config(), CREDENTIALS_FILE, ISOLATED_CONFIG_DIR, MICRO_VM_ENABLED, PROXY_URL, check_distro_microvm_support(), detect_kvm_support(), detect_linux_distro() (+14 more)

### Community 3 - "_get_http_session() / piiproxyhandler"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 4 - "cluster_4"
Cohesion: 0.11
Nodes (25): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+17 more)

### Community 5 - "should / with"
Cohesion: 0.09
Nodes (16): detector(), mask(), Simple redaction detector for testing purposes, Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently (+8 more)

### Community 6 - "vendored / graphify"
Cohesion: 0.12
Nodes (12): fake_pkg(), Проверяет что vendored graphifyy уже патчен (precondition)., Создаёт минимальный faux graphify пакет для патчинга., Idempotent: после первого apply повторный — no-op., Если dry-run patch fails — best-effort exit 0, fails counted., Скопировать реальные vendored файлы в fake_pkg для valid patch context., End-to-end: после apply_patches graphify update пишет relative paths., run_apply() (+4 more)

### Community 7 - "configure_git_hooks() / create_claude_symlink()"
Cohesion: 0.12
Nodes (14): repair_isolated_environment(), get_pii_proxy_python(), _pii_proxy_cascade_install(), _pii_proxy_check_prerequisites(), _pii_proxy_download_model(), _pii_download_spacy_model(), install_isolated_pii_proxy(), _pip_proxy_args() (+6 more)

### Community 8 - "setup_isolated_config() / check_isolated_status()"
Cohesion: 0.11
Nodes (10): setup_isolated_config(), check_isolated_status(), CLAUDE_CONFIG_DIR, ISOLATED_NVM_DIR, detect_ohmyposh_platform(), get_ohmyposh_path(), check_ohmyposh_status(), get_claude_version() (+2 more)

### Community 9 - "should / redacted"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD be detected and redacted, Anthropic API keys should be redacted, Google AI Studio keys should be redacted, Stripe secret keys should be redacted, Stripe test keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted, Visa credit cards should be redacted (+2 more)

### Community 10 - "should"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD NOT be redacted (false positive risks), UUIDs should NOT be redacted even if 32+ hex chars, Git commit hashes should NOT be treated as tokens, Version tags should NOT be redacted, Docker image references should not be completely redacted, Template variables should NOT be redacted, Bash placeholders should NOT be redacted, Test/example passwords in test files should preferably not be redacted (+2 more)

### Community 11 - "mask_token"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 12 - "документирует"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 13 - "hook / token"
Cohesion: 0.14
Nodes (14): block-secrets.py hook, Caveman token compression, Claude Code Router, Chrome integration, Claude Code, Graphify knowledge graph, iclaude, Isolated NVM Environment (+6 more)

### Community 14 - "test / suite"
Cohesion: 0.18
Nodes (9): Claude Code CLI, iclaude Project, _pii_dnat_sweep_stale(), Phase 0 Regression Test Suite, CCR integration test suite, PII DNAT E2E L3 test suite, PII DNAT iptables L2 test suite, PII DNAT test runner (L1+L2+L3) (+1 more)

### Community 15 - "should / string"
Cohesion: 0.18
Nodes (6): Empty string should not crash, String with 'None' should not crash, Unicode characters should be handled gracefully, Text with multiple different secret types should redact all, Partial patterns should not be redacted if incomplete, TestEdgeCases

### Community 16 - "isolated_config_dir"
Cohesion: 0.2
Nodes (8): ISOLATED_CONFIG_DIR env var, save_isolated_lockfile(), setup_isolated_nvm(), detect_statusline(), cleanup_old_claude_installations(), recreate_claude_symlinks(), update_isolated_claude(), update_claude_code()

### Community 17 - "redacted / should"
Cohesion: 0.2
Nodes (5): Apply all patterns and return redacted text + found patterns, AWS Access Key IDs should be redacted, Credentials in URLs should be redacted, Generic secret assignments should be redacted, HuggingFace tokens should be redacted

### Community 18 - "module / core"
Cohesion: 0.25
Nodes (8): Core Init Module, Core JSON Module, Core Logging Module, Core Validation Module, Proxy Configure Module, Proxy Git Module, Proxy Validation Module, Lib README

### Community 19 - "hook / block-secrets.py"
Cohesion: 0.25
Nodes (4): block-secrets.py hook, redact-secrets.py hook, run_hook(), test-redact-hook.sh test suite

### Community 22 - "check_dependencies() / install_claude_code()"
Cohesion: 0.67
Nodes (3): check_dependencies(), install_claude_code(), install_nodejs()

### Community 24 - "ccr_host / ccr_port"
Cohesion: 0.67
Nodes (3): CCR_HOST, CCR_PORT, get_ccr_port()

## Knowledge Gaps
- **131 isolated node(s):** `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.`, `Detect installed spaCy models from venv marker files or by probing spacy.      R`, `Lazy-initialize Presidio NLP engine with all available language models.      Thr` (+126 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `iclaude.sh (main entry point)` connect `dispatch_command() / detect_graphify()` to `configure_git_hooks() / create_claude_symlink()`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Why does `TestShouldRedact` connect `should / redacted` to `should / with`, `redacted / should`, `private / keys`, `github / tokens`, `long / .env`, `secret / access`, `groq / keys`, `passwords / config`, `tokens / should`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `TestMaskToken` connect `mask_token` to `should / with`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.` to the rest of the system?**
  _131 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `dispatch_command() / detect_graphify()` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._