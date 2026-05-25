# Graph Report - .  (2026-05-25)

## Corpus Check
- Large corpus: 289 files · ~343,583 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 700 nodes · 803 edges · 106 communities (43 shown, 63 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 81 edges (avg confidence: 0.77)
- Token cost: 0 input · 70,080 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Caveman Skill Modes|Caveman Skill Modes]]
- [[_COMMUNITY_Skills and Security Hooks|Skills and Security Hooks]]
- [[_COMMUNITY_PII Proxy HTTP Handler|PII Proxy HTTP Handler]]
- [[_COMMUNITY_GSD Spec Artifacts|GSD Spec Artifacts]]
- [[_COMMUNITY_GSD Dev Workflow|GSD Dev Workflow]]
- [[_COMMUNITY_TOON End-to-End Tests|TOON End-to-End Tests]]
- [[_COMMUNITY_Decision Gates|Decision Gates]]
- [[_COMMUNITY_Pattern Detection Tests|Pattern Detection Tests]]
- [[_COMMUNITY_PII Proxy Core|PII Proxy Core]]
- [[_COMMUNITY_TOON Skill Tests|TOON Skill Tests]]
- [[_COMMUNITY_Graphify Patch Tests|Graphify Patch Tests]]
- [[_COMMUNITY_TOON Converter|TOON Converter]]
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
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 72|Community 72]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 81|Community 81]]
- [[_COMMUNITY_Community 82|Community 82]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]
- [[_COMMUNITY_Community 88|Community 88]]
- [[_COMMUNITY_Community 89|Community 89]]
- [[_COMMUNITY_Community 90|Community 90]]
- [[_COMMUNITY_Community 91|Community 91]]
- [[_COMMUNITY_Community 92|Community 92]]
- [[_COMMUNITY_Community 93|Community 93]]
- [[_COMMUNITY_Community 94|Community 94]]
- [[_COMMUNITY_Community 95|Community 95]]
- [[_COMMUNITY_Community 96|Community 96]]
- [[_COMMUNITY_Community 97|Community 97]]
- [[_COMMUNITY_Community 98|Community 98]]
- [[_COMMUNITY_Community 100|Community 100]]
- [[_COMMUNITY_Community 101|Community 101]]
- [[_COMMUNITY_Community 102|Community 102]]
- [[_COMMUNITY_Community 103|Community 103]]
- [[_COMMUNITY_Community 104|Community 104]]
- [[_COMMUNITY_Community 105|Community 105]]

## God Nodes (most connected - your core abstractions)
1. `TestShouldRedact` - 21 edges
2. `PIIProxyHandler` - 20 edges
3. `iclaude: bash wrapper for Claude Code` - 17 edges
4. `GSD Discuss Phase Workflow` - 17 edges
5. `main()` - 15 edges
6. `Discuss Phase Workflow` - 14 edges
7. `Get-Shit-Done Framework` - 11 edges
8. `TestFalsePositives` - 10 edges
9. `TestMaskToken` - 10 edges
10. `Provider Adapter System` - 10 edges

## Surprising Connections (you probably didn't know these)
- `iclaude: bash wrapper for Claude Code` --wraps--> `Claude Code CLI`  [EXTRACTED]
  CLAUDE.md → README.md
- `iclaude: bash wrapper for Claude Code` --features--> `HTTP/HTTPS Proxy Management`  [EXTRACTED]
  CLAUDE.md → README.md
- `iclaude: bash wrapper for Claude Code` --features--> `Status Line Metrics`  [EXTRACTED]
  CLAUDE.md → README.md
- `iclaude: bash wrapper for Claude Code` --features--> `microVM Sandbox (Firecracker)`  [EXTRACTED]
  CLAUDE.md → README.md
- `iclaude: bash wrapper for Claude Code` --features--> `Graphify Knowledge Graph`  [EXTRACTED]
  CLAUDE.md → README.md

## Hyperedges (group relationships)
- **Skill Documentation Ecosystem** — caveman_skill, compact_session_skill, graphify_skill, prompt_verifier_skill, idd_skill, agent_builder_skill [INFERRED 0.85]
- **Shared Infrastructure Components** — markdown_templates, frontmatter_parser, yaml_workflow [INFERRED 0.80]
- **TOON Format Documentation Chain** — toon_skill, toon_converters_readme, toon_integration_guide, toon_integration_guide_architecture [EXTRACTED 0.90]

