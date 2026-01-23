---
name: architecture-documentation
description: Generate detailed architectural documentation in YAML and TOON formats with component dependencies and relationships
version: 1.2.0
tags: [documentation, architecture, yaml, toon, dependencies, graph, token-efficiency]
dependencies: [context-awareness, thinking-framework]
author: Claude Code Skills Team
files:
  templates: ./templates/*.yaml
  templates_toon: ./templates/toon/*.toon.template
  converters: ./converters/*.mjs
  schemas: ./schemas/*.schema.json
  examples: ./examples/*.md
  examples_toon: ./examples/toon/*.toon.example
  rules: ./rules/*.md
user-invocable: true
changelog:
  - version: 1.2.0
    date: 2026-01-23
    changes:
      - "**TOON Format Integration**: Added Token-Oriented Object Notation support"
      - "Added TOON converter (converters/toon-converter.mjs) with full API"
      - "Created 4 TOON templates: components, dependency-graph, data-flow, quality-attributes"
      - "Dual-format structured output: YAML (human-facing) + TOON (LLM-facing)"
      - "Token savings: 30-60% compared to JSON/YAML (39.1% for components, 48.9% for graphs)"
      - "Added comprehensive TOON Integration Guide with examples and benchmarks"
      - "Step 6b: Generate TOON documentation for token-efficient inter-skill communication"
      - "Lossless round-trip conversion (TOON ↔ JSON) validated"
  - version: 1.1.0
    date: 2026-01-20
    changes:
      - Updated documentation to reflect actual implementation (.md files instead of .mmd)
      - Added notes about embedded Mermaid blocks in Markdown files
      - Clarified GitHub rendering advantages
  - version: 1.0.0
    date: 2025-11-23
    changes:
      - Initial release
---

# Architecture Documentation Skill

## When to Use

Use this skill when you need to:
- Document the architecture of an existing project
- Create architectural diagrams and dependency graphs
- Understand component relationships in a codebase
- Generate architecture documentation as part of project setup
- Update architecture docs after refactoring

**Automatic invocation:**
- After Phase 1 (Analysis) in complex projects
- When implementing new architectural components

**Manual invocation:**
`/architecture-documentation` or `@skill:architecture-documentation`

## How It Works

### Step 1: Project Context Detection

Use `@skill:context-awareness` to gather:
- `project_context.language`
- `project_context.framework`
- `project_context.project_root`
- `project_context.package_manager`
- `project_context.structure`

### Step 2: Determine Complexity

Based on project size:
- **Minimal:** < 10 files, 1-5 components → Use `@template:architecture-lite`
- **Standard:** 10-50 files, 5-20 components → Use `@template:architecture-full`
- **Complex:** > 50 files, > 20 components → Use `@template:architecture-full` + separate component files

### Step 3: Component Discovery

Use Glob and Grep tools to find components:

**For JavaScript/TypeScript:**
- Search for: `export class`, `export function`, `export default`, `module.exports`
- Package manifest: `package.json` (dependencies, scripts)
- Entry points: `src/index.{js,ts}`, `src/main.{js,ts}`, `src/app.{js,ts}`

**For Python:**
- Search for: `class`, `def` in `__init__.py`, `from X import Y`
- Package manifest: `requirements.txt`, `pyproject.toml`, `setup.py`
- Entry points: `__main__.py`, `app.py`, `main.py`

**For Go:**
- Search for: `package`, `type`, `func`
- Package manifest: `go.mod`
- Entry points: `main.go`

**For Rust:**
- Search for: `pub mod`, `pub struct`, `pub fn`
- Package manifest: `Cargo.toml`
- Entry points: `src/main.rs`, `src/lib.rs`

**For Bash/Shell:**
- Search for: `function`, `(){`, sourced files
- Entry points: Main script files

### Step 4: Dependency Extraction

Parse import/require statements:
- Use Grep to find: `import .* from`, `require(`, `from .* import`, `source`
- Build dependency map: component_id → [dependency_ids]
- Classify as: required (used in code), dev (only in tests), optional (dynamic imports)

### Step 5: Pattern Detection

Analyze directory structure and code patterns:
- **Layered:** Presence of `controllers/`, `services/`, `models/` or `repositories/`
- **MVC:** Presence of `models/`, `views/`, `controllers/`
- **Microservices:** Multiple `package.json` files or separate `services/` directories
- **Hexagonal:** Presence of `ports/`, `adapters/`, `domain/`
- **Event-driven:** Presence of `events/`, `subscribers/`, `publishers/`
- **Modular:** Skills system with subdirectories

### Step 6: Generate YAML Documentation

Fill template with discovered data:
- Replace all `{{placeholders}}` with actual values
- Generate component IDs in kebab-case from file paths
- Write descriptions based on file/class comments or infer from names
- Calculate metrics (dependency count, complexity)

### Step 6b: Generate TOON Documentation (NEW)

**TOON (Token-Oriented Object Notation)** - Compact data format for LLM communication.

**Generate TOON for token-efficient structured output:**

1. **Convert components to TOON:**
   - Use `componentsToToon(componentsArray)` from `converters/toon-converter.mjs`
   - Result: `components[N]{id,name,type,path,description,layer}:\n  ...`
   - **Token savings: 35-45%** compared to JSON

2. **Convert dependency graph to TOON:**
   - Use `dependencyGraphToToon(nodes, edges)`
   - Result: Nested TOON with `nodes[N]{...}:` and `edges[M]{...}:`
   - **Token savings: 40-50%** compared to JSON

3. **Store TOON in structured output:**
   - Embed TOON strings in JSON: `"components_toon": "components[15]{...}:\n..."`
   - Calculate token savings: `calculateTokenSavings(jsonObj)`
   - Include `token_savings` and `size_comparison` metrics

**When to use TOON:**
- ✅ Structured output between skills (internal communication)
- ✅ Large datasets (> 10 components, > 20 edges)
- ✅ Tabular data with consistent schema
- ❌ Human-facing files in git (use YAML for better tooling)
- ❌ Deeply nested metadata (< 3 levels)

### Step 7: Validate Output

Before writing files:
- Verify all dependency references exist
- Detect circular dependencies (A depends on B, B depends on A)
- Check ID format (kebab-case: `^[a-z][a-z0-9-]*$`)
- Ensure descriptions are not placeholders (min 10 chars, not "TODO" or "Component")

### Step 8: Generate Mermaid Diagram

Convert dependency_graph to Mermaid syntax for visualization:

**Mermaid generation logic:**

**Note:** Diagrams are generated as Markdown files (`.md`) with embedded Mermaid code blocks (` ```mermaid ... ``` `). This format provides:
- Automatic rendering on GitHub
- Support in VS Code, Obsidian, Jekyll
- Ability to include descriptions and metadata
- Better version control (all content in one file)

Generate `/docs/architecture/diagrams/dependency-graph.md` with embedded Mermaid block:

1. Graph type: `graph TD` (top-down) or `graph LR` (left-right) based on depth
2. Nodes: One per component with abbreviated ID
3. Edges: Dependencies as arrows `-->` with labels
4. Styling: Color by layer (presentation=blue, business=yellow, data=red)
5. Subgraphs: Group by architectural layer if layered pattern detected

**Color scheme by layer:**
- presentation: `#e1f5ff` (light blue)
- business: `#fff4e1` (light yellow)
- data: `#ffe1e1` (light red)
- infrastructure: `#e1ffe1` (light green)
- external: `#f0f0f0` (gray)

**Edge labels:**
- Include dependency type (required/optional/dev)
- Mark circular dependencies in red

### Step 9: Write Documentation Files

Create directory structure:
```bash
mkdir -p /docs/architecture/components
mkdir -p /docs/architecture/diagrams
```

Write files:
- `/docs/architecture/overview.yaml` - Main architecture (from template)
- `/docs/architecture/dependency-graph.yaml` - Graph structure only (if complex)
- `/docs/architecture/diagrams/dependency-graph.md` - Markdown with embedded Mermaid visualization (ALWAYS)
- `/docs/architecture/diagrams/data-flow-{flow-id}.md` - Data flow diagrams with embedded Mermaid (if data flows exist)
- `/docs/architecture/components/{component-id}.yaml` - Per-component (if complex)
- `/docs/architecture/README.md` - Index with embedded Mermaid diagrams for GitHub rendering

### Step 10: Generate Output JSON

Provide structured output for workflow:
```json
{
  "architecture_documentation": {
    "status": "success",
    "output_directory": "/docs/architecture",
    "files_created": [
      "overview.yaml",
      "diagrams/dependency-graph.md",
      "diagrams/data-flow-user-login.md",
      "README.md"
    ],
    "component_count": 15,
    "dependency_count": 42,
    "detected_patterns": ["layered"],
    "warnings": ["circular-dependency: auth-service ↔ user-service"],
    "complexity": "standard",
    "mermaid_diagrams_generated": 2
  }
}
```

### Step 11: Display Summary

Show user-friendly markdown summary with:
- Files created (including Mermaid diagrams)
- Component count
- Detected patterns
- Mermaid diagram preview (rendered in terminal if supported)
- Warnings (circular dependencies, missing descriptions)
- Next steps:
  - Review YAML files in `/docs/architecture/`
  - View Mermaid diagrams directly on GitHub (auto-rendered) or using Mermaid preview extension in VS Code/Obsidian
  - Commit architecture docs to git

## Output Format

### Workflow Integration (JSON)

**Dual-format structured output** (YAML for humans, TOON for LLMs):

```json
{
  "architecture_documentation": {
    "status": "success|partial|failed",
    "output_directory": "/docs/architecture",
    "formats": {
      "yaml": {
        "files_created": ["overview.yaml", "diagrams/dependency-graph.md"],
        "output_directory": "/docs/architecture"
      },
      "toon": {
        "components_toon": "components[15]{id,name,type,path,description,layer}:\n  proxy-mgmt,Proxy Management,module,...",
        "dependency_graph_toon": "dependency_graph:\n  nodes[15]{id,label,type,layer}:\n    ...\n  edges[42]{from,to,type,description}:\n    ...",
        "token_savings": "42%",
        "size_comparison": "YAML: 8542 tokens, TOON: 4951 tokens"
      }
    },
    "component_count": 15,
    "dependency_count": 42,
    "detected_patterns": ["layered", "dependency-injection"],
    "warnings": ["circular-dependency: A ↔ B"],
    "complexity": "minimal|standard|complex",
    "mermaid_diagrams_generated": 2
  }
}
```

**TOON format benefits:**
- **30-60% token savings** compared to JSON/YAML
- Improved LLM parsing accuracy (73.9% vs 69.7% for JSON)
- Ideal for tabular data (components, edges, quality attributes)
- Lossless round-trip conversion

**Token savings by data type:**
| Data Type | JSON Tokens | TOON Tokens | Savings |
|-----------|-------------|-------------|---------|
| Components (3 items) | 202 | 123 | 39.1% |
| Dependency Graph | 223 | 114 | 48.9% |
| Data Flow | ~180 | ~95 | 47.2% |
| Quality Attributes | ~150 | ~85 | 43.3% |

### Documentation Files (YAML)

- `/docs/architecture/overview.yaml` - Main architecture document
- `/docs/architecture/components/*.yaml` - Individual component docs
- `/docs/architecture/dependency-graph.yaml` - Dependency relationships
- `/docs/architecture/diagrams/dependency-graph.md` - Markdown with embedded Mermaid visualization
- `/docs/architecture/diagrams/data-flow-*.md` - Data flow diagrams with embedded Mermaid
- `/docs/architecture/README.md` - Architecture documentation index

## Templates

### YAML Templates (Human-facing)

- `@template:architecture-lite` - Minimal architecture (< 10 components)
- `@template:architecture-full` - Complete architecture documentation
- `@template:component` - Single component specification
- `@template:dependency-graph` - Dependency graph structure
- `@template:dependency-graph.md` - Markdown with Mermaid dependency visualization
- `@template:data-flow.md` - Markdown with Mermaid data flow diagram
- `@template:README.md` - Architecture documentation index

### TOON Templates (LLM-facing, token-efficient)

- `@template:components.toon` - Components in TOON tabular format
- `@template:dependency-graph.toon` - Dependency graph (nodes + edges) in TOON
- `@template:data-flow.toon` - Data flow steps in TOON
- `@template:quality-attributes.toon` - Quality attributes in TOON

**TOON templates achieve 30-60% token savings** compared to JSON/YAML.

See [TOON Integration Guide](./examples/TOON-INTEGRATION-GUIDE.md) for usage details.

## Schemas

- `@schema:architecture` - Architecture YAML validation
- `@schema:component` - Component YAML validation
- `@schema:dependency` - Dependency graph validation

## Examples

- `@example:web-application` - Express.js web app
- `@example:microservices` - Multi-service architecture
- `@example:monorepo` - Monorepo with multiple packages

## TOON Format Integration

### What is TOON?

**TOON (Token-Oriented Object Notation)** is a compact, human-readable data format optimized for LLM prompts and inter-agent communication. It combines YAML indentation, CSV tabular format, and JSON data model while achieving **30-60% token reduction**.

### Why Use TOON?

**Benefits:**
- ✅ **30-60% token savings** (components: 39.1%, dependency graphs: 48.9%)
- ✅ **Improved parsing accuracy** (73.9% vs 69.7% for JSON in LLM benchmarks)
- ✅ **Lossless conversion** (round-trip TOON ↔ JSON preserves all data)
- ✅ **Ideal for tabular data** (components, edges, quality attributes)

**When to use:**
- Structured output between skills (internal communication)
- Large datasets (> 10 components, > 20 edges)
- Token-constrained environments

**When NOT to use:**
- Human-facing files in git commits (use YAML for tooling support)
- Deeply nested structures (> 3 levels)
- Small datasets where savings are minimal

### TOON Converter API

Located in `converters/toon-converter.mjs`:

```javascript
import {
  jsonToToon,           // Generic JSON → TOON
  toonToJson,           // Generic TOON → JSON
  componentsToToon,     // Components array → TOON table
  dependencyGraphToToon,// Nodes + edges → TOON graph
  calculateTokenSavings,// Measure token reduction
  validateToon,         // Validate TOON syntax
  roundTripTest         // Test lossless conversion
} from './converters/toon-converter.mjs';
```

**Usage example:**
```javascript
// Convert components to TOON
const components = [
  { id: 'proxy-mgmt', name: 'Proxy Management', type: 'module',
    path: 'iclaude.sh:1343-1666', description: 'Handle proxy config',
    layer: 'infrastructure' }
];

const toonString = componentsToToon(components);
// Result: components[1]{id,name,type,path,description,layer}:
//   proxy-mgmt,Proxy Management,module,"iclaude.sh:1343-1666",Handle proxy config,infrastructure

// Calculate token savings
const stats = calculateTokenSavings({ components });
console.log(`Saved ${stats.savedPercent} tokens`); // Saved 39.1% tokens
```

### TOON Templates

**Components:**
```
components[{{count}}]{id,name,type,path,description,layer}:
{{#each components}}
  {{id}},{{name}},{{type}},{{path}},{{description}},{{layer}}
{{/each}}
```

**Dependency Graph:**
```
dependency_graph:
  nodes[{{node_count}}]{id,label,type,layer}:
{{#each nodes}}
    {{id}},{{label}},{{type}},{{layer}}
{{/each}}
  edges[{{edge_count}}]{from,to,type,description}:
{{#each edges}}
    {{from}},{{to}},{{type}},{{description}}
{{/each}}
```

**Data Flow:**
```
data_flow:
  id: {{flow_id}}
  name: {{flow_name}}
  trigger: {{trigger}}
  steps[{{step_count}}]{step_number,component,action,data_in,data_out}:
{{#each steps}}
    {{step_number}},{{component}},{{action}},{{data_in}},{{data_out}}
{{/each}}
```

**Quality Attributes:**
```
quality_attributes[{{count}}]{attribute,target,measurement,status}:
{{#each attributes}}
  {{attribute}},{{target}},{{measurement}},{{status}}
{{/each}}
```

### Integration Workflow

**Step-by-step process:**

1. **Generate YAML documentation** (existing Step 6)
   - Fill `templates/architecture-full.yaml`
   - Create component and dependency data structures

2. **Generate TOON documentation** (NEW Step 6b)
   ```javascript
   import { componentsToToon, dependencyGraphToToon, calculateTokenSavings }
     from './converters/toon-converter.mjs';

   // Convert components
   const componentsToon = componentsToToon(components);

   // Convert dependency graph
   const graphToon = dependencyGraphToToon(nodes, edges);

   // Calculate savings
   const stats = calculateTokenSavings({ components, dependency_graph: { nodes, edges } });
   ```

3. **Embed in structured output**
   ```json
   {
     "architecture_documentation": {
       "formats": {
         "toon": {
           "components_toon": "components[15]{...}:\n  ...",
           "dependency_graph_toon": "dependency_graph:\n  nodes[15]{...}:\n  ...",
           "token_savings": "42%",
           "size_comparison": "YAML: 8542 tokens, TOON: 4951 tokens"
         }
       }
     }
   }
   ```

4. **Validate TOON output**
   ```javascript
   import { validateToon, roundTripTest } from './converters/toon-converter.mjs';

   // Validate syntax
   const validation = validateToon(componentsToon);
   if (!validation.valid) throw new Error(validation.error);

   // Test lossless conversion
   const test = roundTripTest({ components });
   if (!test.success) throw new Error('Round-trip failed');
   ```

### Hybrid Architecture

**Best practice:** Use both YAML and TOON for different purposes.

**YAML files (in git):**
- `/docs/architecture/overview.yaml` - Human-readable, git-diffable
- `/docs/architecture/diagrams/*.md` - Mermaid visualizations
- Better tooling support (syntax highlighting, validation)

**TOON format (in structured output):**
- Embedded in JSON: `"components_toon": "..."`
- Token-efficient inter-skill communication
- Not committed to git (generated on-demand)

### Token Savings Examples

**Real benchmarks from iclaude project:**

| Data Type | JSON Tokens | TOON Tokens | Savings |
|-----------|-------------|-------------|---------|
| **Components** (3 items) | 202 | 123 | **39.1%** |
| **Dependency Graph** | 223 | 114 | **48.9%** |
| **Data Flow** (5 steps) | ~180 | ~95 | **47.2%** |
| **Quality Attributes** (5 items) | ~150 | ~85 | **43.3%** |

**Large dataset example** (15 components, 42 edges):
- YAML: 8,542 tokens
- TOON: 4,951 tokens
- **Savings: 3,591 tokens (-42.0%)**

### Examples

See comprehensive examples in:
- `examples/toon/components.toon.example` - 6 components from iclaude
- `examples/toon/dependency-graph.toon.example` - 6 nodes, 7 edges
- `examples/toon/data-flow.toon.example` - User launch workflow
- `examples/toon/quality-attributes.toon.example` - 5 quality attributes
- `examples/TOON-INTEGRATION-GUIDE.md` - Complete guide with tutorials

### Further Reading

- **TOON Integration Guide:** `examples/TOON-INTEGRATION-GUIDE.md`
- **Converter API Reference:** `converters/README.md`
- **TOON Format Website:** [toonformat.dev](https://toonformat.dev)
- **NPM Package:** [@toon-format/toon](https://www.npmjs.com/package/@toon-format/toon)

---

## Workflow Integration

### Input Dependencies

Requires data from:
- `context-awareness` → `project_context`
- `thinking-framework` → Component analysis

### Output Consumers

Provides data to:
- `validation-framework` → Validate architecture quality (consumes TOON or YAML)
- `git-workflow` → Commit documentation (YAML files only)
- Downstream skills → Use TOON for token-efficient data passing
- User → Review and modify YAML files
