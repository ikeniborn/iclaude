---
name: mermaid-obsidian
description: Use this skill whenever you need to create, generate, write, or fix Mermaid diagrams for viewing in Obsidian. Triggers when the user asks to "draw a diagram", "create a flowchart", "make a sequence diagram", "visualize architecture", "show relationships as a diagram", "create a mindmap in Obsidian", mentions Mermaid syntax, asks to fix a broken diagram, or wants to add any kind of chart/graph to their Obsidian notes. Covers all Mermaid diagram types: flowchart, sequence, class, ER, state, gantt, pie, gitGraph, mindmap, timeline. Always use this skill even if the user just says "draw" or "diagram" without specifying Mermaid explicitly — if they're working in Obsidian, Mermaid is the right tool.
version: 1.0.0
---

# Mermaid Diagrams for Obsidian

Produce correct, styled Mermaid diagrams that render reliably in Obsidian.

## Obsidian Constraints (Mermaid 11.4.1)

Obsidian bundles Mermaid 11.4.1. Know these quirks before writing any diagram:

- **Node IDs**: alphanumeric + underscores only — `node_1`, `UserService`, `phase_A`. Never spaces or special chars in IDs.
- **Labels with special chars**: wrap in quotes — `A["Label (with parens)"]`, `B["50% done"]`.
- **Subgraph IDs**: always use the `subgraph id["Title"]` pattern. Bare `subgraph "Title"` causes parse errors.
- **Live Preview vs Reading Mode**: diagrams sometimes appear as empty boxes in Live Preview — this is an Obsidian rendering bug, not a syntax error. Advise the user to switch to Reading Mode if this happens.
- **Multibyte characters**: avoid in node IDs; they can break rendering. Put them only in quoted labels.
- **No `\n` in labels**: the `\n` escape sequence does not work in Mermaid/Obsidian — it renders as literal `\n` text. For line breaks in sequence diagram messages use `<br/>` only where supported; in node labels there is no reliable multiline syntax — keep labels on one line.
- **Reserved keyword `end` in labels**: the word `end` (even inside quoted labels) can confuse the Mermaid 11.4.1 parser and cause a parse error. Replace `end-to-end` with `e2e`, `end state` with `final state`, etc.
- **Numbered labels `1.`, `2.` etc.**: a digit followed by a dot at the start of a label (`"1. Step one"`) is parsed as a markdown ordered list and causes a parse error. Use `1)` instead — `A["1) Step one"]` — or drop the numbering entirely.

## Theme Initialization

Always start diagrams with `%%{init}%%`. Use `base` theme for full color control, `dark` or `default` for quick presets.

**Dark theme** (Catppuccin Mocha palette — ideal for dark Obsidian):
```
%%{init: {'theme': 'base', 'themeVariables': {
  'background': '#1e1e2e',
  'primaryColor': '#313244',
  'primaryTextColor': '#cdd6f4',
  'primaryBorderColor': '#89b4fa',
  'lineColor': '#888888',
  'secondaryColor': '#181825',
  'tertiaryColor': '#45475a'
}}}%%
```

**Light theme** (clean minimal palette):
```
%%{init: {'theme': 'base', 'themeVariables': {
  'background': '#fafafa',
  'primaryColor': '#e8e8f0',
  'primaryTextColor': '#333344',
  'primaryBorderColor': '#5c6bc0',
  'lineColor': '#888888',
  'secondaryColor': '#f0f0f8',
  'tertiaryColor': '#e0e0f0'
}}}%%
```

> **`lineColor: '#888888'`** — средний тон, одинаково виден на тёмном и светлом фоне (~4:1 контраст на обоих). Не используй тёмные (`#333`) или светлые (`#ccc`) цвета соединений — они теряются на соответствующих темах.

**Quick dark preset** (simpler, less control):
```
%%{init: {'theme': 'dark'}}%%
```

## Semantic Color Palettes

Apply colors with `classDef` to communicate meaning visually.

### Dark (Catppuccin Mocha)
```
classDef primary  fill:#89b4fa,color:#1e1e2e,stroke:#74c7ec,stroke-width:2px
classDef success  fill:#a6e3a1,color:#1e1e2e,stroke:#40a02b
classDef warning  fill:#f9e2af,color:#1e1e2e,stroke:#df8e1d
classDef danger   fill:#f38ba8,color:#1e1e2e,stroke:#d20f39
classDef neutral  fill:#585b70,color:#cdd6f4,stroke:#6c7086
classDef info     fill:#94e2d5,color:#1e1e2e,stroke:#179299
```

### Light
```
classDef primary  fill:#c5cae9,color:#1a237e,stroke:#5c6bc0,stroke-width:2px
classDef success  fill:#c8e6c9,color:#1b5e20,stroke:#43a047
classDef warning  fill:#fff3e0,color:#e65100,stroke:#fb8c00
classDef danger   fill:#ffcdd2,color:#b71c1c,stroke:#e53935
classDef neutral  fill:#f5f5f5,color:#424242,stroke:#9e9e9e
classDef info     fill:#b2dfdb,color:#004d40,stroke:#00897b
```

Assign classes to nodes: `class NodeA primary` or `class NodeA,NodeB success`.
For a single node override: `style NodeA fill:#89b4fa,color:#1e1e2e`.

## Diagram Templates

