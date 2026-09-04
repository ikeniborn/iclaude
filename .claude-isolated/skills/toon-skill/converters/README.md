# TOON Converter API Documentation

Централизованный API для конвертации JSON ↔ TOON в Claude Code skills.

## Quick Start

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Convert array to TOON
const warnings = [
  { file: 'app.js', line: 42, severity: 'BLOCKING', message: 'SQL injection' },
  { file: 'db.js', line: 15, severity: 'WARNING', message: 'Missing index' }
];

const toonWarnings = arrayToToon('warnings', warnings, ['file', 'line', 'severity', 'message']);
console.log(toonWarnings);
// Output:
// warnings[2]{file,line,severity,message}:
//   app.js,42,BLOCKING,SQL injection
//   db.js,15,WARNING,Missing index

// Calculate savings
const stats = calculateTokenSavings({ warnings });
console.log(`Token savings: ${stats.savedPercent}`); // "38.5%"
```

## API Functions

### Generic Converters (Primary API)

#### `arrayToToon(arrayName, items, fields)`

Конвертирует массив объектов в TOON table format.

**Параметры:**
- `arrayName` (string) - Название массива для TOON header
- `items` (Array<Object>) - Массив объектов для конвертации
- `fields` (string[]) - Поля для включения в TOON таблицу

**Возвращает:** string - TOON formatted table

**Когда использовать:** Любой uniform массив >= 5 элементов с consistent schema

**Примеры:**

```javascript
// Code review warnings
const warnings = [
  { category: 'security', file: 'app.js', line: 42, severity: 'BLOCKING', message: 'SQL injection', suggestion: 'Use parameterized queries' },
  { category: 'code_quality', file: 'db.js', line: 15, severity: 'WARNING', message: 'Missing index', suggestion: 'Add index on user_id column' }
];

const toonWarnings = arrayToToon('warnings', warnings, ['category', 'file', 'line', 'severity', 'message', 'suggestion']);
```

```javascript
// Execution steps
const steps = [
  { step_number: 1, description: 'Create FastAPI endpoint', validation: 'Run pytest tests/test_api.py' },
  { step_number: 2, description: 'Add Pydantic model', validation: 'Check type annotations' }
];

const toonSteps = arrayToToon('execution_steps', steps, ['step_number', 'description', 'validation']);
```

```javascript
// PR checks
const checks = [
  { name: 'pytest', status: 'passed', duration_ms: 1250, details_url: 'https://...' },
  { name: 'eslint', status: 'failed', duration_ms: 340, details_url: 'https://...' }
];

const toonChecks = arrayToToon('checks', checks, ['name', 'status', 'duration_ms', 'details_url']);
```

#### `nestedToToon(parentName, childArrays)`

Конвертирует nested object с multiple arrays в TOON format.

**Параметры:**
- `parentName` (string) - Название parent object
- `childArrays` (Object) - Object с child array definitions:
  - `<childName>.items` (Array) - Массив элементов
  - `<childName>.fields` (string[]) - Поля для этого массива

**Возвращает:** string - TOON formatted nested structure

**Когда использовать:** Dependency graphs, nested structures с multiple child arrays

**Пример:**

```javascript
// Dependency graph
const graph = {
  nodes: [
    { id: 'proxy-mgmt', label: 'Proxy Management', type: 'module', layer: 'infrastructure' },
    { id: 'oauth-handler', label: 'OAuth Handler', type: 'function', layer: 'business' }
  ],
  edges: [
    { from: 'proxy-mgmt', to: 'oauth-handler', type: 'required', description: 'Requires OAuth for authenticated proxies' }
  ]
};

const toonGraph = nestedToToon('dependency_graph', {
  nodes: { items: graph.nodes, fields: ['id', 'label', 'type', 'layer'] },
  edges: { items: graph.edges, fields: ['from', 'to', 'type', 'description'] }
});
```

#### `jsonToToon(jsonObj, options)`

Generic JSON → TOON конвертация (uses @toon-format/toon encoder).

**Параметры:**
- `jsonObj` (Object) - JSON object для конвертации
- `options` (Object, optional):
  - `delimiter` (string) - Delimiter for arrays: ',', '\t', '|' (default: ',')
  - `indent` (number) - Indentation size (default: 2)

**Возвращает:** string - TOON formatted string

**Когда использовать:** Complex nested structures, когда `arrayToToon()` не подходит

**Пример:**

```javascript
const complexData = {
  metadata: { version: '1.0.0', timestamp: '2026-01-23T10:00:00Z' },
  components: [{ id: 'a', name: 'Component A' }],
  quality_attributes: [{ name: 'Performance', value: 'high' }]
};

const toon = jsonToToon(complexData);
```

#### `toonToJson(toonString, options)`

TOON → JSON конвертация (uses @toon-format/toon decoder).

**Параметры:**
- `toonString` (string) - TOON formatted string
- `options` (Object, optional):
  - `strict` (boolean) - Enable strict mode (default: true)

**Возвращает:** Object - Parsed JSON object

**Когда использовать:** Reading TOON output from upstream skills

**Пример:**

```javascript
const toonString = 'warnings[2]{file,line,severity}:\n  app.js,42,BLOCKING\n  db.js,15,WARNING';
const jsonObj = toonToJson(toonString);
// Returns: { warnings: [{ file: 'app.js', line: 42, severity: 'BLOCKING' }, ...] }
```

---

### Utility Functions

#### `calculateTokenSavings(jsonObj)`

Рассчитывает token savings между JSON и TOON форматами.

**Параметры:**
- `jsonObj` (Object) - JSON object для сравнения

**Возвращает:** Object
- `jsonTokens` (number) - Estimated JSON tokens
- `toonTokens` (number) - Estimated TOON tokens
- `savedTokens` (number) - Absolute token savings
- `savedPercent` (string) - Percentage savings (formatted, e.g., "42.3%")
- `jsonSize` (number) - JSON size in bytes
- `toonSize` (number) - TOON size in bytes

**Пример:**

```javascript
const data = { warnings: [...] }; // 15 warnings
const stats = calculateTokenSavings(data);

