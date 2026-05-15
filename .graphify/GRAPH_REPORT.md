# Graph Report - .  (2026-05-15)

## Corpus Check
- Large corpus: 284 files · ~345,386 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 682 nodes · 849 edges · 88 communities (63 shown, 25 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 32 edges (avg confidence: 0.85)
- Token cost: 45,479 input · 2,000 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]

## God Nodes (most connected - your core abstractions)
1. `iclaude.sh (main entry point)` - 27 edges
2. `TestShouldRedact` - 21 edges
3. `PIIProxyHandler` - 20 edges
4. `install_microvm()` - 16 edges
5. `main()` - 15 edges
6. `microVM unit test suite` - 14 edges
7. `ISOLATED_NVM_DIR` - 13 edges
8. `iclaude` - 13 edges
9. `parse_with_adapter()` - 11 edges
10. `TestFalsePositives` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Graphify Patch Applier` --references--> `Graphify Patches Tests`  [EXTRACTED]
  lib/graphify/apply_patches.sh → tests/test_graphify_patches.py
- `redact-secrets.py hook` --references--> `test-redact-hook.sh test suite`  [EXTRACTED]
  .nvm-isolated/.claude-isolated/hooks/redact-secrets.py → tests/test-redact-hook.sh
- `redact-secrets.py hook` --calls--> `run_hook()`  [EXTRACTED]
  .nvm-isolated/.claude-isolated/hooks/redact-secrets.py → tests/test-redact-hook.sh
- `block-secrets.py hook` --references--> `test-redact-hook.sh test suite`  [EXTRACTED]
  .nvm-isolated/.claude-isolated/hooks/block-secrets.py → tests/test-redact-hook.sh
- `iclaude.sh (main entry point)` --calls--> `install_isolated_pii_proxy()`  [EXTRACTED]
  iclaude.sh → lib/pii-proxy/install.sh

## Hyperedges (group relationships)
- **launch_claude orchestrates PII proxy, CCR router, and telemetry subsystems with trap-based cleanup** — launch_launch_claude, launch_start_pii_proxy_server, launch_start_ccr_server, launch_stop_pii_proxy_server, launch_stop_ccr_server, otel_print_telemetry_status [EXTRACTED 1.00]
- **setup_telemetry exports OTEL_* env vars consumed by Claude Code launched in launch_claude** — otel_setup_telemetry, otel_print_telemetry_status, launch_launch_claude [INFERRED 0.85]

## Communities (88 total, 25 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (61): body, filtered, flagPath, fs, { getDefaultMode, safeWriteFlag }, INDEPENDENT_MODES, mode, os (+53 more)

### Community 1 - "Community 1"
Cohesion: 0.08
Nodes (35): detect_graphify(), install_graphify(), _patch_graphify_watch(), _graphify_rebuild_graph(), _graphify_resolve_proxy(), _graphify_resolve_uv(), check_graphify_status(), iclaude.sh (main entry point) (+27 more)

### Community 2 - "Community 2"
Cohesion: 0.08
Nodes (21): load_claude_config(), CREDENTIALS_FILE, ISOLATED_CONFIG_DIR, MICRO_VM_ENABLED, PROXY_URL, check_distro_microvm_support(), detect_kvm_support(), detect_linux_distro() (+13 more)

### Community 3 - "Community 3"
Cohesion: 0.09
Nodes (19): adapters/anthropic.sh, adapters/gemini.sh, adapters/generic.sh, adapters/ollama.sh, adapters/openai.sh, get_provider_adapter(), parse_with_adapter(), get_chunk_type() (+11 more)

### Community 4 - "Community 4"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 5 - "Community 5"
Cohesion: 0.09
Nodes (12): caveman-activate.js (SessionStart hook), getDefaultMode(), readFlag(), safeWriteFlag(), caveman-mode-tracker.js (UserPromptSubmit hook), CAVEMAN_DEFAULT_MODE (env var), CLAUDE_CONFIG_DIR (env var), ICLAUDE_MICROVM_ACTIVE (env var) (+4 more)

### Community 6 - "Community 6"
Cohesion: 0.09
Nodes (16): detector(), mask(), Simple redaction detector for testing purposes, Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently (+8 more)

### Community 7 - "Community 7"
Cohesion: 0.11
Nodes (16): ANTHROPIC_BASE_URL env var, ICLAUDE_PII_ACTIVE env var, MICRO_VM_ENABLED env var, MICRO_VM_NET_SUBNET env var, init_environment(), _alloc_microvm_slot(), _claim_microvm_slot(), configure_guest_environment() (+8 more)

### Community 8 - "Community 8"
Cohesion: 0.12
Nodes (23): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+15 more)

### Community 9 - "Community 9"
Cohesion: 0.12
Nodes (12): fake_pkg(), Проверяет что vendored graphifyy уже патчен (precondition)., Создаёт минимальный faux graphify пакет для патчинга., Idempotent: после первого apply повторный — no-op., Если dry-run patch fails — best-effort exit 0, fails counted., Скопировать реальные vendored файлы в fake_pkg для valid patch context., End-to-end: после apply_patches graphify update пишет relative paths., run_apply() (+4 more)

### Community 10 - "Community 10"
Cohesion: 0.1
Nodes (11): setup_isolated_config(), check_isolated_status(), CLAUDE_CONFIG_DIR, ISOLATED_NVM_DIR, detect_ohmyposh_platform(), get_ohmyposh_path(), check_ohmyposh_status(), get_claude_version() (+3 more)

### Community 11 - "Community 11"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD be detected and redacted, GitHub tokens should be redacted, AWS Access Key IDs should be redacted, Visa credit cards should be redacted, PEM private keys should be redacted, Generic secret assignments should be redacted, Google AI Studio keys should be redacted, Groq API keys should be redacted (+2 more)

### Community 12 - "Community 12"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD NOT be redacted (false positive risks), UUIDs should NOT be redacted even if 32+ hex chars, Git commit hashes should NOT be treated as tokens, Version tags should NOT be redacted, Docker image references should not be completely redacted, Template variables should NOT be redacted, Bash placeholders should NOT be redacted, Test/example passwords in test files should preferably not be redacted (+2 more)

### Community 13 - "Community 13"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 14 - "Community 14"
Cohesion: 0.17
Nodes (9): parse_gemini_data(), parse_generic_data(), parse_ollama_data(), get_context_limit_for_model(), parse_openai_data(), calculate_cost(), get_model_display_name(), normalize_model_name() (+1 more)

### Community 15 - "Community 15"
Cohesion: 0.13
Nodes (12): adapters/anthropic.sh, claude-statusline.sh, adapters/gemini.sh, init_streaming_state(), is_streaming_chunk(), adapters/ollama.sh, adapters/openai.sh, parse_with_adapter() (+4 more)

### Community 16 - "Community 16"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 17 - "Community 17"
Cohesion: 0.22
Nodes (11): _pii_proxy_cascade_install(), _pii_proxy_check_prerequisites(), _pii_proxy_download_model(), _pii_download_spacy_model(), install_isolated_pii_proxy(), _pip_proxy_args(), _install_regex_only_mode(), _resolve_proxy() (+3 more)

### Community 18 - "Community 18"
Cohesion: 0.14
Nodes (14): block-secrets.py hook, Caveman token compression, Claude Code Router, Chrome integration, Claude Code, Graphify knowledge graph, iclaude, Isolated NVM Environment (+6 more)

### Community 19 - "Community 19"
Cohesion: 0.18
Nodes (9): NODE_VERSION, check_oauth_token(), check_token_expiration(), CLAUDE_CODE_OAUTH_TOKEN, .credentials.json, ISOLATED_NVM_DIR, refresh_oauth_token(), TOKEN_REFRESH_THRESHOLD (+1 more)

### Community 20 - "Community 20"
Cohesion: 0.18
Nodes (9): Claude Code CLI, iclaude Project, _pii_dnat_sweep_stale(), Phase 0 Regression Test Suite, CCR integration test suite, PII DNAT E2E L3 test suite, PII DNAT iptables L2 test suite, PII DNAT test runner (L1+L2+L3) (+1 more)

### Community 21 - "Community 21"
Cohesion: 0.23
Nodes (12): cleanup_orphaned_pii_proxies, cleanup_stale_session_env, launch_claude, _register_pii_consumer, start_ccr_server, start_pii_proxy_server, stop_ccr_server, stop_pii_proxy_server (+4 more)

### Community 22 - "Community 22"
Cohesion: 0.29
Nodes (10): is_excluded(), main(), Применяет все паттерны маскирования к тексту.     Возвращает (новый_текст, списо, Маскирует секреты в указанных текстовых полях словаря., Маскирует секреты в массиве edits инструмента MultiEdit.     Маскируется только, Записывает флаг события безопасности для статус-лайна., redact_fields(), redact_multiedit() (+2 more)

### Community 23 - "Community 23"
Cohesion: 0.18
Nodes (6): Empty string should not crash, String with 'None' should not crash, Unicode characters should be handled gracefully, Text with multiple different secret types should redact all, Partial patterns should not be redacted if incomplete, TestEdgeCases

### Community 24 - "Community 24"
Cohesion: 0.29
Nodes (9): is_excluded(), is_safe_template(), is_sensitive_path(), main(), Возвращает True, если путь находится в директории исключений., Возвращает True если файл — известный безопасный шаблон (.env.example и т.п.)., Проверяет путь на совпадение с паттернами чувствительных файлов., Записывает флаг события безопасности для статус-лайна. (+1 more)

### Community 25 - "Community 25"
Cohesion: 0.2
Nodes (5): Apply all patterns and return redacted text + found patterns, Anthropic API keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted, Credentials in URLs should be redacted

### Community 26 - "Community 26"
Cohesion: 0.25
Nodes (4): block-secrets.py hook, redact-secrets.py hook, run_hook(), test-redact-hook.sh test suite

### Community 27 - "Community 27"
Cohesion: 0.25
Nodes (8): Core JSON Module, Core Logging Module, Core Validation Module, Proxy Configure Module, Proxy Credentials Module, Proxy Git Module, Proxy Validation Module, Lib README

### Community 29 - "Community 29"
Cohesion: 0.33
Nodes (3): ISOLATED_CONFIG_DIR env var, setup_isolated_nvm(), detect_statusline()

### Community 31 - "Community 31"
Cohesion: 0.33
Nodes (3): cmd_view(), find_results_files(), find_session_file()

### Community 33 - "Community 33"
Cohesion: 0.67
Nodes (3): check_dependencies(), install_claude_code(), install_nodejs()

### Community 34 - "Community 34"
Cohesion: 0.67
Nodes (3): cleanup_old_claude_installations(), recreate_claude_symlinks(), update_claude_code()

### Community 35 - "Community 35"
Cohesion: 0.67
Nodes (3): CCR_HOST, CCR_PORT, get_ccr_port()

## Knowledge Gaps
- **201 isolated node(s):** `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.`, `Detect installed spaCy models from venv marker files or by probing spacy.      R`, `Lazy-initialize Presidio NLP engine with all available language models.      Thr` (+196 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **25 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `parse_with_adapter()` connect `Community 3` to `Community 5`, `Community 14`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `ICLAUDE_PII_ACTIVE env var` connect `Community 7` to `Community 5`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.` to the rest of the system?**
  _201 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._