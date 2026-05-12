# Graph Report - .  (2026-05-12)

## Corpus Check
- 107 files · ~134,851 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 687 nodes · 867 edges · 84 communities (60 shown, 24 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 26 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `73e93eb7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_path  body|path / body]]
- [[_COMMUNITY_dispatch_command()  detect_graphify()|dispatch_command() / detect_graphify()]]
- [[_COMMUNITY_anthropic_base_url|anthropic_base_url]]
- [[_COMMUNITY_load_claude_config()  credentials_file|load_claude_config() / credentials_file]]
- [[_COMMUNITY_adaptersanthropic.sh  adaptersgemini.sh|adapters/anthropic.sh / adapters/gemini.sh]]
- [[_COMMUNITY__get_http_session()  piiproxyhandler|_get_http_session() / piiproxyhandler]]
- [[_COMMUNITY_hook)  caveman-activate.js|hook) / caveman-activate.js]]
- [[_COMMUNITY_should  with|should / with]]
- [[_COMMUNITY_cluster_8|cluster_8]]
- [[_COMMUNITY_vendored  graphify|vendored / graphify]]
- [[_COMMUNITY_setup_isolated_config()  check_isolated_status()|setup_isolated_config() / check_isolated_status()]]
- [[_COMMUNITY_should  redacted|should / redacted]]
- [[_COMMUNITY_should|should]]
- [[_COMMUNITY_mask_token|mask_token]]
- [[_COMMUNITY_parse_anthropic_data()  get_gemini_context_limit()|parse_anthropic_data() / get_gemini_context_limit()]]
- [[_COMMUNITY_adaptersanthropic.sh  calculate_cost()|adapters/anthropic.sh / calculate_cost()]]
- [[_COMMUNITY_документирует|документирует]]
- [[_COMMUNITY__pii_proxy_cascade_install()  _pii_proxy_check_prerequisites()|_pii_proxy_cascade_install() / _pii_proxy_check_prerequisites()]]
- [[_COMMUNITY_hook  token|hook / token]]
- [[_COMMUNITY_node_version  nvm-exec|node_version / nvm-exec]]
- [[_COMMUNITY_test  suite|test / suite]]
- [[_COMMUNITY_маскирует  секреты|маскирует / секреты]]
- [[_COMMUNITY_should  string|should / string]]
- [[_COMMUNITY_возвращает  если|возвращает / если]]
- [[_COMMUNITY_redacted  should|redacted / should]]
- [[_COMMUNITY_hook  block-secrets.py|hook / block-secrets.py]]
- [[_COMMUNITY_module  proxy|module / proxy]]
- [[_COMMUNITY_isolated_config_dir|isolated_config_dir]]
- [[_COMMUNITY_create_test_chrome_dir()  test_chromium_browser()|create_test_chrome_dir() / test_chromium_browser()]]
- [[_COMMUNITY_cmd_list()  cmd_stats()|cmd_list() / cmd_stats()]]
- [[_COMMUNITY__alloc_microvm_slot()  _microvm_ip_at()|_alloc_microvm_slot() / _microvm_ip_at()]]
- [[_COMMUNITY_check_dependencies()  install_claude_code()|check_dependencies() / install_claude_code()]]
- [[_COMMUNITY_detect_nvm()  cleanup_old_claude_installations()|detect_nvm() / cleanup_old_claude_installations()]]
- [[_COMMUNITY_ccr_host  ccr_port|ccr_host / ccr_port]]
- [[_COMMUNITY_is_chrome_running()  is_claude_chrome_extension_installed()|is_chrome_running() / is_claude_chrome_extension_installed()]]
- [[_COMMUNITY_nvm_default_install_dir()  nvm_dir|nvm_default_install_dir() / nvm_dir]]
- [[_COMMUNITY_credentials  urls|credentials / urls]]
- [[_COMMUNITY_huggingface  tokens|huggingface / tokens]]
- [[_COMMUNITY_access|access]]
- [[_COMMUNITY_tokens  should|tokens / should]]
- [[_COMMUNITY_long  .env|long / .env]]
- [[_COMMUNITY_google  studio|google / studio]]
- [[_COMMUNITY_anthropic  keys|anthropic / keys]]
- [[_COMMUNITY_graphify  patch|graphify / patch]]
- [[_COMMUNITY_is_claude_chrome_extension_installed()  chrome|is_claude_chrome_extension_installed() / chrome]]
- [[_COMMUNITY_node  version|node / version]]
- [[_COMMUNITY_libcavemaninstall.sh|lib/caveman/install.sh]]
- [[_COMMUNITY_caveman  install|caveman / install]]
- [[_COMMUNITY_quality  analysis|quality / analysis]]
- [[_COMMUNITY_pattern  examples|pattern / examples]]
- [[_COMMUNITY_oauth  token|oauth / token]]
- [[_COMMUNITY_nvm_has()  install|nvm_has() / [install]]]
- [[_COMMUNITY_nvm_echo()  install|nvm_echo() / [install]]]
- [[_COMMUNITY_behavioral  guidelines|behavioral / guidelines]]
- [[_COMMUNITY_streaming-parser.sh|streaming-parser.sh]]
- [[_COMMUNITY_adaptersgeneric.sh|adapters/generic.sh]]

## God Nodes (most connected - your core abstractions)
1. `iclaude.sh (main entry point)` - 28 edges
2. `TestShouldRedact` - 21 edges
3. `PIIProxyHandler` - 20 edges
4. `install_microvm()` - 16 edges
5. `main()` - 15 edges
6. `launch_claude()` - 15 edges
7. `microVM unit test suite` - 14 edges
8. `ISOLATED_NVM_DIR` - 13 edges
9. `iclaude` - 13 edges
10. `parse_with_adapter()` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Graphify Patches Tests` --references--> `Graphify Patch Applier`  [EXTRACTED]
  tests/test_graphify_patches.py → lib/graphify/apply_patches.sh
- `test-redact-hook.sh test suite` --references--> `redact-secrets.py hook`  [EXTRACTED]
  tests/test-redact-hook.sh → .nvm-isolated/.claude-isolated/hooks/redact-secrets.py
- `run_hook()` --calls--> `redact-secrets.py hook`  [EXTRACTED]
  tests/test-redact-hook.sh → .nvm-isolated/.claude-isolated/hooks/redact-secrets.py
- `test-redact-hook.sh test suite` --references--> `block-secrets.py hook`  [EXTRACTED]
  tests/test-redact-hook.sh → .nvm-isolated/.claude-isolated/hooks/block-secrets.py
- `iclaude.sh (main entry point)` --calls--> `install_isolated_pii_proxy()`  [EXTRACTED]
  iclaude.sh → lib/pii-proxy/install.sh

## Communities (84 total, 24 thin omitted)

### Community 0 - "path / body"
Cohesion: 0.05
Nodes (61): body, filtered, flagPath, fs, { getDefaultMode, safeWriteFlag }, INDEPENDENT_MODES, mode, os (+53 more)

### Community 1 - "dispatch_command() / detect_graphify()"
Cohesion: 0.06
Nodes (46): detect_graphify(), install_graphify(), _patch_graphify_watch(), _graphify_rebuild_graph(), _graphify_resolve_proxy(), _graphify_resolve_uv(), check_graphify_status(), iclaude.sh (main entry point) (+38 more)

### Community 2 - "anthropic_base_url"
Cohesion: 0.07
Nodes (19): ANTHROPIC_BASE_URL env var, ICLAUDE_PII_ACTIVE env var, MICRO_VM_ENABLED env var, MICRO_VM_NET_SUBNET env var, init_environment(), start_pii_proxy_server(), _alloc_microvm_slot(), _claim_microvm_slot() (+11 more)

### Community 3 - "load_claude_config() / credentials_file"
Cohesion: 0.08
Nodes (21): load_claude_config(), CREDENTIALS_FILE, ISOLATED_CONFIG_DIR, MICRO_VM_ENABLED, PROXY_URL, check_distro_microvm_support(), detect_kvm_support(), detect_linux_distro() (+13 more)

### Community 4 - "adapters/anthropic.sh / adapters/gemini.sh"
Cohesion: 0.09
Nodes (19): adapters/anthropic.sh, adapters/gemini.sh, adapters/generic.sh, adapters/ollama.sh, adapters/openai.sh, get_provider_adapter(), parse_with_adapter(), get_chunk_type() (+11 more)

### Community 5 - "_get_http_session() / piiproxyhandler"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 6 - "hook) / caveman-activate.js"
Cohesion: 0.09
Nodes (12): caveman-activate.js (SessionStart hook), getDefaultMode(), readFlag(), safeWriteFlag(), caveman-mode-tracker.js (UserPromptSubmit hook), CAVEMAN_DEFAULT_MODE (env var), CLAUDE_CONFIG_DIR (env var), ICLAUDE_MICROVM_ACTIVE (env var) (+4 more)

### Community 7 - "should / with"
Cohesion: 0.09
Nodes (16): detector(), mask(), Simple redaction detector for testing purposes, Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently (+8 more)

### Community 8 - "cluster_8"
Cohesion: 0.12
Nodes (23): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+15 more)

