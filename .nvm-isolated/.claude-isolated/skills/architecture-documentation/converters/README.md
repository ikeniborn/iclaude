# TOON Converter

Wrapper around [@toon-format/toon](https://www.npmjs.com/package/@toon-format/toon) for architecture-documentation skill.

## Features

- ✅ **JSON ↔ TOON conversion** with lossless round-trip guarantee
- ✅ **Specialized converters** for components, dependency graphs, edges
- ✅ **Token savings calculation** for benchmarking
- ✅ **CLI interface** for command-line usage
- ✅ **ES Module** (Node.js 18+)

## Installation

```bash
cd converters/
npm install
```

## API Usage

### ES Module Import

```javascript
import {
  jsonToToon,
  toonToJson,
  componentsToToon,
  dependencyGraphToToon,
  edgesToToon,
  calculateTokenSavings,
  validateToon,
  roundTripTest
} from './toon-converter.mjs';
```

### Generic Conversion

```javascript
// JSON → TOON
const toonString = jsonToToon({ components: [...] });

// TOON → JSON
const jsonObj = toonToJson(toonString);
```

### Specialized Converters

```javascript
// Components
const components = [
  {
    id: 'proxy-mgmt',
    name: 'Proxy Management',
    type: 'module',
    path: 'iclaude.sh:1343-1666',
    description: 'Handle proxy config',
    layer: 'infrastructure'
  }
];
const toon = componentsToToon(components);
// Output: components[1]{id,name,type,path,description,layer}:
//   proxy-mgmt,Proxy Management,module,"iclaude.sh:1343-1666",Handle proxy config,infrastructure

// Dependency Graph
const nodes = [
  { id: 'a', label: 'Component A', type: 'component', layer: 'business' }
];
const edges = [
  { from: 'a', to: 'b', type: 'required', description: 'Uses B' }
];
const graphToon = dependencyGraphToToon(nodes, edges);
```

### Validation

```javascript
// Validate TOON string
const validation = validateToon(toonString);
if (!validation.valid) {
  console.error('Invalid TOON:', validation.error);
}

// Round-trip test
const result = roundTripTest(jsonObj);
console.log(result.success ? 'Lossless!' : 'Failed!');
```

### Token Savings

```javascript
const stats = calculateTokenSavings(jsonObj);
console.log(`JSON: ${stats.jsonTokens} tokens`);
console.log(`TOON: ${stats.toonTokens} tokens`);
console.log(`Saved: ${stats.savedPercent}`);
```

## CLI Usage

```bash
# JSON → TOON
node toon-converter.mjs encode ../examples/components.json

# TOON → JSON
node toon-converter.mjs decode ../examples/components.toon

# Round-trip test
node toon-converter.mjs test ../examples/components.json
# Output: ✓ Round-trip test passed! Lossless conversion confirmed.

# Token statistics
node toon-converter.mjs stats ../examples/components.json
# Output:
# Token Statistics:
#   JSON: ~202 tokens (808 bytes)
#   TOON: ~123 tokens (491 bytes)
#   Saved: ~79 tokens (-39.1%)
```

## API Reference

### `jsonToToon(jsonObj, options?)`

Convert JSON object to TOON string.

**Parameters:**
- `jsonObj` (Object): JSON object to convert
- `options` (Object, optional):
  - `delimiter` (string): Delimiter for arrays (',' | '\t' | '|'). Default: ','
  - `indent` (number): Indentation size. Default: 2

**Returns:** (string) TOON formatted string

**Example:**
```javascript
const toon = jsonToToon({ components: [...] }, { delimiter: '\t' });
```

---

### `toonToJson(toonString, options?)`

Convert TOON string to JSON object.

**Parameters:**
- `toonString` (string): TOON formatted string
- `options` (Object, optional):
  - `strict` (boolean): Enable strict mode. Default: true

**Returns:** (Object) Parsed JSON object

**Example:**
```javascript
const json = toonToJson('components[1]{id,name}:\n  foo,Foo');
// Returns: { components: [{ id: 'foo', name: 'Foo' }] }
```

---

### `componentsToToon(components)`

Convert components array to TOON tabular format.

**Parameters:**
- `components` (Array): Array of component objects
  - `id` (string): Component ID (kebab-case)
  - `name` (string): Component name
  - `type` (string): Component type (module, class, function, etc.)
  - `path` (string): File path or location
  - `description` (string): Component description
  - `layer` (string): Architectural layer

**Returns:** (string) TOON formatted components table

**Example:**
```javascript
const toon = componentsToToon([
  {
    id: 'proxy-mgmt',
    name: 'Proxy Management',
    type: 'module',
    path: 'iclaude.sh:100-200',
    description: 'Handle proxy config',
    layer: 'infrastructure'
  }
]);
```

---

### `dependencyGraphToToon(nodes, edges)`

Convert dependency graph (nodes + edges) to TOON format.

**Parameters:**
- `nodes` (Array): Array of node objects
  - `id` (string): Node ID
  - `label` (string): Node label
  - `type` (string): Node type
  - `layer` (string): Architectural layer
- `edges` (Array): Array of edge objects
  - `from` (string): Source node ID
  - `to` (string): Target node ID
  - `type` (string): Edge type (required, optional, dev)
  - `description` (string): Edge description

**Returns:** (string) TOON formatted dependency graph

**Example:**
```javascript
const toon = dependencyGraphToToon(
  [{ id: 'a', label: 'A', type: 'component', layer: 'business' }],
  [{ from: 'a', to: 'b', type: 'required', description: 'Uses B' }]
);
```

---

### `edgesToToon(edges)`

Convert edges array to TOON tabular format.

**Parameters:**
- `edges` (Array): Array of edge objects (same schema as `dependencyGraphToToon`)

**Returns:** (string) TOON formatted edges table

---

### `calculateTokenSavings(jsonObj)`

Calculate token savings between JSON and TOON formats.

**Parameters:**
- `jsonObj` (Object): JSON object to compare

**Returns:** (Object) Token statistics
- `jsonTokens` (number): Estimated JSON tokens (~4 chars/token)
- `toonTokens` (number): Estimated TOON tokens
- `savedTokens` (number): Absolute token savings
- `savedPercent` (string): Percentage savings (formatted, e.g. "39.1%")
- `jsonSize` (number): JSON byte size
- `toonSize` (number): TOON byte size

**Example:**
```javascript
const stats = calculateTokenSavings({ components: [...] });
console.log(`Saved ${stats.savedPercent} tokens`);
```

---

### `validateToon(toonString)`

Validate TOON string for correctness.

**Parameters:**
- `toonString` (string): TOON string to validate

**Returns:** (Object) Validation result
- `valid` (boolean): Whether TOON is valid
- `error` (string): Error message if invalid

**Example:**
```javascript
const result = validateToon('components[1]{id,name}:\n  foo,Foo');
if (!result.valid) console.error(result.error);
```

---

### `roundTripTest(jsonObj)`

Round-trip test: JSON → TOON → JSON

**Parameters:**
- `jsonObj` (Object): JSON object to test

**Returns:** (Object) Test result
- `success` (boolean): Whether round-trip succeeded
- `error` (string): Error message if failed
- `original` (Object): Original JSON (if success)
- `roundtrip` (Object): Round-trip JSON (if success)

**Example:**
```javascript
const result = roundTripTest({ components: [...] });
console.log(result.success ? 'Lossless!' : 'Failed: ' + result.error);
```

---

## Token Savings Benchmarks

| Data Type | JSON Tokens | TOON Tokens | Savings |
|-----------|-------------|-------------|---------|
| Components (3 items) | 202 | 123 | 39.1% |
| Dependency Graph | 223 | 114 | 48.9% |
| Data Flow (5 steps) | ~180 | ~95 | 47.2% |
| Quality Attributes (5 items) | ~150 | ~85 | 43.3% |

## Troubleshooting

### Error: "Cannot find module '@toon-format/toon'"

Run `npm install` in converters/ directory.

### Error: "ERR_REQUIRE_ESM"

Use ES Module import, not CommonJS require():
```javascript
// ✅ Correct
import { jsonToToon } from './toon-converter.mjs';

// ❌ Wrong
const { jsonToToon } = require('./toon-converter.mjs');
```

### Round-trip test failed

Check:
1. Array length matches schema: `components[3]{...}:` must have exactly 3 rows
2. Special characters escaped: use quotes for values with commas
3. Consistent field order

## License

MIT (same as @toon-format/toon)

## Further Reading

- [TOON Integration Guide](../examples/TOON-INTEGRATION-GUIDE.md)
- [TOON Format Website](https://toonformat.dev)
- [@toon-format/toon on NPM](https://www.npmjs.com/package/@toon-format/toon)
