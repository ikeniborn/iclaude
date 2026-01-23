# TOON Integration Guide for Architecture Documentation

## Table of Contents

- [What is TOON?](#what-is-toon)
- [Why Use TOON?](#why-use-toon)
- [Token Savings Benchmarks](#token-savings-benchmarks)
- [How to Read TOON Format](#how-to-read-toon-format)
- [Conversion Examples](#conversion-examples)
- [Best Practices](#best-practices)
- [Integration with architecture-documentation Skill](#integration-with-architecture-documentation-skill)
- [Troubleshooting](#troubleshooting)

---

## What is TOON?

**TOON (Token-Oriented Object Notation)** is a compact, human-readable data format designed specifically for LLM prompts and inter-agent communication. It combines the best features of YAML (indentation-based structure), CSV (tabular data), and JSON (data model) while achieving 30-60% token reduction compared to JSON.

### Key Characteristics

- **Schema-aware**: Explicit array declarations with field names: `arrayName[length]{field1,field2,...}:`
- **Tabular format**: CSV-style rows for homogeneous data (perfect for components, dependencies, edges)
- **Lossless conversion**: Round-trip TOON ↔ JSON preserves all data
- **Human-readable**: Easier to parse than JSON for both humans and LLMs

### Official Resources

- Website: [toonformat.dev](https://toonformat.dev)
- NPM Package: [@toon-format/toon](https://www.npmjs.com/package/@toon-format/toon)
- Specification: [TOON Format Spec](https://toonformat.dev/spec)

---

## Why Use TOON?

### Advantages for Architecture Documentation

#### 1. **Token Efficiency (30-60% savings)**

**Real benchmarks from this skill:**
- Components: **39.1% savings** (202 → 123 tokens)
- Dependency Graph: **48.9% savings** (223 → 114 tokens)

**Impact:**
- More data fits in context window
- Reduced API costs
- Faster LLM processing

#### 2. **Improved Parsing Accuracy**

Research shows TOON achieves **73.9% parsing accuracy** vs JSON **69.7%** (GPT-4 benchmarks).

**Why?**
- Explicit schema declarations help LLMs validate structure
- Array length constraints prevent hallucinations
- Consistent tabular format reduces parsing errors

#### 3. **Ideal for Tabular Data**

Architecture documentation contains many tabular structures:
- Components (id, name, type, path, description, layer)
- Dependency edges (from, to, type, description)
- Quality attributes (attribute, target, measurement, status)
- Data flow steps (step_number, component, action, data_in, data_out)

CSV-style TOON is perfect for these use cases.

#### 4. **Human-Readable**

Despite being compact, TOON is easier to read than dense JSON:

**JSON (verbose):**
```json
{
  "components": [
    { "id": "proxy-mgmt", "name": "Proxy Management", "type": "module" }
  ]
}
```

**TOON (concise):**
```
components[1]{id,name,type}:
  proxy-mgmt,Proxy Management,module
```

### When NOT to Use TOON

**Use YAML/JSON for:**
- Deeply nested structures (> 3 levels)
- Human-facing files in git (better tooling support)
- Configuration files requiring syntax validation
- Data with irregular/heterogeneous structure

**Use TOON for:**
- Structured output between skills (internal communication)
- Tabular data with consistent schema
- Large datasets where token savings matter
- LLM-to-LLM data exchange

---

## Token Savings Benchmarks

### Components Example

**JSON format (202 tokens, 808 bytes):**
```json
{
  "components": [
    {
      "id": "proxy-management",
      "name": "Proxy Management",
      "type": "module",
      "path": "iclaude.sh:1343-1666",
      "description": "Handle proxy URL validation, credential storage, and environment configuration",
      "layer": "infrastructure"
    },
    {
      "id": "isolated-environment",
      "name": "Isolated Environment",
      "type": "module",
      "path": "iclaude.sh:361-978",
      "description": "Manage portable NVM+Node.js+Claude installation",
      "layer": "infrastructure"
    },
    {
      "id": "version-management",
      "name": "Version Management",
      "type": "module",
      "path": "iclaude.sh:616-768",
      "description": "Track and reproduce exact versions of Node.js, npm, and Claude Code",
      "layer": "data"
    }
  ]
}
```

**TOON format (123 tokens, 491 bytes):**
```
components[3]{id,name,type,path,description,layer}:
  proxy-management,Proxy Management,module,"iclaude.sh:1343-1666","Handle proxy URL validation, credential storage, and environment configuration",infrastructure
  isolated-environment,Isolated Environment,module,"iclaude.sh:361-978",Manage portable NVM+Node.js+Claude installation,infrastructure
  version-management,Version Management,module,"iclaude.sh:616-768","Track and reproduce exact versions of Node.js, npm, and Claude Code",data
```

**Savings: 79 tokens (-39.1%)**

### Dependency Graph Example

**JSON format (223 tokens, 890 bytes):**
```json
{
  "dependency_graph": {
    "nodes": [
      { "id": "proxy-management", "label": "Proxy Management", "type": "component", "layer": "infrastructure" },
      { "id": "isolated-environment", "label": "Isolated Environment", "type": "component", "layer": "infrastructure" },
      { "id": "version-management", "label": "Version Management", "type": "component", "layer": "data" }
    ],
    "edges": [
      { "from": "isolated-environment", "to": "version-management", "type": "required", "description": "Uses lockfile for version tracking" },
      { "from": "isolated-environment", "to": "proxy-management", "type": "optional", "description": "Configures proxy if credentials exist" }
    ]
  }
}
```

**TOON format (114 tokens, 456 bytes):**
```
dependency_graph:
  nodes[3]{id,label,type,layer}:
    proxy-management,Proxy Management,component,infrastructure
    isolated-environment,Isolated Environment,component,infrastructure
    version-management,Version Management,component,data
  edges[2]{from,to,type,description}:
    isolated-environment,version-management,required,Uses lockfile for version tracking
    isolated-environment,proxy-management,optional,Configures proxy if credentials exist
```

**Savings: 109 tokens (-48.9%)**

---

## How to Read TOON Format

### Schema Declaration

```
arrayName[length]{field1,field2,field3}:
```

- `arrayName`: Identifies the array
- `[length]`: Number of items (validates consistency)
- `{field1,field2,...}`: Column names (schema)
- `:` Starts tabular data

### Tabular Data Rows

```
  value1,value2,value3
  value4,value5,value6
```

- Each row represents one array item
- Values separated by commas (CSV-style)
- Quoted strings for values with commas/spaces: `"value with, comma"`
- Indentation shows nesting level

### Nested Objects

```
parent:
  childArray[2]{id,name}:
    1,Alice
    2,Bob
```

- Parent object uses `:` without schema
- Child arrays follow same tabular format
- Indentation shows hierarchy

### Example Walkthrough

```
dependency_graph:
  nodes[3]{id,label,type,layer}:
    proxy-management,Proxy Management,component,infrastructure
    isolated-environment,Isolated Environment,component,infrastructure
    version-management,Version Management,component,data
  edges[2]{from,to,type,description}:
    isolated-environment,version-management,required,Uses lockfile for version tracking
    isolated-environment,proxy-management,optional,Configures proxy if credentials exist
```

**Reading this:**
1. `dependency_graph:` - root object
2. `nodes[3]{id,label,type,layer}:` - array "nodes" with 3 items, 4 fields each
3. Next 3 indented lines - node data rows
4. `edges[2]{from,to,type,description}:` - array "edges" with 2 items, 4 fields each
5. Next 2 indented lines - edge data rows

**Equivalent JSON:**
```json
{
  "dependency_graph": {
    "nodes": [
      { "id": "proxy-management", "label": "Proxy Management", "type": "component", "layer": "infrastructure" },
      { "id": "isolated-environment", "label": "Isolated Environment", "type": "component", "layer": "infrastructure" },
      { "id": "version-management", "label": "Version Management", "type": "component", "layer": "data" }
    ],
    "edges": [
      { "from": "isolated-environment", "to": "version-management", "type": "required", "description": "Uses lockfile for version tracking" },
      { "from": "isolated-environment", "to": "proxy-management", "type": "optional", "description": "Configures proxy if credentials exist" }
    ]
  }
}
```

---

## Conversion Examples

### Using TOON Converter (Node.js API)

```javascript
import { jsonToToon, toonToJson, calculateTokenSavings } from './converters/toon-converter.mjs';

// JSON → TOON
const components = {
  components: [
    { id: 'foo', name: 'Foo', type: 'module', path: 'foo.js', description: 'Foo module', layer: 'business' }
  ]
};

const toonString = jsonToToon(components);
console.log(toonString);
// Output:
// components[1]{id,name,type,path,description,layer}:
//   foo,Foo,module,foo.js,Foo module,business

// TOON → JSON
const jsonObj = toonToJson(toonString);
console.log(JSON.stringify(jsonObj, null, 2));

// Calculate token savings
const stats = calculateTokenSavings(components);
console.log(`Saved ${stats.savedPercent} tokens`);
// Output: Saved 35.2% tokens
```

### Using TOON Converter (CLI)

```bash
# JSON → TOON
node converters/toon-converter.mjs encode examples/components.json

# TOON → JSON
node converters/toon-converter.mjs decode examples/components.toon

# Round-trip test
node converters/toon-converter.mjs test examples/components.json
# Output: ✓ Round-trip test passed! Lossless conversion confirmed.

# Token statistics
node converters/toon-converter.mjs stats examples/components.json
# Output:
# Token Statistics:
#   JSON: ~202 tokens (808 bytes)
#   TOON: ~123 tokens (491 bytes)
#   Saved: ~79 tokens (-39.1%)
```

### Using Official TOON CLI

```bash
# Install TOON CLI
npm install -g @toon-format/cli

# Encode JSON to TOON
toon --encode --stats input.json -o output.toon

# Decode TOON to JSON
toon --decode input.toon -o output.json
```

---

## Best Practices

### When to Use TOON

✅ **DO use TOON for:**
- Components lists (id, name, type, path, description, layer)
- Dependency graphs (nodes and edges)
- Data flow steps
- Quality attributes
- Structured output between skills (internal communication)
- Large datasets with consistent schema

❌ **DON'T use TOON for:**
- Deeply nested metadata objects
- Human-facing files in git commits (use YAML for better tooling)
- Irregular/heterogeneous data
- Configuration files requiring IDE validation
- Small objects (< 5 fields, < 10 items) where savings are minimal

### Hybrid Architecture (Recommended)

**Internal Communication (skill → skill):** Use TOON
- Store TOON in structured output JSON: `"components_toon": "components[5]{...}:\n..."`
- Token-efficient data passing

**Human-Facing Files (git commits):** Use YAML/Markdown
- `/docs/architecture/overview.yaml` - YAML for git diffs
- `/docs/architecture/diagrams/dependency-graph.md` - Mermaid for visualization
- `.internal/components.toon` - Optional TOON cache (not in git)

### Validation Best Practices

1. **Always validate TOON before usage:**
   ```javascript
   import { validateToon, roundTripTest } from './converters/toon-converter.mjs';

   const result = validateToon(toonString);
   if (!result.valid) {
     console.error('Invalid TOON:', result.error);
   }

   // Or test round-trip
   const testResult = roundTripTest(jsonObj);
   console.log(testResult.success ? 'Lossless!' : 'Failed!');
   ```

2. **Check array lengths:**
   TOON schema declares array length: `components[15]{...}:`. If actual rows ≠ 15, conversion will fail.

3. **Escape special characters:**
   Values with commas/newlines require quotes: `"value with, comma"`

### Token Savings Calculation

Use `calculateTokenSavings()` to verify savings:

```javascript
const stats = calculateTokenSavings(yourJsonObj);
console.log(`JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`);
console.log(`Saved: ${stats.savedTokens} tokens (${stats.savedPercent})`);
```

**Expected savings:**
- Simple lists (< 5 fields): 20-30%
- Components/edges (5-7 fields): 35-45%
- Nested graphs (nodes + edges): 40-50%
- Large datasets (100+ rows): 50-60%

---

## Integration with architecture-documentation Skill

### Dual-Format Generation

The `architecture-documentation` skill generates **both YAML and TOON** outputs:

**Step 6: Generate YAML documentation** (existing)
- Fill `templates/architecture-full.yaml`
- Write `/docs/architecture/overview.yaml`

**Step 6b: Generate TOON documentation** (NEW)
- Fill `templates/toon/components.toon.template`
- Fill `templates/toon/dependency-graph.toon.template`
- Convert components/edges to TOON
- **Option 1:** Embed in structured output (recommended)
- **Option 2:** Write to `.internal/*.toon` files

**Step 7: Validate both outputs**
- YAML validation via JSON Schema
- TOON validation via round-trip test

### Structured Output Format

```json
{
  "architecture_documentation": {
    "status": "success",
    "formats": {
      "yaml": {
        "files_created": ["overview.yaml", "diagrams/dependency-graph.md"],
        "output_directory": "/docs/architecture"
      },
      "toon": {
        "components_toon": "components[15]{id,name,type,path,description,layer}:\n  proxy-mgmt,Proxy Management,...",
        "dependency_graph_toon": "dependency_graph:\n  nodes[15]{...}:\n    ...\n  edges[42]{...}:\n    ...",
        "token_savings": "42%",
        "size_comparison": "YAML: 8542 tokens, TOON: 4951 tokens"
      }
    },
    "component_count": 15,
    "dependency_count": 42,
    "detected_patterns": ["layered"]
  }
}
```

### Using TOON Output in Downstream Skills

**Example: validation-framework consumes TOON output**

```javascript
// Previous skill output (architecture-documentation)
const architectureOutput = {
  formats: {
    toon: {
      components_toon: "components[15]{id,name,type,path,description,layer}:\n  ...",
      dependency_graph_toon: "dependency_graph:\n  nodes[15]{...}:\n  ..."
    }
  }
};

// Downstream skill (validation-framework)
import { toonToJson } from '../architecture-documentation/converters/toon-converter.mjs';

const components = toonToJson(architectureOutput.formats.toon.components_toon);
console.log(components.components.length); // 15

// Validate architecture quality
const circularDeps = detectCircularDependencies(components);
```

---

## Troubleshooting

### Error: "Cannot find module '@toon-format/toon'"

**Solution:**
```bash
# Install TOON library globally
npm install -g @toon-format/toon @toon-format/cli

# Or install locally in converters/
cd .claude-isolated/skills/architecture-documentation/converters
npm install
```

### Error: "ERR_REQUIRE_ESM: require() of ES Module not supported"

**Solution:** TOON is an ES Module. Use:
```javascript
// ✅ Correct (ES Module)
import { encode, decode } from '@toon-format/toon';

// ❌ Wrong (CommonJS)
const { encode, decode } = require('@toon-format/toon');
```

### Error: "Round-trip test failed"

**Causes:**
1. Mismatched array length in schema: `components[3]{...}:` but only 2 rows
2. Unescaped special characters: use quotes for commas/newlines
3. Inconsistent field order

**Solution:**
```javascript
import { roundTripTest } from './converters/toon-converter.mjs';

const result = roundTripTest(yourJson);
if (!result.success) {
  console.error('Original:', result.original);
  console.error('Roundtrip:', result.roundtrip);
  console.error('Error:', result.error);
}
```

### TOON Output Looks Wrong

**Validate TOON string:**
```bash
# Use official CLI to validate
echo "components[1]{id,name}:\n  foo,Foo" | toon --decode --stats
```

**Or use converter:**
```javascript
import { validateToon } from './converters/toon-converter.mjs';

const result = validateToon(toonString);
if (!result.valid) {
  console.error('Invalid TOON:', result.error);
}
```

### Token Savings Less Than Expected

**Expected savings by data type:**
- Simple objects (< 5 fields): 20-30%
- Tabular data (5-7 fields): 35-45%
- Nested structures: 40-50%

**If savings < 20%:**
1. Data too nested (TOON optimized for tabular)
2. Too few rows (< 5 items)
3. Irregular schema (mixed field types)

**Solution:** Use YAML/JSON for deeply nested or irregular data.

---

## Further Reading

- **TOON Format Specification:** [toonformat.dev/spec](https://toonformat.dev/spec)
- **NPM Package Documentation:** [@toon-format/toon](https://www.npmjs.com/package/@toon-format/toon)
- **Research Paper:** "Token-Efficient Data Formats for LLM Prompts" (toonformat.dev/research)
- **Converter Source Code:** `converters/toon-converter.mjs`
- **Examples:** `examples/toon/*.toon.example`

---

## License

TOON Format: MIT License
This guide: Part of iclaude project (see project LICENSE)

---

**Created:** 2026-01-23
**Version:** 1.0.0
**Author:** Claude Code (architecture-documentation skill v1.1.0)
