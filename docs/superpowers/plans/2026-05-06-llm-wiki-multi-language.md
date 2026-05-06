# LLM Wiki — Multi-Language Source Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Расширить llm-wiki для чтения `.py`, `.ts`, `.js`, `.sh` как полноправных источников наравне с `.md` через систему language readers.

**Architecture:** `source_types` в `domain-map.json` — машиночитаемый реестр расширений → `rules/readers/*.md` — детальные инструкции LLM как читать каждый язык → `ingest` определяет reader по расширению файла и применяет соответствующие правила извлечения.

**Tech Stack:** Markdown (инструкции для LLM), JSON (конфиг), bash (тесты синтаксиса)

**Spec:** `docs/superpowers/specs/2026-05-06-llm-wiki-multi-language-design.md`

**Уже сделано:** `schemas/wiki-page.schema.json` — паттерн `^vaults/` снят с `wiki_sources`

---

## Карта файлов

| Действие | Файл |
|----------|------|
| Создать | `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/markdown.md` |
| Создать | `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/python.md` |
| Создать | `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/typescript.md` |
| Создать | `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/javascript.md` |
| Создать | `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/bash.md` |
| Изменить | `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/ingest-rules.md` |
| Изменить | `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` (3 места) |

---

## Task 1: markdown.md reader — зафиксировать текущее поведение

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/markdown.md`

- [ ] **Step 1: Создать файл reader'а для markdown**

```markdown
# Reader: Markdown

Правила извлечения сущностей из `.md` файлов (заметки, документация, HLD).

## 1. Что искать

| Категория | Паттерны |
|-----------|---------|
| `narrative` | Основной текст между заголовками — факты, описания, решения |
| `frontmatter` | YAML между `---` в начале файла: теги (`tags:`), дата, статус |
| `headings` | `# H1` — название сущности/темы; `## H2` — подтемы |
| `code_blocks` | Блоки ` ```lang ... ``` ` — SQL-запросы, конфигурации, примеры команд |

Особые маркеры приоритета источника:
- Файл содержит "HLD" в пути → источник высшего приоритета
- Файл содержит "Best Practices", "Template", "Architecture" → средний приоритет
- Файл в `!Daily/` или имя `YYYY-MM-DD` → низший приоритет

## 2. Правила именования

- H1 заголовок `# Название сущности` → wiki-страница `название-сущности` (kebab-case)
- Если H1 отсутствует — использовать имя файла без расширения (kebab-case)
- Аббревиатуры сохраняются как есть: `ClickHouse` → `clickhouse`, `SCD2` → `scd2`

## 3. Правила синтеза

**Из narrative:**
- Извлекать факты, характеристики, решения — переформулировать, не копировать дословно
- Исключение: SQL-запросы и конфигурации цитируются в code-блоках

**Структура wiki-страницы из .md источника:**
```
# {Название сущности}

{Определение из H1/первых строк}

## Основные характеристики
{ключевые факты из текста}

## {Разделы по H2 источника, если содержат важную информацию}

## Связанные концепции
{WikiLinks на упомянутые сущности}
```

## 4. Пример

**Вход** (`ростелеком/HLD/ClickHouse-архитектура.md`):
```markdown
---
tags: [база-данных, аналитика]
---
# ClickHouse

Колоночная СУБД для аналитических запросов. Используется в ЦХД для хранения
агрегатов биллинга.

## Особенности
- Сжатие колонок LZ4/ZSTD
- Репликация через ZooKeeper
```

