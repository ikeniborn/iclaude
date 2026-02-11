# Context Window Monitoring для iclaude.sh

Документация вариантов мониторинга заполненности контекстного окна Claude Code.

## 📊 Обзор проблемы

**Контекстное окно** (context window) - это ограниченный объем памяти, который Claude может использовать в одной сессии:
- **Sonnet 4.5**: 200,000 токенов (~150,000 слов)
- **Opus 4.6**: 200,000 токенов
- **Haiku 4.5**: 200,000 токенов

**Проблема**: При достижении лимита Claude теряет контекст начала разговора (автоматическая компрессия) или прерывается работа. Пользователь не видит заполненность в реальном времени.

**Решение**: Автоматический мониторинг и уведомления о приближении к лимиту.

---

## 🎯 Варианты реализации

### Вариант A: Threshold-Based Alerts (Рекомендуется для начала)

**Концепция**: "Молчит, пока не достигнут порог"

#### Как работает
1. Hook `postToolUse.hook.sh` срабатывает после каждого tool call
2. Парсит `.claude.json` → извлекает `lastTotalInputTokens` + `lastTotalOutputTokens`
3. Вычисляет процент: `(total_tokens / 200000) * 100`
4. Если `percent >= 80%` → выводит WARNING в stderr
5. Если `percent >= 90%` → выводит CRITICAL в stderr

#### Пример вывода

**До достижения порога** (< 80%):
```
(ничего не показывается)
```

**При 80% (160k токенов)**:
```
⚠️  WARNING: Context usage: 161,450/200,000 tokens (80%) - Approaching limit
```

**При 90% (180k токенов)**:
```
🔴 CRITICAL: Context usage: 182,300/200,000 tokens (91%) - Consider starting new session
```

#### Где отображается
- В Claude Code UI (stderr автоматически показывается как системное сообщение)
- В системных уведомлениях (если установлен `notify-send` на Linux)
- В логе `/tmp/claude-context-monitor.log`

#### Диаграмма работы
```
┌────────────────────┐
│ Claude Code        │
│ (tool execution)   │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ postToolUse hook   │
│ (triggered auto)   │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ Parse .claude.json │
│ Extract tokens     │
└─────────┬──────────┘
          │
          ▼
    [Calculate %]
          │
     ┌────┴────┐
     │< 80%?   │──── Yes ───> (Silent)
     └────┬────┘
          │ No
          ▼
┌────────────────────┐
│ Show alert (stderr)│
│ + notify-send      │
└────────────────────┘
```

#### Установка
```bash
./iclaude.sh --install-context-monitor
```

#### Конфигурация

Пороги задаются в hook файле (`.nvm-isolated/.claude-isolated/hooks/postToolUse.hook.sh`):
```bash
# Configuration
CONTEXT_LIMIT=200000       # Sonnet 4.5 limit
WARNING_THRESHOLD=80       # Warn at 80%
CRITICAL_THRESHOLD=90      # Critical at 90%
```

**Кастомизация**:
```bash
# Более агрессивные предупреждения
WARNING_THRESHOLD=70       # Warn at 70% (140k tokens)
CRITICAL_THRESHOLD=85      # Critical at 85% (170k tokens)

# Консервативные предупреждения
WARNING_THRESHOLD=90       # Warn only at 90%
CRITICAL_THRESHOLD=95      # Critical at 95%
```

#### Преимущества ✅
- ✅ Минимальное вторжение в UX (не отвлекает)
- ✅ Нулевые внешние зависимости (только jq)
- ✅ Автоматическая установка через iclaude.sh
- ✅ Работает БЕЗ модификации Claude Code
- ✅ Non-blocking (не останавливает работу)

#### Недостатки ⚠️
- ⚠️ Не показывает текущий % до порога
- ⚠️ Обновляется только после завершения turn (не real-time streaming)
- ⚠️ Требует jq для парсинга JSON

#### Рекомендуется для
- Пользователей, которые хотят "просто предупреждения"
- Длительных coding сессий (несколько часов)
- Автоматизированных workflow (CI/CD, loop mode)

---

### Вариант B: Always-On Status Bar

**Концепция**: "Показывать процент постоянно"

