---
wiki_sources: ["lib/core/logging.sh"]
wiki_updated: 2026-05-05
wiki_status: mature
tags: ["bash", "module", "iclaude"]
aliases: ["lib/core/logging.sh", "print_info", "print_error", "print_warning", "print_success"]
---

# lib/core/logging.sh — модуль цветного вывода

Предоставляет четыре функции для стандартизированного вывода сообщений с цветовой кодировкой. Используется во всех модулях iclaude.

## Основные характеристики

| Функция | Цвет | Символ | Назначение |
|---------|------|--------|------------|
| `print_info(msg)` | Синий | ℹ | Информационное сообщение |
| `print_success(msg)` | Зелёный | ✓ | Успешное завершение операции |
| `print_warning(msg)` | Жёлтый | ⚠ | Предупреждение, не прерывающее выполнение |
| `print_error(msg)` | Красный | ✗ | Ошибка; обычно следует `return 1` |

Все функции выводят в stdout через `echo -e`. Цветовые коды (`RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`) определяются в `lib/core/init.sh` и экспортируются до загрузки logging.sh.

## Применение в контексте iclaude

Используется единообразно во всех модулях вместо прямых `echo`. Обеспечивает согласованный пользовательский интерфейс CLI.

Пример из `lib/proxy/configure.sh`:
```bash
print_info "Using proxy CA certificate: $PROXY_CA"
print_warning "TLS certificate verification disabled (insecure mode)"
print_success "Proxy connection successful (Anthropic API reachable)"
```

## Связанные концепции

- [[категории/core-категория]]
- [[модули/core-init]]