**Выход** (`.wiki/ростелеком/субд/clickhouse.md`):
```markdown
---
wiki_sources: ["ростелеком/HLD/ClickHouse-архитектура.md"]
wiki_updated: 2026-05-06
wiki_status: stub
tags: [база-данных]
---
# ClickHouse

Колоночная СУБД для аналитических запросов в ЦХД Ростелеком.

## Основные характеристики
- Хранит агрегаты биллинга в ЦХД
- Сжатие: LZ4/ZSTD
- Репликация: ZooKeeper

## Связанные концепции
[[субд/zookeeper]] · [[архитектура-данных/цхд]]
```
```

- [ ] **Step 2: Проверить что файл создан корректно**

```bash
ls .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/
```

Ожидается: `markdown.md` в списке.

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/markdown.md
git commit -m "feat(llm-wiki): reader markdown.md — зафиксировать существующее поведение"
```

---

## Task 2: python.md reader

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/python.md`

- [ ] **Step 1: Создать файл reader'а для Python**

```markdown
# Reader: Python

Правила извлечения сущностей из `.py` файлов.

## 1. Что искать

| Категория | Паттерны |
|-----------|---------|
| `public_api` | `def имя(` без ведущего `_`, `class Имя:` без ведущего `_`, имена в `__all__` |
| `docstrings` | `"""..."""` или `'''...'''` сразу после `def`/`class` |
| `types` | `@dataclass`, `class X(TypedDict)`, `class X(BaseModel)`, `class X(Protocol)`, `TypeAlias` |
| `imports` | `import X`, `from X import Y` — внешние зависимости и внутренние модули |

**Игнорировать:**
- Приватные объекты: `_func`, `__func`, `__func__` (кроме `__init__`, `__call__`)
- Тело функций (только сигнатура + docstring)
- Тестовые файлы (`test_*.py`, `*_test.py`) — если не указаны явно в source_paths

## 2. Правила именования

| Код | Wiki-страница |
|-----|--------------|
| `def calculate_revenue(` | `calculate-revenue` |
| `class DataPipeline:` | `data-pipeline` |
| `class UserConfig(TypedDict):` | `user-config` (тип — в разделе "Тип") |
| `class MyError(Exception):` | `my-error` |
| `async def fetch_data(` | `fetch-data` |

Модуль (`module.py`) → отдельная wiki-страница `module` только если содержит ≥ 3 публичных объекта.

## 3. Правила синтеза

**Для функции/метода:**
```
# {имя-функции}

{первая строка docstring или вывод из имени}

## Сигнатура
\`\`\`python
def имя(param1: Тип, param2: Тип = default) -> ВозвращаемыйТип:
\`\`\`

## Описание
{полный docstring, если есть; иначе — вывод по имени и параметрам}

## Параметры
| Имя | Тип | Описание |
|-----|-----|---------|
| param1 | Тип | ... |

## Возвращает
{тип + описание из docstring или type hint}

## Использует
{WikiLinks на импортированные модули, если они есть в wiki}
```

**Для класса:**
```
# {имя-класса}

{первая строка docstring}

## Назначение
{полный docstring класса}

## Поля/Атрибуты
| Имя | Тип | Описание |
|-----|-----|---------|

## Методы
- [[имя-метода]] — краткое описание (если создаётся отдельная страница)
- `метод()` — краткое описание (если не создаётся отдельная страница)

## Зависимости
{WikiLinks на родительские классы и ключевые импорты}
```

**Для dataclass / TypedDict / BaseModel:**
Страница создаётся как для класса, но раздел "Поля" — обязательный и подробный (типы + описания полей).

**Порог создания страницы:**
- Функция: создать если ≥ 1 упоминание и есть docstring ИЛИ ≥ 3 упоминания
- Класс: всегда создать если публичный
- Тип (dataclass/TypedDict/BaseModel): всегда создать если публичный

## 4. Пример

**Вход** (`lib/oauth/token.py`):
```python
"""OAuth token management for Claude Code."""

from pathlib import Path
import json

class TokenManager:
    """Manages OAuth token lifecycle: load, refresh, save.
    
    Tokens are stored in .credentials.json with 5-minute refresh threshold.
    """
    
    def __init__(self, credentials_path: Path):
        self.credentials_path = credentials_path
    
    def is_expired(self, threshold_minutes: int = 5) -> bool:
        """Check if token expires within threshold_minutes."""
        ...
    
    def refresh(self) -> str:
        """Refresh OAuth token and save to credentials file.
        
        Returns:
            New access token string.
        
        Raises:
            TokenRefreshError: If refresh request fails.
        """
        ...
```

