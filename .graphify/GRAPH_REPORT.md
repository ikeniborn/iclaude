# Graph Report - .  (2026-06-06)

## Corpus Check
- Large corpus: 291 files · ~346,302 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 315 nodes · 317 edges · 66 communities (25 shown, 41 thin omitted)
- Extraction: 81% EXTRACTED · 19% INFERRED · 0% AMBIGUOUS · INFERRED: 61 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

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
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]

## God Nodes (most connected - your core abstractions)
1. `PIIProxyHandler` - 21 edges
2. `GSD Discuss Phase Workflow` - 17 edges
3. `Discuss Phase Workflow` - 14 edges
4. `Get-Shit-Done Framework` - 10 edges
5. `presidio_mask()` - 8 edges
6. `Checkpoints Taxonomy` - 7 edges
7. `Gates Taxonomy` - 7 edges
8. `GSD Planning Phase Template` - 6 edges
9. `MVP Concepts — index` - 6 edges
10. `Thinking Models: Verification Cluster` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Get-Shit-Done Framework` --uses_template--> `PROJECT.md Template`  [INFERRED]
  .nvm-isolated/.claude-isolated/get-shit-done/templates/README.md → .nvm-isolated/.claude-isolated/get-shit-done/templates/project.md
- `Get-Shit-Done Framework` --uses_template--> `AI-SPEC Template`  [INFERRED]
  .nvm-isolated/.claude-isolated/get-shit-done/templates/README.md → .nvm-isolated/.claude-isolated/get-shit-done/templates/AI-SPEC.md
- `Get-Shit-Done Framework` --uses_template--> `Milestone Entry Template`  [INFERRED]
  .nvm-isolated/.claude-isolated/get-shit-done/templates/README.md → .nvm-isolated/.claude-isolated/get-shit-done/templates/milestone.md
- `Get-Shit-Done Framework` --uses_template--> `Phase Spec Template`  [INFERRED]
  .nvm-isolated/.claude-isolated/get-shit-done/templates/README.md → .nvm-isolated/.claude-isolated/get-shit-done/templates/spec.md
- `Get-Shit-Done Framework` --uses_template--> `Phase Context Template`  [INFERRED]
  .nvm-isolated/.claude-isolated/get-shit-done/templates/README.md → .nvm-isolated/.claude-isolated/get-shit-done/templates/context.md

## Communities (66 total, 41 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.09
Nodes (31): _build_server(), _detect_spacy_models(), init_presidio(), main(), mask_content_block(), mask_request_body(), _mask_value(), _prefix() (+23 more)

### Community 1 - "Community 1"
Cohesion: 0.11
Nodes (12): _get_http_session(), PIIProxyHandler, Return this thread's requests.Session, creating it on first access., HTTP request handler for PII-proxy.      Design: asymmetric masking — only REQUE, Build request headers for upstream forwarding.          In API-key mode (ANTHROP, HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2)., GET /api/metrics — return live masking metrics for statusline integration., Read request body with Content-Length validation.          Handles both Content- (+4 more)

### Community 2 - "Community 2"
Cohesion: 0.08
Nodes (28): AI-SPEC Template, GSD Canonical Artifact Registry, CLAUDE.md Template, Phase Context Template, GSD Copilot Instructions, Debug Template, Discussion Log Template, GSD Execution Phase Template (+20 more)

### Community 3 - "Community 3"
Cohesion: 0.08
Nodes (27): Abort Gate, Chesterton's Fence (Thinking Model), Confirmation Bias Counter (Thinking Model), Counterfactual Thinking (Thinking Model), checkpoint:decision, Escalation Gate, Executor Agent, Checkpoints Taxonomy (+19 more)

### Community 4 - "Community 4"
Cohesion: 0.1
Nodes (20): Add Backlog Workflow, Add Todo Workflow, Check Todos Workflow, Code Review Workflow, Debug Workflow, Diagnose Issues Workflow, Discuss Phase Workflow, Discuss Phase Power Mode Workflow (+12 more)

### Community 5 - "Community 5"
Cohesion: 0.17
Nodes (17): GSD Discovery Phase Workflow, Discuss Phase Context Template, Discuss Phase Discussion Log Template, GSD Discuss Mode: Advisor, GSD Discuss Mode: All, GSD Discuss Mode: Analyze, GSD Discuss Mode: Auto, GSD Discuss Mode: Batch (+9 more)

### Community 6 - "Community 6"
Cohesion: 0.17
Nodes (16): Agent Contracts, GSD Artifact Types, Debugger Philosophy, Doc Conflict Engine, Execute-Phase — MVP+TDD Gate (Runtime Enforcement), Model Profile Resolution, MVP Concepts — index, Planner — MVP Mode (Vertical Slice Strategy) (+8 more)

### Community 7 - "Community 7"
Cohesion: 0.17
Nodes (13): AI Evaluation Reference, GSD Code Review Workflow, GSD Codebase Drift Gate, GSD Complete Milestone Workflow, GSD Debug Workflow, GSD Diagnose Issues Workflow, GSD Do Dispatcher Workflow, Docs Update Workflow (+5 more)

### Community 8 - "Community 8"
Cohesion: 0.22
Nodes (4): Unit tests for the PII proxy supervisor/worker split., TestBuildServer, TestStormGuard, TestSuperviseFlag

### Community 9 - "Community 9"
Cohesion: 0.48
Nodes (5): otel.sh script, log_debug(), log_warn(), patch_no_proxy_for_telemetry(), setup_telemetry()

### Community 10 - "Community 10"
Cohesion: 0.33
Nodes (4): _caveman_python_download(), install_caveman(), install.sh script, install.sh script

### Community 11 - "Community 11"
Cohesion: 0.33
Nodes (6): Debugger Agent, Fault Tree Analysis (Thinking Model), Common Bug Patterns, Thinking Models: Debug Cluster, Hypothesis-Driven Investigation (Thinking Model), Occam's Razor (Thinking Model)

### Community 12 - "Community 12"
Cohesion: 0.33
Nodes (6): Audit Milestone Workflow, Complete Milestone Workflow, Progress Workflow, Ship Workflow, Transition Workflow, Verify Work Workflow

### Community 13 - "Community 13"
Cohesion: 0.4
Nodes (5): Gate Prompt Patterns, Git Integration for GSD, Manager Workflow, Plan Review Convergence Workflow, Quick Task Workflow

### Community 14 - "Community 14"
Cohesion: 0.5
Nodes (4): Domain-Aware Probing Patterns, Codebase scout — map selection table, Thinking Models: Research Cluster, User Profiling: Detection Heuristics Reference

### Community 15 - "Community 15"
Cohesion: 0.5
Nodes (4): Add Phase Workflow, Autonomous Workflow, New Project Workflow, Spike Workflow

### Community 16 - "Community 16"
Cohesion: 0.67
Nodes (3): install_lat(), patch_lat_provider(), install.sh script

### Community 17 - "Community 17"
Cohesion: 0.83
Nodes (3): test_pii_shared_lifecycle.sh script, fail(), pass()

### Community 18 - "Community 18"
Cohesion: 0.67
Nodes (3): CONTEXT.md Template, Questioning Guide, Smart Discuss — Autonomous Mode

### Community 19 - "Community 19"
Cohesion: 0.67
Nodes (3): Shared Theme System, Sketch Toolbar, Multi-Variant HTML Patterns

### Community 20 - "Community 20"
Cohesion: 0.67
Nodes (3): Git Branching Strategy, Git Planning Commit, Planning Config

### Community 21 - "Community 21"
Cohesion: 0.67
Nodes (3): Node Repair Workflow, Plan-Checker Few-Shot Examples, Revision Loop Pattern

### Community 22 - "Community 22"
Cohesion: 0.67
Nodes (3): Cleanup Workflow, Extract Learnings Workflow, Session Report Workflow

### Community 23 - "Community 23"
Cohesion: 0.67
Nodes (3): GSD Execute Phase: Codebase Drift Gate, GSD Execute Phase: Per-Plan Worktree Gate, GSD Execute Phase: Post-Merge Gate

### Community 24 - "Community 24"
Cohesion: 0.67
Nodes (3): GSD Dev Context Profile, GSD Research Context Profile, GSD Review Context Profile

## Knowledge Gaps
- **149 isolated node(s):** `PROJECT.md Template`, `AI-SPEC Template`, `Milestone Entry Template`, `CLAUDE.md Template`, `GSD Copilot Instructions` (+144 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **41 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PIIProxyHandler` connect `Community 1` to `Community 0`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `GSD Discuss Phase Workflow` connect `Community 5` to `Community 7`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `GSD Discuss Phase Workflow` (e.g. with `GSD Discovery Phase Workflow` and `GSD Discuss Phase Assumptions`) actually correct?**
  _`GSD Discuss Phase Workflow` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `Discuss Phase Workflow` (e.g. with `UI Phase Workflow` and `Explore Workflow`) actually correct?**
  _`Discuss Phase Workflow` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `Get-Shit-Done Framework` (e.g. with `PROJECT.md Template` and `AI-SPEC Template`) actually correct?**
  _`Get-Shit-Done Framework` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PROJECT.md Template`, `AI-SPEC Template`, `Milestone Entry Template` to the rest of the system?**
  _149 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._