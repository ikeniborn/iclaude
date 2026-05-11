# Graph Report - .  (2026-05-11)

## Corpus Check
- Corpus is ~46,371 words - fits in a single context window. You may not need a graph.

## Summary
- 304 nodes · 384 edges · 29 communities (13 shown, 16 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e81affe9`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_redacted  should|redacted / should]]
- [[_COMMUNITY_caveman  graphify|caveman / graphify]]
- [[_COMMUNITY__get_http_session()  piiproxyhandler|_get_http_session() / piiproxyhandler]]
- [[_COMMUNITY_cluster_3|cluster_3]]
- [[_COMMUNITY_vendored  graphify|vendored / graphify]]
- [[_COMMUNITY_microvm  architecture|microvm / architecture]]
- [[_COMMUNITY_should|should]]
- [[_COMMUNITY_mask_token|mask_token]]
- [[_COMMUNITY_router  deepseek|router / deepseek]]
- [[_COMMUNITY_simple|simple]]
- [[_COMMUNITY_документирует|документирует]]
- [[_COMMUNITY_skill  agent-builder|skill / agent-builder]]
- [[_COMMUNITY_should  with|should / with]]
- [[_COMMUNITY_libpii-proxyserver.py|lib/pii-proxy/server.py]]
- [[_COMMUNITY_graphify  patches|graphify / patches]]
- [[_COMMUNITY_oauth  token|oauth / token]]
- [[_COMMUNITY_readme|readme]]
- [[_COMMUNITY_claude-statusline.sh|claude-statusline.sh]]
- [[_COMMUNITY_firecracker|firecracker]]
- [[_COMMUNITY_skills  description|skills / description]]
- [[_COMMUNITY_router  documentation|router / documentation]]
- [[_COMMUNITY_proxy  configuration|proxy / configuration]]
- [[_COMMUNITY_proxy  documentation|proxy / documentation]]
- [[_COMMUNITY_telemetry  documentation|telemetry / documentation]]
- [[_COMMUNITY_claude  configuration|claude / configuration]]
- [[_COMMUNITY_status  line|status / line]]
- [[_COMMUNITY_microsoft  presidio|microsoft / presidio]]
- [[_COMMUNITY_pasteguard  proxy|pasteguard / proxy]]
- [[_COMMUNITY_masking  documentation|masking / documentation]]

## God Nodes (most connected - your core abstractions)
1. `TestShouldRedact` - 21 edges
2. `PIIProxyHandler` - 20 edges
3. `PII Proxy Server` - 17 edges
4. `iclaude` - 13 edges
5. `Claude Code Router (CCR)` - 12 edges
6. `Claude Code Skills System` - 11 edges
7. `TestFalsePositives` - 10 edges
8. `TestMaskToken` - 10 edges
9. `iclaude Project` - 10 edges
10. `microVM Sandbox (Firecracker v2)` - 10 edges

## Surprising Connections (you probably didn't know these)
- `PII Proxy Server` --shares_data_with--> `Quality Analysis Tests`  [INFERRED]
  lib/pii-proxy/server.py → tests/test-quality-analysis.py
- `PII Proxy Server` --shares_data_with--> `Pattern Examples Tests`  [INFERRED]
  lib/pii-proxy/server.py → tests/test_patterns_examples.py
- `iclaude Project` --conceptually_related_to--> `Claude Code CLI`  [EXTRACTED]
  docs/architecture/diagrams/README.md → CLAUDE.md
- `microVM (Firecracker) sandbox` --references--> `microVM Sandbox (Firecracker v2)`  [EXTRACTED]
  README.md → docs/functions/MICROVM.md
- `NVM Isolated Environment` --shares_data_with--> `Claude Code CLI`  [EXTRACTED]
  docs/architecture/diagrams/data-flow-isolated-installation.md → CLAUDE.md

## Hyperedges (group relationships)
- **Graphify path-portability workaround stack pending upstream resolution** — graphify_portability_patches, upstream_normalize_paths_hook, upstream_patch_graphify_watch, upstream_issue_777 [EXTRACTED 1.00]

## Communities (29 total, 16 thin omitted)

### Community 0 - "redacted / should"
Cohesion: 0.05
Nodes (28): Apply all patterns and return redacted text + found patterns, Test cases for patterns that SHOULD be detected and redacted, Anthropic API keys should be redacted, Google AI Studio keys should be redacted, Stripe secret keys should be redacted, Stripe test keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted (+20 more)

### Community 1 - "caveman / graphify"
Cohesion: 0.07
Nodes (32): Caveman Auto-Clarity, Caveman, Caveman 4 hooks (activate/config/mode-tracker/stats), Caveman isolated installer (lib/caveman/install.sh), lib/graphify/apply_patches.sh, lib/graphify/detect.sh, Graphify integration, lib/graphify/install.sh (+24 more)

### Community 2 - "_get_http_session() / piiproxyhandler"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 3 - "cluster_3"
Cohesion: 0.11
Nodes (26): PII Proxy Server, _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix() (+18 more)

### Community 4 - "vendored / graphify"
Cohesion: 0.12
Nodes (12): fake_pkg(), Проверяет что vendored graphifyy уже патчен (precondition)., Создаёт минимальный faux graphify пакет для патчинга., Idempotent: после первого apply повторный — no-op., Если dry-run patch fails — best-effort exit 0, fails counted., Скопировать реальные vendored файлы в fake_pkg для valid patch context., End-to-end: после apply_patches graphify update пишет relative paths., run_apply() (+4 more)

### Community 5 - "microvm / architecture"
Cohesion: 0.1
Nodes (19): Architecture Diagrams README, Claude Code CLI, Architecture Overview, iclaude Project, Isolated Installation (NVM), PII DNAT troubleshooting (MICROVM.md), Firecracker VMM, iclaude-guest-init (PID 1) (+11 more)

### Community 6 - "should"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD NOT be redacted (false positive risks), UUIDs should NOT be redacted even if 32+ hex chars, Git commit hashes should NOT be treated as tokens, Version tags should NOT be redacted, Docker image references should not be completely redacted, Template variables should NOT be redacted, Bash placeholders should NOT be redacted, Test/example passwords in test files should preferably not be redacted (+2 more)

### Community 7 - "mask_token"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 8 - "router / deepseek"
Cohesion: 0.12
Nodes (17): Anthropic API, Claude Code Router (CCR), Credential Storage (.claude_proxy_credentials), DeepSeek API, DeepSeek API Provider, Google Gemini API, HTTP_PROXY Environment Variable, HTTPS_PROXY Environment Variable (+9 more)

### Community 9 - "simple"
Cohesion: 0.17
Nodes (10): detector(), mask(), Simple redaction detector for testing purposes, Tests for server.py regex_mask — imported directly to catch divergence., Simple user:pass@host should be masked., Password containing @ must not leak after masking., URLs without credentials must not be altered., Long URL with credentials should not cause ReDoS. (+2 more)

### Community 10 - "документирует"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 11 - "skill / agent-builder"
Cohesion: 0.24
Nodes (11): agent-builder Skill, architecture-documentation Skill, context-awareness Skill, git-workflow Skill, graphify Skill, graphify-context Skill, llm-wiki Skill, mermaid-obsidian Skill (+3 more)

### Community 12 - "should / with"
Cohesion: 0.2
Nodes (6): Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently, TestPerformance

## Knowledge Gaps
- **152 isolated node(s):** `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.`, `Detect installed spaCy models from venv marker files or by probing spacy.      R`, `Lazy-initialize Presidio NLP engine with all available language models.      Thr` (+147 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `iclaude Project` connect `microvm / architecture` to `router / deepseek`, `skill / agent-builder`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._
- **Why does `iclaude` connect `caveman / graphify` to `microvm / architecture`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `PII Proxy Server` (e.g. with `Quality Analysis Tests` and `Pattern Examples Tests`) actually correct?**
  _`PII Proxy Server` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.` to the rest of the system?**
  _152 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `redacted / should` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._