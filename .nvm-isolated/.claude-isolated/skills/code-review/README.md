# Code Review Skill - Architecture Validation

Автоматическая проверка качества, безопасности и **архитектурного соответствия** кода перед commit.

## Новые возможности (Architecture Compliance)

### ✅ Что добавлено

**5-я категория проверок**: Architecture Compliance (BLOCKING priority)

1. **Referential Integrity** - все зависимости компонентов существуют
2. **Circular Dependencies** - обнаружение циклов в графе зависимостей (DFS алгоритм)
3. **Component File Path Validation** - измененные файлы документированы в архитектуре
4. **Layer Boundary Compliance** - соблюдение границ слоев (предотвращение upward dependencies)
5. **Hybrid Scope** - проверка modified components + their dependents

### 🎯 Multi-Format Support

Адаптивный парсер автоматически определяет и поддерживает:

- **iclaude schema** (overview.yaml) - полная поддержка всех проверок
- **C4 Model** - автоконвертация в iclaude формат
- **Generic schema** - минимальная структура (components + dependencies)
- **Markdown frontmatter** - fallback для документации
- **ADR** - информационный формат (не для validation)

### 📁 Структура файлов

```
code-review/
├── code-review.sh                      # Главный исполняемый скрипт ⭐
├── SKILL.md                            # Документация skill (обновлено)
├── README.md                           # Этот файл
├── lib/
│   ├── schema-detector.sh              # Автоопределение формата
│   ├── adaptive-architecture-parser.sh # Multi-format парсер
│   └── dependency-graph.sh             # Граф зависимостей и валидация
├── rules/
│   ├── architecture.md                 # 5 правил архитектуры ⭐
│   └── security.md
├── templates/
│   └── review-output.json              # Обновленный output формат
└── examples/
    ├── architecture-validation.md      # 9 примеров использования ⭐
    ├── supported-formats.md            # Документация по форматам ⭐
    └── basic-usage.md
```

## 🚀 Быстрый старт

### Запуск валидации

```bash
# Из корня проекта
.nvm-isolated/.claude-isolated/skills/code-review/code-review.sh .

# Из другой директории
.nvm-isolated/.claude-isolated/skills/code-review/code-review.sh /path/to/project
```

### Пример output

```json
{
  "code_review": {
    "score": 75,
    "passed": false,
    "blocking_issues": [
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "circular_dependency",
        "cycle_path": "cli-main → proxy-management → credential-storage → cli-main",
        "message": "Circular dependency detected",
        "suggestion": "Break cycle using dependency injection"
      }
    ],
    "metrics": {
      "architecture_compliance": {
        "score": 5,
        "max": 25,
        "issues": 2,
        "checks_run": ["referential_integrity", "circular_dependencies", "layer_boundaries", "component_validation"]
      }
    },
    "architecture_available": true
  }
}
```

## 📦 Требования

### Обязательные инструменты

- **jq** - JSON processing (уже требуется code-review)
- **yq** ИЛИ **Python 3 с PyYAML** - YAML→JSON конвертация

```bash
# Установка yq (рекомендуется)
npm install -g yq

# Альтернатива: Python PyYAML
pip install PyYAML
```

### Опциональные зависимости

- **architecture-documentation skill** - автоматическая генерация архитектуры при отсутствии

## 🔍 Как это работает

### Workflow

```
STEP 1: Проверка зависимостей (jq, yq/python)
  ↓
STEP 2: Поиск архитектурных файлов (5 директорий, 8 имен файлов)
  ↓
STEP 3: Автоопределение формата (YAML/JSON/Markdown)
  ↓
STEP 4: Определение типа схемы (iclaude/C4/Generic/ADR)
  ↓
STEP 5: Нормализация в iclaude формат
  ↓
STEP 6: Определение scope (modified + dependent components)
  ↓
STEP 7: Запуск 4 проверок архитектуры
  ↓
STEP 8: Генерация JSON output
```

### Score Calculation

