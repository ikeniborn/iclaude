# Настройка прокси

Руководство по настройке HTTP/HTTPS прокси для Claude Code.

---

## Быстрый старт

```bash
# Настроить HTTPS прокси
./iclaude.sh --proxy https://user:pass@proxy.example.com:8118

# Настроить HTTP прокси (только localhost)
./iclaude.sh --proxy http://localhost:8118

# Тестировать подключение
./iclaude.sh --test

# Запустить без прокси
./iclaude.sh --no-proxy
```

---

## Поддержка протоколов

| Протокол | Статус | Рекомендация |
|----------|--------|--------------|
| **HTTPS** | ✅ Полная поддержка | **✅ Рекомендуется** |
| **HTTP** | ✅ Полная поддержка | ⚠️ Только для localhost |
| **SOCKS5** | ❌ **НЕ поддерживается** | ❌ Вызывает краш приложения |

---

## HTTPS прокси (рекомендуется)

### С сертификатом (безопасно)

```bash
# Экспортировать сертификат прокси
openssl s_client -showcerts -connect proxy:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem

# Использовать с --proxy-ca
./iclaude.sh --proxy https://proxy:8118 --proxy-ca ./proxy-cert.pem
```

### Без проверки сертификата (небезопасно)

```bash
# Отключить проверку TLS (не рекомендуется)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

**⚠️ Важно:** Используйте `--proxy-ca` вместо `--proxy-insecure` для безопасности.

---

## HTTP прокси (только для localhost)

```bash
# Для локальной разработки
./iclaude.sh --proxy http://localhost:8118
```

**⚠️ Важно:**
- HTTP прокси небезопасен для удаленных серверов
- Используйте только для локального прокси (localhost)
- Весь трафик передается открытым текстом

---

## SOCKS5 прокси (НЕ РАБОТАЕТ)

**Статус:** Полностью не поддерживается (ограничение библиотеки undici)

### Обходные пути

**Вариант 1: Использовать HTTP/HTTPS**
```bash
./iclaude.sh --proxy https://proxy:8118
```

**Вариант 2: Privoxy как переходник**
```bash
# Установить privoxy
sudo apt install privoxy

# Настроить /etc/privoxy/config
echo "forward-socks5 / 127.0.0.1:1080 ." | sudo tee -a /etc/privoxy/config

# Перезапустить
sudo systemctl restart privoxy

# Использовать privoxy как HTTP прокси
./iclaude.sh --proxy http://127.0.0.1:8118
```

**Вариант 3: LLM Gateway**
- Использовать LiteLLM Gateway с поддержкой SOCKS5
- См. https://docs.litellm.ai/

---

## Команды управления прокси

```bash
# Изменить прокси
./iclaude.sh --proxy http://new:proxy@host:port

# Запустить без прокси
./iclaude.sh --no-proxy

# Тестировать прокси без запуска Claude
./iclaude.sh --test

# Очистить сохраненные credentials
./iclaude.sh --clear

# Восстановить git proxy из backup
./iclaude.sh --restore-git-proxy
```

---

## Формат proxy URL

```
http://username:password@host:port
https://username:password@host:port
```

**Примеры:**
```bash
http://alice:secret123@127.0.0.1:8118
https://user:pass@proxy.example.com:8118
```

**⚠️ Важно:** Специальные символы в пароле нужно URL-кодировать:
- `@` → `%40`
- `:` → `%3A`
- `/` → `%2F`

---

## Безопасность

### Критическая уязвимость undici

Библиотека undici **не проверяет сертификаты** целевых HTTPS серверов при работе через прокси ([HackerOne #1583680](https://hackerone.com/reports/1583680)).

**Это означает:**
- Прокси-сервер может видеть и модифицировать все запросы к Anthropic API
- Прокси видит ваши API ключи, код проекта, персональные данные
- **Используйте только доверенные прокси-серверы**

### Рекомендации

✅ **Используйте:**
- HTTPS прокси с корпоративным сертификатом
- HTTP прокси только для localhost
- Доверенные прокси-серверы

❌ **НЕ используйте:**
- HTTP прокси через интернет
- Недоверенные прокси-серверы
- `--proxy-insecure` в production

---

## Troubleshooting

### Прокси не работает

```bash
# Тестировать подключение
./iclaude.sh --test

# Очистить настройки и ввести заново
./iclaude.sh --clear
./iclaude.sh
```

### HTTPS с самоподписанным сертификатом

**Решение (безопасно):**
```bash
openssl s_client -showcerts -connect proxy:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem
./iclaude.sh --proxy https://proxy:8118 --proxy-ca ./proxy-cert.pem
```

**Решение (небезопасно):**
```bash
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

### SOCKS5 краш приложения

**Ошибка:**
```
InvalidArgumentError: Invalid URL protocol: the URL must start with 'http:' or 'https:'
```

**Решение:** Используйте Privoxy как переходник (см. выше)

---

## Источники

- [Claude Code: Corporate Proxy](https://docs.claude.com/en/docs/claude-code/corporate-proxy)
- [GitHub Issue #3387](https://github.com/anthropics/claude-code/issues/3387)
- [HackerOne Report #1583680](https://hackerone.com/reports/1583680)

---

## Дополнительная информация

- [Конфигурация](./CONFIGURATION.md) - все команды
- [Use Cases](./USE_CASES.md) - практические примеры установки и использования
