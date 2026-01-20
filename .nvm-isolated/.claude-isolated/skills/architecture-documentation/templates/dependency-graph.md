# Dependency Graph Template

> This is a template for generating component dependency diagrams.
> The Mermaid diagram below is embedded in Markdown format for better GitHub compatibility.

## Basic Example

```mermaid
graph TD
    %% Component Nodes
    api-controller[API Controller]
    auth-service[Authentication Service]
    database[Database]

    %% Dependencies
    api-controller -->|required| auth-service
    auth-service -->|required| database

    %% Styling by layer
    style api-controller fill:#e1f5ff
    style auth-service fill:#fff4e1
    style database fill:#ffe1e1
```

## Example: Layered Architecture

```mermaid
graph TD
    subgraph presentation["Presentation Layer"]
        auth-controller[Authentication Controller]
        user-controller[User Controller]
    end

    subgraph business["Business Layer"]
        auth-service[Authentication Service]
        user-service[User Service]
    end

    subgraph data["Data Layer"]
        user-model[User Model]
    end

    auth-controller -->|required| auth-service
    user-controller -->|required| user-service
    auth-service -->|required| user-model
    user-service -->|required| user-model

    style auth-controller fill:#e1f5ff
    style user-controller fill:#e1f5ff
    style auth-service fill:#fff4e1
    style user-service fill:#fff4e1
    style user-model fill:#ffe1e1
```

## Color Scheme

| Layer | Color | Hex Code |
|-------|-------|----------|
| Presentation | Light Blue | #e1f5ff |
| Business | Light Yellow | #fff4e1 |
| Data | Light Red | #ffe1e1 |
| Infrastructure | Light Green | #e1ffe1 |
| External | Gray | #f0f0f0 |

## Template Syntax

When generating diagrams, use this syntax:

```
graph TD
    component-id[Component Name]

    component1 -->|dependency-type| component2

    style component-id fill:#color-hex
```

**Placeholders to replace:**
- `component-id` - kebab-case component identifier (e.g., `auth-service`, `api-controller`)
- `Component Name` - human-readable name (e.g., `Authentication Service`)
- `dependency-type` - one of: `required`, `optional`, `dev`
- `#color-hex` - layer color (see Color Scheme table below)

## Usage

This template is used by the `architecture-documentation` skill to generate dependency graphs. The skill will:

1. Analyze codebase structure to identify components
2. Extract dependencies from import/require statements
3. Generate component nodes with kebab-case IDs
4. Create edges with appropriate dependency types
5. Apply styling based on architectural layer detection
6. Generate subgraphs for layered architectures (if detected)

The output is saved as `docs/architecture/diagrams/dependency-graph.md` with embedded Mermaid code blocks.
