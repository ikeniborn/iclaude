---
rfc: 0003
title: TOON Protocol Specification
status: Active
created: 2026-03-04
authors: [iclaude project]
supersedes: null
---

# RFC-0003: TOON Protocol Specification

## Abstract

TOON (Token-Oriented Object Notation) is a hybrid data format for inter-agent communication
in the iclaude pipeline. It combines a JSON envelope with pipe-separated tabular blocks
for large arrays. This RFC formally specifies the TOON v1.1.0 format: syntax rules, threshold
conditions for TOON vs JSON representation, encoding/decoding algorithm, backwards
compatibility guarantees, and rationale for the 40-70% token savings compared to JSON-only
representation. The canonical implementation is in `agents/_shared/toon-protocol.md`.

**Status: Active**

## Motivation

JSON is the standard for structured data exchange but is verbose for tabular data:

```json
// JSON representation of 7 files — 280 tokens
[
  {"path": "lib/command/args.sh", "relevance": "high", "reason": "CLI argument parsing"},
  {"path": "lib/command/help.sh", "relevance": "medium", "reason": "Help text"},
  {"path": "lib/context/sessions.sh", "relevance": "high", "reason": "Session management"},
  {"path": "iclaude.sh", "relevance": "medium", "reason": "Entry point"},
  {"path": "lib/launcher/launch.sh", "relevance": "low", "reason": "Launch orchestration"},
  {"path": "lib/proxy/configure.sh", "relevance": "medium", "reason": "Proxy config"},
  {"path": "lib/oauth/token.sh", "relevance": "low", "reason": "Token refresh"}
]

// TOON representation — ~100 tokens (64% reduction)
TOON:relevant_files:v1
path|relevance|reason
lib/command/args.sh|high|CLI argument parsing
lib/command/help.sh|medium|Help text
lib/context/sessions.sh|high|Session management
iclaude.sh|medium|Entry point
lib/launcher/launch.sh|low|Launch orchestration
lib/proxy/configure.sh|medium|Proxy config
lib/oauth/token.sh|low|Token refresh
```

In a multi-agent pipeline with 60-turn context windows, token efficiency directly affects
how much work each agent can accomplish before hitting context limits.

## Specification

### TOON Block Syntax

A TOON block MUST follow this exact syntax:

```
TOON:{name}:{version}
{field1}|{field2}|...{fieldN}
{value1}|{value2}|...{valueN}
{value1}|{value2}|...{valueN}
```

Rules:
- Line 1: Block header `TOON:<name>:<version>` — no spaces
- Line 2: Field names separated by `|` — no spaces around `|`
- Lines 3+: Data rows, one row per item, values separated by `|`
- Empty rows are NOT permitted within a block
- The block name MUST match the JSON reference `<<TOON:{name}>>`

### File Structure

A TOON file MUST follow this structure:

```
[TOON blocks]
(empty line between blocks)

---JSON---
{
  "field": "<<TOON:{name}>>",
  ...
}
```

Rules:
- TOON blocks MUST appear BEFORE `---JSON---`
- `---JSON---` is the mandatory separator (exactly as written)
- If no TOON blocks are needed, the file MUST still start with `---JSON---`
- Multiple TOON blocks are separated by empty lines
- JSON after `---JSON---` is standard JSON (no comments)

### JSON References

In the JSON section, a TOON block is referenced by its name:

```json
{
  "relevant_files": "<<TOON:relevant_files>>"
}
```

The reference string `"<<TOON:{name}>>"` replaces the array that would otherwise
be inline JSON. Agents reading this file MUST resolve references by finding the
named TOON block above `---JSON---`.

### TOON Threshold Rules

TOON blocks MUST be used when the array meets the threshold. JSON arrays MUST be used
when below the threshold.

| Field | Threshold | Format |
|-------|-----------|--------|
| relevant_files | >= 5 items | TOON |
| phase_{N}_steps | >= 5 items | TOON |
| files_to_change (global) | >= 5 items | TOON |
| reusable_components | always | JSON (typically < 5) |
| risks | always | JSON (typically < 5) |
| retry_guidance | >= 5 items | TOON |
| all other arrays | < 5 items | JSON inline |

### Version String

The version string in the TOON block header (e.g., `v1`) SHOULD be incremented when
the field schema changes. Agents MUST check the version if they depend on specific fields.

Current version: `v1` for all standard TOON blocks.

## Encoding Algorithm

When an agent writes a TOON file:

```
1. Determine which arrays meet the TOON threshold
2. For each qualifying array:
   a. Extract field names from the first item's keys
   b. Generate header line: TOON:{name}:v1
   c. Generate field line: {field1}|{field2}|...
   d. For each item: generate data line: {val1}|{val2}|...
   e. In JSON section: replace inline array with "<<TOON:{name}>>"
3. Assemble file: TOON blocks + empty line + ---JSON--- + JSON
```

## Decoding Algorithm

When an agent reads a TOON file:

```
1. Read full file content
2. Parse up to ---JSON--- as TOON section
3. Parse after ---JSON--- as JSON section
4. For each "<<TOON:{name}>>" reference in JSON:
   a. Find block with header TOON:{name}:v* above ---JSON---
   b. Parse field names from line 2
   c. Parse data rows from line 3+
   d. Reconstruct array of objects
5. Use resolved data
```

Claude Code agents understand TOON natively — no external library is required.

## Backwards Compatibility

TOON v1.1.0 is backwards compatible with v1.0.0. The changes in v1.1.0:
- Added `retry_guidance` block support in critique files
- Added `files_to_change` global block support in plan.toon
- No changes to syntax rules

Files without TOON blocks (pure JSON starting with `---JSON---`) are valid TOON files
and MUST be accepted by all agents.

If an agent receives a research.toon where `relevant_files` is a JSON array (not a TOON
reference), it MUST use the array directly without error. This handles sub-threshold cases.

## Rationale

### Why pipe-separated, not CSV?

CSV requires escaping commas in values. Field values in iclaude TOON blocks (file paths,
descriptions) rarely contain `|` but commonly contain commas. Pipe-separated avoids
the escaping overhead.

### Why not just JSON with compression?

The pipeline uses plain text files that must be human-readable for debugging. Compression
would obscure content during development. TOON provides readability with token efficiency.

### Why a custom format instead of YAML or TOML?

YAML indentation is fragile when generated by LLMs. TOML lacks array-of-objects syntax.
TOON's pipe-separated format is trivial to generate and parse without format-specific knowledge.

### Why 5 items as threshold?

Below 5 items, JSON objects are more readable and the token savings are marginal.
Above 5 items, the repetitive key names in JSON dominate token count. Threshold 5
balances readability against efficiency.

## References

- [RFC-0001: Documentation Standards](RFC-0001-documentation-standards.md)
- [RFC-0002: Agent Pipeline Protocol](RFC-0002-agent-protocol-spec.md)
- [agents/_shared/toon-protocol.md](../.nvm-isolated/.claude-isolated/agents/_shared/toon-protocol.md) — canonical implementation reference
