---
name: Bash Development
description: Разработка и рефакторинг bash-функций для init_claude.sh
version: 1.0.0
author: init_claude Team
tags: [bash, shell, scripting, development, refactoring]
dependencies: []
---

# Bash Development

Автоматизация разработки bash-функций в проекте `init_claude`. Этот скил помогает добавлять новые функции, рефакторить существующий код, работать с переменными окружения и обрабатывать ошибки в соответствии с best practices проекта.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Добавить новый флаг или опцию командной строки в init_claude.sh
- Создать новую bash-функцию с документацией
- Рефакторить существующую функцию
- Работать с переменными окружения (HTTPS_PROXY, HTTP_PROXY, NO_PROXY)
- Обработать ошибки и edge cases
- Работать с credentials файлами (.claude_proxy_credentials)
- Добавить цветной вывод (print_info, print_success, print_error)

Скил автоматически вызывается при запросах типа:
- "Добавь новый флаг --timeout для ограничения времени ожидания"
- "Создай функцию для ротации credentials"
- "Рефактори функцию launch_claude() для улучшения читаемости"
- "Добавь обработку ошибки при недоступности npm"

## Контекст проекта

Проект **init_claude** использует:

### Технологии
- **Bash 4+** с строгим режимом (`set -euo pipefail`)
- **Node.js/npm** для работы с Claude Code
- **curl** для тестирования прокси
- **openssl** для работы с сертификатами

### Архитектура скрипта
```
init_claude.sh
├── Константы и переменные (строки 12-29)
├── Утилиты вывода (print_info, print_success, print_error)
├── Валидация (validate_proxy_url, validate_certificate_file)
├── Парсинг (parse_proxy_url)
├── Управление credentials (save_credentials, load_credentials)
├── Конфигурация (configure_proxy_from_url)
├── Тестирование (test_proxy)
├── Установка (install_script, uninstall_script)
├── Управление Claude Code (get_claude_version, update_claude_code)
└── Главная функция (main)
```

### Стиль кода
- Все функции документированы с комментариями `#######`
- Переменные в `snake_case`, константы в `UPPER_CASE`
- Цветной вывод через функции `print_*`
- Ошибки обрабатываются с правильным `exit code`
- Пользовательский ввод всегда валидируется

### Переменные окружения
- `HTTPS_PROXY`, `HTTP_PROXY` - прокси URL
- `NO_PROXY` - список хостов без прокси
- `NODE_EXTRA_CA_CERTS` - путь к CA сертификату
- `NODE_TLS_REJECT_UNAUTHORIZED` - отключение TLS проверки (insecure)

## Шаблоны кода

### Шаблон 1: Создание новой bash-функции

```bash
#######################################
# {Краткое описание функции}
# Arguments:
#   $1 - {описание первого аргумента}
#   $2 - {описание второго аргумента}
# Returns:
#   0 - успех
#   1 - ошибка
#######################################
your_function_name() {
    local param1=$1
    local param2=${2:-default_value}

    # Валидация входных данных
    if [[ -z "$param1" ]]; then
        print_error "Parameter required"
        return 1
    fi

    # Основная логика
    print_info "Processing..."

    # ... ваш код ...

    # Успешное завершение
    print_success "Done"
    return 0
}
```

### Шаблон 2: Добавление нового флага

```bash
# В функции main(), в блоке while [[ $# -gt 0 ]]:

--your-flag)
    your_variable="$2"
    shift 2
    ;;
--your-boolean-flag)
    your_boolean=true
    shift
    ;;
```

### Шаблон 3: Работа с credentials файлом

```bash
# Чтение
if [[ -f "$CREDENTIALS_FILE" ]]; then
    source "$CREDENTIALS_FILE"
    # Используй переменные из файла
fi

# Запись
touch "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"
cat > "$CREDENTIALS_FILE" << EOF
KEY1=$value1
KEY2=$value2
EOF
```

### Шаблон 4: Обработка ошибок

```bash
if ! some_command; then
    print_error "Operation failed"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check X"
    echo "  2. Try Y"
    return 1
fi
```

### Шаблон 5: Работа с переменными окружения

```bash
# Установка
export VARIABLE_NAME="value"

# Проверка
if [[ -n "${VARIABLE_NAME:-}" ]]; then
    # Переменная установлена
fi

# Удаление
unset VARIABLE_NAME
```

### Шаблон 6: Пользовательский ввод

