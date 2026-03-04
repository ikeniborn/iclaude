---
rfc: 0001
title: iclaude Documentation Standards
status: Active
created: 2026-03-04
authors: [iclaude project]
supersedes: null
---

# RFC-0001: iclaude Documentation Standards

## Abstract

This RFC defines the documentation standards for the iclaude project, with emphasis on
documentation formats that reduce AI agent hallucinations and minimize redundancy. It
establishes the RFC format for inter-agent protocol documentation, defines the relationship
between RFC documents and AGENT.md files (as Architecture Decision Records), and provides
guidelines for the canonical source principle to prevent content duplication.

**Status: Active**

## Motivation

iclaude is an AI-agent-heavy project where documentation is consumed not only by human
developers but by Claude Code sub-agents during task execution. Poor documentation structure
leads to:

1. **AI Hallucinations:** Unstructured or redundant documentation causes LLMs to fill gaps
   with invented information. Research demonstrates that structured documentation
   (hierarchical indexing) improves AI precision from 51.4% to 81.9% in conformance tasks.

2. **Token Waste:** CLAUDE.md at 648 lines is fully loaded into every agent context window.
   Redundant content between CLAUDE.md and docs/ wastes context budget.

3. **Inconsistency:** When the same information exists in multiple places, it diverges over
   time. Agents see conflicting versions and produce inconsistent outputs.

4. **Navigation Failure:** Without a machine-readable index, agents fall back to web scraping
   or hallucinate file paths. The `llms.txt` standard mitigates this.

## RFC Format Specification

### Document Structure

Every RFC document MUST contain the following YAML frontmatter:

```yaml
---
rfc: <number>         # Four-digit number: 0001, 0002, ...
title: <title>        # Human-readable title
status: <status>      # Proposed | Active | Superseded | Withdrawn
created: <date>       # ISO 8601: YYYY-MM-DD
authors: [<name>]     # List of authors
supersedes: <rfc|null>  # RFC number this replaces, or null
---
```

Every RFC document MUST contain the following sections:

1. **Abstract** (required) — One paragraph summary. MUST be self-contained and comprehensible
   without reading the full document. This is what AI agents read first to determine relevance.

2. **Motivation** (required) — Why this RFC is needed. What problem does it solve?

3. **Specification** (required) — Normative content. Uses RFC 2119 keywords.

4. **Rationale** (recommended) — Why this design was chosen over alternatives.

5. **Backwards Compatibility** (if applicable) — What breaks, what is preserved.

6. **References** (if applicable) — Links to related documents, external sources.

### Normative Keywords

This RFC and all iclaude RFC documents use normative keywords per RFC 2119:

- **MUST** / **REQUIRED** / **SHALL** — absolute requirement
- **MUST NOT** / **SHALL NOT** — absolute prohibition
- **SHOULD** / **RECOMMENDED** — best practice, valid exceptions exist
- **SHOULD NOT** / **NOT RECOMMENDED** — inadvisable but not forbidden
- **MAY** / **OPTIONAL** — genuinely optional

### RFC Numbering Convention

RFCs are numbered sequentially starting from 0001. Numbers are never reused.
When an RFC is superseded, the new RFC records `supersedes: <old-number>`.

| Range | Purpose |
|-------|---------|
| 0001-0099 | Meta: documentation standards, project governance |
| 0100-0199 | Agent protocols: pipeline, data contracts, lifecycle |
| 0200-0299 | Data formats: TOON, JSON schemas, file formats |
| 0300-0399 | Integration specs: proxy, OAuth, router, PII proxy |
| 0400-0499 | Security: hooks, patterns, PII masking |

### RFC Lifecycle

```
Proposed → Active → Superseded
         ↘ Withdrawn
```

- **Proposed**: Draft under review. MAY be referenced but SHOULD NOT be implemented.
- **Active**: Approved and implemented. Normative for the project.
- **Superseded**: Replaced by a newer RFC. Historical record only.
- **Withdrawn**: Abandoned proposal. Included for historical reference.

## RFC vs AGENT.md: The RFC→ADR Pattern

iclaude uses a two-layer documentation architecture:

```
RFC documents (docs/RFC-*.md)     ← Protocol design rationale (WHY + WHAT)
        ↓
AGENT.md files (agents/*/AGENT.md) ← Implementation specification (HOW)
```

**RFC documents** capture:
- Why a protocol was designed this way
- What the normative requirements are
- Tradeoffs considered and rejected
- Version history and change rationale

**AGENT.md files** are the implemented Architecture Decision Records (ADRs):
- They implement the protocols defined in RFCs
- They contain operational instructions for sub-agents
- They SHOULD reference the relevant RFC in their frontmatter
- They MAY deviate from RFC proposals during experimentation (document the deviation)

