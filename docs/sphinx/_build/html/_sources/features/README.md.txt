# Features Documentation

Документация дополнительных функций iclaude.sh.

## 📄 Доступные документы

### [Context Window Monitoring](context-monitoring.md)
Полное руководство по мониторингу заполненности контекстного окна Claude Code.

**📄 Доступные документы:**

1. **[CHEATSHEET.txt](CHEATSHEET.txt)** ⭐ **НАЧНИТЕ ЗДЕСЬ**
   - Быстрая ASCII шпаргалка для терминала (5 минут)
   - Таблица сравнения всех вариантов
   - Команды быстрого старта
   - Примеры output
   - Дерево решений

2. **[Полная документация](context-monitoring.md)**
   - 7 вариантов с подробным описанием
   - Диаграммы работы каждого варианта
   - Настройка и кастомизация
   - Troubleshooting

**Как использовать:**
```bash
# В терминале - быстрый reference
cat docs/features/CHEATSHEET.txt

# В редакторе - полная документация
less docs/features/context-monitoring.md
```

**⚡ Быстрый старт (30 секунд):**
```bash
# Рекомендуемый вариант - Combined (Startup + Alerts)
./iclaude.sh --install-context-monitor

# Запустить Claude Code
./iclaude.sh
```

**Что получите:**
- При запуске: красивый summary последней сессии
- Во время работы: уведомления при 80%/90%
```
⚠️  WARNING: Context usage: 161,450/200,000 tokens (80%)
```

---

## 🎯 Краткий обзор вариантов

| # | Вариант | Описание | Сложность | Для кого |
|---|---------|----------|-----------|----------|
| A | Threshold Alerts | Уведомления при 80%/90% | 🟢 Простой | Все |
| B | Always-On Status | Показывать % всегда | 🟢 Простой | Power users |
| C | Startup Summary | Статус при запуске | 🟢 Простой | Короткие сессии |
| **D** | **Combined** | **Запуск + алерты** | 🟡 **Средний** | **Рекомендуется** |
| E | Oh My Posh | Status line интеграция | 🟡 Средний | Rich UI |
| F | Live Dashboard | Отдельное окно monitor | 🟡 Средний | tmux users |
| G | OpenTelemetry | Prometheus + Grafana | 🔴 Сложный | Enterprise |

---

## 📚 Будущие документы

Планируется добавить:
- **Loop Mode Guide** - Автоматизация повторяющихся задач
- **Router Configuration** - Настройка альтернативных LLM провайдеров
- **LSP Integration** - Настройка Language Server Protocol
- **Proxy Configuration** - Продвинутая настройка HTTP/HTTPS прокси
- **Skills Development** - Создание custom skills для Claude Code

---

## 🤝 Вклад в документацию

Если у вас есть идеи или улучшения для документации:

1. Создайте Issue в репозитории
2. Или отправьте Pull Request
3. Или напишите в Discussions

**Формат документов**: Markdown с примерами кода и ASCII диаграммами.

---

**Последнее обновление**: 2026-02-10
