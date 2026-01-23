---
name: Validation Framework
description: Адаптивная валидация с поддержкой partial validation и TOON input
version: 2.1.0
tags: [validation, testing, acceptance-criteria, quality, toon]
dependencies: [structured-planning, architecture-documentation]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
user-invocable: false
changelog:
  - version: 2.1.0
    date: 2026-01-23
    changes:
      - "**TOON Input Support**: Added ability to consume TOON format from architecture-documentation"
      - "TOON parser integration via toon-converter.mjs"
      - "Architecture quality validation from TOON (circular dependencies, edge validation)"
      - "Fallback to YAML/JSON for backward compatibility"
      - "Token savings reporting in validation output"
      - "Comprehensive examples and troubleshooting guide"
  - version: 2.0.0
    date: 2025-11-XX
    changes:
      - Адаптивная валидация с режимами lite/standard/full
      - Initial release
---

# Validation Framework v2.0

Адаптивная валидация с выбором режима по сложности задачи.

## Когда использовать

- После выполнения задачи (Phase 4)
- Перед git commit

## Режимы валидации

| Mode | Checks | Blocking |
|------|--------|----------|
| **lite** | syntax only | syntax |
| **standard** | syntax + acceptance | syntax, acceptance |
| **full** | all checks | all |

## Выбор режима

```
if complexity == "minimal":
  mode = "lite"
elif complexity == "standard":
  mode = "standard"
else:
  mode = "full"
```

## Шаблоны

### Lite (validation-lite)

```json
{
  "validation_lite": {
    "syntax_check": "passed|failed",
    "files_modified": ["file1.py"],
    "status": "PASSED|FAILED"
  }
}
```

### Full (validation-full)

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 2,
      "met": 2,
      "not_met": 0,
      "details": [...]
    },
    "prd_compliance": {
      "compliant": true,
      "conflicts": []
    },
    "syntax_checks": {
      "total_files": 2,
      "passed": 2,
      "failed": 0
    },
    "functional_checks": {
      "total": 1,
      "passed": 1,
      "failed": 0
    },
    "overall_status": "PASSED",
    "can_proceed": true,
    "blocking_issues": []
  }
}
```

## Validation Logic

```javascript
// Lite mode
status = syntax_check === "passed" ? "PASSED" : "FAILED"

// Full mode
overall_status = "PASSED" if (
  acceptance_criteria.not_met === 0 &&
  (prd_compliance.compliant || !has_prd) &&
  syntax_checks.failed === 0 &&
  functional_checks.failed === 0
)

can_proceed = overall_status === "PASSED"
```

## TOON Input Support (NEW)

**Validation Framework теперь поддерживает TOON format input** из structured output других навыков (например, `architecture-documentation`).

### Что такое TOON Input?

TOON (Token-Oriented Object Notation) - компактный формат для inter-skill communication с **30-60% экономией токенов**.

**Преимущества:**
- ✅ Экономия токенов в workflow
- ✅ Improved parsing accuracy (73.9% vs 69.7% для JSON)
- ✅ Lossless conversion (100% data fidelity)

### Как читать TOON Input

**Шаг 1: Импортировать TOON converter**

```javascript
import { toonToJson, validateToon } from '../architecture-documentation/converters/toon-converter.mjs';
```

**Шаг 2: Получить TOON из structured output**

```javascript
// Structured output from architecture-documentation
const archOutput = {
  architecture_documentation: {
    formats: {
      toon: {
        components_toon: "components[15]{id,name,type,path,description,layer}:\n  proxy-mgmt,Proxy Management,...",
        dependency_graph_toon: "dependency_graph:\n  nodes[15]{...}:\n  ...",
        token_savings: "42%"
      }
    },
    component_count: 15,
    dependency_count: 42
  }
};
```

**Шаг 3: Валидировать TOON syntax**

```javascript
// Validate TOON before parsing
const componentsValidation = validateToon(archOutput.architecture_documentation.formats.toon.components_toon);

if (!componentsValidation.valid) {
  console.error('⚠ Invalid TOON input:', componentsValidation.error);
  // Fallback: Request YAML format or skip validation
  throw new Error('TOON validation failed - cannot parse input');
}

