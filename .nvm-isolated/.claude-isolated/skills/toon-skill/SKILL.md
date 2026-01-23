---
skill_name: toon-skill
version: 1.0.0
description: Централизованный API для конвертации JSON ↔ TOON и расчёта token savings
category: utility
dependencies:
  npm:
    - "@toon-format/toon": "^1.0.0"
tags: [toon, token-optimization, data-format, inter-skill-communication]
author: Claude Code Team
created_at: 2026-01-23
updated_at: 2026-01-23
---

# TOON Skill - Token-Oriented Object Notation Support

## Назначение

Базовый навык для работы с TOON форматом - компактным, человеко-читаемым форматом данных для оптимизации LLM промптов (**30-60% token savings**).

TOON (Token-Oriented Object Notation) предназначен для:
- Inter-skill коммуникации (structured output между навыками)
- Token-efficient data serialization
- Lossless двусторонняя JSON ↔ TOON конвертация
- Табличные данные (components, issues, steps, checks)

## Когда использовать

### ✅ ДА - используйте TOON для:

- **Массивы >= 5 элементов** с consistent schema (warnings[], execution_steps[], checks[])
- **Inter-skill коммуникация** (structured output между навыками)
- **Табличные данные** (components, issues, steps, checks, commits)
- **Большие датасеты** где token efficiency критична (30-60% savings)
- **Nested structures** с multiple arrays (dependency graphs)

### ❌ НЕТ - не используйте TOON для:

- **Маленькие массивы** (< 5 элементов) - экономия минимальна (5-15%)
- **Глубоко вложенные структуры** (> 3 уровней) - TOON плохо подходит
- **Человеко-ориентированные файлы** в git (лучше YAML/JSON для readability)
- **Configuration files** (нужна IDE валидация, JSON Schema support)

## API Functions

### 1. Конвертация

```javascript
import { jsonToToon, toonToJson, arrayToToon, nestedToToon } from '../toon-skill/converters/toon-converter.mjs';

// Generic JSON → TOON
const toonString = jsonToToon({ components: [...] });

// TOON → JSON
const jsonObj = toonToJson(toonString);

// Specialized: Array → TOON table (PRIMARY API)
const toonTable = arrayToToon('warnings', warningsArray,
  ['file', 'line', 'severity', 'message']);
// Output: "warnings[15]{file,line,severity,message}:\n  src/app.js,42,BLOCKING,SQL injection\n  ..."

// Nested arrays (dependency graphs)
const toonGraph = nestedToToon('dependency_graph', {
  nodes: { items: nodesArray, fields: ['id', 'label', 'type'] },
  edges: { items: edgesArray, fields: ['from', 'to', 'type'] }
});
```

### 2. Валидация

```javascript
import { validateToon, roundTripTest } from '../toon-skill/converters/toon-converter.mjs';

// Syntax validation
const result = validateToon(toonString);
if (!result.valid) console.error(result.errors);

// Lossless conversion test
const test = roundTripTest(jsonObj);
if (test.success) console.log('Round-trip successful!');
```

### 3. Метрики

```javascript
import { calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

const stats = calculateTokenSavings({ warnings: [...] });
console.log(`JSON: ${stats.jsonTokens} tokens`);
console.log(`TOON: ${stats.toonTokens} tokens`);
console.log(`Saved: ${stats.savedPercent}`); // "43.2%"
```

## Integration Pattern (Hybrid Output)

**Для других skills всегда используйте hybrid approach:**

```javascript
// Step 1: Generate JSON output (always)
const output = {
  status: "success",
  warnings: [...],  // 15 items
  blocking_issues: [...]  // 2 items
};

// Step 2: Add TOON optimization (если >= 5 элементов)
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

if (output.warnings.length >= 5) {
  const dataToConvert = { warnings: output.warnings };
  const stats = calculateTokenSavings(dataToConvert);

  output.toon = {
    warnings_toon: arrayToToon('warnings', output.warnings,
      ['category', 'file', 'line', 'severity', 'message', 'suggestion']),
    token_savings: stats.savedPercent,
    size_comparison: `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`
  };
}

// blocking_issues не конвертируем (< 5 элементов)

// Step 3: Return hybrid output
return output;
```