**Выход** (`.wiki/функции/oauth/token-manager.md`):
```markdown
---
wiki_sources: ["lib/oauth/token.py"]
wiki_updated: 2026-05-06
wiki_status: stub
---
# TokenManager

Управляет жизненным циклом OAuth-токена: загрузка, обновление, сохранение.

## Назначение
Токены хранятся в `.credentials.json` с порогом обновления 5 минут.

## Поля/Атрибуты
| Имя | Тип | Описание |
|-----|-----|---------|
| credentials_path | Path | Путь к файлу .credentials.json |

## Методы
- `is_expired(threshold_minutes=5) → bool` — проверить, истекает ли токен в ближайшие N минут
- `refresh() → str` — обновить токен и сохранить; возвращает новый access token

## Зависимости
[[функции/oauth/token-refresh-error]] · [[функции/возможности/oauth]]
```
```

- [ ] **Step 2: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/python.md
git commit -m "feat(llm-wiki): reader python.md — правила извлечения из .py файлов"
```

---

## Task 3: typescript.md и javascript.md readers

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/typescript.md`
- Create: `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/javascript.md`

- [ ] **Step 1: Создать typescript.md**

```markdown
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
```

- [ ] **Step 2: Создать javascript.md**

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add \
  .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/typescript.md \
  .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/javascript.md
git commit -m "feat(llm-wiki): readers typescript.md и javascript.md"
```

---

## Task 4: bash.md reader

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/bash.md`

- [ ] **Step 1: Создать bash.md**

```markdown
# Reader: Bash

Правила извлечения сущностей из `.sh` файлов.

## 1. Что искать

| Категория | Паттерны |
|-----------|---------|
| `functions` | `function имя()`, `имя()` в начале строки с `{` на той же или следующей строке |
| `flags` | `--flag` в `case $1`/`case $flag`, `getopts "..."`, строки вида `--flag\)` |
| `exports` | `export VAR=`, `export -f func_name` |
| `comments` | `# Комментарий` непосредственно перед функцией (≤ 3 строки выше) |

**Игнорировать:**
- Однострочные вспомогательные функции без комментария и длиной < 5 строк
- Функции с именами `_helper`, `__internal` (ведущий `_`)
- Строки в heredoc (`<<EOF ... EOF`)

## 2. Правила именования

| Код | Wiki-страница |
|-----|--------------|
| `function launch_claude()` | `launch-claude` |
| `setup_proxy()` | `setup-proxy` |
| `--sandbox-microvm)` | `flag-sandbox-microvm` |
| `--no-proxy)` | `flag-no-proxy` |
| `export ISOLATED_NVM_DIR=` | `var-isolated-nvm-dir` (только если значимая конфиг-переменная) |

Флаги группируются в одну wiki-страницу `{модуль}-flags` если их ≥ 5 в одном файле.
Exported переменные — wiki-страница только если ≥ 3 упоминания в других файлах или описаны в `# comment`.

## 3. Правила синтеза

**Для функции:**
```
# {имя-функции}

{Комментарий перед функцией или вывод из имени}

## Сигнатура
\`\`\`bash
имя_функции [аргументы]
\`\`\`

## Описание
{Развёрнутое описание из комментария + анализ тела}

## Параметры
{$1, $2 или именованные переменные внутри функции}

## Переменные окружения
{переменные, которые функция читает: $VAR, ${VAR:-default}}

## Вызывает
{WikiLinks на другие функции из source, вызываемые внутри тела}
```