### Community 9 - "vendored / graphify"
Cohesion: 0.12
Nodes (12): fake_pkg(), Проверяет что vendored graphifyy уже патчен (precondition)., Создаёт минимальный faux graphify пакет для патчинга., Idempotent: после первого apply повторный — no-op., Если dry-run patch fails — best-effort exit 0, fails counted., Скопировать реальные vendored файлы в fake_pkg для valid patch context., End-to-end: после apply_patches graphify update пишет relative paths., run_apply() (+4 more)

### Community 10 - "setup_isolated_config() / check_isolated_status()"
Cohesion: 0.1
Nodes (11): setup_isolated_config(), check_isolated_status(), CLAUDE_CONFIG_DIR, ISOLATED_NVM_DIR, detect_ohmyposh_platform(), get_ohmyposh_path(), check_ohmyposh_status(), get_claude_version() (+3 more)

### Community 11 - "should / redacted"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD be detected and redacted, Google AI Studio keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted, GitHub tokens should be redacted, Visa credit cards should be redacted, PEM private keys should be redacted, AWS Secret Access Keys should be redacted (+2 more)

### Community 12 - "should"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD NOT be redacted (false positive risks), UUIDs should NOT be redacted even if 32+ hex chars, Git commit hashes should NOT be treated as tokens, Version tags should NOT be redacted, Docker image references should not be completely redacted, Template variables should NOT be redacted, Bash placeholders should NOT be redacted, Test/example passwords in test files should preferably not be redacted (+2 more)