```javascript
// 5 категорий с весами:
architecture_compliance = 25%  // BLOCKING
security = 25%                 // BLOCKING
code_quality = 25%             // WARNING
error_handling = 15%           // WARNING
type_safety = 10%              // INFO

total_score = sum(all categories)

// Если architecture недоступна:
// Веса пересчитываются: security(33.33%) + quality(33.33%) + error(20%) + type(13.33%)
```

## 🎓 Примеры использования

См. детальные примеры в:
- [`examples/architecture-validation.md`](examples/architecture-validation.md) - 9 сценариев использования
- [`examples/supported-formats.md`](examples/supported-formats.md) - документация по форматам

### Быстрые примеры

**Успешная валидация**:
```bash
$ ./code-review.sh .
[✓] Parsed ./docs/architecture/overview.yaml (iclaude format)
[✓] Referential integrity: PASSED
[✓] Circular dependencies: PASSED
[✓] Layer boundaries: PASSED
[✓] Component validation: PASSED

Score: 100/100 ✅
```

**Обнаружен цикл**:
```bash
$ ./code-review.sh .
[✗] Circular dependencies: FAILED (1 cycle)
  Cycle: cli-main → proxy → storage → cli-main

Score: 60/100 ❌ (BLOCKING)
```

## 🔧 Интеграция с workflow

### Автоматический запуск при отсутствии архитектуры

```bash
# Если docs/architecture/ не найдено:
[INFO] Triggering @skill:architecture-documentation...
[✓] Architecture generated successfully
[INFO] Retrying architecture validation...
```

### Fallback strategies

| Сценарий | Действие |
|----------|----------|
| Архитектура не найдена | Автозапуск architecture-documentation skill |
| Неизвестная схема | BLOCKING issue + предложение стандартизации |
| Парсер недоступен | BLOCKING issue + инструкции по установке yq/Python |
| Invalid формат | Попытка следующего файла в списке |

## 📊 Обнаруженные проблемы

На текущем проекте iclaude обнаружено:

### BLOCKING (10 issues)
- **7× Referential Integrity**: Недостающие компоненты (version-detection, symlink-creator, symlink-recreator)
- **1× Layer Violation**: installation layer зависит от core layer (upward dependency)

### WARNING (2 issues)
- **2× Undocumented Components**: Измененные файлы не документированы в overview.yaml

**Рекомендация**: Обновить `docs/architecture/overview.yaml` для исправления нарушений.

## 🛠️ Отладка

### Debug mode

```bash
# Вывод подробных логов
bash -x ./code-review.sh . 2>&1 | less
```

### Проверка парсинга

```bash
# Тест парсера
source lib/adaptive-architecture-parser.sh
parse_architecture_adaptive . | jq '.'
```

### Проверка зависимостей

```bash
# Тест граф traversal
source lib/dependency-graph.sh
detect_circular_dependencies "$(cat components.json)" | jq '.'
```

## 📚 Документация

- **SKILL.md** - полная документация skill
- **rules/architecture.md** - детальное описание 5 правил
- **examples/architecture-validation.md** - примеры всех сценариев
- **examples/supported-formats.md** - гайд по поддерживаемым форматам

## 🎯 Roadmap (Post-MVP)

### Planned features

1. **Dependency Visualization** - генерация diff графа зависимостей (до/после)
2. **Auto-fix Suggestions** - конкретные рекомендации по разрыву циклов
3. **Architecture Drift Detection** - сравнение реального кода с документацией
4. **Mermaid Integration** - прямой парсинг `dependency-graph.mmd`
5. **LSP Integration** - обнаружение реальных зависимостей через go-to-definition

## 🤝 Contributing

При добавлении новых проверок:

1. Добавить правило в `rules/architecture.md`
2. Реализовать функцию в `lib/dependency-graph.sh`
3. Интегрировать в `code-review.sh` (validate_architecture)
4. Добавить примеры в `examples/architecture-validation.md`
5. Обновить `templates/review-output.json`

## 📝 License

Part of iclaude project.

---

**Создано**: 2026-01-19
**Версия**: 1.0.0
**Автор**: Claude Code (Sonnet 4.5)
