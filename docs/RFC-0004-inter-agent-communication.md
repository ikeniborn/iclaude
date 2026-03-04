---
rfc: 0004
title: Inter-Agent Communication Optimization
status: Active
created: 2026-03-04
authors: [iclaude project]
supersedes: null
---

# RFC-0004: Inter-Agent Communication Optimization

## Abstract

This RFC documents optimization recommendations for reducing AI agent hallucinations and
improving documentation quality in the iclaude multi-agent pipeline. It identifies current
pain points (CLAUDE.md context bloat, missing Abstract sections in AGENT.md files,
lack of Normative Requirements tables), maps the RFC→ADR relationship for iclaude's
documentation architecture, and specifies measurable improvement targets. This RFC
complements RFC-0001 (documentation standards) with concrete, actionable recommendations
for the existing codebase.

**Status: Active**

## Motivation

The iclaude agent pipeline has evolved organically. As of March 2026, several structural
issues increase the risk of agent hallucinations:

1. **CLAUDE.md context bloat:** At 648 lines, CLAUDE.md is loaded into every agent context
   window via Claude Code's project instructions mechanism. Much of this content is
   duplicated in docs/ files or in AGENT.md files, wasting context tokens on content
   the current agent doesn't need.

2. **No Abstract sections in AGENT.md:** Agents loading another agent's AGENT.md for
   reference must parse the entire file to determine relevance. An Abstract section would
   allow triage in ~50 tokens.

3. **No Normative Requirements tables:** AGENT.md files specify requirements through
   prose, tables, and code blocks. A structured Normative Requirements section would
   enable the Critic agent to verify conformance programmatically.

4. **llms.txt doesn't index RFC documents:** The existing AI-readable index
   (`docs/llms.txt`) covers feature documentation but omits the RFC protocol
   specifications. Agents navigating to protocol docs must guess paths.

## Current State Analysis

### CLAUDE.md Redundancy Map

Sections in CLAUDE.md with canonical sources elsewhere:

| CLAUDE.md Section | Canonical Source | Redundancy Type |
|-------------------|-----------------|-----------------|
| Key Features (list) | README.md | Duplicate summary |
| Proxy Management (full spec) | docs/PROXY.md | Full duplication |
| OAuth Token Management | docs/ (oauth section) | Partial duplication |
| Router Integration (full spec) | docs/ROUTER.md | Full duplication |
| PII Proxy (full spec) | docs/PII_MASKING.md | Full duplication |
| Security Hooks (tables) | CLAUDE.md (unique) | Canonical here |
| Code Architecture | docs/INTEGRATIONS.md | Partial duplication |
| Environment Variables | docs/CONFIGURATION.md | Partial duplication |
| Sandbox Limitations | CLAUDE.md (unique) | Canonical here — keep |
| Related Skills | CLAUDE.md (unique) | Canonical here — keep |

Estimated token savings from removing duplicated sections: ~250-300 lines (~38-46% reduction).

### AGENT.md Current vs Target Structure

Current AGENT.md structure:
```
---frontmatter---
# Role Title
[role description prose]
## Input Data
## Algorithm
### Step N
...
## Rules
## Completion Signal
## Retry Context
```

Target AGENT.md structure with RFC-0004 improvements:
```
---frontmatter---
## Abstract          ← NEW: one-paragraph self-contained summary
# Role Title
[role description prose]
## Normative Requirements   ← NEW: MUST/SHOULD/MAY table
## Input Data
## Algorithm
### Step N
...
## Rules
## Completion Signal
## Retry Context
```

Token cost of Abstract section: ~50-80 tokens.
Token savings when orchestrator skips full AGENT.md load: ~800-1500 tokens per irrelevant agent.

## RFC→ADR Mapping for iclaude

The iclaude documentation follows the RFC→ADR pattern defined in RFC-0001:

### RFC Documents (docs/RFC-*.md) — Protocol Design Rationale

RFCs capture WHY a protocol was designed this way and WHAT the normative requirements are.