#### Как работает
Та же логика, что в Варианте A, но hook выводит статус **при каждом tool call** независимо от порога.

#### Модификация hook
```bash
# Всегда показывать статус (закомментировать условие)
# if [[ $PERCENT -ge $WARNING_THRESHOLD ]]; then
    echo "[Context: $(format_number $TOTAL_TOKENS)/$CONTEXT_LIMIT (${PERCENT}%)]" >&2
# fi
```

#### Пример вывода

**После каждого действия Claude**:
```
[Context: 12,450/200,000 (6%)]
[Context: 18,720/200,000 (9%)]
[Context: 25,300/200,000 (12%)]
...
[Context: 161,450/200,000 (80%)] ⚠️
[Context: 182,300/200,000 (91%)] 🔴
```

#### Цветовая индикация

Можно добавить ANSI цвета в stderr:
```bash
if (( PERCENT < 50 )); then
    color="\e[32m"  # Green
elif (( PERCENT < 80 )); then
    color="\e[33m"  # Yellow
else
    color="\e[31m"  # Red
fi
echo -e "${color}[Context: $TOTAL_TOKENS/$CONTEXT_LIMIT (${PERCENT}%)]\\e[0m" >&2
```

#### Преимущества ✅
- ✅ Постоянная видимость прогресса
- ✅ Можно планировать длинные операции
- ✅ Цветовая индикация "на светофоре"

#### Недостатки ⚠️
- ⚠️ "Шумит" в интерфейсе при каждом действии
- ⚠️ Может отвлекать от coding flow
- ⚠️ Занимает место в Claude Code UI

#### Рекомендуется для
- Power users, которые хотят видеть всё
- Работы с очень большими контекстами (архитектурное планирование)
- Debugging сессий с высокой токен-нагрузкой

---

### Вариант C: Startup Summary

**Концепция**: "Показать статус 1 раз при запуске iclaude.sh"

#### Как работает
1. При запуске `./iclaude.sh` скрипт читает `.claude.json`
2. Извлекает данные **последней завершённой сессии** для текущего проекта
3. Показывает красивый summary перед запуском Claude Code

#### Пример вывода

```bash
$ ./iclaude.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 📊 Last Session Context Usage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project:    /home/ikeniborn/Documents/Project/iclaude
Tokens:     47,602 / 200,000 (23%)
Input:      6,398 tokens
Output:     23,349 tokens
Cache Read: 2,485,530 tokens
Status:     ✅ Normal

[████████░░░░░░░░░░░░░░░░░░] 23%

💡 Tip: Run /context inside Claude to see real-time usage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Claude Code v2.1.15] [Token expires: 6d 14h]

Launching Claude Code...
```

#### Реализация в iclaude.sh

```bash
# Добавить в main() перед launch
show_context_startup_summary() {
    local project_path=$(pwd)
    local claude_json="${CLAUDE_DIR:-$HOME/.claude}/.claude.json"

    if [[ ! -f "$claude_json" ]] || ! command -v jq &>/dev/null; then
        return 0
    fi

    # Extract last session data
    local input_tokens=$(jq -r --arg path "$project_path" \
        '.projects[$path].lastTotalInputTokens // 0' "$claude_json")
    local output_tokens=$(jq -r --arg path "$project_path" \
        '.projects[$path].lastTotalOutputTokens // 0' "$claude_json")
    local cache_read=$(jq -r --arg path "$project_path" \
        '.projects[$path].lastTotalCacheReadInputTokens // 0' "$claude_json")

    local total_tokens=$((input_tokens + output_tokens))
    local percent=$((total_tokens * 100 / 200000))

    # Color coding
    local color status
    if (( percent < 50 )); then
        color="\e[32m"  # Green
        status="✅ Normal"
    elif (( percent < 80 )); then
        color="\e[33m"  # Yellow
        status="⚠️  Moderate"
    else
        color="\e[31m"  # Red
        status="🔴 High"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 📊 Last Session Context Usage"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "Project:    %s\n" "$project_path"
    printf "${color}Tokens:     %'d / %'d (%d%%)\\e[0m\n" \
        "$total_tokens" 200000 "$percent"
    printf "Input:      %'d tokens\n" "$input_tokens"
    printf "Output:     %'d tokens\n" "$output_tokens"
    printf "Cache Read: %'d tokens\n" "$cache_read"
    printf "Status:     %s\n" "$status"
    echo ""

    # ASCII progress bar
    local bar_width=30
    local filled=$((percent * bar_width / 100))
    local empty=$((bar_width - filled))
    printf "[%s%s] %d%%\n" \
        "$(printf '█%.0s' $(seq 1 $filled))" \
        "$(printf '░%.0s' $(seq 1 $empty))" \
        "$percent"

    echo ""
    echo "💡 Tip: Run /context inside Claude to see real-time usage"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}
```