### Community 13 - "mask_token"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 14 - "parse_anthropic_data() / get_gemini_context_limit()"
Cohesion: 0.17
Nodes (9): parse_gemini_data(), parse_generic_data(), parse_ollama_data(), get_context_limit_for_model(), parse_openai_data(), calculate_cost(), get_model_display_name(), normalize_model_name() (+1 more)

### Community 15 - "adapters/anthropic.sh / calculate_cost()"
Cohesion: 0.13
Nodes (12): adapters/anthropic.sh, claude-statusline.sh, adapters/gemini.sh, init_streaming_state(), is_streaming_chunk(), adapters/ollama.sh, adapters/openai.sh, parse_with_adapter() (+4 more)

### Community 16 - "документирует"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 17 - "_pii_proxy_cascade_install() / _pii_proxy_check_prerequisites()"
Cohesion: 0.22
Nodes (11): _pii_proxy_cascade_install(), _pii_proxy_check_prerequisites(), _pii_proxy_download_model(), _pii_download_spacy_model(), install_isolated_pii_proxy(), _pip_proxy_args(), _install_regex_only_mode(), _resolve_proxy() (+3 more)

### Community 18 - "hook / token"
Cohesion: 0.14
Nodes (14): block-secrets.py hook, Caveman token compression, Claude Code Router, Chrome integration, Claude Code, Graphify knowledge graph, iclaude, Isolated NVM Environment (+6 more)