console.log('✓ TOON input validated');
```

**Шаг 4: Парсить TOON → JSON**

```javascript
// Parse TOON strings to JSON
const componentsData = toonToJson(archOutput.architecture_documentation.formats.toon.components_toon);
const graphData = toonToJson(archOutput.architecture_documentation.formats.toon.dependency_graph_toon);

// Now use JSON data for validation
console.log(`Parsed ${componentsData.components.length} components from TOON`);
console.log(`Parsed ${graphData.dependency_graph.nodes.length} nodes, ${graphData.dependency_graph.edges.length} edges`);
```

**Результат:**
```javascript
componentsData = {
  components: [
    { id: 'proxy-mgmt', name: 'Proxy Management', type: 'module', ... },
    { id: 'isolated-env', name: 'Isolated Environment', type: 'module', ... },
    // ... 13 more components
  ]
};

graphData = {
  dependency_graph: {
    nodes: [
      { id: 'proxy-mgmt', label: 'Proxy Management', type: 'component', layer: 'infrastructure' },
      // ... 14 more nodes
    ],
    edges: [
      { from: 'isolated-env', to: 'version-mgmt', type: 'required', description: 'Uses lockfile' },
      // ... 41 more edges
    ]
  }
};
```

### Валидация Architecture Quality из TOON

**Use case:** Валидация circular dependencies и architecture quality из TOON input

```javascript
// Parse TOON dependency graph
const graphData = toonToJson(archOutput.architecture_documentation.formats.toon.dependency_graph_toon);

// Extract nodes and edges
const { nodes, edges } = graphData.dependency_graph;

// 1. Check for circular dependencies
function detectCircularDependencies(nodes, edges) {
  const visited = new Set();
  const recursionStack = new Set();
  const circularDeps = [];

  function hasCycle(nodeId) {
    visited.add(nodeId);
    recursionStack.add(nodeId);

    const outgoing = edges.filter(e => e.from === nodeId);
    for (const edge of outgoing) {
      if (!visited.has(edge.to)) {
        if (hasCycle(edge.to)) return true;
      } else if (recursionStack.has(edge.to)) {
        circularDeps.push(`${nodeId} ↔ ${edge.to}`);
        return true;
      }
    }

    recursionStack.delete(nodeId);
    return false;
  }

  for (const node of nodes) {
    if (!visited.has(node.id)) {
      hasCycle(node.id);
    }
  }

  return circularDeps;
}

const circularDeps = detectCircularDependencies(nodes, edges);

if (circularDeps.length > 0) {
  console.warn('⚠ Circular dependencies detected:', circularDeps);
}

// 2. Check component count matches
const expectedCount = archOutput.architecture_documentation.component_count;
const actualCount = componentsData.components.length;

if (expectedCount !== actualCount) {
  console.error(`⚠ Component count mismatch: expected ${expectedCount}, got ${actualCount}`);
}

// 3. Validate all edge references exist
for (const edge of edges) {
  const fromExists = nodes.some(n => n.id === edge.from);
  const toExists = nodes.some(n => n.id === edge.to);

  if (!fromExists || !toExists) {
    console.error(`⚠ Invalid edge: ${edge.from} → ${edge.to} (missing node)`);
  }
}
```

### Fallback для Legacy Input (YAML/JSON)

**Backward compatibility:** Поддержка YAML/JSON input если TOON недоступен

```javascript
function getComponentsData(structuredOutput) {
  // Try TOON first (token-efficient)
  if (structuredOutput.architecture_documentation?.formats?.toon?.components_toon) {
    try {
      const toonString = structuredOutput.architecture_documentation.formats.toon.components_toon;
      const validation = validateToon(toonString);

      if (validation.valid) {
        const data = toonToJson(toonString);
        console.log('✓ Using TOON input (token-efficient)');
        return data.components;
      } else {
        console.warn('⚠ TOON validation failed, falling back to YAML');
      }
    } catch (error) {
      console.warn('⚠ TOON parsing error:', error.message);
    }
  }

  // Fallback to YAML/JSON (legacy)
  if (structuredOutput.architecture_documentation?.components) {
    console.log('ℹ Using YAML/JSON input (legacy)');
    return structuredOutput.architecture_documentation.components;
  }

  throw new Error('No components data found in structured output');
}

