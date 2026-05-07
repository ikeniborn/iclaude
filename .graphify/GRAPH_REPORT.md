# Graph Report - .  (2026-05-07)

## Corpus Check
- 39 files · ~62,101 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 315 nodes · 436 edges · 19 communities (15 shown, 4 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 10 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Secret Pattern Tests|Secret Pattern Tests]]
- [[_COMMUNITY_Architecture & Module Init|Architecture & Module Init]]
- [[_COMMUNITY_PII Proxy Request Handling|PII Proxy Request Handling]]
- [[_COMMUNITY_PII Proxy NLP Engine|PII Proxy NLP Engine]]
- [[_COMMUNITY_Router & Configuration|Router & Configuration]]
- [[_COMMUNITY_Security Hooks|Security Hooks]]
- [[_COMMUNITY_Proxy & Masking Logic|Proxy & Masking Logic]]
- [[_COMMUNITY_Redaction Pattern Tests|Redaction Pattern Tests]]
- [[_COMMUNITY_Test Infrastructure|Test Infrastructure]]
- [[_COMMUNITY_Quality Analysis Tests|Quality Analysis Tests]]
- [[_COMMUNITY_Graphify Integration|Graphify Integration]]
- [[_COMMUNITY_Permissions & Chunk Fix|Permissions & Chunk Fix]]
- [[_COMMUNITY_LLM Wiki|LLM Wiki]]
- [[_COMMUNITY_Token Pattern Tests|Token Pattern Tests]]
- [[_COMMUNITY_Skills & Context Awareness|Skills & Context Awareness]]
- [[_COMMUNITY_Verify Dialogue Spec|Verify Dialogue Spec]]
- [[_COMMUNITY_Verify Command Flow|Verify Command Flow]]
- [[_COMMUNITY_Plans Directory Config|Plans Directory Config]]
- [[_COMMUNITY_URL Validation|URL Validation]]

## God Nodes (most connected - your core abstractions)
1. `iclaude.sh (main entry point)` - 24 edges
2. `PIIProxyHandler` - 20 edges
3. `TestShouldRedact` - 13 edges
4. `TestFalsePositives` - 10 edges
5. `TestMaskToken` - 10 edges
6. `presidio_mask()` - 8 edges
7. `get_masked()` - 7 edges
8. `presidio_mask` - 7 edges
9. `iclaude README (User Guide v4.0)` - 7 edges
10. `lib/graphify (Knowledge Graph Module)` - 7 edges

## Surprising Connections (you probably didn't know these)
- `SecretDetector (regex pattern engine in tests)` --conceptually_related_to--> `redact-secrets.py (PreToolUse Layer 2)`  [INFERRED]
  tests/test_patterns_examples.py → CLAUDE.md
- `claude-statusline.sh Script` --references--> `lib/pii-proxy/server.py (PII proxy server with regex_mask)`  [EXTRACTED]
  docs/functions/STATUSLINE.md → tests/test_patterns_examples.py
- `iclaude lib Modular Architecture` --references--> `PIIProxyHandler`  [INFERRED]
  lib/README.md → lib/pii-proxy/server.py
- `Claude Code Router (CCR) Server` --references--> `iclaude.sh (main entry point)`  [EXTRACTED]
  docs/functions/ROUTER.md → CLAUDE.md
- `lib/launcher/launch.sh` --references--> `iclaude.sh (main entry point)`  [INFERRED]
  docs/superpowers/plans/2026-05-06-caveman-integration.md → CLAUDE.md

## Hyperedges (group relationships)
- **PII Masking Pipeline** — server_presidomask, server_regexmask, server_initpresidio [EXTRACTED 0.95]

## Communities (19 total, 4 thin omitted)

### Community 0 - "Secret Pattern Tests"
Cohesion: 0.05
Nodes (30): Apply all patterns and return redacted text + found patterns, Test cases for patterns that SHOULD be detected and redacted, Anthropic API keys should be redacted, Google AI Studio keys should be redacted, Stripe secret keys should be redacted, Stripe test keys should be redacted, HuggingFace tokens should be redacted, Groq API keys should be redacted (+22 more)

### Community 1 - "Architecture & Module Init"
Cohesion: 0.08
Nodes (36): docs/architecture/overview.yaml (iclaude v4.1 Architecture YAML), lib/caveman/install.sh, Caveman Integration Implementation Plan, Caveman Module (lib/caveman/), Caveman Token Compression (~65-75%), Claude Code Router (ccr binary), Claude Code CLI (@anthropic-ai/claude-code), CLAUDE_CONFIG_DIR (.nvm-isolated/.claude-isolated/) (+28 more)

### Community 2 - "PII Proxy Request Handling"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 3 - "PII Proxy NLP Engine"
Cohesion: 0.12
Nodes (23): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+15 more)