#### Преимущества ✅
- ✅ Информативно перед началом работы
- ✅ Не мешает во время сессии
- ✅ Красивый ASCII progress bar
- ✅ Понятно с первого взгляда

#### Недостатки ⚠️
- ⚠️ Показывает данные ПРОШЛОЙ сессии (не текущей)
- ⚠️ Не помогает во время длинной сессии
- ⚠️ Нужно перезапускать iclaude.sh для обновления

#### Рекомендуется для
- Пользователей, работающих короткими сессиями (1-2 часа)
- Awareness перед началом работы
- Визуально привлекательный UX

---

### Вариант D: Combined Approach (Рекомендуется)

**Концепция**: "Лучшее из обоих миров"

#### Комбинация
- **Вариант C** (Startup Summary) → показать при запуске
- **Вариант A** (Threshold Alerts) → уведомления во время работы

#### Поведение
1. При `./iclaude.sh` → красивый summary последней сессии
2. Claude Code запускается
3. Во время работы: молчит до 80%
4. При 80% → WARNING в UI
5. При 90% → CRITICAL в UI

#### Пример full flow

**Terminal при запуске**:
```bash
$ ./iclaude.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 📊 Last Session Context Usage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project:    /home/user/myproject
Tokens:     47,602 / 200,000 (23%)
Status:     ✅ Normal
[████████░░░░░░░░░░░░░░░░░░] 23%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Launching Claude Code...
```

**Claude Code UI во время работы** (при достижении 80%):
```
⚠️  WARNING: Context usage: 161,450/200,000 tokens (80%) - Approaching limit
```

#### Преимущества ✅
- ✅ Best of both worlds
- ✅ Awareness перед началом + защита во время работы
- ✅ Не отвлекает до критического момента
- ✅ Визуально приятный UX

#### Недостатки ⚠️
- ⚠️ Немного сложнее в реализации (2 компонента)

#### Рекомендуется для
- **Большинства пользователей** (универсальное решение)
- Production use cases
- Баланс между информативностью и UX

---

### Вариант E: Oh My Posh Status Line (Advanced)

**Концепция**: "Интеграция с терминальным prompt"

#### Как работает
Oh My Posh - это инструмент для кастомизации prompt в терминале. Claude Code имеет встроенную поддержку сегмента для Oh My Posh.

#### Настройка

1. Установить Oh My Posh:
```bash
# Linux
curl -s https://ohmyposh.dev/install.sh | bash -s

# Or via package manager
sudo apt install oh-my-posh  # Debian/Ubuntu
```

2. Создать конфиг для Claude Code segment:
```bash
mkdir -p ~/.config/ohmyposh
cat > ~/.config/ohmyposh/claude-theme.json <<'EOF'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 2,
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        {
          "type": "claude",
          "style": "diamond",
          "foreground": "#FFFFFF",
          "background": "#FF6B35",
          "leading_diamond": "",
          "trailing_diamond": "",
          "template": "{{ .Model }} [{{ .UsageGauge }}] {{ .CostString }}"
        }
      ]
    }
  ]
}
EOF
```

3. Включить в Claude Code settings:
```bash
# Добавить в .nvm-isolated/.claude-isolated/settings.json
{
  "statusLine": {
    "type": "command",
    "command": "oh-my-posh print primary --config ~/.config/ohmyposh/claude-theme.json --shell bash",
    "padding": 0
  }
}
```

#### Пример вывода в prompt

**Terminal prompt внутри Claude Code**:
```
 sonnet-4.5 │ [████████░░░░░░░░░░] 45k/200k (23%) │ $0.24

You:
```

