# init_claude - Запуск Claude Code через прокси

> Автоматическая настройка прокси и запуск Claude Code. Введите настройки один раз - используйте многократно.

---

## Что это?

Утилита для быстрого запуска Claude Code через HTTP/SOCKS5 прокси с автоматическим сохранением настроек.

### Возможности

✅ Настройка прокси один раз
✅ Автоматическое сохранение credentials
✅ Безопасное хранение паролей
✅ Поддержка HTTP, HTTPS, SOCKS5
✅ Проверка подключения перед запуском

---

## Быстрый старт

**3 простых шага:**

```bash
# 1. Установить
cd /path/to/vless/scripts
sudo ./init_claude.sh --install

# 2. Настроить прокси (один раз)
init_claude
# Proxy URL: http://username:password@host:port

# 3. Использовать
init_claude  # Запускает с сохраненными настройками
```

---

## Установка

```bash
cd /path/to/vless/scripts
sudo ./init_claude.sh --install
```

После установки команда `init_claude` доступна из любой директории.

**Автоматическая установка зависимостей:**

При первой установке скрипт автоматически проверит и предложит установить:
- ✅ **Node.js и npm** (если отсутствуют) - через официальный репозиторий NodeSource
- ✅ **Claude Code** (если отсутствует) - через `npm install -g @anthropic-ai/claude-code`

Для каждой зависимости будет запрошено подтверждение.

**Проверка:**
```bash
init_claude --help
```

**Удаление:**
```bash
sudo init_claude --uninstall       # Удалить команду
init_claude --clear                # Очистить сохраненные настройки
```

---

## Изолированная установка (Рекомендуется)

Вместо системной установки можно использовать **изолированное окружение** в директории проекта. Это позволяет:

✅ Избежать конфликтов с системным NVM
✅ Обеспечить воспроизводимость установки
✅ Передавать конфигурацию через git (lockfile)
✅ Работать без sudo на других машинах

### Первая установка

```bash
# Установить NVM + Node.js + Claude Code в .nvm-isolated/
./init_claude.sh --isolated-install

# Это создаст:
# - .nvm-isolated/                    (~200-300MB, коммитится в git)
# - .nvm-isolated-lockfile.json       (коммитится в git)
```

### Проверка статуса

```bash
./init_claude.sh --check-isolated
# Показывает:
# - Статус изолированного окружения
# - Версии Node.js и Claude Code
# - Содержимое lockfile
```

### Установка на другой машине

```bash
# 1. Клонировать репозиторий (содержит .nvm-isolated/ и lockfile)
git clone <repo>
cd <repo>

# 2. Готово! Изолированное окружение уже включено в репозиторий
./init_claude.sh

# Альтернатива: переустановить из lockfile (если нужно обновить версии)
./init_claude.sh --install-from-lockfile
```

### Очистка

```bash
# Удалить .nvm-isolated/, сохранить lockfile
./init_claude.sh --cleanup-isolated

# Для переустановки:
./init_claude.sh --install-from-lockfile
```

### Как это работает

- **По умолчанию**: Скрипт автоматически использует `.nvm-isolated/` если он существует
- **Приоритет**: Изолированное окружение > Системный NVM > Системный Node.js
- **Lockfile**: JSON-файл с точными версиями (Node.js, Claude Code, NVM)
- **Git workflow**: Вся директория `.nvm-isolated/` коммитится (кроме cache файлов)

### Файлы

- `.nvm-isolated/` - изолированная установка NVM (~200-300MB, коммитится в git)
- `.nvm-isolated-lockfile.json` - lockfile с версиями (коммитится в git)
- `.claude_proxy_credentials` - прокси credentials (chmod 600, не коммитить)

**Примечание:** В `.gitignore` исключены только временные файлы (.cache/, .npm/, *.log)

---

## Использование

### Первый запуск

```bash
init_claude
```

Программа попросит ввести proxy URL в формате:
```
http://username:password@host:port
```

Пример: `http://alice:secret123@127.0.0.1:8118`

### Повторные запуски

```bash
init_claude
```

Автоматически использует сохраненные настройки. Если нужно изменить прокси, ответьте `n` на вопрос "Use saved proxy?"

### Дополнительные опции

```bash
# Установить прокси напрямую
init_claude --proxy http://user:pass@host:port

# Запуск БЕЗ прокси (прямое соединение)
init_claude --no-proxy

# Только протестировать подключение
init_claude --test

# Очистить сохраненные настройки
init_claude --clear

# Быстрый запуск (без проверки подключения)
init_claude --no-test

# Пропустить проверку прав (для работы в защищенных окружениях)
init_claude --dangerously-skip-permissions

# Передать аргументы в Claude Code
init_claude -- --model claude-3-opus
```

