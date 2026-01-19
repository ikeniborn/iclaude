# Architecture Compliance Rules

## Rule 1: Referential Integrity (BLOCKING)

**Описание:** Все зависимости компонентов должны ссылаться на существующие компоненты

**Проверка:**
- Парсим архитектурную документацию (YAML/JSON/Markdown)
- Для каждого компонента проверяем массив `dependencies[]`
- Каждый `dependency.component_id` должен существовать в списке компонентов

**Пример нарушения:**

```yaml
# docs/architecture/overview.yaml
components:
  - id: oauth-token-management
    dependencies:
      - component_id: jq-validator  # ← Компонент не существует!
```

**Blocking Issue:**
```json
{
  "category": "architecture_compliance",
  "severity": "BLOCKING",
  "rule": "referential_integrity",
  "component": "oauth-token-management",
  "dependency": "jq-validator",
  "file": "docs/architecture/overview.yaml",
  "message": "Dependency 'jq-validator' not found in components list",
  "suggestion": "Add component 'jq-validator' to overview.yaml or remove from dependencies"
}
```

---

## Rule 2: Circular Dependencies (BLOCKING)

**Описание:** Граф зависимостей должен быть ацикличным (DAG - Directed Acyclic Graph)

**Алгоритм:** Depth-First Search (DFS) для обнаружения циклов

**Пример нарушения:**

```yaml
# Цикл: cli-main → proxy-management → credential-storage → cli-main
components:
  - id: cli-main
    dependencies:
      - component_id: proxy-management

  - id: proxy-management
    dependencies:
      - component_id: credential-storage

  - id: credential-storage
    dependencies:
      - component_id: cli-main  # ← Замыкает цикл!
```

**Blocking Issue:**
```json
{
  "category": "architecture_compliance",
  "severity": "BLOCKING",
  "rule": "circular_dependency",
  "cycle_path": "cli-main → proxy-management → credential-storage → cli-main",
  "message": "Circular dependency detected in architecture",
  "suggestion": "Break cycle using dependency injection, mediator pattern, or event-driven architecture"
}
```

---

## Rule 3: Component File Path Validation (BLOCKING)

**Описание:** Измененные файлы должны соответствовать документированным компонентам

**Проверка:**
- Получаем список измененных файлов из `git diff --name-only`
- Для каждого файла ищем компонент с matching `file_path`
- Если файл не документирован → BLOCKING (требуется обновить архитектуру)

**Пример нарушения:**

```bash
# git diff --name-only
iclaude.sh  # Изменена строка 3850

# docs/architecture/overview.yaml
# Компонент с file_path: "iclaude.sh:3850-3900" не найден!
```

**Blocking Issue:**
```json
{
  "category": "architecture_compliance",
  "severity": "BLOCKING",
  "rule": "undocumented_component",
  "file": "iclaude.sh",
  "line_range": "3850-?",
  "message": "Modified code not documented in architecture",
  "suggestion": "Add component to docs/architecture/overview.yaml or update existing component's file_path"
}
```

---

## Rule 4: Layer Boundary Compliance (BLOCKING)

**Описание:** Компоненты могут зависеть только от компонентов в том же или нижестоящем слое

**Иерархия слоев:** (от высшего к низшему)
```
1. CLI Layer          ← Может зависеть от 2, 3, 4
2. Core Layer         ← Может зависеть от 3, 4
3. Installation Layer ← Может зависеть от 4
4. Infrastructure     ← Не зависит от верхних слоев
```

**Пример нарушения:**

```yaml
# INVALID: Infrastructure зависит от Core (восходящая зависимость!)
- id: credential-storage
  layer: infrastructure
  dependencies:
    - component_id: oauth-token-management  # oauth в слое core
```

**Blocking Issue:**
```json
{
  "category": "architecture_compliance",
  "severity": "BLOCKING",
  "rule": "layer_violation",
  "component": "credential-storage",
  "layer": "infrastructure",
  "depends_on": "oauth-token-management",
  "depends_on_layer": "core",
  "message": "Layer violation: infrastructure component depends on core component (upward dependency)",
  "suggestion": "Move oauth-token-management to infrastructure layer OR remove dependency OR introduce adapter pattern"
}
```

---

## Rule 5: Scope Validation (Гибридный режим)

**Описание:** Проверяем измененные компоненты + все компоненты, зависящие от них

**Алгоритм:**
1. Получить измененные файлы из `git diff`
2. Найти компоненты с matching file_path → `modified_components[]`
3. Найти все компоненты, зависящие от `modified_components[]` → `dependent_components[]`
4. Проверить архитектуру для `modified_components[] ∪ dependent_components[]`

**Почему гибридный?**
- **Быстрее**, чем проверка всей архитектуры при каждом commit
- **Находит проблемы** в зависимых компонентах, которые могут поломаться
- **Меньше false positives**, чем проверка только измененных файлов

**Пример:**

```bash
# Измененный файл
git diff --name-only → iclaude.sh:60-88  # validate-proxy-url

# Компоненты, зависящие от validate-proxy-url:
# - proxy-management (прямая зависимость)
# - cli-main (косвенная через proxy-management)

# Scope проверки:
# 1. validate-proxy-url (измененный)
# 2. proxy-management (прямой dependent)
# 3. cli-main (косвенный dependent)
```

---

## Severity Levels

Все архитектурные проверки имеют severity **BLOCKING**:

- **BLOCKING**: Блокирует commit, требует исправления
  - Referential Integrity violations
  - Circular Dependencies
  - Undocumented Components
  - Layer Boundary violations

**Rationale**: Архитектурные нарушения = технический долг, который сложно исправить позже. Блокирование на уровне code review предотвращает накопление долга.

---

## Fallback Strategies

### Архитектура не найдена

```json
{
  "category": "architecture_compliance",
  "severity": "BLOCKING",
  "rule": "architecture_required",
  "message": "No architecture documentation found",
  "suggestion": "Run @skill:architecture-documentation to generate",
  "action": "trigger_skill"
}
```

**Поведение**: Автоматически запустить `architecture-documentation` skill для генерации.

### Структура не распознана

```json
{
  "category": "architecture_compliance",
  "severity": "BLOCKING",
  "rule": "unknown_schema",
  "message": "Architecture file found but structure not recognized",
  "files_found": ["docs/architecture/custom.yaml"],
  "suggestion": "Run @skill:architecture-documentation to standardize",
  "action": "trigger_skill"
}
```

### Парсер недоступен

```json
{
  "category": "architecture_compliance",
  "severity": "BLOCKING",
  "rule": "missing_dependencies",
  "message": "Required tools not installed: jq, yq or Python",
  "suggestion": "Install dependencies: npm install -g yq OR pip install PyYAML"
}
```

---

## Integration Points

### С architecture-documentation skill

**Автоматический запуск** при:
- Отсутствии файлов архитектуры
- Нераспознанной структуре
- Невалидном формате

**Workflow**:
1. code-review обнаруживает проблему
2. Создает BLOCKING issue с `action: "trigger_skill"`
3. Вызывает `@skill:architecture-documentation --generate`
4. Повторно запускает архитектурную валидацию

### С LSP integration

LSP данные могут улучшить точность проверок:
- Обнаружение реальных зависимостей через `go-to-definition`
- Сравнение документированных vs. фактических зависимостей

---

## Examples

См. `examples/architecture-validation.md` для детальных примеров использования.