#### Преимущества ✅
- ✅ Real-time обновление в status line
- ✅ Красивая визуализация (Unicode блоки █▓▒░)
- ✅ Показывает модель + стоимость + токены
- ✅ Официальная поддержка от Oh My Posh

#### Недостатки ⚠️
- ⚠️ Требует установки Oh My Posh
- ⚠️ Занимает место в status line
- ⚠️ Не работает в external terminal (только внутри Claude Code)

#### Рекомендуется для
- Power users, уже использующих Oh My Posh
- Пользователей, которые хотят rich UI
- Работы исключительно внутри Claude Code terminal

---

### Вариант F: Real-Time Dashboard (Expert)

**Концепция**: "Отдельное окно с live monitoring"

#### Как работает
1. Запускается отдельный скрипт `claude-monitor.sh` в фоне
2. Использует `inotifywait` для отслеживания изменений `.claude.json`
3. Рисует live dashboard в отдельном terminal window/pane

#### Установка

**Зависимости**:
```bash
# Linux
sudo apt install inotify-tools

# macOS
brew install fswatch  # Аналог inotifywait
```

**Скрипт мониторинга** (`tools/claude-monitor.sh`):
```bash
#!/bin/bash
# Real-time context monitor for Claude Code

CLAUDE_JSON="${CLAUDE_DIR:-$HOME/.claude}/.claude.json"
PROJECT_PATH=$(pwd)

# Clear screen and show header
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Claude Code - Context Monitor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Watch for changes
inotifywait -m -e modify "$CLAUDE_JSON" | while read; do
    # Extract tokens
    TOTAL_INPUT=$(jq -r --arg path "$PROJECT_PATH" \
        '.projects[$path].lastTotalInputTokens // 0' "$CLAUDE_JSON" 2>/dev/null)
    TOTAL_OUTPUT=$(jq -r --arg path "$PROJECT_PATH" \
        '.projects[$path].lastTotalOutputTokens // 0' "$CLAUDE_JSON" 2>/dev/null)
    CACHE_READ=$(jq -r --arg path "$PROJECT_PATH" \
        '.projects[$path].lastTotalCacheReadInputTokens // 0' "$CLAUDE_JSON" 2>/dev/null)

    TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))
    PERCENT=$((TOTAL_TOKENS * 100 / 200000))

    # Color coding
    if (( PERCENT < 50 )); then
        color="\e[32m"  # Green
    elif (( PERCENT < 80 )); then
        color="\e[33m"  # Yellow
    else
        color="\e[31m"  # Red
    fi

    # Clear previous line and redraw
    tput cup 4 0
    tput el
    printf "${color}Context: %'d / 200,000 tokens (%d%%)\\e[0m\n" \
        "$TOTAL_TOKENS" "$PERCENT"

    # ASCII progress bar
    tput el
    local bar_width=40
    local filled=$((PERCENT * bar_width / 100))
    local empty=$((bar_width - filled))
    printf "[%s%s]\n" \
        "$(printf '█%.0s' $(seq 1 $filled))" \
        "$(printf '░%.0s' $(seq 1 $empty))"

    tput el
    printf "Input:      %'d tokens\n" "$TOTAL_INPUT"
    tput el
    printf "Output:     %'d tokens\n" "$TOTAL_OUTPUT"
    tput el
    printf "Cache Read: %'d tokens\n" "$CACHE_READ"

    # Timestamp
    tput el
    echo ""
    tput el
    printf "Last update: %s\n" "$(date '+%H:%M:%S')"
done
```

**Запуск в tmux/terminal split**:
```bash
# Вариант 1: tmux split
tmux split-window -h ./tools/claude-monitor.sh

# Вариант 2: Отдельный terminal
gnome-terminal -- ./tools/claude-monitor.sh

# Вариант 3: Автоматически при запуске iclaude.sh
./iclaude.sh --enable-live-monitor
```

#### Пример вывода

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Claude Code - Context Monitor
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Context: 47,602 / 200,000 tokens (23%)
[█████████░░░░░░░░░░░░░░░░░░░░░░░░░░░]
Input:      6,398 tokens
Output:     23,349 tokens
Cache Read: 2,485,530 tokens