**Result structure:**

```json
{
  "status": "success",
  "warnings": [...],          // JSON (всегда присутствует)
  "blocking_issues": [...],   // JSON (всегда присутствует)
  "toon": {                   // TOON (опционально, если >= 5 элементов)
    "warnings_toon": "warnings[15]{category,file,line,severity,message,suggestion}:\n  ...",
    "token_savings": "43.2%",
    "size_comparison": "JSON: 3450 tokens, TOON: 1960 tokens"
  }
}
```

**Преимущества:**
- ✅ 100% backward compatibility (JSON всегда доступен)
- ✅ Opt-in optimization (TOON только когда выгодно)
- ✅ Zero breaking changes (downstream skills читают JSON)
- ✅ Метрики встроены (можем измерить savings)

## TOON Syntax Reference

### Простой массив

```
arrayName[N]{field1,field2,field3}:
  value1_1,value1_2,value1_3
  value2_1,value2_2,value2_3
```

**Правила:**
- `[N]` - точное количество элементов (валидация)
- `{fields}` - схема (названия полей)
- `:` - начало табличных данных
- Comma-separated значения (CSV-style)
- Quoted строки для значений с запятыми: `"value, with comma"`

**Пример:**

```
warnings[3]{file,line,severity,message}:
  src/app.js,42,BLOCKING,SQL injection vulnerability
  src/db.js,15,WARNING,Missing database index
  src/api.js,78,INFO,Consider async/await refactoring
```

### Вложенные структуры

```
parent:
  child1[2]{id,name}:
    1,Alice
    2,Bob
  child2[3]{id,status}:
    1,active
    2,inactive
    3,pending
```

**Пример (dependency graph):**

```
dependency_graph:
  nodes[2]{id,label,type,layer}:
    proxy-mgmt,Proxy Management,module,infrastructure
    oauth-handler,OAuth Handler,function,business
  edges[1]{from,to,type,description}:
    proxy-mgmt,oauth-handler,required,Requires OAuth for authenticated proxies
```

## Skills Integration Examples

### Example 1: code-review skill

```javascript
// In code-review skill
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

const codeReview = {
  score: 85,
  blocking_issues: findBlockingIssues(),  // Usually < 5, no TOON
  warnings: findWarnings(),               // Usually 5-20, TOON candidate
  lsp_diagnostics: getLspDiagnostics()    // Usually 10-50, TOON candidate
};

// Add TOON optimization
const dataToConvert = {};

if (codeReview.warnings.length >= 5) {
  codeReview.toon = codeReview.toon || {};
  codeReview.toon.warnings_toon = arrayToToon('warnings', codeReview.warnings,
    ['category', 'file', 'line', 'severity', 'message', 'suggestion']);
  dataToConvert.warnings = codeReview.warnings;
}

if (codeReview.lsp_diagnostics && codeReview.lsp_diagnostics.length >= 5) {
  codeReview.toon = codeReview.toon || {};
  codeReview.toon.lsp_diagnostics_toon = arrayToToon('lsp_diagnostics', codeReview.lsp_diagnostics,
    ['file', 'line', 'severity', 'code', 'message']);
  dataToConvert.lsp_diagnostics = codeReview.lsp_diagnostics;
}

if (codeReview.toon) {
  const stats = calculateTokenSavings(dataToConvert);
  codeReview.toon.token_savings = stats.savedPercent;
  codeReview.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}

return { code_review: codeReview };
```

### Example 2: structured-planning skill

