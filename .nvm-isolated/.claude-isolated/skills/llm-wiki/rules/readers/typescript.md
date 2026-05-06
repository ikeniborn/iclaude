# Reader: TypeScript

Правила извлечения сущностей из `.ts` и `.tsx` файлов.

## 1. Что искать

| Категория | Паттерны |
|-----------|---------|
| `public_api` | `export function`, `export const`, `export class`, `export default`, `export async function` |
| `docstrings` | JSDoc `/** ... */` непосредственно перед экспортируемым объектом |
| `types` | `export interface X`, `export type X =`, `export enum X` |
| `imports` | `import ... from '...'`, `import type ... from '...'` |

**Игнорировать:**
- Не-экспортируемые объекты (без `export`)
- Реализационные детали внутри тела функций
- `.d.ts` declaration files — читать только для понимания типов, не создавать wiki-страницы

## 2. Правила именования

| Код | Wiki-страница |
|-----|--------------|
| `export function fetchUser(` | `fetch-user` |
| `export class ApiClient` | `api-client` |
| `export interface UserConfig` | `user-config` |
| `export type UserId = string` | `user-id` (только если используется ≥ 3 раз в файле) |
| `export enum Status` | `status-enum` |
| `export const MAX_RETRIES` | пропустить (константа, не сущность) — если только не используется как конфиг API |

## 3. Правила синтеза

**Для функции:**
```
# {имя-функции}

{@description из JSDoc или вывод из имени}

## Сигнатура
\`\`\`typescript
export function имя(param: Тип): ВозвращаемыйТип
\`\`\`

## Описание
{полный JSDoc если есть}

## Параметры
| Имя | Тип | Описание |
|-----|-----|---------|
| param | Тип | {@param описание из JSDoc} |

## Возвращает
{тип + {@returns из JSDoc}}

## Использует
{WikiLinks на импортированные типы/модули}
```

**Для interface/type:**
```
# {имя-типа}

{JSDoc или вывод из имени}

## Поля
| Имя | Тип | Обязательное | Описание |
|-----|-----|-------------|---------|
| поле | Тип | да/нет | ... |

## Используется в
{WikiLinks на функции/классы, принимающие этот тип}
```

**Для enum:**
```
# {имя-enum}

{JSDoc}

## Значения
| Ключ | Значение | Описание |
|------|---------|---------|
```

## 4. Пример

**Вход** (`src/router/client.ts`):
```typescript
/** HTTP client for Claude Code Router with retry logic. */
export class RouterClient {
  /** 
   * Send a chat completion request.
   * @param model - Target model identifier
   * @param messages - Conversation history
   * @returns Completion response
   */
  async complete(model: string, messages: Message[]): Promise<CompletionResponse> {
    ...
  }
}

/** Supported router models. */
export enum RouterModel {
  DeepSeek = 'deepseek/deepseek-chat',
  GPT4o = 'openai/gpt-4o',
}
```

**Выход** (`.wiki/функции/интеграции/router-client.md`):
```markdown
---
wiki_sources: ["src/router/client.ts"]
wiki_updated: 2026-05-06
wiki_status: stub
---
# RouterClient

HTTP-клиент для Claude Code Router с логикой повторных попыток.

## Методы
- `complete(model, messages) → Promise<CompletionResponse>` — отправить запрос chat completion

## Зависимости
[[интеграции/claude-code-router]] · [[функции/router-model]]
```
