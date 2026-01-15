# Basic Usage Example - bash-development

## Scenario

Когда вам нужно разработать или отрефакторить bash-функцию для `init_claude.sh`, bash-development skill автоматизирует создание надёжного, тестируемого кода с error handling.

**Use cases:**
- Добавление новой функции в iclaude.sh
- Рефакторинг существующей bash-функции
- Исправление bug в bash коде

---

## Input

```json
{
  "task": "Добавить функцию для проверки версии gh CLI",
  "function_name": "check_gh_version",
  "requirements": [
    "Проверить, что gh установлен",
    "Получить версию через gh --version",
    "Сравнить с минимальной версией 2.0.0",
    "Вернуть 0 если версия >= 2.0.0, иначе 1"
  ]
}
```

---

## Execution

bash-development skill выполняет следующие шаги:

### Step 1: Анализ требований
- Определяет входные параметры (минимальная версия: 2.0.0)
- Определяет зависимости (gh CLI)
- Планирует error handling (gh not found, invalid version format)

### Step 2: Генерация функции
- Создаёт функцию с:
  - Валидацией параметров
  - Проверкой наличия gh
  - Парсингом версии
  - Сравнением версий
  - Error messages

### Step 3: Валидация
- ShellCheck для синтаксических ошибок
- Тестирование с разными версиями gh
- Проверка return codes (0/1)

---

## Output

```bash
# Сгенерированная функция
check_gh_version() {
    local min_version="${1:-2.0.0}"

    # Проверка установки gh
    if ! command -v gh &>/dev/null; then
        echo "❌ GitHub CLI (gh) не установлен" >&2
        return 1
    fi

    # Получение текущей версии
    local current_version
    current_version=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')

    if [[ -z "$current_version" ]]; then
        echo "❌ Не удалось получить версию gh" >&2
        return 1
    fi

    # Сравнение версий (semver)
    if [[ "$current_version" == "$min_version" ]]; then
        echo "✓ gh version $current_version (минимум: $min_version)"
        return 0
    fi

    # Разбор версий на компоненты
    local IFS='.'
    read -ra current <<< "$current_version"
    read -ra minimum <<< "$min_version"

    # Сравнение major.minor.patch
    for i in 0 1 2; do
        if [[ ${current[$i]:-0} -gt ${minimum[$i]:-0} ]]; then
            echo "✓ gh version $current_version (минимум: $min_version)"
            return 0
        elif [[ ${current[$i]:-0} -lt ${minimum[$i]:-0} ]]; then
            echo "❌ gh version $current_version < $min_version" >&2
            return 1
        fi
    done

    echo "✓ gh version $current_version (минимум: $min_version)"
    return 0
}
```

**Validation output:**
```
✓ ShellCheck: No errors
✓ Тест с gh 2.45.0: PASSED (return 0)
✓ Тест с gh 1.9.0: PASSED (return 1)
✓ Тест без gh: PASSED (return 1, error message)
```

---

## Explanation

### Что было сделано:

1. **Валидация параметров:**
   - `min_version` с default значением 2.0.0
   - Проверка наличия gh через `command -v`

2. **Error handling:**
   - gh не установлен → return 1 с error message
   - Не удалось получить версию → return 1
   - Stderr используется для error messages (`>&2`)

3. **Version comparison:**
   - Парсинг semver версий (major.minor.patch)
   - Покомпонентное сравнение
   - Return 0 если current >= minimum

4. **Best practices:**
   - Local variables
   - `set -euo pipefail` compatible
   - Informative output messages
   - Proper exit codes

### Key features:

- **Robustness:** Обрабатывает edge cases (gh not found, empty version)
- **Testability:** Чистые return codes (0/1)
- **Maintainability:** Понятная структура, комментарии
- **POSIX-compatible:** Работает в любой bash 4.0+

### Интеграция в iclaude.sh:

```bash
# В iclaude.sh добавить проверку перед использованием gh
if ! check_gh_version "2.0.0"; then
    echo "Обновите gh CLI до версии 2.0.0 или выше"
    exit 1
fi
```

---

## Related

- [bash-development/SKILL.md](../SKILL.md) - Full skill documentation
- [bash-development/rules/best-practices.md](../rules/best-practices.md) - Bash coding standards