**Для группы флагов (≥ 5 флагов в файле):**
```
# {модуль}-flags

Флаги CLI модуля {модуль}.

## Флаги
| Флаг | Описание | По умолчанию |
|------|---------|-------------|
| `--flag` | ... | ... |
```

## 4. Пример

**Вход** (`lib/launcher/launch.sh`):
```bash
# Launch Claude Code with configured environment.
# Applies proxy, NVM path, and CLAUDE_CONFIG_DIR before exec.
launch_claude() {
  local claude_path="$1"
  
  export CLAUDE_CONFIG_DIR="$ISOLATED_NVM_DIR/.claude-isolated"
  
  if [[ -n "$PROXY_URL" ]]; then
    setup_proxy
  fi
  
  exec "$claude_path" "${CLAUDE_ARGS[@]}"
}
```

**Выход** (`.wiki/архитектура/функции/launch-claude.md`):
```markdown
---
wiki_sources: ["lib/launcher/launch.sh"]
wiki_updated: 2026-05-06
wiki_status: stub
---
# launch_claude

Запустить Claude Code с настроенным окружением: прокси, NVM path, CLAUDE_CONFIG_DIR.

## Сигнатура
\`\`\`bash
launch_claude claude_path
\`\`\`

## Параметры
| Позиция | Имя | Описание |
|---------|-----|---------|
| $1 | claude_path | Путь к исполняемому файлу claude |

## Переменные окружения
- `PROXY_URL` — если установлена, активирует прокси через `setup_proxy`
- `ISOLATED_NVM_DIR` — базовый путь изолированного окружения
- `CLAUDE_ARGS` — массив аргументов для передачи Claude

## Вызывает
[[архитектура/функции/setup-proxy]] · [[архитектура/launcher/launch-claude]]
```
```

- [ ] **Step 2: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/bash.md
git commit -m "feat(llm-wiki): reader bash.md — правила извлечения из .sh файлов"
```

---

## Task 5: Обновить ingest-rules.md

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/rules/ingest-rules.md`

- [ ] **Step 1: Добавить секцию Source Type Resolution перед "Основными принципами"**

Добавить в начало файла, перед строкой `# Правила операции ingest`:

```markdown
# Правила операции ingest

## Source Type Resolution

Перед чтением файла-источника определить reader:

```
1. ext = lowercase расширение файла (например: ".py", ".md")
2. Найти ext в domain-map.source_types
3. Если найдено:
   a. reader = source_types[ext].reader
   b. Загрузить @rules:readers/{reader}.md
   c. Применять extract-правила данного reader'а на шаге 3 (извлечение сущностей)
4. Если не найдено:
   a. Предупредить: "Тип файла {ext} не в source_types. Обработать как plain text?"
   b. AskUserQuestion: продолжить как plain text | пропустить файл
   c. Если plain text: искать только явные именованные понятия (существительные,
      аббревиатуры ≥ 3 упоминаний)
```

---

```

- [ ] **Step 2: Расширить секцию "Excalidraw-файлы" → "Неподдерживаемые типы файлов"**

Найти в `ingest-rules.md`:
```markdown
### Excalidraw-файлы
Файлы `.excalidraw.md` содержат JSON-данные диаграммы, не читаемый текст.
→ SKIP с сообщением: "Excalidraw файлы не поддерживаются в ingest"
```

Заменить на:
```markdown
### Неподдерживаемые типы файлов

**Excalidraw:**
Файлы `.excalidraw.md` содержат JSON-данные диаграммы, не читаемый текст.
→ SKIP с сообщением: "Excalidraw файлы не поддерживаются в ingest"

**Бинарные и compilation output:**
Файлы `.pyc`, `.whl`, `.so`, `.exe`, `dist/`, `build/`, `node_modules/`, `__pycache__/`
→ SKIP с сообщением: "Бинарный или compilation-output файл: {путь}"

**Неизвестное расширение:**
Расширение не найдено в domain-map.source_types.
→ AskUserQuestion: продолжить как plain text | пропустить файл
```

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/ingest-rules.md
git commit -m "feat(llm-wiki): добавить Source Type Resolution в ingest-rules.md"
```

---

## Task 6: Обновить SKILL.md — ingest (Step 1.5)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md`

