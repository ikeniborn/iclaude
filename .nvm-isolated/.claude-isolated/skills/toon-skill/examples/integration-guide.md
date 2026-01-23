# TOON Integration Guide для Claude Code Skills

Пошаговое руководство по интеграции TOON формата в существующий или новый skill.

## Быстрый старт (3 шага)

### Шаг 1: Импорт API

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';
```

### Шаг 2: Добавить TOON в output generation

```javascript
// Существующая генерация JSON (не меняется!)
const output = {
  status: "success",
  items: [...]  // Ваши данные
};

// НОВОЕ: Добавить TOON optimization (если >= 5 элементов)
if (output.items.length >= 5) {
  output.toon = {
    items_toon: arrayToToon('items', output.items, ['field1', 'field2', 'field3']),
    token_savings: calculateTokenSavings({ items: output.items }).savedPercent
  };
}

return output;
```

### Шаг 3: Обновить документацию

Добавить в `SKILL.md`:

```markdown
## TOON Format Support (vX.Y.Z)

Skill автоматически генерирует TOON format для token efficiency:

**Threshold:** TOON генерируется если `items >= 5`

**Output Structure:**
\`\`\`json
{
  "items": [...],  // JSON (всегда)
  "toon": {        // TOON (опционально)
    "items_toon": "items[N]{field1,field2,field3}:\n  ...",
    "token_savings": "42.3%"
  }
}
\`\`\`

**Token Savings:** ~35-45% для массивов >= 10 элементов
```

---

## Полная интеграция (Checklist)

### ☐ 1. Анализ данных

**Определить target arrays:**

```javascript
// Какие массивы в вашем output >= 5 элементов?
const output = {
  blocking_issues: [...],  // Usually < 5, skip
  warnings: [...],         // Usually 5-20, TOON candidate ✓
  suggestions: [...],      // Usually 3-10, TOON candidate ✓
  lsp_diagnostics: [...]   // Usually 10-50, TOON candidate ✓
};
```

**Определить fields для каждого массива:**

```javascript
// Какие поля важны для downstream consumers?
const warningsFields = ['category', 'file', 'line', 'severity', 'message', 'suggestion'];
const suggestionsFields = ['type', 'description', 'priority'];
const lspDiagnosticsFields = ['file', 'line', 'severity', 'code', 'message'];
```

### ☐ 2. Обновить код

**Создать helper function (рекомендуется):**

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

/**
 * Add TOON optimization to output
 */
