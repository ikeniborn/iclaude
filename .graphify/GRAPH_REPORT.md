# Graph Report - .  (2026-05-07)

## Corpus Check
- 53 files · ~80,593 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 338 nodes · 450 edges · 19 communities (17 shown, 2 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.88)
- Token cost: 178,869 input · 16,008 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Secret Redaction Patterns|Secret Redaction Patterns]]
- [[_COMMUNITY_Project Architecture Overview|Project Architecture Overview]]
- [[_COMMUNITY_PII Proxy HTTP Handlers|PII Proxy HTTP Handlers]]
- [[_COMMUNITY_Path Normalization Tests|Path Normalization Tests]]
- [[_COMMUNITY_PII Proxy Server Core|PII Proxy Server Core]]
- [[_COMMUNITY_Graphify Design Docs|Graphify Design Docs]]
- [[_COMMUNITY_Graphify Patch Tests|Graphify Patch Tests]]
- [[_COMMUNITY_MASK_TOKEN Configuration|MASK_TOKEN Configuration]]
- [[_COMMUNITY_PII Detector Tests|PII Detector Tests]]
- [[_COMMUNITY_PII Quality Analysis|PII Quality Analysis]]
- [[_COMMUNITY_Caveman & Patch Plans|Caveman & Patch Plans]]
- [[_COMMUNITY_Edge Case Redaction Tests|Edge Case Redaction Tests]]
- [[_COMMUNITY_Redaction Performance Tests|Redaction Performance Tests]]
- [[_COMMUNITY_Graphify Integration|Graphify Integration]]
- [[_COMMUNITY_Skills Ecosystem|Skills Ecosystem]]
- [[_COMMUNITY_Shared PII Proxy|Shared PII Proxy]]
- [[_COMMUNITY_LLM Wiki Multilang|LLM Wiki Multilang]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]

## God Nodes (most connected - your core abstractions)
1. `TestShouldRedact` - 21 edges
2. `PIIProxyHandler` - 20 edges
3. `iclaude.sh Main Script` - 12 edges
4. `TestFalsePositives` - 10 edges
5. `TestMaskToken` - 10 edges
6. `TestNormalizeManifest` - 8 edges
7. `presidio_mask()` - 8 edges
8. `Lib README` - 8 edges
9. `get_masked()` - 7 edges
10. `mask_request_body()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Graphify C3 Patch Design (Layer 2)` --conceptually_related_to--> `Graphify Patches Tests`  [INFERRED]
  docs/superpowers/specs/2026-05-07-graphify-c3-patch-graphifyy-design.md → tests/test_graphify_patches.py
- `iclaude Project` --implements--> `block-secrets.py Security Hook`  [EXTRACTED]
  CLAUDE.md → .nvm-isolated/.claude-isolated/hooks/block-secrets.py
- `iclaude Project` --implements--> `redact-secrets.py Security Hook`  [EXTRACTED]
  CLAUDE.md → .nvm-isolated/.claude-isolated/hooks/redact-secrets.py
- `PII Proxy Shared Server Plan` --implements--> `lib/pii-proxy/server.py`  [EXTRACTED]
  docs/superpowers/plans/2026-05-07-pii-shared-server.md → lib/pii-proxy/server.py
- `Graphify Path Normalization Plan` --implements--> `normalize-paths.py hook`  [EXTRACTED]
  docs/superpowers/plans/2026-05-07-graphify-portability-plan.md → .nvm-isolated/.claude-isolated/hooks/normalize-paths.py

## Communities (19 total, 2 thin omitted)

### Community 0 - "Secret Redaction Patterns"
Cohesion: 0.05
Nodes (32): Apply all patterns and return redacted text + found patterns, Test cases for patterns that SHOULD be detected and redacted, Anthropic API keys should be redacted, Google AI Studio keys should be redacted, Stripe secret keys should be redacted, Stripe test keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted (+24 more)

### Community 1 - "Project Architecture Overview"
Cohesion: 0.06
Nodes (35): block-secrets.py Security Hook, Claude Code CLI, Claude Code Router (CCR), Claude Configuration File, DeepSeek API, Architecture Overview, microVM Documentation, PII Masking Documentation (+27 more)

### Community 2 - "PII Proxy HTTP Handlers"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 3 - "Path Normalization Tests"
Cohesion: 0.07
Nodes (9): Симулирует git clone на другой машине., Создаёт временную .graphify/-подобную директорию., Прямой вызов (пустой stdin) — нормализация выполняется., TestGetProjectRoot, TestHookFilter, TestNormalizeCacheFile, TestNormalizeManifest, TestNormalizeRoot (+1 more)