Last update: 14:32:18
```

#### Преимущества ✅
- ✅ Максимум информации в реальном времени
- ✅ Отдельное окно (не мешает работе в Claude)
- ✅ Красивая визуализация с цветами
- ✅ Автообновление при каждом turn

#### Недостатки ⚠️
- ⚠️ Требует inotify-tools/fswatch
- ⚠️ Занимает отдельный terminal window/pane
- ⚠️ Сложная настройка для новичков
- ⚠️ Обновляется только после turn (не streaming)

#### Рекомендуется для
- Expert users с tmux/terminal multiplexer
- Работы с несколькими проектами одновременно
- Debugging и performance analysis

---

### Вариант G: OpenTelemetry Integration (Enterprise)

**Концепция**: "Профессиональный monitoring с метриками"

#### Как работает
Claude Code имеет встроенную поддержку OpenTelemetry для экспорта метрик в Prometheus, Grafana, Datadog, и другие системы.

#### Установка

1. Включить telemetry в iclaude.sh:
```bash
# Добавить в iclaude.sh перед launch
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=prometheus
export OTEL_LOGS_EXPORTER=console
export OTEL_METRIC_EXPORT_INTERVAL=10000    # 10 sec
export ANTHROPIC_LOG=debug
```

2. Запустить Prometheus + Grafana:
```yaml
# docker-compose.yml
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  prometheus-data:
  grafana-data:
```

3. Настроить Prometheus для scraping:
```yaml
# prometheus.yml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: 'claude-code'
    static_configs:
      - targets: ['host.docker.internal:9464']
```

4. Создать Grafana dashboard для визуализации.

#### Метрики доступные для мониторинга
- `claude_code_tokens_input_total` - Входные токены
- `claude_code_tokens_output_total` - Выходные токены
- `claude_code_tokens_cache_read_total` - Cache read токены
- `claude_code_cost_usd_total` - Стоимость в USD
- `claude_code_api_duration_ms` - Длительность API вызовов
- `claude_code_tool_duration_ms` - Длительность tool execution

#### Пример Grafana dashboard

**Metrics панели**:
1. **Token Usage Over Time** (line chart)
   - Input tokens (blue)
   - Output tokens (green)
   - Total (red line at 200k limit)

2. **Context Window Gauge** (gauge panel)
   - Current: 47,602 / 200,000
   - Thresholds: Green < 50%, Yellow < 80%, Red >= 80%

3. **Cost Tracking** (stat panel)
   - Current session cost: $2.81
   - Today's total: $15.42

4. **Cache Efficiency** (pie chart)
   - Cache hits: 2.4M tokens
   - Direct input: 6.3k tokens
   - Hit rate: 99.7%

#### Преимущества ✅
- ✅ Профессиональный monitoring stack
- ✅ Исторические данные (time-series DB)
- ✅ Красивые dashboards (Grafana)
- ✅ Alerts через Alertmanager
- ✅ Интеграция с Slack/email/PagerDuty

#### Недостатки ⚠️
- ⚠️ Очень сложная настройка
- ⚠️ Требует Docker/Kubernetes
- ⚠️ Overhead на систему (Prometheus + Grafana)
- ⚠️ Overkill для личного использования

#### Рекомендуется для
- Enterprise teams
- DevOps/SRE специалистов
- Управления бюджетом на большом масштабе
- Compliance и auditing

---

## 📊 Сравнительная таблица

| Вариант | Сложность | Зависимости | Real-time? | UX Impact | Для кого |
|---------|-----------|-------------|------------|-----------|----------|
| **A. Threshold Alerts** | 🟢 Низкая | jq | ⚠️ После turn | 🟢 Минимальный | Все пользователи |
| **B. Always-On Status** | 🟢 Низкая | jq | ⚠️ После turn | 🟡 Шумный | Power users |
| **C. Startup Summary** | 🟢 Низкая | jq | ❌ Прошлая сессия | 🟢 Нулевой | Короткие сессии |
| **D. Combined** | 🟡 Средняя | jq | ⚠️ После turn | 🟢 Оптимальный | **Рекомендуется** |
| **E. Oh My Posh** | 🟡 Средняя | Oh My Posh | ✅ Real-time | 🟡 Занимает место | Rich UI fans |
| **F. Live Dashboard** | 🟡 Средняя | inotify-tools | ⚠️ После turn | 🟡 Отдельное окно | tmux users |
| **G. OpenTelemetry** | 🔴 Высокая | Docker, Prometheus | ✅ Real-time | 🟢 Отдельная система | Enterprise |

**Легенда**:
- 🟢 = Хорошо
- 🟡 = Средне
- 🔴 = Сложно
- ✅ = Да
- ⚠️ = Частично
- ❌ = Нет

---

## 🎯 Рекомендации по выбору

### Для начинающих пользователей
→ **Вариант A** (Threshold Alerts)
- Простая установка: `./iclaude.sh --install-context-monitor`
- Не отвлекает от работы
- Предупреждает в критический момент

### Для обычных пользователей
→ **Вариант D** (Combined Approach)
- Awareness при запуске
- Защита во время работы
- Лучший баланс UX/функциональность

### Для power users
→ **Вариант F** (Live Dashboard) + **Вариант A** (Alerts)
- Полный контроль через отдельное окно
- Alerts как fallback

### Для enterprise
→ **Вариант G** (OpenTelemetry)
- Профессиональный monitoring
- Интеграция с существующей инфраструктурой
- Исторические данные и аналитика

---

## 🔧 Быстрый старт

### Установка рекомендуемого варианта (D)

```bash
# 1. Установить context monitor hook (для alerts)
./iclaude.sh --install-context-monitor