console.log(`Token savings: ${stats.savedPercent}`); // "43.2%"
console.log(`JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`);
```

#### `validateToon(toonString)`

Валидирует TOON string на корректность.

**Параметры:**
- `toonString` (string) - TOON string для валидации

**Возвращает:** Object
- `valid` (boolean) - Whether TOON is valid
- `error` (string, optional) - Error message if invalid

**Пример:**

```javascript
const toonString = 'warnings[2]{file,line}:\n  app.js,42\n  db.js,15';
const result = validateToon(toonString);

if (!result.valid) {
  console.error('Invalid TOON:', result.error);
}
```

#### `roundTripTest(jsonObj)`

Тестирует lossless конвертацию: JSON → TOON → JSON.

**Параметры:**
- `jsonObj` (Object) - JSON object для тестирования

**Возвращает:** Object
- `success` (boolean) - Whether round-trip succeeded
- `error` (string, optional) - Error message if failed
- `original` (Object, optional) - Original JSON (if success)
- `roundtrip` (Object, optional) - Round-trip JSON (if success)

**Пример:**

```javascript
const data = { items: [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }] };
const result = roundTripTest(data);

if (result.success) {
  console.log('✓ Lossless conversion confirmed!');
} else {
  console.error('✗ Round-trip failed:', result.error);
}
```

---

### Specialized Converters (Legacy)

Эти функции предназначены для специфичных skills (architecture-documentation).
Для новых skills используйте **generic API** (`arrayToToon`, `nestedToToon`).

#### `componentsToToon(components)`

Specialized converter для architecture-documentation components.

**Пример:**

```javascript
const components = [
  { id: 'proxy-mgmt', name: 'Proxy Management', type: 'module',
    path: 'iclaude.sh:100-200', description: 'Handle proxy config', layer: 'infrastructure' }
];

const toon = componentsToToon(components);
```

#### `dependencyGraphToToon(nodes, edges)`

Specialized converter для architecture-documentation dependency graphs.

**Пример:**

```javascript
const nodes = [{ id: 'a', label: 'A', type: 'component', layer: 'business' }];
const edges = [{ from: 'a', to: 'b', type: 'required', description: 'Uses B' }];

const toon = dependencyGraphToToon(nodes, edges);
```

#### `edgesToToon(edges)`

Specialized converter для architecture-documentation edges.

---

## Integration Pattern (Hybrid Output)

**Всегда используйте этот паттерн для backward compatibility:**

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Step 1: Generate JSON output (always)
const output = {
  status: "success",
  warnings: [...]  // 15 warnings
};

// Step 2: Add TOON optimization (if >= 5 elements)
if (output.warnings.length >= 5) {
  output.toon = {
    warnings_toon: arrayToToon('warnings', output.warnings,
      ['category', 'file', 'line', 'severity', 'message', 'suggestion']),
    token_savings: calculateTokenSavings({ warnings: output.warnings }).savedPercent,
    size_comparison: `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`
  };
}

// Step 3: Return hybrid output
return output;
```

**Result structure:**

```json
{
  "status": "success",
  "warnings": [...],  // JSON (always present)
  "toon": {           // TOON (optional, if >= 5 elements)
    "warnings_toon": "warnings[15]{category,file,line,severity,message,suggestion}:\n  ...",
    "token_savings": "43.2%",
    "size_comparison": "JSON: 3450 tokens, TOON: 1960 tokens"
  }
}
```

---

## CLI Usage

Конвертер можно использовать через command line:

```bash
# Convert JSON file to TOON
node toon-converter.mjs encode input.json

# Convert TOON file to JSON
node toon-converter.mjs decode input.toon

# Run round-trip test
node toon-converter.mjs test input.json

# Show token savings statistics
node toon-converter.mjs stats input.json
```

---

## Token Savings Guidelines

| Array Size | TOON Worth It? | Expected Savings | Recommendation |
|------------|----------------|------------------|----------------|
| < 3 elements | ❌ No | 5-15% | Skip TOON |
| 3-4 elements | ⚠️ Maybe | 15-25% | Edge case, usually skip |
| **5-9 elements** | ✅ Yes | **25-35%** | **Threshold met** |
| **10-19 elements** | ✅✅ Yes | **35-45%** | **High value** |
| **20+ elements** | ✅✅✅ Definitely | **45-60%** | **Maximum savings** |

---

## Best Practices

### ✅ DO

- Use `arrayToToon()` для uniform arrays >= 5 elements
- Use `nestedToToon()` для dependency graphs, nested structures
- Always generate JSON first (backward compatibility)
- Add TOON as optional optimization layer
- Include `token_savings` метрику в output
- Test round-trip conversion

### ❌ DON'T

- Replace JSON with TOON (breaking change!)
- Convert маленькие массивы (< 5 elements, minimal savings)
- Use TOON для deeply nested structures (> 3 levels, poor fit)
- Export TOON в git (human-facing files should be YAML/JSON)

---

## References

- **TOON Specification**: https://toonformat.dev/spec
- **NPM Package**: @toon-format/toon
- **Integration Guide**: ../examples/integration-guide.md
- **Patterns**: ../../_shared/TOON-PATTERNS.md
