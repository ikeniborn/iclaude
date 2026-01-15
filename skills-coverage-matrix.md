# Skills Coverage Matrix

**Дата:** 2026-01-15
**Scope:** Глобальные skills в `/home/UF.RT.RU/i.y.tischenko/Документы/Git/iclaude/.nvm-isolated/.claude-isolated/skills`

---

## Overview

Этот документ показывает, какие глобальные skills используются в Template файлах и какие доступны, но не используются.

**Источник данных:**
- Глобальные skills: `.nvm-isolated/.claude-isolated/skills/` (21 skill)
- Template файлы: `/home/UF.RT.RU/i.y.tischenko/Документы/Notes/Work/ИИ/Claude code/Template`
- Проверка: `validate-template-skills.sh`

---

## Skills Coverage Matrix

Матрица использования глобальных skills в Template файлах.

| # | Глобальный Skill | Template | Статус | Примечание |
|---|------------------|----------|--------|------------|
| 1 | adaptive-workflow | ✅ | USED | Адаптивный выбор workflow по сложности |
| 2 | approval-gates | ✅ | USED | Упрощённые approval gates для подтверждения плана |
| 3 | architecture-documentation | ❌ | UNUSED | Генерация архитектурной документации в YAML |
| 4 | bash-development | ❌ | UNUSED | Разработка bash-функций для init_claude.sh |
| 5 | code-review | ✅ | USED | Автоматический review кода перед commit |
| 6 | context7-integration | ✅ | USED | Автоматическая загрузка library docs через Context7 |
| 7 | context-awareness | ✅ | USED | Автоматическое определение контекста проекта |
| 8 | error-handling | ✅ | USED | Структурированная обработка ошибок workflow |
| 9 | git-workflow | ✅ | USED | Стандартизированный git workflow с Conventional Commits |
| 10 | isolated-environment | ❌ | UNUSED | Управление изолированной установкой NVM и Claude |
| 11 | lsp-integration | ✅ | USED | Автоматическая установка LSP plugins |
| 12 | phase-execution | ❌ | UNUSED | Автоматизация выполнения одной фазы из phase file |
| 13 | pr-automation | ✅ | USED | Автоматизация создания PR с мониторингом CI/CD |
| 14 | prd-generator | ❌ | UNUSED | Автоматизированное создание PRD документов |
| 15 | proxy-management | ❌ | UNUSED | Настройка HTTP/HTTPS/SOCKS5 прокси для Claude |
| 16 | rollback-recovery | ✅ | USED | Механизм отката при критических ошибках |
| 17 | skill-generator | ❌ | UNUSED | Автоматизированное создание новых skills |
| 18 | structured-planning | ✅ | USED | Создание планов задач с адаптивной JSON Schema |
| 19 | task-decomposition | ❌ | UNUSED | Разбиение задачи на 2-5 логических фаз |
| 20 | thinking-framework | ✅ | USED | Структурированный reasoning через 3 шаблона |
| 21 | validation-framework | ✅ | USED | Адаптивная валидация с partial validation |

**Статистика:**
- **USED**: 13 skills (61.9%)
- **UNUSED**: 8 skills (38.1%)
- **Total**: 21 global skills

---

## Used Skills (13)

Skills, которые активно используются в Template:

1. **adaptive-workflow** - Адаптивный выбор сложности workflow
2. **approval-gates** - Упрощённые approval gates
3. **code-review** - Автоматический review кода
4. **context7-integration** - Загрузка library docs
5. **context-awareness** - Определение контекста проекта
6. **error-handling** - Обработка ошибок workflow
7. **git-workflow** - Git workflow с Conventional Commits
8. **lsp-integration** - LSP plugins для code intelligence
9. **pr-automation** - Автоматизация PR и CI/CD
10. **rollback-recovery** - Механизм отката
11. **structured-planning** - Создание планов задач
12. **thinking-framework** - Структурированный reasoning
13. **validation-framework** - Адаптивная валидация

---

## Unused Skills (8)

Skills, которые существуют, но не используются в Template.

### Кандидаты на интеграцию:

| Skill | Потенциал интеграции | Предложение |
|-------|---------------------|-------------|
| **skill-generator** | ВЫСОКИЙ | Использовать для генерации новых domain-specific skills в Template |
| **task-decomposition** | ВЫСОКИЙ | Интегрировать в adaptive-workflow для декомпозиции complex tasks |
| **prd-generator** | СРЕДНИЙ | Использовать для создания PRD перед structured-planning |
| **phase-execution** | СРЕДНИЙ | Интегрировать с task-decomposition для пошагового выполнения |

### Специализированные skills (не для Template):

| Skill | Назначение | Рекомендация |
|-------|-----------|--------------|
| **bash-development** | Разработка bash-функций для iclaude.sh | Оставить как есть (используется при разработке iclaude) |
| **isolated-environment** | Управление .nvm-isolated/ | Оставить как есть (используется для iclaude setup) |
| **architecture-documentation** | Генерация архитектурной документации | Оставить как есть (используется для больших проектов) |
| **proxy-management** | Настройка прокси для Claude | Оставить как есть (используется для iclaude proxy setup) |

---

## Missing Skills (13)

Skills, которые упоминаются в Template, но **не существуют** в глобальных skills.