// Usage
const components = getComponentsData(archOutput);
console.log(`Loaded ${components.length} components`);
```

### TOON Validation Output

**Enhanced validation result** с TOON token savings:

```json
{
  "validation_results": {
    "input_format": "toon",
    "input_token_savings": "42%",
    "toon_validation": {
      "components_valid": true,
      "dependency_graph_valid": true,
      "round_trip_test": "passed"
    },
    "architecture_quality": {
      "circular_dependencies": 0,
      "component_count_matches": true,
      "all_edges_valid": true
    },
    "acceptance_criteria": {
      "total": 3,
      "met": 3,
      "not_met": 0
    },
    "overall_status": "PASSED",
    "can_proceed": true
  }
}
```

### Примеры

**Пример 1: Валидация architecture из TOON**

```javascript
// Input: TOON from architecture-documentation
const toonInput = {
  architecture_documentation: {
    formats: {
      toon: {
        components_toon: "components[6]{id,name,type,path,description,layer}:\n  ...",
        dependency_graph_toon: "dependency_graph:\n  nodes[6]{...}:\n  edges[7]{...}:\n  ...",
        token_savings: "42.3%"
      }
    },
    component_count: 6,
    dependency_count: 7
  }
};

// Parse TOON
const components = toonToJson(toonInput.architecture_documentation.formats.toon.components_toon);
const graph = toonToJson(toonInput.architecture_documentation.formats.toon.dependency_graph_toon);

// Validate
const circularDeps = detectCircularDependencies(graph.dependency_graph.nodes, graph.dependency_graph.edges);

// Output
console.log(circularDeps.length === 0 ? '✓ No circular dependencies' : '⚠ Circular dependencies found');
```

**Пример 2: Token savings reporting**

```javascript
// Report token savings from TOON usage
const tokenSavings = toonInput.architecture_documentation.formats.toon.token_savings;

console.log(`
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: PASSED
═══════════════════════════════════════════════════════════

INPUT FORMAT: TOON (token-efficient)
TOKEN SAVINGS: ${tokenSavings}

ARCHITECTURE QUALITY: ✓
- Components: ${components.components.length}
- Circular dependencies: 0
- All edges valid: true

═══════════════════════════════════════════════════════════
`);
```

### Когда использовать TOON Input

✅ **Рекомендуется:**
- Structured output от `architecture-documentation` с TOON support
- High-volume workflows (экономия токенов критична)
- Inter-skill communication (architecture-documentation → validation-framework → git-workflow)

❌ **Не рекомендуется:**
- Human-provided input (используйте YAML/JSON)
- Small datasets (< 5 компонентов, overhead превышает savings)
- Legacy workflows без TOON support

### Troubleshooting

**Ошибка: "Cannot find module toon-converter"**

```bash
# Установите TOON converter
cd ../architecture-documentation/converters
npm install
```

**Ошибка: "TOON validation failed"**

```javascript
// Debug invalid TOON
const validation = validateToon(toonString);
console.error('TOON validation error:', validation.error);

// Fallback to YAML
console.log('Using YAML fallback');
const components = structuredOutput.architecture_documentation.components;
```

**Ошибка: "Round-trip test failed"**

```javascript
// Test lossless conversion
const { roundTripTest } = await import('../architecture-documentation/converters/toon-converter.mjs');
const result = roundTripTest({ components });

if (!result.success) {
  console.error('Data loss detected:', result.error);
  // Abort or use YAML
}
```

---

## Syntax Commands

Используй: `@shared:syntax-commands`

## Markdown Output

```
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: {status}
═══════════════════════════════════════════════════════════

SYNTAX: {passed}/{total} ✓
ACCEPTANCE: {met}/{total} ✓

{если FAILED}
🛑 BLOCKING:
- {issue1}
- {issue2}

═══════════════════════════════════════════════════════════
```

## Примеры

- Passed: `@example:passed`
- Failed: `@example:failed`
