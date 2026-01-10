---
name: architecture-documentation
description: Generate detailed architectural documentation in YAML format with component dependencies and relationships
version: 1.0.0
tags: [documentation, architecture, yaml, dependencies, graph]
dependencies: [context-awareness, thinking-framework]
author: Claude Code Skills Team
files:
  templates: ./templates/*.yaml
  schemas: ./schemas/*.schema.json
  examples: ./examples/*.md
  rules: ./rules/*.md
user-invocable: true
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

### Step 7: Validate Output

Before writing files:
- Verify all dependency references exist
- Detect circular dependencies (A depends on B, B depends on A)
- Check ID format (kebab-case: `^[a-z][a-z0-9-]*$`)
- Ensure descriptions are not placeholders (min 10 chars, not "TODO" or "Component")

### Step 8: Generate Mermaid Diagram

Convert dependency_graph to Mermaid syntax for visualization:

**Mermaid generation logic:**

Generate `/docs/architecture/diagrams/dependency-graph.mmd` with:

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
- `/docs/architecture/diagrams/dependency-graph.mmd` - Mermaid visualization (ALWAYS)
- `/docs/architecture/diagrams/data-flow-{flow-id}.mmd` - Data flow diagrams (if data flows exist)
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
      "diagrams/dependency-graph.mmd",
      "diagrams/data-flow-user-login.mmd",
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
  - View Mermaid diagrams on GitHub or using Mermaid preview extension
  - Commit architecture docs to git

## Output Format

### Workflow Integration (JSON)

```json
{
  "architecture_documentation": {
    "status": "success|partial|failed",
    "output_directory": "/docs/architecture",
    "files_created": ["overview.yaml", "components/service1.yaml"],
    "component_count": 15,
    "dependency_count": 42,
    "detected_patterns": ["layered", "dependency-injection"],
    "warnings": ["circular-dependency: A ↔ B"],
    "complexity": "minimal|standard|complex",
    "mermaid_diagrams_generated": 2
  }
}
```

### Documentation Files (YAML)

- `/docs/architecture/overview.yaml` - Main architecture document
- `/docs/architecture/components/*.yaml` - Individual component docs
- `/docs/architecture/dependency-graph.yaml` - Dependency relationships
- `/docs/architecture/diagrams/dependency-graph.mmd` - Mermaid visualization
- `/docs/architecture/diagrams/data-flow-*.mmd` - Data flow diagrams
- `/docs/architecture/README.md` - Architecture documentation index

## Templates

- `@template:architecture-lite` - Minimal architecture (< 10 components)
- `@template:architecture-full` - Complete architecture documentation
- `@template:component` - Single component specification
- `@template:dependency-graph` - Dependency graph structure
- `@template:dependency-graph.mmd` - Mermaid dependency visualization
- `@template:data-flow.mmd` - Mermaid data flow diagram
- `@template:README.md` - Architecture documentation index

## Schemas

- `@schema:architecture` - Architecture YAML validation
- `@schema:component` - Component YAML validation
- `@schema:dependency` - Dependency graph validation

## Examples

- `@example:web-application` - Express.js web app
- `@example:microservices` - Multi-service architecture
- `@example:monorepo` - Monorepo with multiple packages

## Workflow Integration

### Input Dependencies

Requires data from:
- `context-awareness` → `project_context`
- `thinking-framework` → Component analysis

### Output Consumers

Provides data to:
- `validation-framework` → Validate architecture quality
- `git-workflow` → Commit documentation
- User → Review and modify YAML files
