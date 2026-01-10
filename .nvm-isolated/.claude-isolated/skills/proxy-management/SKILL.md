---
name: Proxy Management
description: Настройка, тестирование и отладка HTTP/HTTPS/SOCKS5 прокси для Claude Code
version: 1.0.0
author: init_claude Team
tags: [proxy, http, https, socks5, curl, tls, certificates, debugging]
dependencies: []
user-invocable: false
---

# Proxy Management

Автоматизация работы с прокси-конфигурациями в проекте `init_claude`. Этот скил помогает настраивать прокси, тестировать подключения, работать с TLS сертификатами и отлаживать проблемы с прокси.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Добавить поддержку нового типа прокси (например, SOCKS4)
- Отладить проблемы с прокси (timeout, auth failures, TLS errors)
- Улучшить валидацию proxy URL
- Работать с CA сертификатами (--proxy-ca)
- Тестировать подключение через прокси
- Добавить новые проверки в `test_proxy()`
- Изменить логику парсинга proxy URL

Скил автоматически вызывается при запросах типа:
- "Отладь проблему с HTTPS прокси и самоподписанным сертификатом"
- "Добавь поддержку SOCKS4 прокси"
- "Почему proxy test failed?"
- "Улучши валидацию proxy URL для поддержки IPv6"

## Контекст проекта

### Поддерживаемые протоколы
- **HTTP** (`http://`) - стандартный HTTP прокси
- **HTTPS** (`https://`) - HTTPS прокси с TLS
- **SOCKS5** (`socks5://`) - SOCKS5 прокси

### Формат proxy URL
```
protocol://[username:password@]host:port
```

Примеры:
- `http://alice:secret@127.0.0.1:8118`
- `https://user:pass@proxy.example.com:8118`
- `socks5://proxy.example.com:1080` (без auth)

### Переменные окружения для прокси
```bash
HTTPS_PROXY="http://user:pass@host:port"  # Для HTTPS соединений
HTTP_PROXY="http://user:pass@host:port"   # Для HTTP соединений
NO_PROXY="localhost,127.0.0.1"            # Хосты без прокси
```

### TLS безопасность для HTTPS прокси

**Проблема:** HTTPS прокси с самоподписанным сертификатом

**Решение 1: --proxy-ca (SECURE - рекомендуется)**
```bash
init_claude --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem
```
- Использует `NODE_EXTRA_CA_CERTS` для добавления ТОЛЬКО proxy сертификата
- TLS проверка работает для всех остальных соединений (Claude → Anthropic API)
- Безопасно

**Решение 2: --proxy-insecure (INSECURE - не рекомендуется)**
```bash
init_claude --proxy https://proxy:8118 --proxy-insecure
```
- Использует `NODE_TLS_REJECT_UNAUTHORIZED=0`
- Отключает TLS проверку для ВСЕХ Node.js соединений
- Опасно: атака Man-in-the-Middle возможна на API соединениях

### Функции для работы с прокси

**Ключевые функции в init_claude.sh:**
- `validate_proxy_url()` - валидация формата URL
- `parse_proxy_url()` - парсинг URL на компоненты
- `configure_proxy_from_url()` - установка переменных окружения
- `test_proxy()` - тестирование через curl
- `validate_certificate_file()` - валидация CA сертификата
- `export_proxy_certificate_help()` - инструкции по экспорту сертификата

## Шаблоны кода

### Шаблон 1: Парсинг proxy URL

