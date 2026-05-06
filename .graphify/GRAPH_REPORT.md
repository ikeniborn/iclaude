# Graph Report - .  (2026-05-06)

## Corpus Check
- 60 files · ~75,314 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 222 nodes · 310 edges · 23 communities (15 shown, 8 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 26 edges (avg confidence: 0.78)
- Token cost: 240,000 input · 115,531 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Context & Graph Awareness|Context & Graph Awareness]]
- [[_COMMUNITY_PII Proxy HTTP Layer|PII Proxy HTTP Layer]]
- [[_COMMUNITY_Presidio NLP Pipeline|Presidio NLP Pipeline]]
- [[_COMMUNITY_Caveman Config System|Caveman Config System]]
- [[_COMMUNITY_Agent & Architecture Skills|Agent & Architecture Skills]]
- [[_COMMUNITY_TOON Conversion Engine|TOON Conversion Engine]]
- [[_COMMUNITY_PII Proxy Design Rationale|PII Proxy Design Rationale]]
- [[_COMMUNITY_TOON Testing & Variants|TOON Testing & Variants]]
- [[_COMMUNITY_Workflow & Docs Skills|Workflow & Docs Skills]]
- [[_COMMUNITY_LLM Wiki Language Readers|LLM Wiki Language Readers]]
- [[_COMMUNITY_Caveman Mode Lifecycle|Caveman Mode Lifecycle]]
- [[_COMMUNITY_Session Stats Analysis|Session Stats Analysis]]
- [[_COMMUNITY_Caveman History|Caveman History]]
- [[_COMMUNITY_URL Validation|URL Validation]]
- [[_COMMUNITY_Flag Append|Flag Append]]
- [[_COMMUNITY_Valid Modes|Valid Modes]]
- [[_COMMUNITY_Stats Formatter|Stats Formatter]]
- [[_COMMUNITY_Recent Session Finder|Recent Session Finder]]
- [[_COMMUNITY_Compressed Session Summarizer|Compressed Session Summarizer]]
- [[_COMMUNITY_Nested TOON Converter|Nested TOON Converter]]

## God Nodes (most connected - your core abstractions)
1. `PIIProxyHandler` - 20 edges
2. `main()` - 15 edges
3. `graphify Skill` - 10 edges
4. `llm-wiki Skill` - 10 edges
5. `jsonToToon()` - 9 edges
6. `Architecture Documentation Skill` - 9 edges
7. `presidio_mask()` - 8 edges
8. `jsonToToon` - 8 edges
9. `Wiki Conventions` - 8 edges
10. `presidio_mask` - 7 edges

## Surprising Connections (you probably didn't know these)
- `iclaude lib Modular Architecture` --references--> `PIIProxyHandler`  [INFERRED]
  lib/README.md → lib/pii-proxy/server.py
- `Graphify Context Skill` --semantically_similar_to--> `Architecture Documentation Skill`  [INFERRED] [semantically similar]
  .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md → .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md
- `main()` --calls--> `readFlag()`  [INFERRED]
  .nvm-isolated/.claude-isolated/hooks/caveman-stats.js → .nvm-isolated/.claude-isolated/hooks/caveman-config.js
- `main()` --calls--> `appendFlag()`  [INFERRED]
  .nvm-isolated/.claude-isolated/hooks/caveman-stats.js → .nvm-isolated/.claude-isolated/hooks/caveman-config.js
- `main()` --calls--> `safeWriteFlag()`  [INFERRED]
  .nvm-isolated/.claude-isolated/hooks/caveman-stats.js → .nvm-isolated/.claude-isolated/hooks/caveman-config.js

## Hyperedges (group relationships)
- **PII Masking Pipeline** — server_presidomask, server_regexmask, server_initpresidio [EXTRACTED 0.95]
- **Caveman Flag Read-Write Lifecycle** — cavemanconfig_safewriteflag, cavemanconfig_readflag, cavemanconfig_appendflag [EXTRACTED 0.95]
- **TOON Lossless Round-Trip Conversion** — toonconverter_jsontotoon, toonconverter_toontoson, toonconverter_roundtriptest [EXTRACTED 0.95]
- **Context Awareness integrates Graph and Wiki into project_context** — skill_context_awareness, skill_graphify, skill_llm_wiki, context_awareness_project_context [EXTRACTED 0.95]
- **Graphify Extraction Pipeline: AST + Semantic Subagents + Merge** — skill_graphify, graphify_semantic_extraction, graphify_direct_backend, graphify_incremental_update [EXTRACTED 0.95]
- **TOON Skill: API + RFC-0003 + Integration Pattern form token optimization layer** — skill_toon, toon_converter_api, toon_rfc0003, toon_hybrid_output_pattern [EXTRACTED 0.95]
- **LLM Wiki Reader Pipeline - all language readers share wiki-conventions output format** — reader_javascript, reader_typescript, reader_python, reader_bash, reader_markdown, wiki_conventions [INFERRED 0.85]
- **Agent Builder Generation Flow - skill + best practices + examples form agent creation system** — agent_builder_skill, agent_best_practices, agent_builder_full_example, agent_builder_minimal_example [EXTRACTED 1.00]
- **TOON Documentation Ecosystem - converter, guide, benchmarks, workflow together implement TOON integration** — toon_converter_readme, toon_integration_guide, toon_benchmarks, toon_workflow_example [EXTRACTED 1.00]