### Community 19 - "node_version / nvm-exec"
Cohesion: 0.18
Nodes (9): NODE_VERSION, check_oauth_token(), check_token_expiration(), CLAUDE_CODE_OAUTH_TOKEN, .credentials.json, ISOLATED_NVM_DIR, refresh_oauth_token(), TOKEN_REFRESH_THRESHOLD (+1 more)

### Community 20 - "test / suite"
Cohesion: 0.18
Nodes (9): Claude Code CLI, iclaude Project, _pii_dnat_sweep_stale(), Phase 0 Regression Test Suite, CCR integration test suite, PII DNAT E2E L3 test suite, PII DNAT iptables L2 test suite, PII DNAT test runner (L1+L2+L3) (+1 more)

### Community 21 - "маскирует / секреты"
Cohesion: 0.29
Nodes (10): is_excluded(), main(), Применяет все паттерны маскирования к тексту.     Возвращает (новый_текст, списо, Маскирует секреты в указанных текстовых полях словаря., Маскирует секреты в массиве edits инструмента MultiEdit.     Маскируется только, Записывает флаг события безопасности для статус-лайна., redact_fields(), redact_multiedit() (+2 more)

### Community 22 - "should / string"
Cohesion: 0.18
Nodes (6): Empty string should not crash, String with 'None' should not crash, Unicode characters should be handled gracefully, Text with multiple different secret types should redact all, Partial patterns should not be redacted if incomplete, TestEdgeCases

### Community 23 - "возвращает / если"
Cohesion: 0.29
Nodes (9): is_excluded(), is_safe_template(), is_sensitive_path(), main(), Возвращает True, если путь находится в директории исключений., Возвращает True если файл — известный безопасный шаблон (.env.example и т.п.)., Проверяет путь на совпадение с паттернами чувствительных файлов., Записывает флаг события безопасности для статус-лайна. (+1 more)

### Community 24 - "redacted / should"
Cohesion: 0.2
Nodes (5): Apply all patterns and return redacted text + found patterns, Stripe secret keys should be redacted, Stripe test keys should be redacted, Generic secret assignments should be redacted, Groq API keys should be redacted

### Community 25 - "hook / block-secrets.py"
Cohesion: 0.25
Nodes (4): block-secrets.py hook, redact-secrets.py hook, run_hook(), test-redact-hook.sh test suite

### Community 26 - "module / proxy"
Cohesion: 0.25
Nodes (8): Core JSON Module, Core Logging Module, Core Validation Module, Proxy Configure Module, Proxy Credentials Module, Proxy Git Module, Proxy Validation Module, Lib README

### Community 27 - "isolated_config_dir"
Cohesion: 0.33
Nodes (3): ISOLATED_CONFIG_DIR env var, setup_isolated_nvm(), detect_statusline()

### Community 29 - "cmd_list() / cmd_stats()"
Cohesion: 0.33
Nodes (3): cmd_view(), find_results_files(), find_session_file()

### Community 31 - "check_dependencies() / install_claude_code()"
Cohesion: 0.67
Nodes (3): check_dependencies(), install_claude_code(), install_nodejs()

### Community 32 - "detect_nvm() / cleanup_old_claude_installations()"
Cohesion: 0.67
Nodes (3): cleanup_old_claude_installations(), recreate_claude_symlinks(), update_claude_code()

### Community 33 - "ccr_host / ccr_port"
Cohesion: 0.67
Nodes (3): CCR_HOST, CCR_PORT, get_ccr_port()

## Knowledge Gaps
- **196 isolated node(s):** `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.`, `Detect installed spaCy models from venv marker files or by probing spacy.      R`, `Lazy-initialize Presidio NLP engine with all available language models.      Thr` (+191 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ICLAUDE_PII_ACTIVE env var` connect `anthropic_base_url` to `hook) / caveman-activate.js`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `parse_with_adapter()` connect `adapters/anthropic.sh / adapters/gemini.sh` to `hook) / caveman-activate.js`, `parse_anthropic_data() / get_gemini_context_limit()`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.` to the rest of the system?**
  _196 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `path / body` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `dispatch_command() / detect_graphify()` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._