```javascript
// In structured-planning skill
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

const taskPlan = {
  task_summary: "Implement user authentication",
  execution_steps: [...],  // 7 steps
  acceptance_criteria: [...],  // 5 criteria
  files_to_change: [...]  // 12 files
};

// Add TOON optimization
if (taskPlan.execution_steps.length >= 5) {
  taskPlan.toon = {
    execution_steps_toon: arrayToToon('execution_steps', taskPlan.execution_steps,
      ['step_number', 'description', 'validation']),
    token_savings: calculateTokenSavings({ execution_steps: taskPlan.execution_steps }).savedPercent
  };
}

if (taskPlan.files_to_change.length >= 5) {
  taskPlan.toon = taskPlan.toon || {};
  taskPlan.toon.files_to_change_toon = arrayToToon('files_to_change', taskPlan.files_to_change,
    ['file_path', 'change_type', 'description']);
}

return { task_plan: taskPlan };
```

### Example 3: pr-automation skill

```javascript
// In pr-automation skill
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

const prResult = {
  pr_url: "https://github.com/...",
  checks: [...],  // 8 checks
  autoFixedErrors: [...],  // 12 fixes
  commits: [...]  // 15 commits
};

// Add TOON for all arrays >= 5
const dataToConvert = {};

['checks', 'autoFixedErrors', 'commits'].forEach(arrayName => {
  if (prResult[arrayName].length >= 5) {
    prResult.toon = prResult.toon || {};

    const fields = {
      'checks': ['name', 'status', 'duration_ms', 'details_url'],
      'autoFixedErrors': ['file', 'line', 'error_type', 'fix_applied'],
      'commits': ['hash', 'author', 'message', 'timestamp']
    };

    prResult.toon[`${arrayName}_toon`] = arrayToToon(arrayName, prResult[arrayName], fields[arrayName]);
    dataToConvert[arrayName] = prResult[arrayName];
  }
});

if (prResult.toon) {
  const stats = calculateTokenSavings(dataToConvert);
  prResult.toon.token_savings = stats.savedPercent;
  prResult.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}

return prResult;
```

## Token Savings Benchmarks

| Use Case | Array Size | JSON Tokens | TOON Tokens | Savings |
|----------|------------|-------------|-------------|---------|
| **Components** (architecture-documentation) | 6 items | 202 | 123 | **39.1%** |
| **Dependency Graph** (architecture-documentation) | 4 nodes + 6 edges | 223 | 114 | **48.9%** |
| **Code Review Warnings** (code-review) | 15 items | 450 | 260 | **42.2%** |
| **Execution Steps** (structured-planning) | 10 items | 380 | 220 | **42.1%** |
| **PR Checks** (pr-automation) | 8 items | 290 | 175 | **39.7%** |
| **LSP Diagnostics** (code-review) | 50 items | 2100 | 1050 | **50.0%** |

**Aggregate savings для typical workflow:**
- Complex task (10 steps + 15 warnings + 8 checks): **~45% total token reduction**
- Standard task (5 steps + 8 warnings): **~38% total token reduction**
- Simple task (3 steps + 2 warnings): **0% (threshold not met)**

## Consuming TOON (Downstream Skills)

Если ваш skill получает output от другого skill с TOON:

```javascript
import { toonToJson } from '../toon-skill/converters/toon-converter.mjs';

// Input: hybrid output from upstream skill
const upstreamOutput = {
  items: [...],  // JSON (всегда доступен)
  toon: {
    items_toon: "items[15]{...}:\n  ..."  // TOON (опционально)
  }
};

// Strategy 1: Always use JSON (safest, backward compatible)
const items = upstreamOutput.items;

// Strategy 2: Prefer TOON if available (token efficient)
const items = upstreamOutput.toon?.items_toon
  ? toonToJson(upstreamOutput.toon.items_toon).items
  : upstreamOutput.items;

// Strategy 3: Use TOON for validation только
if (upstreamOutput.toon?.items_toon) {
  const toonItems = toonToJson(upstreamOutput.toon.items_toon).items;
  // Validate consistency
  assert.deepStrictEqual(toonItems, upstreamOutput.items);
}
```