## Communities (106 total, 63 thin omitted)

### Community 0 - "Caveman Skill Modes"
Cohesion: 0.05
Nodes (61): body, filtered, flagPath, fs, { getDefaultMode, safeWriteFlag }, INDEPENDENT_MODES, mode, os (+53 more)

### Community 1 - "Skills and Security Hooks"
Cohesion: 0.06
Nodes (42): Scalability Analysis, Token Savings Analysis, TOON Format Token Savings Benchmarks, block-secrets.py file access control, Brainstorm Skill, Caveman Token Compression, Router config at router.json, Claude Code CLI (+34 more)

### Community 2 - "PII Proxy HTTP Handler"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 3 - "GSD Spec Artifacts"
Cohesion: 0.08
Nodes (30): AI-SPEC Template, GSD Canonical Artifact Registry, GSD check-plan Command, GSD check-spec Command, CLAUDE.md Template, Phase Context Template, GSD Copilot Instructions, Debug Template (+22 more)

### Community 4 - "GSD Dev Workflow"
Cohesion: 0.09
Nodes (30): AI Evaluation Reference, GSD Code Review Workflow, GSD Codebase Drift Gate, GSD Complete Milestone Workflow, GSD Debug Workflow, GSD Diagnose Issues Workflow, GSD Discovery Phase Workflow, Discuss Phase Context Template (+22 more)

### Community 5 - "TOON End-to-End Tests"
Cohesion: 0.07
Nodes (26): actualCodes, archDocContent, archDocMd, archDocResults, __dirname, discoveryToon, e001, errorsJson (+18 more)

### Community 6 - "Decision Gates"
Cohesion: 0.08
Nodes (27): Abort Gate, Chesterton's Fence (Thinking Model), Confirmation Bias Counter (Thinking Model), Counterfactual Thinking (Thinking Model), checkpoint:decision, Escalation Gate, Executor Agent, Checkpoints Taxonomy (+19 more)

### Community 7 - "Pattern Detection Tests"
Cohesion: 0.09
Nodes (16): detector(), mask(), Simple redaction detector for testing purposes, Performance tests to detect potential ReDoS issues, PEM key with maximum allowed content should complete quickly, Malformed PEM (no END marker) should not cause timeout, Long URLs with credentials should process quickly, Text with many matches should process efficiently (+8 more)

### Community 8 - "PII Proxy Core"
Cohesion: 0.12
Nodes (23): _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix(), presidio_mask() (+15 more)

### Community 9 - "TOON Skill Tests"
Cohesion: 0.09
Nodes (20): extracted, extractedErrors, extractedQuestions, extractedRoundtrip, notFound, originalJson, reconstructedJson, results (+12 more)

### Community 10 - "Graphify Patch Tests"
Cohesion: 0.12
Nodes (12): fake_pkg(), Проверяет что vendored graphifyy уже патчен (precondition)., Создаёт минимальный faux graphify пакет для патчинга., Idempotent: после первого apply повторный — no-op., Если dry-run patch fails — best-effort exit 0, fails counted., Скопировать реальные vendored файлы в fake_pkg для valid patch context., End-to-end: после apply_patches graphify update пишет relative paths., run_apply() (+4 more)

### Community 11 - "TOON Converter"
Cohesion: 0.12
Nodes (18): args, calculateTokenSavings(), componentsToToon(), dependencyGraphToToon(), __dirname, edgesToToon(), extractToonBlock(), __filename (+10 more)

### Community 12 - "Community 12"
Cohesion: 0.1
Nodes (20): Add Backlog Workflow, Add Todo Workflow, Check Todos Workflow, Code Review Workflow, Debug Workflow, Diagnose Issues Workflow, Discuss Phase Workflow, Discuss Phase Power Mode Workflow (+12 more)

### Community 13 - "Community 13"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD NOT be redacted (false positive risks), UUIDs should NOT be redacted even if 32+ hex chars, Git commit hashes should NOT be treated as tokens, Version tags should NOT be redacted, Docker image references should not be completely redacted, Template variables should NOT be redacted, Bash placeholders should NOT be redacted, Test/example passwords in test files should preferably not be redacted (+2 more)