```bash
# Вход: protocol://username:password@host:port
# Выход: protocol, username, password, host, port

parse_proxy_url() {
    local url=$1

    # Extract protocol
    local protocol=$(echo "$url" | grep -oP '^[^:]+')

    # Extract remainder after protocol://
    local remainder=$(echo "$url" | sed 's|^[^:]*://||')

    # Check if credentials present (contains @)
    if [[ "$remainder" =~ @ ]]; then
        # Extract user:pass
        local credentials=$(echo "$remainder" | grep -oP '^[^@]+')
        local username=$(echo "$credentials" | cut -d':' -f1)
        local password=$(echo "$credentials" | cut -d':' -f2-)

        # Extract host:port after @
        local hostport=$(echo "$remainder" | sed 's|^[^@]*@||')
        local host=$(echo "$hostport" | cut -d':' -f1)
        local port=$(echo "$hostport" | cut -d':' -f2)

        echo "protocol=$protocol"
        echo "username=$username"
        echo "password=$password"
        echo "host=$host"
        echo "port=$port"
    else
        # No credentials
        local host=$(echo "$remainder" | cut -d':' -f1)
        local port=$(echo "$remainder" | cut -d':' -f2)

        echo "protocol=$protocol"
        echo "username="
        echo "password="
        echo "host=$host"
        echo "port=$port"
    fi
}
```

### Шаблон 2: Валидация proxy URL с regex

```bash
validate_proxy_url() {
    local url=$1

    # Regex: http(s)://[user:pass@]host:port
    if [[ ! "$url" =~ ^(http|https|socks5)://.*:[0-9]+$ ]]; then
        return 1
    fi

    return 0
}
```

### Шаблон 3: Тестирование прокси через curl

```bash
test_proxy() {
    local proxy_url="${HTTPS_PROXY:-${HTTP_PROXY}}"

    # Prepare curl command
    local curl_opts=(-x "$proxy_url" -s -m 5 -o /dev/null -w "%{http_code}")

    # Configure TLS for HTTPS proxies
    if [[ "$proxy_url" =~ ^https:// ]]; then
        if [[ -n "${PROXY_CA_PATH:-}" ]] && [[ -f "${PROXY_CA_PATH}" ]]; then
            curl_opts+=(--proxy-cacert "${PROXY_CA_PATH}")
        elif [[ "${PROXY_INSECURE:-false}" == "true" ]]; then
            curl_opts+=(--proxy-insecure)
        fi
    fi

    # Test connection
    local http_code=$(curl "${curl_opts[@]}" https://www.google.com 2>/dev/null)

    if [[ "$http_code" == "200" ]]; then
        print_success "Proxy connection successful"
        return 0
    else
        print_warning "Proxy test failed: HTTP $http_code"
        return 1
    fi
}
```

### Шаблон 4: Валидация CA сертификата

```bash
validate_certificate_file() {
    local cert_path=$1

    # Check if file exists
    if [[ ! -f "$cert_path" ]]; then
        print_error "Certificate file not found: $cert_path"
        return 1
    fi

    # Check if file is readable
    if [[ ! -r "$cert_path" ]]; then
        print_error "Certificate file not readable: $cert_path"
        return 1
    fi

    # Check if file contains PEM certificate markers
    if ! grep -q "BEGIN CERTIFICATE" "$cert_path" 2>/dev/null; then
        print_error "Invalid certificate format (PEM expected): $cert_path"
        return 1
    fi

    # Verify with openssl (if available)
    if command -v openssl &> /dev/null; then
        if ! openssl x509 -in "$cert_path" -noout 2>/dev/null; then
            print_error "Certificate validation failed (openssl): $cert_path"
            return 1
        fi
    fi

    return 0
}
```

### Шаблон 5: Конфигурация переменных окружения для прокси

```bash
configure_proxy_from_url() {
    local proxy_url=$1
    local insecure=${2:-false}
    local ca_path=${3:-}

    # Set environment variables
    export HTTPS_PROXY="$proxy_url"
    export HTTP_PROXY="$proxy_url"
    export NO_PROXY="localhost,127.0.0.1"

    # Security configuration for HTTPS proxies
    if [[ "$proxy_url" =~ ^https:// ]]; then
        # Priority 1: Use CA certificate (SECURE)
        if [[ -n "$ca_path" ]] && [[ -f "$ca_path" ]]; then
            export NODE_EXTRA_CA_CERTS="$ca_path"
            print_success "Using proxy CA certificate: $ca_path"
        # Priority 2: Use insecure mode (INSECURE)
        elif [[ "$insecure" == "true" ]]; then
            export NODE_TLS_REJECT_UNAUTHORIZED=0
            print_warning "INSECURE MODE: TLS verification disabled"
        fi
    fi
}
```