### Community 4 - "PII Proxy Server Core"
Cohesion: 0.11
Nodes (25): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+17 more)

### Community 5 - "Graphify Design Docs"
Cohesion: 0.13
Nodes (22): Graphify C3 Patch Design (Layer 2), Graphify Integration Design, Graphify Portability Design (Layer 1), graphifyy Upstream Repository, Main Entry Script, Core Init Module, Core JSON Module, Core Logging Module (+14 more)

### Community 6 - "Graphify Patch Tests"
Cohesion: 0.12
Nodes (12): fake_pkg(), Проверяет что vendored graphifyy уже патчен (precondition)., Создаёт минимальный faux graphify пакет для патчинга., Idempotent: после первого apply повторный — no-op., Если dry-run patch fails — best-effort exit 0, fails counted., Скопировать реальные vendored файлы в fake_pkg для valid patch context., End-to-end: после apply_patches graphify update пишет relative paths., run_apply() (+4 more)

### Community 7 - "MASK_TOKEN Configuration"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 8 - "PII Detector Tests"
Cohesion: 0.17
Nodes (10): detector(), mask(), Simple redaction detector for testing purposes, Tests for server.py regex_mask — imported directly to catch divergence., Simple user:pass@host should be masked., Password containing @ must not leak after masking., URLs without credentials must not be altered., Long URL with credentials should not cause ReDoS. (+2 more)

### Community 9 - "PII Quality Analysis"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 10 - "Caveman & Patch Plans"
Cohesion: 0.2
Nodes (11): Caveman JS Hooks, Caveman Integration Design, Caveman Token Compression Integration, Caveman Upstream Repository, Graphify Portability v2 Patch Plan, Graphify Path Normalization Plan, lib/caveman/install.sh, Caveman Install Script (+3 more)

### Community 11 - "Edge Case Redaction Tests"
Cohesion: 0.18
Nodes (6): Empty string should not crash, String with 'None' should not crash, Unicode characters should be handled gracefully, Text with multiple different secret types should redact all, Partial patterns should not be redacted if incomplete, TestEdgeCases

### Community 12 - "Redaction Performance Tests"
Cohesion: 0.2
Nodes (6): Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently, TestPerformance

### Community 13 - "Graphify Integration"
Cohesion: 0.36
Nodes (10): Graph Integration into Skills, Graphify Hardcode Audit Design, Graphify GRAPHIFY_OUT Hardcode Fix, Graphify Integration Implementation Plan, Graphify Manifest Path Bug Fix, graphifyy (PyPI tool), lib/graphify/install.sh, context-awareness SKILL.md (+2 more)

### Community 14 - "Skills Ecosystem"
Cohesion: 0.31
Nodes (9): Architecture Documentation Skill, Brainstorming Skill, Context Awareness Graph Integration Design, Context Awareness Skill, Graphify Chunk Path Fix Design, Graphify Context Skill, Graphify Manifest Path Bug Design, Graphify Skill (+1 more)

### Community 15 - "Shared PII Proxy"
Cohesion: 0.48
Nodes (7): lib/launcher/launch.sh, lib/pii-proxy/server.py, Shared PII Proxy, PII Proxy Detach Design Spec, PII Shared Proxy Detach Plan, PII Shared Server Design Spec, PII Proxy Shared Server Plan

### Community 16 - "LLM Wiki Multilang"
Cohesion: 0.67
Nodes (3): LLM Wiki Multi-Language Support, LLM Wiki Language Readers, llm-wiki SKILL.md

## Knowledge Gaps
- **123 isolated node(s):** `Создаёт временную .graphify/-подобную директорию.`, `Симулирует git clone на другой машине.`, `Прямой вызов (пустой stdin) — нормализация выполняется.`, `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.` (+118 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TestShouldRedact` connect `Secret Redaction Patterns` to `PII Detector Tests`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `TestMaskToken` connect `MASK_TOKEN Configuration` to `PII Detector Tests`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `PIIProxyHandler` connect `PII Proxy HTTP Handlers` to `PII Proxy Server Core`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **What connects `Создаёт временную .graphify/-подобную директорию.`, `Симулирует git clone на другой машине.`, `Прямой вызов (пустой stdin) — нормализация выполняется.` to the rest of the system?**
  _123 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Secret Redaction Patterns` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Project Architecture Overview` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `PII Proxy HTTP Handlers` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._