---

## Все команды

| Команда | Описание |
|---------|----------|
| `init_claude` | Запуск с сохраненными настройками |
| `init_claude -p URL` | Установить прокси напрямую |
| `init_claude --no-proxy` | Запуск БЕЗ прокси (прямое соединение) |
| `init_claude --test` | Проверить подключение |
| `init_claude --clear` | Очистить настройки |
| `init_claude --no-test` | Запуск без проверки |
| `init_claude --dangerously-skip-permissions` | Пропустить проверку прав (использовать осторожно) |
| `init_claude -- --model opus` | Передать аргументы в Claude Code |
| `sudo ./init_claude.sh --install` | Установить |
| `sudo init_claude --uninstall` | Удалить |
| `init_claude --help` | Справка |

---

## Формат proxy URL

```
protocol://username:password@host:port
```

**Поддерживаемые протоколы:** `http://`, `https://`, `socks5://`

**Примеры:**
- `http://alice:secret123@127.0.0.1:8118`
- `socks5://bob:pass456@proxy.example.com:1080`
- `http://127.0.0.1:8118` (без авторизации)

---

## Примеры использования

### Первая настройка

```bash
sudo ./init_claude.sh --install
init_claude
# Proxy URL: http://alice:secret@127.0.0.1:8118
```

### Ежедневное использование

```bash
init_claude
# Use saved proxy? (Y/n): [Enter]
```

### Смена прокси

```bash
init_claude
# Use saved proxy? (Y/n): n
# Proxy URL: [новый URL]
```

### Использование с внешним прокси

```bash
# Если есть прокси-сервер
init_claude --proxy http://username:password@host:port
```

### Запуск без прокси

```bash
# Если нужен прямой доступ к интернету (без прокси)
init_claude --no-proxy

# С дополнительными параметрами
init_claude --no-proxy -- --model claude-3-opus
```

---

## Troubleshooting

### Ошибка: "Invalid URL format"

Используйте формат: `protocol://user:pass@host:port`

Правильно: `http://alice:secret@127.0.0.1:8118`

### Ошибка: "Proxy test failed"

Прокси недоступен или неверный пароль.

**Решение:**
```bash
# Проверить прокси
curl -x http://user:pass@host:port https://www.google.com

# Проверить credentials
init_claude --show-password

# Очистить и ввести заново
init_claude --clear
```

### Ошибка: "Claude Code not found"

**При установке:**
Скрипт автоматически предложит установить Claude Code. Подтвердите установку (Y).

**Ручная установка:**
```bash
npm install -g @anthropic-ai/claude-code
```

### Ошибка: "npm not found"

**При установке:**
Скрипт автоматически предложит установить Node.js и npm. Подтвердите установку (Y).

**Ручная установка:**
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Проблемы с правами доступа

Если Claude Code выдает ошибки проверки прав:
```bash
init_claude --dangerously-skip-permissions
```

⚠️ **Используйте только в доверенных окружениях!**

### Как изменить прокси?

```bash
# Вариант 1
init_claude
# Use saved proxy? (Y/n): n

# Вариант 2
init_claude --clear
init_claude
```

### Проблемы с git push/pull через прокси

**Проблема:** `git push` выдает ошибку `Proxy CONNECT aborted`

**Причина:** Некоторые HTTP прокси не поддерживают HTTPS CONNECT для git операций, хотя отлично работают для Claude Code и curl.

**Решение:**

```bash
# Вариант 1: Временно отключить прокси для git
unset HTTPS_PROXY HTTP_PROXY NO_PROXY
git push origin master
git pull origin master

# Вариант 2: Использовать SSH вместо HTTPS
git remote set-url origin git@github.com:username/repo.git
git push origin master
```

**Важно:** Прокси credentials из `.claude_proxy_credentials` используются только скриптом `init_claude` и не влияют на git, пока вы не экспортируете переменные окружения вручную.

---

## Безопасность

✅ Пароли хранятся в файле с правами `600` (только владелец)
✅ Файл автоматически исключен из git
✅ Пароль маскируется в выводе: `user:****@host:port`

**Рекомендации:**
- Используйте отдельный пароль для прокси
- Очищайте credentials перед передачей проекта: `init_claude --clear`

---

**Справка:** `init_claude --help`