This pattern prevents duplication: RFCs contain the stable rationale; AGENT.md files
contain the executable specification. When a protocol changes, update both, but each
serves a different audience (architectural vs operational).

## Canonical Source Principle

**The canonical source principle is the primary defense against documentation redundancy.**

Rule: Every piece of information MUST have exactly one canonical source. All other
references MUST link to that source rather than duplicate the content.

### Application to CLAUDE.md

CLAUDE.md MUST serve as an index and quick-reference, NOT as a canonical source for
detailed specifications. It SHOULD contain:

- Project overview (1-2 paragraphs)
- Quick start commands
- References to canonical RFC documents for each subsystem
- References to AGENT.md files for agent-specific behavior

CLAUDE.md MUST NOT contain:
- Full specification of any protocol (delegate to RFC docs)
- Duplicate content from docs/*.md files
- Inline specifications that belong in AGENT.md files

### Application to docs/ Structure

```
docs/
├── llms.txt              # AI-readable index (canonical navigation entry)
├── RFC-*.md              # Protocol specifications (canonical for each protocol)
├── sphinx/api-reference/ # API documentation (canonical for function signatures)
└── *.md                  # Feature documentation (canonical for user-facing features)
```

## Evidence: Structured Documentation and AI Accuracy

The following findings from published research support this RFC's approach:

1. **DocTree decomposition** (arXiv:2504.18050): Dividing RFC documents into hierarchical
   sections with a knowledge graph reduces LLM hallucinations in protocol interpretation.
   Structured sections (Abstract → Specification → Examples) enable agents to locate
   relevant content without loading full documents.

2. **Documentation-Augmented Generation** (arXiv:2407.09726): Providing structured API
   documentation to LLMs reduces hallucinations for low-frequency APIs. The key factor
   is explicit parameter descriptions with format requirements and validation rules.

3. **RFCAudit semantic indexing** (arXiv:2506.00714): Hierarchical semantic indexes of
   protocol implementations improve conformance checking precision from 51.4% to 81.9%.
   The index allows agents to narrow scope to relevant sections rather than loading
   entire specifications.

4. **llms.txt standard** (llmstxt.org): Machine-readable documentation index reduces
   context window waste by up to 10x compared to HTML. iclaude already implements this.

## Optimization Plan for iclaude Documentation

The following recommendations reduce hallucinations and redundancy across the iclaude
documentation corpus:

### Priority 1: CLAUDE.md Reduction

Current state: CLAUDE.md contains 648 lines with inline specifications for features
that already have dedicated documentation files.

Target state: CLAUDE.md reduced to ~200 lines of overview + references.

Implementation:
1. For each section in CLAUDE.md that duplicates docs/*.md content:
   - Replace inline content with a one-line reference: `See RFC-XXXX for full specification`
2. Move inline agent documentation to AGENT.md files
3. Keep Quick Start, key commands, and security warnings in CLAUDE.md

### Priority 2: AGENT.md Abstract Sections

Each AGENT.md file SHOULD add an `## Abstract` section immediately after the frontmatter.
This allows the orchestrator to read only the Abstract before deciding whether to load the
full AGENT.md, reducing token consumption in multi-agent pipelines.

Format:
```markdown
## Abstract

One paragraph. States: (1) what this agent does, (2) what it reads, (3) what it writes,
(4) when to use it. MUST be comprehensible without reading the rest of the file.
```

### Priority 3: Normative Requirements Tables

Each AGENT.md file that specifies a protocol SHOULD add a Normative Requirements section
with a table of MUST/SHOULD/MAY requirements. This enables Critic agents to verify
conformance programmatically rather than parsing prose.

### Priority 4: llms.txt RFC Section

docs/llms.txt MUST be extended with an RFC Documents section listing all Active RFC files.
This enables AI agents to navigate to protocol specifications without hallucinating paths.

## References

- [RFC 2119: Key words for use in RFCs](https://www.rfc-editor.org/rfc/rfc2119)
- [Wikipedia: Request for Comments](https://ru.wikipedia.org/wiki/RFC)
- [RFC-0002: Agent Protocol Specification](RFC-0002-agent-protocol-spec.md)
- [RFC-0003: TOON Protocol](RFC-0003-toon-protocol.md)
- [RFC-0004: Inter-Agent Communication Optimization](RFC-0004-inter-agent-communication.md)
- [RFCAudit: AI Agent Auditing Against RFC Specifications](https://arxiv.org/html/2506.00714v2)
- [On Mitigating Code LLM Hallucinations with API Documentation](https://arxiv.org/html/2407.09726v1)
- [llms.txt standard](https://llmstxt.org/)