## Troubleshooting

### Q: TOON не генерируется, хотя массив >= 5 элементов

**A:** Проверьте, что все поля имеют consistent типы и schema. TOON требует uniform структуру.

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

**A:** TOON наиболее эффективен для >= 10 элементов, табличных структур. Для 5-9 элементов экономия 25-35%.

### Q: Ошибка при конвертации обратно в JSON

**A:** Используйте `validateToon()` для проверки синтаксиса:

```javascript
const result = validateToon(toonString);
if (!result.valid) {
  console.error('Invalid TOON:', result.error);
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

**A:** Да, добавьте optional `toon` field используя `$ref: "_shared/base-schema.json#/definitions/toon_optimization"`:

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

## File Structure

```
toon-skill/
├── SKILL.md                           # Этот файл
├── converters/
│   ├── toon-converter.mjs             # Main API (generic + specialized converters)
│   └── README.md                      # API documentation
├── templates/
│   └── hybrid-output.json             # Шаблон JSON + TOON output
├── examples/
│   ├── array-conversion.example       # Примеры конвертации массивов
│   ├── nested-objects.example         # Примеры вложенных структур
│   ├── hybrid-output.example          # Пример hybrid output
│   └── integration-guide.md           # Руководство по интеграции в другие skills
├── schemas/
│   └── toon-output.schema.json        # JSON Schema для toon field
└── tests/
    ├── round-trip.test.mjs            # Тесты lossless конвертации
    └── token-savings.test.mjs         # Тесты расчёта экономии
```

## CLI Usage

TOON converter можно использовать через command line:

```bash
# Convert JSON file to TOON
node converters/toon-converter.mjs encode input.json

# Convert TOON file to JSON
node converters/toon-converter.mjs decode input.toon

# Run round-trip test
node converters/toon-converter.mjs test input.json

# Show token savings statistics
node converters/toon-converter.mjs stats input.json
```

## References

- **TOON Specification**: https://toonformat.dev/spec
- **NPM Package**: @toon-format/toon
- **CLI Tool**: @toon-format/cli (installed: `.nvm-isolated/npm-global/bin/toon`)
- **Integration Guide**: examples/integration-guide.md
- **Patterns**: ../_shared/TOON-PATTERNS.md

## Skills с TOON Support

См. актуальный список в:
- `../_shared/TOON-PATTERNS.md` - Integration patterns
- `../README.md` - Skills status matrix с TOON support

**High Priority Skills:**
- ✅ **architecture-documentation** v1.2.0 - Components, dependency_graph (42% savings)
- ✅ **validation-framework** v2.1.0 - Consumer (reads TOON input)
- 🔄 **code-review** - warnings[], lsp_diagnostics[] (planned 43% savings)
- 🔄 **structured-planning** - execution_steps[], files_to_change[] (planned 38% savings)
- 🔄 **pr-automation** - checks[], autoFixedErrors[], commits[] (planned 40% savings)
- 🔄 **skill-generator** - validation_results[], files_created[] (planned 42% savings)
- 🔄 **prd-generator** - sections[], diagrams[], features[] (planned 48% savings)

**Legend:**
- ✅ Complete - TOON fully integrated
- 🔄 Planned - Scheduled for integration
- ❌ N/A - Not applicable

## Version History

### v1.0.0 (2026-01-23)
- ✅ Initial release
- ✅ Generic converters: `arrayToToon()`, `nestedToToon()`
- ✅ Specialized converters: `componentsToToon()`, `dependencyGraphToToon()`, `edgesToToon()`
- ✅ Utility functions: `calculateTokenSavings()`, `validateToon()`, `roundTripTest()`
- ✅ CLI interface
- ✅ Full documentation (SKILL.md, converters/README.md)
- ✅ Examples и tests

## License

MIT License

---

**Разработан командой Claude Code для оптимизации inter-skill коммуникации и снижения token costs.**