### Шаблон 6: Экспорт proxy сертификата

```bash
# Method 1: Using openssl
openssl s_client -showcerts -connect proxy.example.com:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem

# Method 2: Using browser
# 1. Configure browser to use proxy
# 2. Visit any HTTPS site through proxy
# 3. View certificate in browser
# 4. Export as PEM format
```

## Проверочный чеклист

После настройки/изменения proxy конфигурации проверь:

- [ ] Proxy URL валидируется корректно (включая edge cases)
- [ ] Переменные окружения установлены правильно (HTTPS_PROXY, HTTP_PROXY, NO_PROXY)
- [ ] TLS сертификаты валидируются если используется --proxy-ca
- [ ] Test proxy проходит успешно (curl возвращает 200)
- [ ] Credentials сохраняются с правильными permissions (chmod 600)
- [ ] Пароли маскируются в выводе (****) если не указан --show-password
- [ ] Git operations работают (NO_PROXY включает localhost)
- [ ] Claude Code запускается с настроенным прокси
- [ ] Документация обновлена если добавлены новые флаги

## Связанные скилы

- **bash-development**: для создания новых функций работы с прокси
- **documentation** (будущий): для обновления troubleshooting секций

## Примеры использования

### Пример 1: Отладка проблемы с HTTPS прокси

**Запрос:**
```
Отладь проблему с HTTPS прокси. Test proxy failed с ошибкой "SSL certificate problem: self signed certificate".
Что делать?
```

**Claude использует proxy-management скил:**

1. **Анализирует проблему:**
   - Ошибка указывает на самоподписанный сертификат
   - Нужно либо использовать --proxy-ca, либо --proxy-insecure

2. **Предлагает решение:**
```bash
# Вариант 1 (SECURE - рекомендуется):
# Экспортируй proxy сертификат
openssl s_client -showcerts -connect proxy.example.com:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem

# Используй с --proxy-ca
init_claude --proxy https://user:pass@proxy.example.com:8118 --proxy-ca proxy-cert.pem

# Вариант 2 (INSECURE - только для тестирования):
init_claude --proxy https://user:pass@proxy.example.com:8118 --proxy-insecure
```

3. **Объясняет разницу:**
   - `--proxy-ca`: Добавляет только proxy сертификат, остальные проверки работают (SECURE)
   - `--proxy-insecure`: Отключает ВСЕ TLS проверки, включая Claude → Anthropic API (INSECURE)

### Пример 2: Добавление поддержки SOCKS4

**Запрос:**
```
Добавь поддержку SOCKS4 прокси в init_claude.sh
```

**Claude использует proxy-management + bash-development скилы:**

1. Модифицирует `validate_proxy_url()` для поддержки `socks4://`:
```bash
if [[ ! "$url" =~ ^(http|https|socks5|socks4)://.*:[0-9]+$ ]]; then
```

2. Обновляет `parse_proxy_url()` для обработки `socks4://` протокола

3. Добавляет в `show_usage()` описание socks4 в примерах

4. Обновляет README.md и CLAUDE.md

### Пример 3: Улучшение валидации для IPv6

**Запрос:**
```
Улучши валидацию proxy URL для поддержки IPv6 адресов (например, http://[::1]:8118)
```

**Claude использует proxy-management + bash-development скилы:**

1. Модифицирует regex в `validate_proxy_url()`:
```bash
# Old regex не поддерживает IPv6
^(http|https|socks5)://.*:[0-9]+$

# New regex с поддержкой IPv6
^(http|https|socks5)://((\[[0-9a-fA-F:]+\])|([^:]+)):[0-9]+$
```

2. Обновляет `parse_proxy_url()` для правильного парсинга IPv6 в квадратных скобках

3. Добавляет примеры в документацию:
```bash
http://[::1]:8118                          # IPv6 localhost
http://user:pass@[2001:db8::1]:8118      # IPv6 with auth
```