- [ ] **Step 1: Добавить Step 1.5 между шагами 1а и 2 в операции ingest**

Найти в SKILL.md:
```
      Если отменить: завершить

2. Прочитать файл через Read tool
```

Заменить на:
```
      Если отменить: завершить

1.5. Source Type Resolution:
     a. ext = lowercase расширение файла
     b. Найти ext в domain-map.source_types
     c. Если найдено → загрузить @rules:readers/{source_types[ext].reader}.md
     d. Если не найдено → AskUserQuestion: plain text | пропустить
     (Детали: @rules:ingest-rules.md#source-type-resolution)

2. Прочитать файл через Read tool
```

- [ ] **Step 2: Проверить синтаксис изменения**

```bash
# Убедиться что шаги идут в правильном порядке
grep -n "^1\.\|^1а\.\|^1\.5\.\|^2\." .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md | head -20
```

Ожидается: строки `1.`, `1а.`, `1.5.`, `2.` в нужном порядке.

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "feat(llm-wiki): SKILL.md — Step 1.5 Source Type Resolution в ingest"
```

---

## Task 7: Обновить SKILL.md — init (динамический glob)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md`

- [ ] **Step 1: Обновить bootstrap-анализ (шаг а)**

Найти в SKILL.md:
```
      а) Glob "**/*.md" по source_paths, исключить *.excalidraw.md
         Если 0 файлов → ошибка: "Файлы не найдены в source_paths"
         Если файлов ≥ 50 → AskUserQuestion:
           "Найдено {N} файлов. Анализ займёт много токенов. Продолжить?"
           Варианты: да, продолжить | нет, отменить

      б) Прочитать ВСЕ найденные файлы (Read tool)
         Собрать: #теги из frontmatter и тела, заголовки H1/H2/H3,
                  повторяющиеся именованные существительные и ключевые понятия
```

Заменить на:
```
      а) Построить glob-паттерн из ключей domain-map.source_types:
         extensions = ключи source_types без точки (["md","py","ts","js","sh"])
         pattern = "**/*.{" + extensions.join(",") + "}"
         Glob {pattern} по source_paths
         Исключить: *.excalidraw.md, node_modules/, __pycache__/, .git/
         Если 0 файлов → ошибка: "Файлы не найдены в source_paths"
         Если файлов ≥ 50 → AskUserQuestion:
           "Найдено {N} файлов. Анализ займёт много токенов. Продолжить?"
           Варианты: да, продолжить | нет, отменить

      б) Прочитать ВСЕ найденные файлы (Read tool)
         Для .md файлов: собрать #теги из frontmatter, заголовки H1/H2/H3,
                         повторяющиеся именованные существительные
         Для кода (.py/.ts/.js/.sh): применить соответствующий @rules:readers/*.md,
                         собрать публичные функции/классы/типы как кандидатов entity_types
         Во всех случаях: искать повторяющиеся понятия ≥ 3 упоминаний
```

- [ ] **Step 2: Обновить шаг 2 операции init**

Найти в SKILL.md:
```
2. Получить список .md файлов:
   IF $source_files_list уже собран (после bootstrap-анализа) → использовать его
   ELSE → Glob "**/*.md" по source_paths, исключить *.excalidraw.md
```

Заменить на:
```
2. Получить список файлов:
   IF $source_files_list уже собран (после bootstrap-анализа) → использовать его
   ELSE:
     extensions = ключи domain-map.source_types без точки
     pattern = "**/*.{" + extensions.join(",") + "}"
     Glob {pattern} по source_paths
     Исключить: *.excalidraw.md, node_modules/, __pycache__/, .git/
```

