# Reader: JavaScript

Правила извлечения сущностей из `.js` и `.mjs` файлов.
Если файл является TypeScript с расширением `.js` (compiled output) — пропустить, читать исходник `.ts`.

## 1. Что искать

| Категория | Паттерны |
|-----------|---------|
| `public_api` | `module.exports = {`, `exports.имя =`, `export function`, `export const`, `export default` |
| `docstrings` | JSDoc `/** ... */` перед экспортируемым объектом |
| `imports` | `require('...')`, `import ... from '...'` |

**Игнорировать:**
- Файлы в `dist/`, `build/`, `node_modules/` — это compilation output
- Minified файлы (строки длиннее 500 символов без переносов)

## 2. Правила именования

Аналогично TypeScript reader. CamelCase → kebab-case, camelCase → kebab-case.

`module.exports.functionName` → `function-name`

## 3. Правила синтеза

Аналогично TypeScript reader, но без типов в сигнатуре.

Если JSDoc содержит `@param {Type}` — включить тип в таблицу параметров.

```
## Сигнатура
\`\`\`javascript
function имя(param1, param2)
\`\`\`
```

## 4. Пример

**Вход** (`lib/proxy/manager.js`):
```javascript
/**
 * Validate proxy URL format and accessibility.
 * @param {string} url - Proxy URL to validate
 * @returns {boolean} True if valid and reachable
 */
exports.validateProxy = function(url) {
  ...
}
```

**Выход** (`.wiki/функции/proxy/validate-proxy.md`):
```markdown
---
wiki_sources: ["lib/proxy/manager.js"]
wiki_updated: 2026-05-06
wiki_status: stub
---
# validateProxy

Проверить формат и доступность URL прокси-сервера.

## Сигнатура
\`\`\`javascript
exports.validateProxy(url)
\`\`\`

## Параметры
| Имя | Тип | Описание |
|-----|-----|---------|
| url | string | URL прокси для проверки |

## Возвращает
`boolean` — `true` если URL корректен и доступен
```