### Пример 4: Добавление теста DNS resolution

**Запрос:**
```
Добавь в test_proxy() проверку что прокси-хост резолвится в DNS перед попыткой подключения
```

**Claude использует proxy-management + bash-development скилы:**

1. Создает новую функцию `test_dns_resolution()`:
```bash
#######################################
# Test if proxy host resolves in DNS
# Arguments:
#   $1 - proxy host
# Returns:
#   0 - resolves
#   1 - does not resolve
#######################################
test_dns_resolution() {
    local host=$1

    if host "$host" &> /dev/null || nslookup "$host" &> /dev/null; then
        return 0
    else
        return 1
    fi
}
```

2. Интегрирует в `test_proxy()`:
```bash
test_proxy() {
    # ... existing code ...

    # Parse host from proxy URL
    local host=$(echo "$proxy_url" | sed -E 's|.*://([^:@]+:)?([^:@]+@)?([^:]+):.*|\3|')

    # Test DNS first
    if ! test_dns_resolution "$host"; then
        print_error "Proxy host does not resolve: $host"
        echo ""
        echo "  Check:"
        echo "  - Host name is correct"
        echo "  - DNS servers are configured"
        echo "  - /etc/hosts contains entry"
        return 1
    fi

    # ... rest of test_proxy ...
}
```

## Часто задаваемые вопросы

**Q: Почему proxy test failed с HTTP 407?**

A: HTTP 407 = Proxy Authentication Required. Проблемы:
- Неверный username/password
- Credentials не переданы в URL
- Прокси требует другой метод аутентификации

Решение:
```bash
# Проверь credentials
init_claude --show-password

# Очисти и введи заново
init_claude --clear
init_claude
```

**Q: Почему proxy test failed с HTTP 000?**

A: HTTP 000 = Connection failed/timeout. Проблемы:
- Прокси недоступен или выключен
- Firewall блокирует соединение
- Неверный host/port
- Для HTTPS прокси: проблема с TLS сертификатом

Решение:
```bash
# Проверь доступность прокси
telnet proxy.example.com 8118

# Проверь с curl напрямую
curl -x http://user:pass@proxy:8118 https://www.google.com -v

# Для HTTPS прокси используй --proxy-ca
init_claude --proxy https://proxy:8118 --proxy-ca cert.pem
```

**Q: Как экспортировать proxy сертификат из браузера?**

A:
1. Настрой браузер использовать прокси
2. Зайди на любой HTTPS сайт (например, https://google.com)
3. Кликни на иконку замка в адресной строке
4. "Просмотр сертификата" → найди сертификат прокси (не сайта!)
5. Экспорт → выбери формат PEM/Base64
6. Сохрани как `proxy-cert.pem`

**Q: Как проверить что Claude Code использует прокси?**

A: После запуска init_claude проверь:
```bash
# Переменные окружения установлены
echo $HTTPS_PROXY
echo $HTTP_PROXY

# Проверь логи Claude (если есть ошибки подключения, прокси не работает)
```

**Q: В чем разница между HTTP и HTTPS прокси?**

A:
- **HTTP прокси** (`http://`): Обычный прокси без шифрования
- **HTTPS прокси** (`https://`): Соединение с прокси зашифровано через TLS

Важно: И HTTP, и HTTPS прокси могут проксировать HTTPS трафик (через CONNECT метод).

**Q: Почему git push не работает через прокси?**

A: Некоторые HTTP прокси не поддерживают CONNECT метод для git+https. Решения:
```bash
# Вариант 1: Временно отключить прокси
unset HTTPS_PROXY HTTP_PROXY
git push

# Вариант 2: Использовать git+ssh вместо https
git remote set-url origin git@github.com:user/repo.git
git push
```

**Q: Как добавить больше хостов в NO_PROXY?**

A: Модифицируй `configure_proxy_from_url()`:
```bash
export NO_PROXY="localhost,127.0.0.1,.internal,.local"
```