function addToonOptimization(output, arrayConfigs) {
  const dataToConvert = {};

  arrayConfigs.forEach(({ arrayName, threshold = 5, fields }) => {
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
```

**Использовать в output generation:**

```javascript
// Генерация JSON (существующий код)
const output = {
  status: "success",
  warnings: findWarnings(),
  suggestions: findSuggestions(),
  lsp_diagnostics: getLspDiagnostics()
};

// Добавить TOON optimization
addToonOptimization(output, [
  { arrayName: 'warnings', fields: ['category', 'file', 'line', 'severity', 'message', 'suggestion'] },
  { arrayName: 'suggestions', fields: ['type', 'description', 'priority'] },
  { arrayName: 'lsp_diagnostics', fields: ['file', 'line', 'severity', 'code', 'message'] }
]);

return output;
```

### ☐ 3. Обновить JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "status": { "enum": ["success", "failed"] },
    "warnings": {
      "type": "array",
      "items": { "$ref": "#/definitions/warning" }
    },
    "toon": {
      "$ref": "../_shared/base-schema.json#/definitions/toon_optimization"
    }
  },
  "required": ["status", "warnings"]
}
```

### ☐ 4. Добавить examples

Создать файл `examples/toon-output.example`:

```javascript
import { generateOutput } from '../your-skill.mjs';

// Example with TOON generation
const output = generateOutput({
  // Your test data that generates >= 5 items
});

console.log('=== JSON Output ===');
console.log(JSON.stringify(output.warnings, null, 2));

console.log('\n=== TOON Output ===');
if (output.toon?.warnings_toon) {
  console.log(output.toon.warnings_toon);
  console.log(`\nToken Savings: ${output.toon.token_savings}`);
}
```

### ☐ 5. Обновить документацию

**В SKILL.md добавить раздел:**

```markdown
## TOON Format Support

**Version:** Added in vX.Y.Z

Skill автоматически генерирует TOON format для arrays >= threshold:

| Array | Threshold | Fields | Expected Savings |
|-------|-----------|--------|------------------|
| warnings | 5 | category, file, line, severity, message, suggestion | 40-45% |
| suggestions | 5 | type, description, priority | 35-40% |
| lsp_diagnostics | 5 | file, line, severity, code, message | 45-50% |

**Output Structure:**
\`\`\`json
{
  "warnings": [...],  // JSON (always present)
  "toon": {           // TOON (optional, if >= threshold)
    "warnings_toon": "warnings[15]{category,file,line,severity,message,suggestion}:\n  ...",
    "token_savings": "43.2%",
    "size_comparison": "JSON: 3450 tokens, TOON: 1960 tokens"
  }
}
\`\`\`

**Backward Compatibility:** 100% compatible. JSON always present. TOON is additive only.

**See also:** [TOON Integration Guide](../toon-skill/examples/integration-guide.md)
```

### ☐ 6. Тестирование

**Создать unit tests:**

```javascript
// tests/toon-integration.test.mjs
import { generateOutput } from '../your-skill.mjs';
import { validateToon, roundTripTest, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';
import assert from 'assert';

// Test 1: TOON generated when threshold met
const output1 = generateOutput({ itemCount: 10 });
assert(output1.toon, 'TOON should be generated for 10 items');
assert(output1.toon.items_toon, 'TOON items_toon should exist');

// Test 2: TOON not generated when below threshold
const output2 = generateOutput({ itemCount: 3 });
assert(!output2.toon, 'TOON should NOT be generated for 3 items');

// Test 3: TOON is valid
if (output1.toon?.items_toon) {
  const validation = validateToon(output1.toon.items_toon);
  assert(validation.valid, `TOON validation failed: ${validation.error}`);
}

// Test 4: Round-trip lossless
if (output1.toon?.items_toon) {
  const result = roundTripTest({ items: output1.items });
  assert(result.success, `Round-trip failed: ${result.error}`);
}

// Test 5: Token savings >= 25%
if (output1.toon?.token_savings) {
  const savingsPercent = parseFloat(output1.toon.token_savings);
  assert(savingsPercent >= 25, `Token savings too low: ${savingsPercent}%`);
}

console.log('✓ All TOON integration tests passed');
```

**Run tests:**

```bash
node tests/toon-integration.test.mjs
```

### ☐ 7. Version bump

Обновить версию skill в SKILL.md frontmatter:

```yaml
---
version: X.Y.0  # Minor version bump (backward compatible feature)
updated_at: 2026-01-23
---
```

---

## Паттерны для разных use cases

### Pattern 1: Single Array

```javascript
if (output.items.length >= 5) {
  output.toon = {
    items_toon: arrayToToon('items', output.items, ['field1', 'field2']),
    token_savings: calculateTokenSavings({ items: output.items }).savedPercent
  };
}
```

### Pattern 2: Multiple Arrays

```javascript
const dataToConvert = {};

if (output.warnings.length >= 5) {
  output.toon = output.toon || {};
  output.toon.warnings_toon = arrayToToon('warnings', output.warnings, [...]);
  dataToConvert.warnings = output.warnings;
}

if (output.suggestions.length >= 5) {
  output.toon = output.toon || {};
  output.toon.suggestions_toon = arrayToToon('suggestions', output.suggestions, [...]);
  dataToConvert.suggestions = output.suggestions;
}

if (output.toon) {
  const stats = calculateTokenSavings(dataToConvert);
  output.toon.token_savings = stats.savedPercent;
  output.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}
```

### Pattern 3: Nested Structures (Dependency Graph)

```javascript
import { nestedToToon } from '../toon-skill/converters/toon-converter.mjs';

if (output.dependency_graph.nodes.length >= 3 && output.dependency_graph.edges.length >= 3) {
  output.toon = {
    dependency_graph_toon: nestedToToon('dependency_graph', {
      nodes: { items: output.dependency_graph.nodes, fields: ['id', 'label', 'type'] },
      edges: { items: output.dependency_graph.edges, fields: ['from', 'to', 'type'] }
    }),
    token_savings: calculateTokenSavings({ dependency_graph: output.dependency_graph }).savedPercent
  };
}
```

---

## FAQ

### Q: Нужно ли обновлять существующий JSON output?

**A:** НЕТ! JSON output остаётся неизменным. TOON добавляется как дополнительное поле `toon`.

### Q: Что делать с маленькими массивами (< 5 элементов)?

**A:** Не конвертировать. Token savings минимальны (5-15%), не стоит overhead.

### Q: Как обрабатывать values с запятыми?

**A:** `arrayToToon()` автоматически quotes значения с запятыми. Ничего делать не нужно.

### Q: Нужно ли изменять downstream consumers?

**A:** НЕТ! Consumers могут продолжать читать JSON. TOON - opt-in optimization.

### Q: Как измерить реальные token savings?

**A:** Используйте `calculateTokenSavings()` и включите метрику в output: `output.toon.token_savings`.

### Q: Как обрабатывать ошибки конвертации?

**A:** Используйте try-catch:

```javascript
try {
  output.toon = {
    items_toon: arrayToToon('items', output.items, fields),
    token_savings: calculateTokenSavings({ items: output.items }).savedPercent
  };
} catch (error) {
  console.warn(`TOON generation failed: ${error.message}`);
  // Fallback: JSON only (no TOON)
}
```

---

## Checklist Summary

- ☐ Анализ: Определить target arrays и fields
- ☐ Код: Импорт API, добавить TOON generation
- ☐ Schema: Обновить JSON Schema с `toon` field
- ☐ Examples: Создать example с TOON output
- ☐ Docs: Обновить SKILL.md с TOON section
- ☐ Tests: Добавить unit tests для TOON
- ☐ Version: Bump minor version (X.Y.0)

---

**Готовы к интеграции? Начните с шага 1!** 🚀
