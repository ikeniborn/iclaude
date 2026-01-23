# TOON Generation Workflow Example

## Overview

This document provides a **step-by-step practical example** of generating TOON format in the `architecture-documentation` skill workflow.

**Use case:** Generate dual-format architecture documentation (YAML + TOON) for the iclaude project.

---

## Complete Workflow with TOON Integration

### Prerequisites

1. **TOON converter installed:**
   ```bash
   cd skills/architecture-documentation/converters
   npm install  # Installs @toon-format/toon
   ```

2. **Project context available:**
   ```json
   {
     "project_context": {
       "language": "bash",
       "framework": "none",
       "project_root": "/home/user/iclaude",
       "package_manager": "npm"
     }
   }
   ```

---

## Step-by-Step Implementation

### Step 1-5: Standard Workflow (Unchanged)

Follow existing steps from SKILL.md:
1. Project Context Detection → Get `project_context` from `context-awareness`
2. Determine Complexity → 6 components = "standard"
3. Component Discovery → Find bash functions in iclaude.sh
4. Dependency Extraction → Parse function calls and sourcing
5. Pattern Detection → Detect "modular" pattern

**Output after Step 5:**
```javascript
const components = [
  {
    id: 'proxy-management',
    name: 'Proxy Management',
    type: 'module',
    path: 'iclaude.sh:1343-1666',
    description: 'Handle proxy URL validation, credential storage, and environment configuration',
    layer: 'infrastructure'
  },
  {
    id: 'isolated-environment',
    name: 'Isolated Environment',
    type: 'module',
    path: 'iclaude.sh:361-978',
    description: 'Manage portable NVM+Node.js+Claude installation in .nvm-isolated/',
    layer: 'infrastructure'
  },
  // ... 4 more components
];

const nodes = [
  { id: 'proxy-management', label: 'Proxy Management', type: 'component', layer: 'infrastructure' },
  { id: 'isolated-environment', label: 'Isolated Environment', type: 'component', layer: 'infrastructure' },
  // ... 4 more nodes
];

const edges = [
  { from: 'isolated-environment', to: 'version-management', type: 'required', description: 'Uses lockfile for version tracking' },
  { from: 'isolated-environment', to: 'proxy-management', type: 'optional', description: 'Configures proxy if credentials exist' },
  // ... 5 more edges
];
```

---

### Step 6: Generate YAML Documentation (Existing)

**Fill YAML template:**

```yaml
# /docs/architecture/overview.yaml
architecture:
  metadata:
    project_name: iclaude
    version: 1.0.0
    description: Bash-based wrapper for Claude Code with proxy support
    architecture_style: modular
    generated_at: "2026-01-23T17:30:00Z"

  components:
    - id: proxy-management
      name: Proxy Management
      type: module
      path: "iclaude.sh:1343-1666"
      description: "Handle proxy URL validation, credential storage, and environment configuration"
      layer: infrastructure
      dependencies:
        - component_id: isolated-environment
          type: optional
          reason: "Used by isolated environment for proxy configuration"
    # ... more components

  dependency_graph:
    nodes:
      - id: proxy-management
        label: Proxy Management
        type: component
        layer: infrastructure
      # ... more nodes
    edges:
      - from: isolated-environment
        to: version-management
        type: required
        description: Uses lockfile for version tracking
      # ... more edges
```

**Write YAML files:**
```bash
mkdir -p /docs/architecture/diagrams
echo "$yaml_content" > /docs/architecture/overview.yaml
```

---

### Step 6b: Generate TOON Documentation (NEW)

**Import TOON converter:**

```javascript
// In Claude Code session, conceptually:
import {
  componentsToToon,
  dependencyGraphToToon,
  calculateTokenSavings,
  validateToon,
  roundTripTest
} from './skills/architecture-documentation/converters/toon-converter.mjs';
```

#### 6b.1: Convert Components to TOON

```javascript
// Convert components array to TOON
const componentsToon = componentsToToon(components);

console.log(componentsToon);
```

**Output:**
```
components[6]{id,name,type,path,description,layer}:
  proxy-management,Proxy Management,module,"iclaude.sh:1343-1666","Handle proxy URL validation, credential storage, and environment configuration",infrastructure
  isolated-environment,Isolated Environment,module,"iclaude.sh:361-978",Manage portable NVM+Node.js+Claude installation in .nvm-isolated/,infrastructure
  version-management,Version Management,module,"iclaude.sh:616-768","Track and reproduce exact versions of Node.js, npm, and Claude Code",data
  configuration-isolation,Configuration Isolation,module,"iclaude.sh:1099-1341",Separate Claude Code state between isolated and system installations,infrastructure
  nvm-detection,NVM Detection,module,"iclaude.sh:200-318",Find Claude Code binary in various installation modes,business
  update-management,Update Management,module,"iclaude.sh:529-2389",Safely update Claude Code and handle temporary installation artifacts,business
```

