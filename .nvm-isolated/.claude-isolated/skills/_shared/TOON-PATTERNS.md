# TOON Integration Patterns for Claude Code Skills

**Version:** 1.0.0
**Last Updated:** 2026-01-23
**Purpose:** Централизованные паттерны использования TOON формата для token-efficient structured output между skills

---

## Overview

Этот документ содержит проверенные паттерны интеграции TOON (Token-Oriented Object Notation) формата в Claude Code skills для достижения **60-75% token savings** при inter-skill коммуникации.

**Ключевые принципы:**
- ✅ JSON остаётся primary format (100% backward compatibility)
- ✅ TOON добавляется как optimization layer (opt-in)
- ✅ Threshold: генерировать TOON только для массивов >= 5 элементов
- ✅ Metrics embedded: всегда включать token_savings в output

**Кому это нужно:**
- Разработчикам новых skills
- При обновлении существующих skills
- При оптимизации token usage в workflows

---

## Pattern 1: Simple Array Conversion

**Когда использовать:** Массив >= 5 элементов с consistent schema

**Use Cases:**
- Code review warnings (15 items)
- Task execution steps (10 items)
- PR checks (8 items)
- Commit history (20 items)

**Implementation:**

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Step 1: Generate JSON output (always)
const output = {
  status: "success",
  warnings: [
    { category: 'security', file: 'app.js', line: 42, severity: 'BLOCKING', message: 'SQL injection' },
    { category: 'code_quality', file: 'db.js', line: 15, severity: 'WARNING', message: 'Missing index' },
    // ... 13 more warnings
  ]
};

// Step 2: Add TOON optimization (if >= 5 elements)
if (output.warnings.length >= 5) {
  const stats = calculateTokenSavings({ warnings: output.warnings });

  output.toon = {
    warnings_toon: arrayToToon('warnings', output.warnings,
      ['category', 'file', 'line', 'severity', 'message', 'suggestion']),
    token_savings: stats.savedPercent,
    size_comparison: `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`
  };
}