- [ ] **Step 3: Проверить что оба места обновлены**

```bash
grep -n '"**\/\*\.md"' .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
```

Ожидается: пустой вывод (все хардкоды `**/*.md` в init заменены).

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "feat(llm-wiki): SKILL.md — динамический glob в init из ключей source_types"
```

---

## Task 8: Обновить SKILL.md — Phase 0 (шаблон domain-map)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md`

- [ ] **Step 1: Добавить source_types в шаблон пустого domain-map.json**

Найти в SKILL.md (Phase 0, Step 0.1):
```json
  "special_source_types": {}
}
```

Заменить на:
```json
  "special_source_types": {},
  "source_types": {
    ".md": {
      "reader": "markdown",
      "extract": ["narrative", "frontmatter", "code_blocks", "headings"],
      "rules_file": "rules/readers/markdown.md"
    },
    ".py": {
      "reader": "python",
      "extract": ["public_api", "docstrings", "types", "imports"],
      "rules_file": "rules/readers/python.md"
    },
    ".ts": {
      "reader": "typescript",
      "extract": ["public_api", "docstrings", "types", "imports"],
      "rules_file": "rules/readers/typescript.md"
    },
    ".js": {
      "reader": "javascript",
      "extract": ["public_api", "docstrings", "imports"],
      "rules_file": "rules/readers/javascript.md"
    },
    ".sh": {
      "reader": "bash",
      "extract": ["functions", "flags", "exports", "comments"],
      "rules_file": "rules/readers/bash.md"
    }
  }
}
```

- [ ] **Step 2: Проверить что JSON в шаблоне валиден**

```bash
# Извлечь шаблон и валидировать
python3 -c "
import re, json, sys
content = open('.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md').read()
# Найти JSON-блок шаблона domain-map
m = re.search(r'Шаблон пустого domain-map\.json.*?\`\`\`json\n(.*?)\`\`\`', content, re.DOTALL)
if m:
    json.loads(m.group(1))
    print('JSON валиден')
else:
    print('Шаблон не найден', file=sys.stderr)
    sys.exit(1)
"
```

Ожидается: `JSON валиден`

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
git commit -m "feat(llm-wiki): SKILL.md — добавить source_types в шаблон domain-map.json"
```

---

## Task 9: Финальная проверка целостности

- [ ] **Step 1: Проверить что все новые файлы на месте**

```bash
ls .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/
```

Ожидается: `bash.md  javascript.md  markdown.md  python.md  typescript.md`

- [ ] **Step 2: Проверить что ни одного хардкода `**/*.md` не осталось в init**

```bash
grep -n 'Glob "\*\*/\*\.md"' .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
```

Ожидается: пустой вывод.

- [ ] **Step 3: Проверить что source_types есть в шаблоне Phase 0**

```bash
grep -c '"source_types"' .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
```

Ожидается: `1` (один раз — в шаблоне).

- [ ] **Step 4: Проверить что Step 1.5 есть в ingest**

```bash
grep -c "1\.5\." .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
```

Ожидается: `1`.

- [ ] **Step 5: Проверить Source Type Resolution в ingest-rules.md**

```bash
grep -c "Source Type Resolution" .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/ingest-rules.md
```

Ожидается: `1`.

- [ ] **Step 6: Проверить синтаксис bash (если применимо)**

```bash
bash -n .nvm-isolated/.claude-isolated/skills/llm-wiki/rules/readers/bash.md 2>&1 || true
# Файл .md — bash -n вернёт ошибки, это нормально. Проверяем только iclaude.sh
bash -n iclaude.sh && echo "iclaude.sh: OK"
```

Ожидается: `iclaude.sh: OK`

- [ ] **Step 7: Финальный commit если были правки**

```bash
git status
# Если чисто — уже всё закоммичено. Если есть изменения:
git add -p  # добавить только нужное
git commit -m "fix(llm-wiki): финальные правки после интеграционной проверки"
```