**Список:**
1. **arm-optimization** - Оптимизация для ARM архитектуры
2. **authentication-security** - Безопасность аутентификации
3. **bot-development** - Разработка ботов
4. **db-management** - Управление базами данных
5. **docker-management** - Управление Docker контейнерами
6. **monitoring-troubleshooting** - Мониторинг и troubleshooting
7. **network-configuration** - Настройка сети
8. **ralph-loop** - Ralph-Loop plugin integration (существует как **plugin**, НЕ skill)
9. **security-hardening** - Security hardening
10. **service-management** - Управление сервисами
11. **storage-optimization** - Оптимизация хранилища
12. **system-administration** - Системное администрирование
13. **websocket-realtime** - WebSocket и real-time коммуникация

**Рекомендации:**

### 1. Переместить в project-specific skills

Эти skills специфичны для конкретных проектов и должны быть в `.claude/skills/` локальных проектов:

- **docker-management** → для проектов с Docker
- **db-management** → для проектов с БД
- **service-management** → для системных проектов
- **network-configuration** → для сетевых проектов
- **storage-optimization** → для проектов с хранилищем
- **system-administration** → для системных проектов
- **websocket-realtime** → для real-time приложений
- **bot-development** → для проектов с ботами
- **arm-optimization** → для ARM-специфичных проектов
- **authentication-security** → для проектов с аутентификацией
- **security-hardening** → для security-focused проектов
- **monitoring-troubleshooting** → для production систем

### 2. Ralph-Loop - это plugin, НЕ skill

**ralph-loop** упоминается как `@skill:ralph-loop`, но это **Claude Code Plugin**, а не skill.

**Корректное использование:**
- В Template упоминать как external dependency
- См. `.nvm-isolated/.claude-isolated/skills/_shared/external-dependencies.md`
- Установка: `/plugin install ralph-loop@claude-plugins-official`

**Предложение:** Заменить ссылки `@skill:ralph-loop` на упоминание external dependency в Template.

---

## Recommendations

### 1. Интегрировать unused skills с высоким потенциалом

**task-decomposition + phase-execution:**
```
adaptive-workflow (minimal/standard/complex)
  └─> IF complex: task-decomposition
       └─> Создать phase files
            └─> FOR EACH phase: phase-execution
                 └─> Execute with checkpoints
```

**Выгода:** Систематическая декомпозиция больших задач на управляемые фазы.

**skill-generator:**
- Использовать в Template для генерации domain-specific skills
- Пример: Если проект использует FastAPI, генерировать `fastapi-development` skill

**prd-generator:**
- Интегрировать перед structured-planning для сложных задач
- Генерация PRD → structured-planning создаёт план из PRD

### 2. Очистить Template от missing skills

**Удалить ссылки на:**
- Project-specific skills (переместить в локальные .claude/skills/)
- ralph-loop как skill (заменить на external dependency)

**Обновить Template:**
```bash
# Найти все @skill:docker-management
grep -rn '@skill:docker-management' Template/

# Заменить на project-specific reference
# Или удалить, если не нужно
```

### 3. Документировать skill categories

Создать `skills/README.md` с категориями:

**Core Skills** (обязательны для Template):
- adaptive-workflow, thinking-framework, structured-planning, validation-framework

**Integration Skills** (опциональны, зависят от external dependencies):
- lsp-integration, context7-integration

**Workflow Skills** (для git и PR):
- git-workflow, pr-automation, code-review

**Utility Skills** (вспомогательные):
- error-handling, rollback-recovery, approval-gates, context-awareness

**Specialized Skills** (для специфичных задач):
- bash-development, isolated-environment, architecture-documentation, proxy-management

**Generator Skills** (для создания контента):
- skill-generator, prd-generator, task-decomposition, phase-execution

---

## Validation Script

Используйте `validate-template-skills.sh` для проверки ссылок:

```bash
# Запуск валидации
./validate-template-skills.sh

# Output:
# ✓ Найдено глобальных skills: 13
# ⏭️  Пропущено project-specific: 3
# ✗ Отсутствующих глобальных skills: 13
```

**Скрипт автоматически:**
- Находит все @skill:* ссылки в Template файлах
- Игнорирует project-specific skills (api-development, clickhouse-sql, frontend-development)
- Проверяет существование SKILL.md в глобальных skills
- Выводит список missing skills

---

## Next Steps

**Immediate (высокий приоритет):**
1. Заменить `@skill:ralph-loop` на external dependency reference в Template
2. Переместить project-specific skills из Template в локальные проекты
3. Документировать skill categories в skills/README.md

**Short-term (средний приоритет):**
4. Интегрировать task-decomposition в adaptive-workflow для complex tasks
5. Интегрировать phase-execution для пошагового выполнения фаз
6. Использовать skill-generator для генерации domain skills

**Long-term (низкий приоритет):**
7. Интегрировать prd-generator перед structured-planning
8. Создать centralized skills documentation hub

---

## References

- [validate-template-skills.sh](./validate-template-skills.sh) - Validation script
- [External Dependencies](.nvm-isolated/.claude-isolated/skills/_shared/external-dependencies.md) - External dependencies guide
- [Template](../../Notes/Work/ИИ/Claude code/Template) - Template files location
- [Global Skills](.nvm-isolated/.claude-isolated/skills/) - Global skills directory

---

## Version History

- **1.0.0** (2026-01-15): Initial skills coverage matrix
  - 21 global skills analyzed
  - 13 used, 8 unused
  - 13 missing skills identified
  - Recommendations for integration and cleanup