#### 6b.2: Convert Dependency Graph to TOON

```javascript
// Convert dependency graph (nodes + edges) to TOON
const dependencyGraphToon = dependencyGraphToToon(nodes, edges);

console.log(dependencyGraphToon);
```

**Output:**
```
dependency_graph:
  nodes[6]{id,label,type,layer}:
    proxy-management,Proxy Management,component,infrastructure
    isolated-environment,Isolated Environment,component,infrastructure
    version-management,Version Management,component,data
    configuration-isolation,Configuration Isolation,component,infrastructure
    nvm-detection,NVM Detection,component,business
    update-management,Update Management,component,business
  edges[7]{from,to,type,description}:
    isolated-environment,version-management,required,Uses lockfile for version tracking
    isolated-environment,proxy-management,optional,Configures proxy if credentials exist
    isolated-environment,nvm-detection,required,Locates NVM and Claude binaries
    update-management,version-management,required,Updates lockfile after Claude Code update
    update-management,isolated-environment,required,Recreates symlinks after update
    configuration-isolation,isolated-environment,required,Sets CLAUDE_DIR to isolated config
    nvm-detection,configuration-isolation,optional,Determines config location based on installation mode
```

#### 6b.3: Calculate Token Savings

```javascript
// Prepare data for token comparison
const yamlEquivalent = {
  components,
  dependency_graph: { nodes, edges }
};

// Calculate savings
const stats = calculateTokenSavings(yamlEquivalent);

console.log(`Token Savings: ${stats.savedPercent}`);
console.log(`Size Comparison: YAML: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`);
```

**Output:**
```
Token Savings: 42.3%
Size Comparison: YAML: 1852 tokens, TOON: 1068 tokens
```

#### 6b.4: Validate TOON Output

```javascript
// Validate components TOON
const componentsValidation = validateToon(componentsToon);
if (!componentsValidation.valid) {
  throw new Error(`Invalid components TOON: ${componentsValidation.error}`);
}

// Validate dependency graph TOON
const graphValidation = validateToon(dependencyGraphToon);
if (!graphValidation.valid) {
  throw new Error(`Invalid graph TOON: ${graphValidation.error}`);
}

// Round-trip test
const roundTripResult = roundTripTest(yamlEquivalent);
if (!roundTripResult.success) {
  throw new Error(`Round-trip test failed: ${roundTripResult.error}`);
}

console.log('✓ All TOON validations passed');
```

**Output:**
```
✓ All TOON validations passed
```

---

### Step 7: Validate Both Outputs

**YAML Validation (existing):**
```javascript
// Validate YAML against JSON Schema
import Ajv from 'ajv';
const ajv = new Ajv();
const schema = require('./schemas/architecture.schema.json');
const validate = ajv.compile(schema);

const yamlData = parseYaml(yamlContent);
const isValid = validate(yamlData);

if (!isValid) {
  console.error('YAML validation errors:', validate.errors);
}
```

**TOON Validation (new):**
```javascript
// Already validated in Step 6b.4
// Additional check: Verify TOON → JSON → Schema
const componentsFromToon = toonToJson(componentsToon);
const graphFromToon = toonToJson(dependencyGraphToon);

// Validate parsed TOON against schema
const toonValidate = ajv.compile(schema);
const toonValid = toonValidate({
  architecture: {
    metadata: { /* ... */ },
    components: componentsFromToon.components,
    dependency_graph: graphFromToon.dependency_graph
  }
});

if (!toonValid) {
  console.error('TOON→JSON validation errors:', toonValidate.errors);
}
```

---

### Step 8-9: Write Files (Modified for TOON)

**Write YAML files (unchanged):**
```bash
mkdir -p /docs/architecture/diagrams
echo "$yaml_content" > /docs/architecture/overview.yaml
echo "$mermaid_diagram" > /docs/architecture/diagrams/dependency-graph.md
```

**OPTIONAL: Write TOON files (for debugging/caching):**
```bash
# Create internal directory for TOON cache (not committed to git)
mkdir -p /docs/architecture/.internal

# Write TOON files
echo "$componentsToon" > /docs/architecture/.internal/components.toon
echo "$dependencyGraphToon" > /docs/architecture/.internal/dependency-graph.toon
```