### Community 14 - "Community 14"
Cohesion: 0.11
Nodes (10): Test cases for patterns that SHOULD be detected and redacted, Anthropic API keys should be redacted, HuggingFace tokens should be redacted, AWS Access Key IDs should be redacted, Visa credit cards should be redacted, AWS Secret Access Keys should be redacted, Passwords in config files should be redacted, Google AI Studio keys should be redacted (+2 more)

### Community 15 - "Community 15"
Cohesion: 0.16
Nodes (9): Tests for configurable MASK_TOKEN in server.py masking modes., Default MASK_TOKEN must be 'REDACTED' (not '[PII_REDACTED]', no brackets)., Custom MASK_TOKEN value is preserved at module level., Empty-string MASK_TOKEN (deletion mode) is accepted without error., secrets mode: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., secrets mode: JWT uses [JWT_REDACTED], not MASK_TOKEN., standard mode regex_mask: GitHub token uses [GITHUB_TOKEN], not MASK_TOKEN., ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing. (+1 more)

### Community 16 - "Community 16"
Cohesion: 0.17
Nodes (16): Agent Contracts, GSD Artifact Types, Debugger Philosophy, Doc Conflict Engine, Execute-Phase — MVP+TDD Gate (Runtime Enforcement), Model Profile Resolution, MVP Concepts — index, Planner — MVP Mode (Vertical Slice Strategy) (+8 more)

### Community 17 - "Community 17"
Cohesion: 0.24
Nodes (13): assert_clean(), assert_masked(), assert_missed(), assert_pii_missed(), get_masked(), Документирует PII, который хук НЕ покрывает по дизайну., Запускает хук и возвращает (stdout, stderr)., Возвращает маскированное содержимое или None если не изменено. (+5 more)

### Community 18 - "Community 18"
Cohesion: 0.18
Nodes (10): arrayToToon(), roundTripTest(), toonToJson(), validateToon(), input, items, output, parsed (+2 more)

### Community 19 - "Community 19"
Cohesion: 0.17
Nodes (12): Compact Session Skill, Context Awareness Basic Usage Example, YAML Frontmatter Parser, Graphify Skill, IDD (Intent-Driven Design) Skill, Markdown Output Templates, Prompt Verifier Example: Agent Instructions, Prompt Verifier Example: Basic CLAUDE.md (+4 more)

### Community 20 - "Community 20"
Cohesion: 0.18
Nodes (6): Empty string should not crash, String with 'None' should not crash, Unicode characters should be handled gracefully, Text with multiple different secret types should redact all, Partial patterns should not be redacted if incomplete, TestEdgeCases

### Community 21 - "Community 21"
Cohesion: 0.25
Nodes (11): Provider Adapter Factory, Anthropic Provider Adapter, Chunk Parser Module, Gemini Provider Adapter, Generic Provider Adapter, Ollama Provider Adapter, OpenAI Provider Adapter, Pricing Lookup Module (+3 more)

### Community 22 - "Community 22"
Cohesion: 0.2
Nodes (5): Apply all patterns and return redacted text + found patterns, Google AI Studio keys should be redacted, Stripe test keys should be redacted, GitHub tokens should be redacted, Groq API keys should be redacted

### Community 23 - "Community 23"
Cohesion: 0.31
Nodes (4): _make_handler(), Tests for GET /api/meta endpoint in pii-proxy-server.py., Return a PIIProxyHandler wired for testing (no real socket)., TestMetaEndpoint

### Community 24 - "Community 24"
Cohesion: 0.27
Nodes (10): Code refs: @lat: [[section-id]] comments, install-lat skill: full setup guide, lat-check skill: validate wiki links, lat-init skill: initialize lat.md/ scaffold, lat-md skill: authoring guide, lat.md documentation graph system, lat-search skill: semantic search + locate, Section structure: leading paragraph ≤250 chars (+2 more)

### Community 25 - "Community 25"
Cohesion: 0.31
Nodes (9): Agent Builder Best Practices, Agent Builder Example: Full Agent, Agent Builder Example: Minimal Agent, Agent Builder Skill, Architecture Documentation TOON Converters, TOON Converter API Documentation, TOON Integration Guide, TOON Integration Guide for Architecture Documentation (+1 more)

