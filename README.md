# iclaude — Руководство пользователя

> Версия: 4.0 | Дата: 2026-05

---

## Что такое iclaude

**iclaude** — bash-обёртка для запуска [Claude Code](https://claude.ai/code) с расширенными возможностями: управлением прокси, изолированной средой, защитой персональных данных, поддержкой альтернативных LLM-провайдеров и мониторингом сессий.

Claude Code — официальный CLI от Anthropic для работы с ИИ-ассистентом напрямую из терминала. iclaude решает практические проблемы, которые возникают при его использовании в реальных условиях.

---

## Какие проблемы решает

### 1. Корпоративная сеть и прокси

Claude Code не умеет работать через корпоративные HTTP/HTTPS прокси "из коробки". iclaude:
- Сохраняет настройки прокси между сессиями
- Поддерживает HTTPS-прокси с кастомными CA-сертификатами
- Настраивает git-прокси синхронно с Claude Code

### 2. Изоляция от системного окружения

Системная установка Claude Code (`npm install -g`) конкурирует с другими глобальными npm-пакетами, требует sudo, не позволяет контролировать версию. iclaude:
- Держит Claude Code в `.nvm-isolated/` — полностью изолированном каталоге
- Не требует системного npm или sudo для установки
- Позволяет воспроизводить точную версию через lockfile

### 3. Утечка секретов и персональных данных

При работе с реальными проектами в контекст Claude Code попадают: API-ключи, пароли, JWT-токены, персональные данные клиентов. iclaude:
- Блокирует доступ к файлам с секретами (`.env`, `.pem`, `.key`, `.ssh/`)
- Автоматически маскирует секреты в аргументах инструментов до отправки в API
- Опционально запускает NLP-прокси (Presidio) для маскирования PII в запросах

### 4. Стоимость API и альтернативные провайдеры

Anthropic API — дорого для фоновых агентов и массовой обработки. iclaude:
- Интегрируется с Claude Code Router для маршрутизации запросов на DeepSeek, OpenRouter, Ollama и другие провайдеры
- Позволяет запускать фоновые агенты через локальную Ollama (бесплатно)
- Отображает стоимость сессии в реальном времени в статуслайне

### 5. Отсутствие видимости сессии

Нет способа видеть сколько токенов использовано, какая модель работает, есть ли кэш. iclaude:
- Добавляет статуслайн с метриками: токены, кэш, стоимость, модель, git-ветка
- Адаптирует отображение под ширину терминала
- Показывает кликабельные ссылки на историю сессии и память проекта

### 6. Безопасность выполнения кода

Claude Code может читать, изменять и выполнять файлы с широкими правами. iclaude:
- Предоставляет kernel-level изоляцию через Firecracker microVM
- Разделяет конфигурацию каждого проекта через `CLAUDE_CONFIG_DIR`

---

## Реализованные функции

### Управление прокси

| Флаг | Действие |
|------|----------|
| `--proxy <url>` | Установить HTTP/HTTPS прокси |
| `--proxy-ca <file>` | Задать CA-сертификат для HTTPS (безопасно) |
| `--proxy-insecure` | Отключить проверку TLS (не рекомендуется) |
| `--no-proxy` | Запустить без прокси |
| `--test` | Проверить подключение через прокси |
| `--clear` | Очистить сохранённые credentials |
| `--restore-git-proxy` | Восстановить git-прокси из резервной копии |

Настройки сохраняются в `.claude_config` (chmod 600, не попадает в git).

**Поддерживаемые протоколы:** HTTP, HTTPS. SOCKS5 не поддерживается — используйте Privoxy как переходник.

### Изолированная среда (NVM)

Все компоненты Claude Code устанавливаются в `.nvm-isolated/` — изолированный каталог внутри репозитория.

| Флаг | Действие |
|------|----------|
| `--isolated-install` | Первичная установка (без системного npm) |
| `--repair-isolated` | Восстановить симлинки после `git clone` |
| `--repair-plugins` | Починить пути плагинов после переноса проекта |
| `--check-isolated` | Статус изолированной среды и версия |
| `--isolated-update` | Обновить Claude Code (без sudo) |
| `--install-from-lockfile` | Установить точные версии из lockfile |
| `--create-symlink` | Создать глобальный симлинк `iclaude` |
| `--cleanup-isolated` | Удалить среду, сохранив lockfile |

**Порядок поиска бинарного файла Claude Code:**
1. `$npm_prefix/bin/claude` (симлинк npm)
2. `bin/claude.exe` (нативный бинарник, v2.1.114+)
3. `cli.js` через `node` (legacy)

### Безопасность: хуки PreToolUse

Двухуровневая защита активна всегда, без дополнительных настроек.

**Слой 1 — `block-secrets.py`**: блокирует доступ к файлам по пути (exit code 2).

| Паттерн | Действие |
|---------|----------|
| `.env`, `.pem`, `.key`, `.p12`, `.pfx` | Заблокировано |
| `.ssh/`, `.gnupg/` | Заблокировано |
| `.env.example`, `.env.sample` | Разрешено (шаблоны) |
| `.claude-isolated/hooks/` | Разрешено (самоисключение) |

**Слой 2 — `redact-secrets.py`**: маскирует содержимое через `toolInputOverride`.

| Паттерн | Замена |
|---------|--------|
| `sk-ant-...`, `sk-proj-...` | `[ANTHROPIC_API_KEY]` |
| `AKIA{16}` (AWS) | `[AWS_ACCESS_KEY_ID]` |
| `ghp_`, `github_pat_` | `[GITHUB_TOKEN]` |
| `eyJ...` (JWT) | `[JWT_REDACTED]` |
| `scheme://[CREDENTIALS]@host` | `[CREDENTIALS_REDACTED]` |
| `.env` переменные (`KEY=значение{20+}`) | `[ENV_VAR_REDACTED]` |
| PEM приватные ключи | `[PRIVATE_KEY_REDACTED]` |

> `Edit.old_string` не маскируется — это поисковый паттерн, маскирование сломает инструмент Edit.

### PII-прокси (Presidio NLP)

Локальный HTTP-прокси между Claude Code и Anthropic API. Перехватывает запросы и маскирует персональные данные с помощью Microsoft Presidio (NLP) и regex.

```bash
./iclaude.sh --install-pii-proxy   # Установка (Python venv + Presidio, ~587MB)
./iclaude.sh --pii-proxy           # Запустить с PII-маскированием
```

**Уровни маскирования** (задаются в `.claude_config`):

| Уровень | Что делает |
|---------|-----------|
| `standard` | Presidio NLP + regex (по умолчанию) |
| `secrets` | Только regex: ключи, токены, пароли |
| `off` | Трафик проходит насквозь (отладка) |

В статуслайне при активном PII-прокси появляется иконка `🛡42` — счётчик замаскированных элементов.

### Claude Code Router (альтернативные LLM)

Маршрутизирует запросы Claude Code на альтернативные LLM-провайдеры.

```bash
./iclaude.sh --install-router   # Установка CCR
./iclaude.sh --router           # Запуск через router
./iclaude.sh --check-router     # Статус
```

**Поддерживаемые провайдеры:** DeepSeek, OpenRouter, Ollama, Gemini, OpenAI, Volcengine, SiliconFlow.

**Слоты маршрутизации** (настраиваются в `router.json`):

| Слот | Назначение |
|------|-----------|
| `default` | Основные запросы |
| `background` | Фоновые агенты (рекомендуется Ollama) |
| `think` | Plan Mode, reasoning-задачи |
| `longContext` | Запросы >60K токенов |
| `webSearch` | Запросы с веб-поиском |

Динамическое переключение модели прямо в сессии: `/model deepseek,deepseek-chat`.

### Статуслайн

Отображает метрики Claude Code в строке состояния терминала в реальном времени.

```bash
./iclaude.sh --install-statusline   # Установка
./iclaude.sh --install-posh         # Установка oh-my-posh (опционально)
```

**Пример вывода (полный режим, ≥130 колонок):**
```
💳 113K | 📊 51K (26%) | 📦 79K | Sonnet 4.5 | $1.06 🌐 | 🔀 deepseek | 🛡42 | ⛏ | 📄 | 🧠 | main +2
```

| Компонент | Значение |
|-----------|----------|
| `💳 113K` | Суммарные токены сессии (для биллинга) |
| `📊 51K (26%)` | Активный контекст (только новые токены, без кэша) |
| `📦 79K` | Токены в кэше (prompt cache) |
| `Sonnet 4.5` | Текущая модель |
| `$1.06` | Стоимость сессии |
| `🔀 deepseek` | Активный router-провайдер |
| `🛡42` | PII-прокси: 42 замаскированных элемента |
| `⛏` | Caveman активен. Счётчик сэкономленных токенов (`⛏ 5.2k`) появляется только после ручного вызова `/caveman-stats` |
| `📄` | Ссылка на читаемую историю сессии |
| `🧠` | Ссылка на MEMORY.md проекта |
| `main +2` | Git-ветка и количество незафиксированных изменений |

**Адаптивные режимы:**
- **Полный** (≥130 колонок): все компоненты
- **Компактный** (110–129): сокращения, скрыт router/git
- **Минимальный** (<110): только токены, модель, стоимость

### microVM-изоляция (Firecracker)

Запуск Claude Code внутри изолированной виртуальной машины Firecracker с отдельным Linux-ядром.

```bash
./iclaude.sh --install-microvm    # Установка (~1.4 GB)
./iclaude.sh --sandbox-microvm    # Запуск с kernel-изоляцией
```

**Уровни изоляции:**

| Уровень | Механизм | Активен |
|---------|----------|---------|
| Security hooks | block-secrets.py + redact-secrets.py | Всегда |
| Config isolation | CLAUDE_CONFIG_DIR в `.nvm-isolated/` | Всегда |
| microVM | Firecracker KVM (отдельный Linux kernel) | `--sandbox-microvm` |

### OAuth и токены

```bash
./iclaude.sh --refresh-token   # Обновить OAuth-токен (~1 год lifetime)
```

Токен сохраняется в `CLAUDE_CONFIG_DIR` и автоматически используется при запуске.

### Chrome-интеграция

Автоматизация браузерных задач через расширение "Claude in Chrome".

```bash
./iclaude.sh --chrome      # Включить Chrome-интеграцию
./iclaude.sh --no-chrome   # Отключить явно
```

**Требования:** Google Chrome, расширение v1.0.36+, Claude Code CLI v2.0.73+, платный план.

**По умолчанию отключена** — включение без выполненных требований вызывает ошибки при старте.

### Управление конфигурацией

```bash
./iclaude.sh --check-config          # Статус конфигурации
./iclaude.sh --export-config <path>  # Резервная копия
./iclaude.sh --import-config <path>  # Восстановление
./iclaude.sh --isolated-config       # Использовать изолированный конфиг
./iclaude.sh --shared-config         # Использовать системный ~/.claude/
```

**Ключевые переменные** (в `.claude_config`):

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | 32000 | Лимит output-токенов (макс. 128000) |
| `CLAUDE_CODE_ENABLE_TASKS` | true | Tasks-система |
| `CLAUDE_CODE_NO_CHROME` | false | Отключить Chrome |
| `CLAUDE_CODE_MODEL` | claude-4-5-sonnet | Модель |

### Граф документации (iwiki)

Документационный граф проекта обслуживает **MCP-сервер iwiki** — внешний central-store,
адресуемый доменами (один проект = один домен). Поиск, чтение и запись страниц выполняются
инструментами `wiki_*` напрямую из сессии.

| Инструмент | Назначение |
|---|---|
| `wiki_status` / `wiki_bind` | Определить домен проекта и привязать read/write |
| `wiki_search "вопрос"` | Семантический поиск по домену → секции + ссылки |
| `wiki_read_page` / `wiki_write_page` | Чтение и запись страниц домена |
| `wiki_index` | Переиндексация после записи (writes не индексируются автоматически) |
| `wiki_lint` | Здоровье домена: битые `[[refs]]`, сироты, устаревшие секции |
| `wiki_related` | Связанные секции по графу `[[refs]]` |

Исходник плагина сохранён в `plugin/iwiki/` (в архивном виде, отключён); активная работа
идёт через MCP-сервер.

---

### GSD Framework (Get Shit Done)

Устанавливает набор slash-команд [GSD](https://github.com/JuliusBrussee/get-shit-done-cc) в изолированную среду Claude Code. GSD — фреймворк spec-driven разработки: `/gsd` запускает интерактивный процесс написания спецификации → плана → реализации.

```bash
./iclaude.sh --install-gsd          # Установка (npx get-shit-done-cc@latest)
./iclaude.sh --install-gsd --force  # Переустановка (удаляет старые skill-каталоги)
./iclaude.sh --check-gsd            # Статус: версия, установленные skills
```

**Что устанавливается:** GSD создаёт каталоги `skills/gsd-*/` в `$CLAUDE_CONFIG_DIR`. Версия фиксируется в маркере `.gsd-version` для offline-чтения lockfile.

**Интеграция:**
- `--update` автоматически обновляет GSD, если он установлен
- `--install-from-lockfile` восстанавливает GSD по полю `gsdVersion` из lockfile
- Поле `gsdVersion` добавляется в lockfile при каждом `save_isolated_lockfile`

**В сессии:** запустите Claude Code и введите `/gsd` для старта.

### Сжатие токенов (Caveman)

Сокращает использование output-токенов на ~65–75% через [caveman](https://github.com/JuliusBrussee/caveman) — компрессивный стиль ответов модели (drop articles/filler/pleasantries). Не затрагивает код, коммиты, security warnings, error quotes.

```bash
./iclaude.sh --install-caveman      # Скачать 4 хука + патчить settings.json
./iclaude.sh --check-caveman        # Статус: установка, версия, режим
./iclaude.sh --uninstall-caveman    # Удалить
```

**Конфигурация (`.claude_config`):**

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `CAVEMAN_DEFAULT_MODE` | `full` | `off` / `lite` / `full` / `ultra` / `wenyan-*` / `commit` / `review` / `compress` |
| `CAVEMAN_STATUSLINE` | `false` | Badge экономии токенов в статусной строке |

В сессии: `/caveman lite|full|ultra` для переключения, `stop caveman` для выхода.

**Изоляция:** хуки ставятся только в `$CLAUDE_CONFIG_DIR/hooks/` — `~/.claude/` не затрагивается.

Подробнее: [docs/functions/CAVEMAN.md](docs/functions/CAVEMAN.md).

### Loop Engineering (loen)

Плагин `loen` (`plugin/loen/`, маркетплейс `iclaude`) запускает управляемую петлю
`Plan → Act → Check → Report` с независимым verifier. Задача описывается машиночитаемым
контрактом `loop.yaml`; worker делает минимальный diff; детерминированные gates и
subagent `verifier` подтверждают результат; отчёт собирается в `docs/loen/<run-id>/report.html`.

```bash
# В сессии:
/loop-delivery <task>              # выполнить петлю (planner → апрув → act → verifier → отчёт)
/loop-repair <описание падения>    # починка: воспроизвести → изолировать → минимальный фикс → регресс-тест
/loop-autoresearch <цель-метрика>  # исследование: baseline → гипотеза → изменение → фикс. eval → keep/revert
/loen:audit plan|act|check|result  # проверить стадию (mode-aware) + обновить report.html
/loen:loop-goal                    # опционально: evidence-first строка /goal из одобренного loop.yaml + рецепт /loop
```

**Артефакты:** `docs/loen/<run-id>/` (loop.yaml, plan.md, state.md, iterations/iter-NN/,
experiments.jsonl, report.html, pr-summary.md). В research-режиме eval пишет JSONL-метрики
в `iterations/iter-NN/metrics.jsonl` (через `$LOEN_METRICS_PATH`), а каждый эксперимент
логируется детерминированным `log_experiment.py`. Шаблоны — ассеты плагина. Хук
`loop-guard.py` жёстко контролирует раскладку/именование и scope; в не-loop репозиториях — no-op.

**Изоляция верификатора (opt-in):** `verifier_isolation: microvm` в `loop.yaml` —
верификатор выполняется headless внутри Firecracker microVM над одноразовым снапшотом
дерева (канала записи на хост нет). Требует установленный microVM
(`./iclaude.sh --install-microvm`); по умолчанию `subagent`. См.
[docs/functions/MICROVM.md](docs/functions/MICROVM.md).

Подробнее: [docs/functions/LOEN.md](docs/functions/LOEN.md).

### Обновление и диагностика

```bash
./iclaude.sh --update           # Обновить Claude Code
./iclaude.sh --check-update     # Проверить доступные обновления
./iclaude.sh --check-isolated   # Статус изолированной среды
./iclaude.sh --check-router     # Статус Claude Code Router
./iclaude.sh --check-statusline # Статус статуслайна
```

---

## Workflow разработки: IDD → iwiki → brainstorm

iclaude поставляет интегрированный процесс spec-driven разработки через систему скиллов.

### Полный цикл

```
/idd <тема>                          ← захват намерения (6 вопросов + контекст через wiki_search)
       ↓
/brainstorm                          ← дизайн решения на основе intent-doc
       ↓
/check-spec                          ← проверка spec на соответствие intent
       ↓
/check-plan                          ← проверка плана на соответствие spec
       ↓
implement                            ← реализация по плану
       ↓
wiki_write_page + wiki_index         ← записать/обновить страницу домена iwiki
wiki_lint                            ← проверить здоровье домена iwiki
```

### Как работает IDD с iwiki

**Без iwiki** — `/idd` задаёт 6 вопросов вхолодную. Пользователь отвечает без контекста о текущем состоянии проекта.

**С iwiki** — перед первым вопросом IDD выполняет `wiki_search "<тема>"`, показывает найденные страницы домена iwiki и зависимости, затем задаёт вопросы с учётом найденного контекста.

```bash
# В сессии: author markdown → wiki_write_page → wiki_index

# Дальше — обычный запуск
./iclaude.sh
# В сессии: /idd <тема> — IDD автоматически обогатит контекст через wiki_search
```

### Разделение ответственности

| Инструмент | Домен |
|-----------|-------|
| `iwiki` | Граф документации (MCP-сервер, домены): архитектурные решения, WHY, `[[ссылки]]` |
| `IDD (/idd)` | Захват намерения до начала проектирования |
| `GSD (/brainstorm → /check-spec → /check-plan)` | Spec-driven проектирование |

---

## Быстрый старт

### Первая установка

```bash
git clone <repo>
cd iclaude

# Починить симлинки после clone
./iclaude.sh --repair-isolated

# Настроить прокси (если нужно)
./iclaude.sh --proxy https://proxy.example.com:8118

# Проверить подключение
./iclaude.sh --test

# Запустить
./iclaude.sh
```

### Запуск с альтернативным провайдером (DeepSeek + Ollama)

```bash
# Установить router
./iclaude.sh --install-router

# Добавить ключ в .claude_config
echo "export DEEPSEEK_API_KEY=sk-..." >> .claude_config

# Запустить через router
./iclaude.sh --router
```

### Запуск с максимальной защитой данных

```bash
# Установить PII-прокси
./iclaude.sh --install-pii-proxy

# Запустить с PII-маскированием и microVM
./iclaude.sh --pii-proxy --sandbox-microvm
```

---

## Архитектура

```
iclaude.sh
├── lib/core/        — инициализация, глобальные переменные
├── lib/command/     — разбор аргументов, справка
├── lib/proxy/       — HTTP/HTTPS прокси
├── lib/nvm/         — изолированная NVM-среда
├── lib/oauth/       — OAuth-токены
├── lib/router/      — Claude Code Router
├── lib/pii-proxy/   — PII NLP-прокси (Presidio)
├── lib/sandbox/     — Firecracker microVM
├── lib/statusline/  — метрики в статуслайне
├── lib/launcher/    — запуск Claude Code (финальный вызов)
├── plugin/iwiki/    — iwiki плагин, архивный/отключён (Python-движок + slash-команды); работа идёт через MCP-сервер
└── lib/gsd/         — GSD framework (detect, install, status)
```

Хуки безопасности: `.nvm-isolated/.claude-isolated/hooks/`
Скрипты статуслайна: `.nvm-isolated/.claude-isolated/scripts/`

---

## Документация по разделам

| Тема | Файл |
|------|------|
| Прокси | `docs/functions/PROXY.md` |
| Router и провайдеры | `docs/functions/ROUTER.md` |
| PII-маскирование | `docs/functions/PII_MASKING.md` |
| Статуслайн | `docs/functions/STATUSLINE.md` |
| microVM | `docs/functions/MICROVM.md` |
| GSD Framework | `docs/superpowers/plans/2026-05-14-gsd-integration.md` |
| Сжатие токенов (Caveman) | `docs/functions/CAVEMAN.md` |
| Loop Engineering (loen) | `docs/functions/LOEN.md` |
| Все команды | `docs/functions/CONFIGURATION.md` |
| Примеры сценариев | `docs/functions/USE_CASES.md` |
| Телеметрия | `docs/functions/TELEMETRY.md` |