// Step 3: Return hybrid output
return output;
```

**Output Structure:**

```json
{
  "status": "success",
  "warnings": [...],  // JSON (always present)
  "toon": {           // TOON (optional, if >= 5 elements)
    "warnings_toon": "warnings[15]{category,file,line,severity,message,suggestion}:\n  security,app.js,42,BLOCKING,SQL injection,Use parameterized queries\n  ...",
    "token_savings": "59.3%",
    "size_comparison": "JSON: 450 tokens, TOON: 260 tokens"
  }
}
```

**Expected Savings:** 35-45% для 5-10 элементов, 40-60% для 10-20 элементов

---

## Pattern 2: Nested Arrays (Dependency Graph)

**Когда использовать:** Объект с несколькими массивами (nodes[], edges[])

**Use Cases:**
- Dependency graphs (nodes + edges)
- Service mesh (services + routes + health_checks)
- Test results (passed + failed + skipped)

**Implementation:**

```javascript
import { nestedToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Step 1: Generate JSON output
const output = {
  dependency_graph: {
    nodes: [
      { id: 'proxy-mgmt', label: 'Proxy Management', type: 'module', layer: 'infrastructure' },
      { id: 'oauth-handler', label: 'OAuth Handler', type: 'function', layer: 'business' },
      // ... more nodes
    ],
    edges: [
      { from: 'proxy-mgmt', to: 'oauth-handler', type: 'required', description: 'OAuth for proxies' },
      // ... more edges
    ]
  }
};

// Step 2: Add TOON optimization (if both arrays >= threshold)
const nodes = output.dependency_graph.nodes;
const edges = output.dependency_graph.edges;

if (nodes.length >= 3 && edges.length >= 3) {
  const stats = calculateTokenSavings({ dependency_graph: output.dependency_graph });

  output.toon = {
    dependency_graph_toon: nestedToToon('dependency_graph', {
      nodes: { items: nodes, fields: ['id', 'label', 'type', 'layer'] },
      edges: { items: edges, fields: ['from', 'to', 'type', 'description'] }
    }),
    token_savings: stats.savedPercent,
    size_comparison: `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`
  };
}

return output;
```

**TOON Output Example:**

```
dependency_graph:
  nodes[4]{id,label,type,layer}:
    proxy-mgmt,Proxy Management,module,infrastructure
    oauth-handler,OAuth Handler,function,business
    token-refresh,Token Refresh,function,business
    api-client,API Client,class,business
  edges[3]{from,to,type,description}:
    proxy-mgmt,oauth-handler,required,OAuth for proxies
    oauth-handler,token-refresh,required,Refresh tokens
    api-client,oauth-handler,required,API auth
```

**Expected Savings:** 45-60% для nested structures

---

## Pattern 3: Hybrid Output (JSON Primary + TOON Optimization)

**Когда использовать:** ВСЕГДА! Это базовый паттерн для всех skills с TOON support

**Why Hybrid?**
- ✅ 100% backward compatibility (JSON всегда доступен)
- ✅ Zero breaking changes (downstream skills работают без изменений)
- ✅ Opt-in optimization (TOON генерируется только когда выгодно)
- ✅ Gradual migration (можно добавлять TOON постепенно)

**Template:**

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

/**
 * Generate output with optional TOON optimization
 */
function generateOutput(data) {
  // Step 1: ALWAYS generate JSON (primary format)
  const output = {
    status: "success",
    items: data.items,  // Your actual data
    metadata: {
      generated_at: new Date().toISOString(),
      version: "1.0.0"
    }
  };

  // Step 2: Add TOON optimization (if threshold met)
  if (output.items.length >= 5) {
    const stats = calculateTokenSavings({ items: output.items });

    output.toon = {
      items_toon: arrayToToon('items', output.items, ['field1', 'field2', 'field3']),
      token_savings: stats.savedPercent,
      size_comparison: `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`
    };
  }

  // Step 3: Return hybrid output
  return output;
}
```

**Consuming Hybrid Output (Downstream Skills):**

```javascript
import { toonToJson } from '../toon-skill/converters/toon-converter.mjs';

function consumeOutput(upstreamOutput) {
  // Strategy 1: Always use JSON (safest, backward compatible)
  const items = upstreamOutput.items;

  // Strategy 2: Prefer TOON if available (token efficient)
  const items = upstreamOutput.toon?.items_toon
    ? toonToJson(upstreamOutput.toon.items_toon).items
    : upstreamOutput.items;

  // Strategy 3: Use TOON for validation only
  if (upstreamOutput.toon?.items_toon) {
    const toonItems = toonToJson(upstreamOutput.toon.items_toon).items;
    const jsonItems = upstreamOutput.items;

    // Verify consistency
    const consistent = JSON.stringify(toonItems) === JSON.stringify(jsonItems);
    console.log(`TOON ↔ JSON consistency: ${consistent ? '✓' : '✗'}`);
  }

  return items;
}
```

---

## Pattern 4: Conditional TOON (Multiple Arrays)

**Когда использовать:** Skill генерирует несколько массивов, каждый может превысить threshold

**Use Cases:**
- code-review: warnings[], lsp_diagnostics[], blocking_issues[]
- pr-automation: checks[], autoFixedErrors[], commits[]
- skill-generator: validation_results[], files_created[]

**Implementation:**

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Step 1: Generate JSON output
const output = {
  status: "success",
  warnings: [...],        // 15 elements (>= 5, convert!)
  suggestions: [...],     // 3 elements (< 5, skip)
  lsp_diagnostics: [...]  // 20 elements (>= 5, convert!)
};

// Step 2: Add TOON for each array >= threshold
const dataToConvert = {};

// warnings: 15 elements (convert)
if (output.warnings.length >= 5) {
  output.toon = output.toon || {};
  output.toon.warnings_toon = arrayToToon('warnings', output.warnings,
    ['category', 'file', 'line', 'severity', 'message', 'suggestion']);
  dataToConvert.warnings = output.warnings;
}

// suggestions: 3 elements (skip, below threshold)
// No TOON conversion

// lsp_diagnostics: 20 elements (convert)
if (output.lsp_diagnostics.length >= 5) {
  output.toon = output.toon || {};
  output.toon.lsp_diagnostics_toon = arrayToToon('lsp_diagnostics', output.lsp_diagnostics,
    ['file', 'line', 'severity', 'code', 'message']);
  dataToConvert.lsp_diagnostics = output.lsp_diagnostics;
}

// Step 3: Calculate overall savings (for converted arrays only)
if (output.toon && Object.keys(dataToConvert).length > 0) {
  const stats = calculateTokenSavings(dataToConvert);
  output.toon.token_savings = stats.savedPercent;
  output.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}

return output;
```

**Helper Function (Recommended):**

```javascript
/**
 * Add TOON optimization to output for multiple arrays
 */
function addToonOptimization(output, arrayConfigs) {
  const dataToConvert = {};

  arrayConfigs.forEach(({ arrayName, fields, threshold = 5 }) => {
    if (output[arrayName] && output[arrayName].length >= threshold) {
      output.toon = output.toon || {};
      output.toon[`${arrayName}_toon`] = arrayToToon(arrayName, output[arrayName], fields);
      dataToConvert[arrayName] = output[arrayName];
    }
  });

  if (output.toon && Object.keys(dataToConvert).length > 0) {
    const stats = calculateTokenSavings(dataToConvert);
    output.toon.token_savings = stats.savedPercent;
    output.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
  }

  return output;
}

// Usage:
addToonOptimization(output, [
  { arrayName: 'warnings', fields: ['category', 'file', 'line', 'severity', 'message'] },
  { arrayName: 'lsp_diagnostics', fields: ['file', 'line', 'severity', 'code', 'message'] }
]);
```

---

## Pattern 5: Consuming TOON (Downstream Skills)

**Когда использовать:** Skill получает output от другого skill с TOON field

**Strategies:**

### Strategy 1: Always Use JSON (Safest)

```javascript
// No changes needed, just read JSON
const items = upstreamOutput.items;
```

**Pros:** 100% backward compatible, zero code changes
**Cons:** Не используется token savings

### Strategy 2: Prefer TOON if Available

```javascript
import { toonToJson } from '../toon-skill/converters/toon-converter.mjs';

const items = upstreamOutput.toon?.items_toon
  ? toonToJson(upstreamOutput.toon.items_toon).items
  : upstreamOutput.items;
```

**Pros:** Использует token savings, fallback на JSON
**Cons:** Требует импорт toon-skill

### Strategy 3: Validate TOON ↔ JSON Consistency

```javascript
import { toonToJson, roundTripTest } from '../toon-skill/converters/toon-converter.mjs';

if (upstreamOutput.toon?.items_toon) {
  const toonItems = toonToJson(upstreamOutput.toon.items_toon).items;
  const jsonItems = upstreamOutput.items;

  // Deep equality check
  const consistent = JSON.stringify(toonItems) === JSON.stringify(jsonItems);

  if (!consistent) {
    console.error('TOON ↔ JSON mismatch detected!');
    // Use JSON as source of truth
  }
}

// Always use JSON for actual processing
const items = upstreamOutput.items;
```

**Pros:** Catches inconsistencies, uses JSON as source of truth
**Cons:** Additional overhead (validation)

**Recommendation:** Use Strategy 1 для большинства cases. Strategy 2 только если token savings критична.

---

## Best Practices

### ✅ DO

1. **Always generate JSON first** (primary format, backward compatibility)
2. **Add TOON as optional layer** (optimization, not replacement)
3. **Use threshold 5 элементов** (balance savings vs overhead)
4. **Include token_savings метрику** (показывает value)
5. **Test round-trip conversion** (ensure lossless)
6. **Document TOON support** в SKILL.md
7. **Use consistent field order** (easier to read TOON output)
8. **Handle special characters** (arrayToToon auto-quotes commas)

### ❌ DON'T

1. **Replace JSON with TOON** (breaking change!)
2. **Convert маленькие массивы** (< 5 elements, minimal savings)
3. **Use для deeply nested** (> 3 levels, poor fit)
4. **Export TOON в git** (human-facing files should be YAML/JSON)
5. **Skip metrics** (always include token_savings)
6. **Forget fallback** (downstream skills must handle missing TOON)
7. **Modify JSON structure** (keep it unchanged for compatibility)

---

## Threshold Guidelines

| Array Size | TOON Worth It? | Expected Savings | Recommendation | Use Case Examples |
|------------|----------------|------------------|----------------|-------------------|
| **< 3 elements** | ❌ No | 5-15% | Skip TOON | blocking_issues (usually 0-2) |
| **3-4 elements** | ⚠️ Maybe | 15-25% | Edge case, usually skip | Small task steps |
| **5-9 elements** | ✅ Yes | **25-35%** | **Threshold met** | execution_steps, acceptance_criteria |
| **10-19 elements** | ✅✅ Yes | **35-45%** | **High value** | warnings, checks, commits |
| **20-49 elements** | ✅✅✅ Definitely | **45-60%** | **Very high value** | LSP diagnostics, file changes |
| **50+ elements** | ✅✅✅✅ Maximum | **60-75%** | **Maximum savings** | Large datasets, logs |

**Threshold Rationale:**
- **5 элементов** - баланс между savings и overhead
- **< 5** - overhead (header, fields) не окупается savings
- **>= 5** - savings начинают существенно превышать overhead

**Exceptions:**
- Nested structures (dependency graphs): threshold может быть 3-4 элемента для каждого array
- Always-large arrays (PRD sections, diagrams): можно не проверять threshold

---

## Integration Checklist

При добавлении TOON в skill:

### ☐ Phase 1: Analysis

- [ ] Определить target arrays (какие массивы в output >= 5 элементов?)
- [ ] Определить fields для каждого массива (какие поля важны?)
- [ ] Проверить consistent schema (все элементы имеют одинаковую структуру?)
- [ ] Оценить expected savings (сколько токенов сэкономим?)

### ☐ Phase 2: Implementation

- [ ] Импортировать API: `import { arrayToToon, calculateTokenSavings } from '../toon-skill/...`
- [ ] Добавить TOON generation после JSON output
- [ ] Использовать threshold (>= 5 элементов)
- [ ] Включить token_savings метрику
- [ ] Обработать special characters (quotes, commas)

### ☐ Phase 3: Schema & Docs

- [ ] Обновить JSON Schema с `toon` field (`$ref: "_shared/base-schema.json#/definitions/toon_optimization"`)
- [ ] Обновить SKILL.md с "TOON Format Support" секцией
- [ ] Добавить examples/toon-output.example
- [ ] Документировать threshold и expected savings

### ☐ Phase 4: Testing

- [ ] Написать unit tests для TOON generation
- [ ] Проверить round-trip conversion (lossless?)
- [ ] Измерить actual token savings (>= expected?)
- [ ] Протестировать backward compatibility (старые consumers работают?)
- [ ] Проверить edge cases (empty arrays, null values, special characters)

### ☐ Phase 5: Deployment

- [ ] Version bump (minor: X.Y.0 для backward compatible feature)
- [ ] Update CHANGELOG (если есть)
- [ ] Commit с описанием TOON integration
- [ ] Обновить skills README.md status matrix

---

## Skills с TOON Support

### Completed ✅

| Skill | Version | Arrays Converted | Token Savings | Status |
|-------|---------|------------------|---------------|--------|
| **toon-skill** | 1.0.0 | - (base skill) | - | ✅ Complete |
| **architecture-documentation** | 1.2.0 | components, dependency_graph | 42% | ✅ Complete |
| **validation-framework** | 2.1.0 | (consumer only) | N/A | ✅ Complete |

### Planned 🔄

| Skill | Priority | Arrays | Expected Savings | ETA |
|-------|----------|--------|------------------|-----|
| **code-review** | HIGH | warnings, lsp_diagnostics | 40-50% | Phase 1 |
| **structured-planning** | HIGH | execution_steps, files_to_change | 35-45% | Phase 1 |
| **pr-automation** | HIGH | checks, autoFixedErrors, commits | 35-45% | Phase 1 |
| **skill-generator** | HIGH | validation_results, files_created | 40-50% | Phase 1 |
| **prd-generator** | HIGH | sections, diagrams, features | 45-55% | Phase 1 |
| **phase-execution** | MEDIUM | checkpoint_validation_steps | 25-35% | Phase 4 |
| **adaptive-workflow** | MEDIUM | complexity_factors, phase_recommendations | 20-30% | Phase 4 |
| **git-workflow** | MEDIUM | commit_history, validation_checks | 20-30% | Phase 4 |

### Not Applicable ❌

| Skill | Reason |
|-------|--------|
| context-awareness | No arrays (returns single object) |
| error-handling | Arrays typically < 5 elements |
| isolated-environment | No structured output |
| proxy-management | No arrays |

---

## Troubleshooting

### Q: TOON не генерируется, хотя массив >= 5 элементов

**A:** Проверьте consistent schema:

```javascript
// ❌ Bad: inconsistent schema
const items = [
  { id: 1, name: 'Alice' },
  { id: 2, name: 'Bob', age: 30 }  // 'age' only in second item
];

// ✅ Good: consistent schema
const items = [
  { id: 1, name: 'Alice', age: null },
  { id: 2, name: 'Bob', age: 30 }
];
```

### Q: Token savings меньше ожидаемых

**A:** Возможные причины:
- Массив слишком маленький (< 10 элементов) - savings 25-35% вместо 40-60%
- Много nested objects - TOON лучше работает с flat structures
- Длинные значения с запятыми - требуют quoting

**Решение:** TOON наиболее эффективен для >= 10 элементов, табличных структур.

### Q: Ошибка при конвертации обратно в JSON

**A:** Используйте `validateToon()` для проверки синтаксиса:

```javascript
import { validateToon } from '../toon-skill/converters/toon-converter.mjs';

const result = validateToon(toonString);
if (!result.valid) {
  console.error('Invalid TOON:', result.error);
  // Fallback to JSON
}
```

### Q: Как обрабатывать values с запятыми?

**A:** `arrayToToon()` автоматически quotes значения с запятыми:

```javascript
const items = [
  { file: 'app.js', message: 'Error: invalid input, check validation' }
];

const toon = arrayToToon('items', items, ['file', 'message']);
// Output: items[1]{file,message}:
//   app.js,"Error: invalid input, check validation"
```

### Q: Нужно ли обновлять JSON Schema?

**A:** Да, добавьте optional `toon` field:

```json
{
  "type": "object",
  "properties": {
    "status": { "enum": ["success", "failed"] },
    "warnings": { "type": "array" },
    "toon": {
      "$ref": "../_shared/base-schema.json#/definitions/toon_optimization"
    }
  },
  "required": ["status", "warnings"]
}
```

### Q: Как обрабатывать ошибки конвертации?

**A:** Используйте try-catch с fallback на JSON:

```javascript
try {
  output.toon = {
    items_toon: arrayToToon('items', output.items, fields),
    token_savings: calculateTokenSavings({ items: output.items }).savedPercent
  };
} catch (error) {
  console.warn(`TOON generation failed: ${error.message}`);
  // Fallback: JSON only (no TOON)
  // output.toon остаётся undefined
}
```

### Q: Downstream skill не понимает TOON format

**A:** Это нормально! TOON - opt-in optimization. Downstream skills могут:
1. Игнорировать TOON и читать JSON (Strategy 1)
2. Опционально использовать TOON если доступен (Strategy 2)
3. Не требует изменений в existing consumers

---

## Token Savings Calculator

Быстрая оценка token savings для вашего массива:

```javascript
import { calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

const yourArray = [
  // ... your data
];

const stats = calculateTokenSavings({ items: yourArray });

console.log(`Array size: ${yourArray.length} elements`);
console.log(`JSON: ${stats.jsonTokens} tokens (${stats.jsonSize} bytes)`);
console.log(`TOON: ${stats.toonTokens} tokens (${stats.toonSize} bytes)`);
console.log(`Saved: ${stats.savedTokens} tokens (${stats.savedPercent})`);

if (yourArray.length < 5) {
  console.log('⚠️ Array too small, TOON not recommended (overhead > savings)');
} else if (parseFloat(stats.savedPercent) >= 40) {
  console.log('✅ Excellent candidate for TOON!');
} else {
  console.log('✅ Good candidate for TOON');
}
```

---

## References

### Documentation

- **toon-skill/SKILL.md** - Базовый навык с полной документацией
- **toon-skill/converters/README.md** - API reference
- **toon-skill/examples/integration-guide.md** - Пошаговое руководство
- **_shared/base-schema.json** - JSON Schema definitions

### Examples

- **toon-skill/examples/array-conversion.example** - 6 примеров конвертации массивов
- **toon-skill/examples/nested-objects.example** - 4 примера nested structures
- **toon-skill/examples/hybrid-output.example** - Полный пример hybrid pattern

### External Resources

- **TOON Specification**: https://toonformat.dev/spec
- **NPM Package**: @toon-format/toon (v2.1.0)
- **CLI Tool**: @toon-format/cli
- **GitHub**: https://github.com/toon-format/toon

### Skills Integration Status

См. актуальный список в:
- **skills/README.md** - Skills status matrix с TOON support
- **task-lite-v7.0.md** - Универсальный шаблон с TOON documentation

---

## Version History

### v1.0.0 (2026-01-23)

- ✅ Initial release
- ✅ 5 integration patterns documented
- ✅ Best practices и threshold guidelines
- ✅ Integration checklist (5 phases)
- ✅ Troubleshooting section
- ✅ Skills status matrix

---

**Автор:** Claude Code Team
**Licence:** MIT
**Поддержка:** См. toon-skill/SKILL.md для вопросов по API

---

**Готовы интегрировать TOON? Начните с Pattern 3 (Hybrid Output)!** 🚀