# 2. Включить startup summary (будет добавлено в следующем релизе)
# Пока недоступно - в разработке

# 3. Запустить Claude Code
./iclaude.sh
```

### Кастомизация порогов

```bash
# Отредактировать hook
nano .nvm-isolated/.claude-isolated/hooks/postToolUse.hook.sh

# Изменить:
WARNING_THRESHOLD=70   # Вместо 80
CRITICAL_THRESHOLD=85  # Вместо 90

# Перезапустить Claude Code
./iclaude.sh
```

### Просмотр логов

```bash
# Real-time log monitoring
tail -f /tmp/claude-context-monitor.log

# Анализ последних 10 записей
tail -n 10 /tmp/claude-context-monitor.log
```

---

## 🐛 Troubleshooting

### Hook не срабатывает

**Проверить**:
```bash
# 1. Hook файл существует и executable?
ls -la .nvm-isolated/.claude-isolated/hooks/postToolUse.hook.sh

# 2. jq установлен?
which jq

# 3. .claude.json существует?
ls -la .nvm-isolated/.claude-isolated/.claude.json

# 4. Verbose режим для debugging
ANTHROPIC_LOG=debug ./iclaude.sh
```

**Решение**:
```bash
# Переустановить hook
./iclaude.sh --install-context-monitor

# Установить jq
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS
```

### Уведомления не появляются в UI

**Причина**: Claude Code не показывает stderr в некоторых режимах.

**Решение**: Проверить настройки verbose mode:
```bash
# Запустить с verbose
./iclaude.sh -- --verbose

# Или проверить в логе
tail -f /tmp/claude-context-monitor.log
```

### Неправильный подсчет токенов

**Причина**: `.claude.json` обновляется только после завершения turn.

**Решение**: Это нормальное поведение. Для real-time нужен OpenTelemetry (Вариант G).

---

## 📚 Дополнительные ресурсы

- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
- [Oh My Posh Claude Segment](https://ohmyposh.dev/docs/segments/cli/claude)
- [OpenTelemetry Integration](https://signoz.io/blog/claude-code-monitoring-with-opentelemetry/)
- [Context Window Management Guide](https://deepwiki.com/FlorianBruniaux/claude-code-ultimate-guide/3.2-context-window-management)

---

## 📝 Changelog

- **2026-02-10**: Создан документ с описанием 7 вариантов мониторинга
- **TBD**: Реализация Варианта D (Combined) в iclaude.sh
- **TBD**: Интеграция Oh My Posh (Вариант E)

---

**Автор**: iclaude.sh project
**Лицензия**: MIT
**Версия документа**: 1.0.0