| RFC | Title | ADR Counterpart |
|-----|-------|-----------------|
| RFC-0001 | Documentation Standards | This RFC + CLAUDE.md @skill references |
| RFC-0002 | Agent Pipeline Protocol | agents/_shared/workspace.md |
| RFC-0003 | TOON Protocol | agents/_shared/toon-protocol.md |
| RFC-0004 | Inter-Agent Communication | agents/*/AGENT.md files collectively |

### AGENT.md Files — Implemented ADRs

AGENT.md files are the operational specifications that implement the protocols defined
in RFCs. The relationship:

```
RFC-0002 (pipeline spec)
    → researcher-agent/AGENT.md (implements Researcher role)
    → planning-agent/AGENT.md (implements Planner role)
    → execution-agent/AGENT.md (implements Executor role)
    → critic-agent/AGENT.md (implements Critic role)

RFC-0003 (TOON spec)
    → _shared/toon-protocol.md (reference implementation)
    → All AGENT.md files (use TOON for output)

RFC-0002 (workspace spec)
    → _shared/workspace.md (canonical workspace rules)
    → All AGENT.md files (reference workspace rules)
```

### Authority Chain

When an agent or human needs to understand a protocol:

1. Read RFC for WHY and normative requirements (stable, infrequently updated)
2. Read AGENT.md for HOW (implementation details, may be updated frequently)
3. Read _shared/*.md for shared definitions (TOON syntax, workspace rules)

If AGENT.md contradicts RFC: the RFC is authoritative. Document the deviation in AGENT.md
frontmatter with reason and planned resolution.

## Implementation Recommendations

### Recommendation 1: Add Abstract to Each AGENT.md

Priority: High. Effort: Low (add ~50-80 tokens per agent file).

Template:
```markdown
## Abstract

This agent {role description in one sentence}. It reads {input files} and writes
{output file}. Use this agent {when/how}. It MUST NOT {key restriction}.
```

Apply to:
- `agents/researcher-agent/AGENT.md` — after frontmatter, before `# Роль`
- `agents/planning-agent/AGENT.md` — after frontmatter, before `# Роль`
- `agents/execution-agent/AGENT.md` — after frontmatter, before `# Роль`
- `agents/critic-agent/AGENT.md` — after frontmatter, before `# Роль`
- `agents/deep-research-agent/AGENT.md` — after frontmatter, before `# Роль`

### Recommendation 2: Add Normative Requirements to AGENT.md Files

Priority: Medium. Effort: Medium.

Template for each AGENT.md:
```markdown
## Normative Requirements

| Requirement | Level | Verification |
|-------------|-------|--------------|
| Use absolute paths for workspace files | MUST | Critic checks path format |
| Write output to WORKSPACE, not CWD | MUST | Critic checks file location |
| Include schema_version in output | MUST | Critic: schema_version check |
| Complete within maxTurns | SHOULD | Orchestrator monitors turns |
```

This enables the Critic to verify conformance against a structured table rather than
parsing prose descriptions.

### Recommendation 3: CLAUDE.md Restructuring

Priority: High. Effort: Medium.

Target: Reduce CLAUDE.md from 648 lines to ~200 lines.

Steps:
1. Replace each full-specification section with a one-line reference:
   ```
   ## Proxy Management
   See [docs/PROXY.md](docs/PROXY.md) and [RFC-0300: Proxy Protocol](docs/RFC-0300-proxy-protocol.md)
   ```
2. Keep sections that are unique to CLAUDE.md:
   - Sandbox Limitations (important warnings)
   - Security Hooks (two-layer protection tables)
   - Related Skills (skill references)
   - Quick Start commands
3. Keep Code Architecture section but replace module descriptions with RFC references

### Recommendation 4: Extend llms.txt with RFC Section

Priority: High. Effort: Low.

Add the following section to `docs/llms.txt`:

```markdown
## RFC Documents (Protocol Specifications)

- [RFC-0001: Documentation Standards](/docs/RFC-0001-documentation-standards.md)
- [RFC-0002: Agent Pipeline Protocol](/docs/RFC-0002-agent-protocol-spec.md)
- [RFC-0003: TOON Protocol](/docs/RFC-0003-toon-protocol.md)
- [RFC-0004: Inter-Agent Communication](/docs/RFC-0004-inter-agent-communication.md)
```

This allows agents to navigate to protocol specifications without hallucinating paths.

### Recommendation 5: Version Cross-Reference in AGENT.md Frontmatter

Priority: Low. Effort: Low.

Add RFC reference to AGENT.md frontmatter:

```yaml
---
name: researcher-agent
# version: 2.1.1 | updated: 2026-02-24
# implements: RFC-0002 (researcher role)
---
```

This creates a machine-readable link from AGENT.md to its governing RFC.

## Token Budget Analysis

### Before Optimization

| Component | Tokens (estimated) | Loaded in every session |
|-----------|-------------------|------------------------|
| CLAUDE.md | ~8,500 | Yes (project instructions) |
| AGENT.md (per agent) | ~2,000-4,000 | Only when sub-agent runs |
| Total per pipeline run | ~8,500 + (5 × 3,000) | ~23,500 tokens |

### After Optimization (targets)

| Component | Tokens (target) | Change |
|-----------|----------------|--------|
| CLAUDE.md (restructured) | ~2,700 | -68% |
| AGENT.md Abstract only (triage) | ~75 | -97% vs full load |
| AGENT.md full (when needed) | ~2,500 | -17% (removed redundancy) |
| Total per pipeline run | ~2,700 + (5 × 2,500) | ~15,200 tokens (-35%) |

Note: Actual savings depend on implementation quality. Conservative estimate: 25-35% reduction.

## Measuring Success

The following metrics indicate successful implementation:

1. **CLAUDE.md line count** < 250 lines (from 648)
2. **All AGENT.md files** contain `## Abstract` section
3. **docs/llms.txt** contains RFC section with all Active RFCs
4. **No duplicate content** between CLAUDE.md and docs/*.md (verified by grep)
5. **Critic WARN rate** for research tasks decreases (measured over 10+ pipeline runs)

## References

- [RFC-0001: Documentation Standards](RFC-0001-documentation-standards.md)
- [RFC-0002: Agent Pipeline Protocol](RFC-0002-agent-protocol-spec.md)
- [RFC-0003: TOON Protocol](RFC-0003-toon-protocol.md)
- [docs/llms.txt](llms.txt) — existing AI-readable index
- [CLAUDE.md](../CLAUDE.md) — primary target for redundancy reduction
- [agents/researcher-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/researcher-agent/AGENT.md)
- [agents/planning-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/planning-agent/AGENT.md)
- [agents/execution-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/execution-agent/AGENT.md)
- [agents/critic-agent/AGENT.md](../.nvm-isolated/.claude-isolated/agents/critic-agent/AGENT.md)
- [Engineering Planning with RFCs, Design Documents and ADRs](https://newsletter.pragmaticengineer.com/p/rfcs-and-design-docs)
- [ADRs and RFCs: Differences and When to Use Which](https://candost.blog/adrs-rfcs-differences-when-which/)