### Community 26 - "Community 26"
Cohesion: 0.33
Nodes (6): Debugger Agent, Fault Tree Analysis (Thinking Model), Common Bug Patterns, Thinking Models: Debug Cluster, Hypothesis-Driven Investigation (Thinking Model), Occam's Razor (Thinking Model)

### Community 27 - "Community 27"
Cohesion: 0.33
Nodes (6): Audit Milestone Workflow, Complete Milestone Workflow, Progress Workflow, Ship Workflow, Transition Workflow, Verify Work Workflow

### Community 28 - "Community 28"
Cohesion: 0.4
Nodes (5): Gate Prompt Patterns, Git Integration for GSD, Manager Workflow, Plan Review Convergence Workflow, Quick Task Workflow

### Community 29 - "Community 29"
Cohesion: 0.5
Nodes (5): PRD Best Practices Guide, PRD Example: TaskFlow Pro, PRD Markdown Guidelines, PRD Mermaid Diagram Templates, Mermaid-Obsidian Skill

### Community 30 - "Community 30"
Cohesion: 0.5
Nodes (4): Domain-Aware Probing Patterns, Codebase scout — map selection table, Thinking Models: Research Cluster, User Profiling: Detection Heuristics Reference

### Community 31 - "Community 31"
Cohesion: 0.5
Nodes (4): Add Phase Workflow, Autonomous Workflow, New Project Workflow, Spike Workflow

### Community 32 - "Community 32"
Cohesion: 0.67
Nodes (3): GSD Brainstorming Phase, IDD Intent Capture (6 Questions), lat.md Wiki Links

### Community 33 - "Community 33"
Cohesion: 0.67
Nodes (3): Shared Theme System, Sketch Toolbar, Multi-Variant HTML Patterns

### Community 34 - "Community 34"
Cohesion: 0.67
Nodes (3): Git Branching Strategy, Git Planning Commit, Planning Config

### Community 35 - "Community 35"
Cohesion: 0.67
Nodes (3): CONTEXT.md Template, Questioning Guide, Smart Discuss — Autonomous Mode

### Community 36 - "Community 36"
Cohesion: 0.67
Nodes (3): Node Repair Workflow, Plan-Checker Few-Shot Examples, Revision Loop Pattern

### Community 37 - "Community 37"
Cohesion: 0.67
Nodes (3): Cleanup Workflow, Extract Learnings Workflow, Session Report Workflow

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (3): GSD Execute Phase: Codebase Drift Gate, GSD Execute Phase: Per-Plan Worktree Gate, GSD Execute Phase: Post-Merge Gate

### Community 39 - "Community 39"
Cohesion: 0.67
Nodes (3): GSD Dev Context Profile, GSD Research Context Profile, GSD Review Context Profile

### Community 40 - "Community 40"
Cohesion: 0.67
Nodes (3): Git Workflow Skill, Git Workflow Basic Usage Example, Git Workflow Task Summary Template

## Knowledge Gaps
- **374 isolated node(s):** `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.`, `Detect installed spaCy models from venv marker files or by probing spacy.      R`, `Lazy-initialize Presidio NLP engine with all available language models.      Thr` (+369 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **63 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `iclaude: bash wrapper for Claude Code` connect `Skills and Security Hooks` to `GSD Spec Artifacts`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `TestShouldRedact` connect `Community 14` to `Pattern Detection Tests`, `Community 41`, `Community 42`, `Community 43`, `Community 44`, `Community 45`, `Community 46`, `Community 47`, `Community 22`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `TestMaskToken` connect `Community 15` to `Pattern Detection Tests`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `GSD Discuss Phase Workflow` (e.g. with `GSD Discovery Phase Workflow` and `GSD Discuss Phase Assumptions`) actually correct?**
  _`GSD Discuss Phase Workflow` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Validate upstream URL: must be HTTPS or loopback HTTP (prevents SSRF via file://`, `Return this thread's requests.Session, creating it on first access.`, `Configure 'pii-proxy' logger directly (not root logger) for reliability.` to the rest of the system?**
  _374 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Caveman Skill Modes` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Skills and Security Hooks` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._