## Communities (23 total, 8 thin omitted)

### Community 0 - "Context & Graph Awareness"
Cohesion: 0.08
Nodes (31): context-awareness Basic Usage Example, Graph Detection (Step 6), project_context Output Object, Wiki Detection (Step 5), Circular Dependency Detection Algorithm, Direct LLM Backend (Kimi/Ollama), Incremental Update (--update), Graphify MCP Server (+23 more)

### Community 1 - "PII Proxy HTTP Layer"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 2 - "Presidio NLP Pipeline"
Cohesion: 0.12
Nodes (23): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+15 more)

### Community 3 - "Caveman Config System"
Cohesion: 0.17
Nodes (21): appendFlag(), getConfigDir(), getConfigPath(), getDefaultMode(), readFlag(), readHistory(), safeWriteFlag(), aggregateHistory() (+13 more)

### Community 4 - "Agent & Architecture Skills"
Cohesion: 0.14
Nodes (22): Agent Best Practices, Agent Builder Full Example (security-auditor), Agent Builder Minimal Example (file-summarizer), Agent Builder Skill, Agent Minimum Privilege Principle, Architecture Documentation Skill, Architecture Full YAML Template, Architecture README Template (+14 more)

### Community 5 - "TOON Conversion Engine"
Cohesion: 0.22
Nodes (11): arrayToToon(), calculateTokenSavings(), componentsToToon(), dependencyGraphToToon(), edgesToToon(), extractToonBlock(), jsonToToon(), roundTripTest() (+3 more)

### Community 6 - "PII Proxy Design Rationale"
Cohesion: 0.13
Nodes (18): iclaude lib Modular Architecture, Asymmetric Masking Design, _build_upstream_headers, _detect_spacy_models, _forward, _get_http_session, init_presidio, mask_content_block (+10 more)

### Community 7 - "TOON Testing & Variants"
Cohesion: 0.24
Nodes (14): architecture-documentation toon-converter wrapper, end-to-end TOON integration test suite, round-trip test suite, skill-md-integration test suite, calculateTokenSavings, componentsToToon, dependencyGraphToToon, edgesToToon (+6 more)

### Community 8 - "Workflow & Docs Skills"
Cohesion: 0.2
Nodes (10): git-workflow basic-usage example, git-workflow SKILL.md, task-summary template, mermaid-obsidian SKILL.md, PRD basic SaaS product example, PRD Best Practices rules, Markdown Guidelines for PRD, Mermaid Diagram Templates for PRD (+2 more)

### Community 9 - "LLM Wiki Language Readers"
Cohesion: 0.31
Nodes (9): Lint Criteria, Reader Bash, Reader JavaScript, Reader Markdown, Reader Python, Reader TypeScript, Wiki Conventions, Wiki Frontmatter Convention (+1 more)

### Community 10 - "Caveman Mode Lifecycle"
Cohesion: 0.47
Nodes (6): caveman-activate main, getDefaultMode, readFlag, safeWriteFlag, Symlink-Safe Flag Write Design, caveman-mode-tracker main

### Community 11 - "Session Stats Analysis"
Cohesion: 0.67
Nodes (3): COMPRESSION, deriveSavings, parseSession

## Knowledge Gaps
- **77 isolated node(s):** `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.`, `Detect installed spaCy models from venv marker files or by probing spacy.      R`, `Lazy-initialize Presidio NLP engine with all available language models.      Thr` (+72 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PIIProxyHandler` connect `PII Proxy HTTP Layer` to `Presidio NLP Pipeline`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `main()` (e.g. with `readFlag()` and `appendFlag()`) actually correct?**
  _`main()` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `graphify Skill` (e.g. with `compact-session Skill` and `llm-wiki Skill`) actually correct?**
  _`graphify Skill` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.` to the rest of the system?**
  _77 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Context & Graph Awareness` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `PII Proxy HTTP Layer` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._
- **Should `Presidio NLP Pipeline` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._