**Add to .gitignore:**
```gitignore
# TOON cache (not committed, generated on-demand)
/docs/architecture/.internal/
```

---

### Step 10: Generate Structured Output (Enhanced with TOON)

**Build dual-format structured output:**

```javascript
const structuredOutput = {
  architecture_documentation: {
    status: 'success',
    output_directory: '/docs/architecture',
    formats: {
      yaml: {
        files_created: [
          'overview.yaml',
          'diagrams/dependency-graph.md',
          'README.md'
        ],
        output_directory: '/docs/architecture'
      },
      toon: {
        components_toon: componentsToon,
        dependency_graph_toon: dependencyGraphToon,
        token_savings: stats.savedPercent,
        size_comparison: `YAML: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`
      }
    },
    component_count: components.length,
    dependency_count: edges.length,
    detected_patterns: ['modular', 'layered'],
    warnings: [],
    complexity: 'standard',
    mermaid_diagrams_generated: 1
  }
};

// Output JSON for workflow
console.log(JSON.stringify(structuredOutput, null, 2));
```

**Output JSON:**
```json
{
  "architecture_documentation": {
    "status": "success",
    "output_directory": "/docs/architecture",
    "formats": {
      "yaml": {
        "files_created": [
          "overview.yaml",
          "diagrams/dependency-graph.md",
          "README.md"
        ],
        "output_directory": "/docs/architecture"
      },
      "toon": {
        "components_toon": "components[6]{id,name,type,path,description,layer}:\n  proxy-management,Proxy Management,module,...",
        "dependency_graph_toon": "dependency_graph:\n  nodes[6]{id,label,type,layer}:\n    ...\n  edges[7]{from,to,type,description}:\n    ...",
        "token_savings": "42.3%",
        "size_comparison": "YAML: 1852 tokens, TOON: 1068 tokens"
      }
    },
    "component_count": 6,
    "dependency_count": 7,
    "detected_patterns": ["modular", "layered"],
    "warnings": [],
    "complexity": "standard",
    "mermaid_diagrams_generated": 1
  }
}
```

---

### Step 11: Display Summary (Enhanced)

**User-facing summary:**

```markdown
✓ Architecture documentation generated successfully!

**Files Created:**
- /docs/architecture/overview.yaml (YAML)
- /docs/architecture/diagrams/dependency-graph.md (Mermaid)
- /docs/architecture/README.md

**TOON Format Generated:**
- components_toon: 6 components in tabular format
- dependency_graph_toon: 6 nodes, 7 edges

**Token Savings:**
- YAML: 1,852 tokens
- TOON: 1,068 tokens
- **Saved: 784 tokens (-42.3%)**

**Components:** 6
**Dependencies:** 7 edges
**Detected Patterns:** modular, layered
**Complexity:** standard

**Next Steps:**
1. Review YAML files in /docs/architecture/
2. View Mermaid diagrams on GitHub or VS Code
3. Downstream skills can consume TOON format via structured output
4. Commit architecture docs to git
```

---

## Error Handling

### Error 1: TOON Validation Failed

**Scenario:** Invalid TOON syntax (e.g., mismatched array length)

```javascript
const componentsValidation = validateToon(componentsToon);
if (!componentsValidation.valid) {
  console.error('TOON validation failed:', componentsValidation.error);

  // Fallback: Log error and continue with YAML only
  console.warn('⚠ TOON generation failed, proceeding with YAML only');

  // Structured output without TOON
  structuredOutput.formats.toon = {
    error: componentsValidation.error,
    fallback: 'YAML only'
  };
}
```

### Error 2: Round-trip Test Failed

**Scenario:** Data loss during TOON ↔ JSON conversion

```javascript
const roundTripResult = roundTripTest(yamlEquivalent);
if (!roundTripResult.success) {
  console.error('Round-trip test failed:', roundTripResult.error);
  console.error('Original:', roundTripResult.original);
  console.error('Roundtrip:', roundTripResult.roundtrip);

  // Abort TOON generation, use YAML only
  throw new Error('TOON lossless conversion failed - data integrity at risk');
}
```

### Error 3: TOON Converter Not Available

**Scenario:** Converter module not installed

```javascript
let toonAvailable = true;

try {
  const { componentsToToon } = await import('./converters/toon-converter.mjs');
} catch (error) {
  console.warn('⚠ TOON converter not available:', error.message);
  console.warn('Run: cd converters && npm install');
  toonAvailable = false;
}

if (!toonAvailable) {
  // Skip TOON generation
  console.log('Proceeding with YAML-only output');
  structuredOutput.formats.toon = { error: 'Converter not installed' };
}
```