### Flowchart
```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'background': '#1e1e2e', 'primaryColor': '#313244', 'primaryTextColor': '#cdd6f4', 'primaryBorderColor': '#89b4fa', 'lineColor': '#6c7086'}}}%%
flowchart TD
    A["Start"] --> B{"Decision?"}
    B -- Yes --> C["Action A"]
    B -- No  --> D["Action B"]
    C --> E["End"]
    D --> E

    classDef decision fill:#f9e2af,color:#1e1e2e,stroke:#df8e1d
    class B decision
```

### Sequence Diagram
```mermaid
%%{init: {'theme': 'dark'}}%%
sequenceDiagram
    participant U as User
    participant S as Server
    participant DB as Database

    U->>S: POST /login
    S->>DB: SELECT user WHERE email=?
    DB-->>S: user record
    S-->>U: 200 OK + token
    Note over U,S: Authenticated
```

### Class Diagram
```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'background': '#1e1e2e', 'primaryColor': '#313244', 'primaryTextColor': '#cdd6f4', 'primaryBorderColor': '#89b4fa', 'lineColor': '#6c7086'}}}%%
classDiagram
    class Animal {
        +String name
        +int age
        +move() void
        +speak() String
    }
    class Dog {
        +String breed
        +bark() void
    }
    class Cat {
        +purr() void
    }
    Animal <|-- Dog
    Animal <|-- Cat
```

### ER Diagram
```mermaid
%%{init: {'theme': 'dark'}}%%
erDiagram
    USER {
        int id PK
        string email
        string name
    }
    ORDER {
        int id PK
        date created_at
        int user_id FK
    }
    LINE_ITEM {
        int id PK
        int order_id FK
        int product_id FK
        int quantity
    }
    USER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
```

### State Diagram
```mermaid
%%{init: {'theme': 'dark'}}%%
stateDiagram-v2
    [*] --> Idle
    Idle --> Processing : start
    Processing --> Done : success
    Processing --> Error : failure
    Error --> Idle : retry
    Done --> [*]
```

### Mind Map
```mermaid
%%{init: {'theme': 'dark'}}%%
mindmap
  root((Project))
    Frontend
      React
      Styling
    Backend
      API
      Database
    DevOps
      CI/CD
      Monitoring
```

### Git Graph
```mermaid
%%{init: {'theme': 'dark', 'gitGraph': {'rotateCommitLabel': true}}}%%
gitGraph
   commit id: "init"
   branch feature/auth
   checkout feature/auth
   commit id: "add login"
   commit id: "add jwt"
   checkout main
   merge feature/auth id: "merge auth"
   commit id: "hotfix"
```

### Pie Chart
```mermaid
%%{init: {'theme': 'dark'}}%%
pie title Traffic Sources
    "Organic" : 45
    "Direct"  : 30
    "Social"  : 15
    "Paid"    : 10
```

### Gantt
```mermaid
%%{init: {'theme': 'dark'}}%%
gantt
    title Project Timeline
    dateFormat YYYY-MM-DD
    section Design
    Wireframes  : a1, 2024-01-01, 7d
    Mockups     : after a1, 5d
    section Dev
    Backend API : b1, 2024-01-10, 14d
    Frontend    : after b1, 10d
```

### Timeline
```mermaid
%%{init: {'theme': 'dark'}}%%
timeline
    title History of Social Media
    2004 : Facebook
    2005 : YouTube
    2006 : Twitter
    2010 : Instagram
    2016 : TikTok
```

## Workflow

**Generating a new diagram:**
1. Determine theme (ask if unclear; default to dark for Obsidian).
2. Choose diagram type based on what the user wants to show.
3. Add `%%{init}%%` with appropriate theme variables.
4. Apply semantic `classDef` colors to highlight key nodes.
5. Wrap all labels containing special characters, numbers-only, or spaces in quotes.
6. Use alphanumeric IDs; put display text in labels.
7. Output inside a fenced ` ```mermaid ` block.

**Fixing a broken diagram:**
1. Identify the error: syntax issue, rendering quirk, or missing theme.
2. Fix syntax: quote problematic labels, rename non-alphanumeric IDs, fix subgraph patterns.
3. Add `%%{init}%%` if missing.
4. Return corrected code with a brief explanation of each change.

## Common Errors Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| Empty box in Live Preview | Obsidian rendering bug | Use Reading Mode |
| `Parse error` near subgraph | Bare `subgraph "Name"` | Use `subgraph id["Name"]` |
| Arrows not rendering | Special chars in node ID | Rename to alphanumeric |
| Colors not applying | No `%%{init}%%` or wrong theme | Add `base` theme init |
| `Undefined` in diagram | Duplicate node IDs | Make all IDs unique |
| Missing last node | Syntax error earlier in diagram | Check for unclosed quotes/brackets |
| Literal `\n` in label | `\n` not supported in Mermaid/Obsidian | Remove `\n`; keep labels single-line |
| Parse error на середине диаграммы | Слово `end` в label (`end-to-end`, `end state`) | Заменить: `e2e`, `final state` и т.д. |
| Parse error при `"1. Label"` | `digit + dot` парсится как markdown list | Использовать `"1) Label"` или убрать нумерацию |
| Стрелки не видны на светлой/тёмной теме | `lineColor` слишком тёмный или светлый | Использовать `#888888` (средний тон) |