```bash
# Интерактивный ввод
if [ -t 0 ]; then
    read -p "Enter value: " user_input
else
    print_error "Cannot prompt in non-interactive mode"
    exit 1
fi

# Подтверждение
read -p "Continue? (Y/n): " confirm
if [[ -z "$confirm" ]] || [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Пользователь подтвердил
fi
```

## Проверочный чеклист

После создания/изменения bash-функции проверь:

- [ ] Функция документирована с комментарием `#######`
- [ ] Все параметры описаны в комментарии
- [ ] Используется `local` для локальных переменных
- [ ] Валидация входных данных присутствует
- [ ] Ошибки обрабатываются с правильным `return code`
- [ ] Используются функции `print_*` для вывода
- [ ] Код следует стилю проекта (`snake_case`)
- [ ] Edge cases обработаны
- [ ] Добавлен в `show_usage()` если это новый флаг
- [ ] Протестировано вручную (нет автотестов)

## Связанные скилы

- **proxy-management**: для функций работы с прокси
- **documentation** (будущий): для обновления README.md и CLAUDE.md

## Примеры использования

### Пример 1: Добавление нового флага --timeout

**Запрос:**
```
Добавь новый флаг --timeout <seconds> для ограничения времени ожидания при тестировании прокси.
По умолчанию используй 5 секунд.
```

**Claude использует bash-development скил:**
1. Добавляет переменную `timeout=5` в начало `main()`
2. Добавляет новый `case` в парсер:
```bash
--timeout)
    timeout="$2"
    shift 2
    ;;
```
3. Модифицирует функцию `test_proxy()` для использования `$timeout` вместо хардкода `-m 5`
4. Обновляет `show_usage()` с описанием нового флага

### Пример 2: Создание функции для ротации credentials

**Запрос:**
```
Создай функцию rotate_credentials() которая создает backup старых credentials перед сохранением новых.
Храни до 3 последних backups.
```

**Claude использует bash-development скил:**
1. Создает функцию с документацией:
```bash
#######################################
# Rotate credentials backups
# Keeps up to 3 most recent backups
#######################################
rotate_credentials() {
    # Если credentials существуют, создать backup
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        # Сдвинуть существующие backups
        [[ -f "${CREDENTIALS_FILE}.2" ]] && mv "${CREDENTIALS_FILE}.2" "${CREDENTIALS_FILE}.3"
        [[ -f "${CREDENTIALS_FILE}.1" ]] && mv "${CREDENTIALS_FILE}.1" "${CREDENTIALS_FILE}.2"

        # Создать новый backup
        cp "$CREDENTIALS_FILE" "${CREDENTIALS_FILE}.1"
    fi
}
```
2. Интегрирует вызов в `save_credentials()`

### Пример 3: Рефакторинг функции launch_claude()

**Запрос:**
```
Рефактори функцию launch_claude() - вынеси логику поиска claude в отдельную функцию find_claude_binary()
```

**Claude использует bash-development скил:**
1. Создает новую функцию `find_claude_binary()` с документацией
2. Переносит логику поиска из `launch_claude()` в `find_claude_binary()`
3. Упрощает `launch_claude()` для вызова `find_claude_binary()`

## Часто задаваемые вопросы

**Q: Как добавить новый цвет для вывода?**

A: Добавь константу в начало скрипта (после строки 12):
```bash
PURPLE='\033[0;35m'
```

**Q: Как обработать опциональные аргументы?**

A: Используй default value:
```bash
local optional_param=${2:-default_value}
```

**Q: Как проверить что команда существует?**

A:
```bash
if command -v npm &> /dev/null; then
    # npm доступен
fi
```

**Q: Как работать с путями содержащими пробелы?**

A: Всегда используй кавычки:
```bash
local path="/path/with spaces/file.txt"
cd "$path"  # ПРАВИЛЬНО
cd $path    # НЕПРАВИЛЬНО
```

**Q: Где добавлять новые функции в init_claude.sh?**

A: Следуй логической группировке:
- Утилиты вывода → строки 34-48
- Валидация → строки 50-100
- Парсинг → строки 140-180
- Credentials → строки 330-395
- Конфигурация → строки 465-515
- Тестирование → строки 615-670
- Установка → строки 1345-1415
- Запуск → строки 1420-1510

**Q: Нужно ли писать тесты?**

A: В проекте нет автоматизированных тестов. Протестируй вручную:
```bash
# Тест с разными флагами
./init_claude.sh --your-flag value --test

# Тест edge cases
./init_claude.sh --your-flag "" --test  # пустое значение
./init_claude.sh --test                  # без флага
```