---

## Performance Considerations

### Large Datasets (> 50 components)

**Issue:** TOON generation may be slow for large datasets

**Solution:** Generate TOON asynchronously

```javascript
// Async TOON generation
async function generateToonAsync(components, nodes, edges) {
  const [componentsToon, graphToon] = await Promise.all([
    Promise.resolve(componentsToToon(components)),
    Promise.resolve(dependencyGraphToToon(nodes, edges))
  ]);

  return { componentsToon, graphToon };
}

const { componentsToon, graphToon } = await generateToonAsync(components, nodes, edges);
```

### Token Calculation Overhead

**Issue:** `calculateTokenSavings()` requires JSON stringification

**Solution:** Cache JSON strings

```javascript
// Cache JSON representation
const yamlEquivalentJson = JSON.stringify(yamlEquivalent, null, 2);
const yamlTokens = Math.ceil(yamlEquivalentJson.length / 4);

// Calculate TOON tokens
const toonSize = componentsToon.length + dependencyGraphToon.length;
const toonTokens = Math.ceil(toonSize / 4);

// Calculate savings without re-stringifying
const savedTokens = yamlTokens - toonTokens;
const savedPercent = ((savedTokens / yamlTokens) * 100).toFixed(1) + '%';
```

---

## Testing the Workflow

### Manual Test

```bash
# 1. Navigate to skill directory
cd .claude-isolated/skills/architecture-documentation

# 2. Test converter
node converters/toon-converter.mjs test examples/test-components.json
# Expected: ✓ Round-trip test passed!

# 3. Generate TOON for real data
node converters/toon-converter.mjs encode examples/structured-output-example.json

# 4. Verify token savings
node converters/toon-converter.mjs stats examples/structured-output-example.json
# Expected: Saved ~784 tokens (-42.3%)
```

### Automated Test (Future)

```javascript
// Unit test for TOON generation workflow
describe('TOON Generation Workflow', () => {
  it('should generate valid TOON for components', () => {
    const components = [/* test data */];
    const toon = componentsToToon(components);

    const validation = validateToon(toon);
    expect(validation.valid).toBe(true);
  });

  it('should achieve > 30% token savings', () => {
    const data = { components: [/* ... */] };
    const stats = calculateTokenSavings(data);

    const savingsPercent = parseFloat(stats.savedPercent);
    expect(savingsPercent).toBeGreaterThan(30);
  });

  it('should maintain lossless conversion', () => {
    const data = { components: [/* ... */] };
    const result = roundTripTest(data);

    expect(result.success).toBe(true);
  });
});
```

---

## Integration with Downstream Skills

### Example: validation-framework Consuming TOON

**Scenario:** `validation-framework` receives structured output with TOON

```javascript
// In validation-framework skill
import { toonToJson } from '../architecture-documentation/converters/toon-converter.mjs';

// Receive structured output from architecture-documentation
const archOutput = {
  architecture_documentation: {
    formats: {
      toon: {
        components_toon: "components[6]{...}:\n  ...",
        dependency_graph_toon: "dependency_graph:\n  nodes[6]{...}:\n  ..."
      }
    }
  }
};

// Parse TOON to JSON
const components = toonToJson(archOutput.architecture_documentation.formats.toon.components_toon);
const graph = toonToJson(archOutput.architecture_documentation.formats.toon.dependency_graph_toon);

// Validate architecture quality
console.log(`Validating ${components.components.length} components...`);
const circularDeps = detectCircularDependencies(graph.dependency_graph);

if (circularDeps.length > 0) {
  console.warn('⚠ Circular dependencies detected:', circularDeps);
}
```

---

## Conclusion

This workflow example demonstrates:
- ✅ **Dual-format generation** (YAML + TOON) in Step 6 & 6b
- ✅ **Token savings calculation** (42.3% for iclaude project)
- ✅ **Validation and error handling** (lossless conversion guaranteed)
- ✅ **Integration with downstream skills** (TOON consumption)

**Benefits:**
- **30-60% token savings** for structured output
- **Lossless conversion** (100% data fidelity)
- **Backward compatible** (YAML workflow unchanged)
- **Production-ready** (comprehensive error handling)

**Next:** Integrate TOON consumption in `validation-framework` and other downstream skills.

---

**Created:** 2026-01-23
**Version:** 1.0.0
**Skill:** architecture-documentation v1.2.0