### Community 4 - "Router & Configuration"
Cohesion: 0.09
Nodes (24): CCR Router Slots (default/background/think/longContext), Claude Code Router (CCR) Server, CCR Transformers (deepseek/gemini/openrouter...), iclaude Configuration Reference, microVM Sandbox (Firecracker) Documentation, microVM Snapshots, microVM Workspace Modes (full/isolated), Ollama Local LLM Integration (+16 more)

### Community 5 - "Security Hooks"
Cohesion: 0.14
Nodes (19): block-secrets.py PreToolUse Hook, caveman (Claude Code token compression plugin), block-secrets.py (PreToolUse Layer 1), redact-secrets.py (PreToolUse Layer 2), lib/pii-proxy/server.py (PII Proxy, Presidio NLP), PII_PROXY_MASK_TOKEN (configurable masking token), PasteGuard PII Proxy, PII Masking Documentation (+11 more)

### Community 6 - "Proxy & Masking Logic"
Cohesion: 0.13
Nodes (18): iclaude lib Modular Architecture, Asymmetric Masking Design, _build_upstream_headers, _detect_spacy_models, _forward, _get_http_session, init_presidio, mask_content_block (+10 more)

### Community 7 - "Redaction Pattern Tests"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 8 - "Test Infrastructure"
Cohesion: 0.17
Nodes (10): detector(), mask(), Simple redaction detector for testing purposes, Tests for server.py regex_mask — imported directly to catch divergence., Simple user:pass@host should be masked., Password containing @ must not leak after masking., URLs without credentials must not be altered., Long URL with credentials should not cause ReDoS. (+2 more)

### Community 9 - "Quality Analysis Tests"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 10 - "Graphify Integration"
Cohesion: 0.26
Nodes (13): graph_fresh (staleness signal in project_context), graphifyy PyPI package (Knowledge Graph builder), lib/graphify (Knowledge Graph Module), project_context (shared data object between skills), skill: architecture-documentation (graph god_nodes as Core Components), skill: brainstorming (Step 1 graph integration), skill: context-awareness (populates project_context), skill: graphify-context (reads .graphify/ knowledge graph) (+5 more)

### Community 11 - "Permissions & Chunk Fix"
Cohesion: 0.18
Nodes (13): CLAUDE_CODE_SKIP_PERMISSIONS Variable, .claude_config.example, CHUNK_OUTPUT_PATH Substitution, Graphify Chunk Path Fix Plan, lib/graphify/detect.sh, graphifyy PyPI Package, lib/graphify/install.sh, Graphify Integration Implementation Plan (+5 more)

### Community 12 - "LLM Wiki"
Cohesion: 0.22
Nodes (11): domain-map.json (llm-wiki source types config), llm-wiki ingest-rules.md, llm-wiki Bootstrap Integration into Init Plan, llm-wiki Multi-Language Source Support Plan, llm-wiki Reader: Bash, llm-wiki Reader: JavaScript, llm-wiki Reader: Markdown, llm-wiki Reader: Python (+3 more)

### Community 13 - "Token Pattern Tests"
Cohesion: 0.2
Nodes (6): Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently, TestPerformance

### Community 14 - "Skills & Context Awareness"
Cohesion: 0.38
Nodes (7): architecture-documentation SKILL.md, brainstorming SKILL.md, Context Awareness Graph Integration Plan, context-awareness SKILL.md, graph_fresh Propagation, graphify-context Skill, prd-generator SKILL.md

## Knowledge Gaps
- **126 isolated node(s):** `Запускает хук и возвращает (stdout, stderr).`, `Возвращает маскированное содержимое или None если не изменено.`, `Утверждает что контент ДОЛЖЕН быть замаскирован с указанным плейсхолдером.`, `Утверждает что контент НЕ должен быть изменён хуком.`, `Документирует ПРОПУЩЕННЫЙ секрет (false negative — дыра в защите).` (+121 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `iclaude.sh (main entry point)` connect `Architecture & Module Init` to `Graphify Integration`, `Permissions & Chunk Fix`, `Router & Configuration`, `Security Hooks`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Why does `TestMaskToken` connect `Redaction Pattern Tests` to `Test Infrastructure`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Why does `lib/graphify (Knowledge Graph Module)` connect `Graphify Integration` to `Architecture & Module Init`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **What connects `Запускает хук и возвращает (stdout, stderr).`, `Возвращает маскированное содержимое или None если не изменено.`, `Утверждает что контент ДОЛЖЕН быть замаскирован с указанным плейсхолдером.` to the rest of the system?**
  _126 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Secret Pattern Tests` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Architecture & Module Init` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `PII Proxy Request Handling` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._