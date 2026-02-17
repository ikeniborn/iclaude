# Исследование: Переписывание iclaude на Rust

## Контекст

**Цель исследования:** Оценить техническую возможность и целесообразность замены bash-реализации iclaude (~9,600 строк, 57 модулей) на Rust-бинарик.

**Что побудило рассмотреть Rust:**
- Растущая сложность bash кодовой базы (v4.0 — 14 фаз загрузки)
- Зависимость от внешних утилит (jq, sed, grep, getent, curl) на каждой платформе
- Отсутствие type safety и слабая обработка ошибок в bash
- Потребность в кроссплатформенном дистрибуции (Linux + macOS ARM/x86_64)

---

## Анализ текущей кодовой базы

### Общая статистика

| Показатель | Значение |
|------------|----------|
| Общий размер | ~9,611 строк (839 iclaude.sh + 8,772 lib/) |
| Модулей | 57 файлов в 21 директории |
| Уникальных функций | 131 |
| Фаз загрузки | 14 (phase-based dependency management) |
| Внешних команд | 25+ (jq, git, curl, sed, grep, nvm, node, ...) |

### Рейтинг компонентов по сложности переписки

| Компонент | LOC | Сложность | Главная проблема |
|-----------|-----|-----------|-----------------|
| **lib/loop/** | 1,432 | 🔴 ВЫСОКАЯ | AI merge conflicts, Markdown parser, git worktree |
| **lib/context/** | 850 | 🟡 СРЕДНЯЯ | rsync/tar operations, worktree sync |
| **lib/nvm/** | 756 | 🟡 СРЕДНЯЯ | Dynamic PATH manipulation, binary detection |
| **lib/proxy/** | 698 | 🟡 СРЕДНЯЯ | DNS fallback chain, URL parsing |
| **lib/lockfile/** | 484 | 🟢 НИЗКАЯ | JSON read/write → serde_json |
| **lib/oauth/** | 261 | 🟢 НИЗКАЯ | JSON parsing + timestamp arithmetic |
| **lib/launcher/** | 164 | 🟢 НИЗКАЯ | `std::process::Command` |
| **lib/chrome/** | 74 | 🟢 НИЗКАЯ | File/process search |
| **claude-statusline.sh** | 892 | 🟡 СРЕДНЯЯ | Multi-provider parsing, ANSI, adaptive display |

---

## Технический анализ по функциям

### ✅ Исправление #1: exec-паттерн (критично для архитектуры)

**Подтверждено:** `launch_claude()` использует `exec` — замену текущего процесса, а не `spawn`.

```bash
# lib/launcher/launch.sh — три точки exec:
exec "$ccr_cmd" code "$@"                    # Router путь
exec npx @anthropic-ai/claude-code "$@"      # npx fallback
eval exec "$claude_cmd" '"$@"'               # Основной путь (с пробелами в пути)
exec "$claude_cmd" "$@"                      # Основной путь (без пробелов)
```

В Rust это реализуется через `CommandExt::exec()` (Unix-only trait):

```rust
use std::os::unix::process::CommandExt;
use std::process::Command;

// exec() замещает текущий процесс — НИКОГДА не возвращает Ok(())
let error = Command::new(&claude_bin)
    .args(&claude_args)
    .env("HTTPS_PROXY", &proxy_url)
    .env("PATH", &new_path)
    .exec();  // возвращает только если exec() провалился

// Если дошли сюда — exec упал
eprintln!("Failed to exec claude: {}", error);
std::process::exit(1);
```

**Вывод:** `exec()` в Rust требует `std::os::unix::process::CommandExt` trait — это Unix-only. Для Windows нужен отдельный fallback (spawn + wait), но iclaude ориентирован только на Linux/macOS, поэтому проблемы нет.

### Функции с высокой сложностью в Rust

**1. Dynamic PATH manipulation (lib/nvm/)**

NVM detection (detect.sh) ищет claude по приоритетной цепочке:
1. `$NVM_DIR/versions/node/$version/bin/claude`
2. `.claude-*` временные бинарники (сортировка по mtime, новейший первым)
3. `node_modules/@anthropic-ai/claude-code/cli.js` (вызов через `node path/cli.js`)
4. Повтор для npm prefix

```rust
// PATH передаётся через env (не глобальный set_var, так как exec заменяет процесс)
let nvm_bin = nvm_dir.join("versions/node").join(&node_version).join("bin");
let new_path = format!("{}:{}", nvm_bin.display(), std::env::var("PATH")?);

Command::new(&claude_bin)
    .env("PATH", &new_path)
    .exec();
```

**Вывод:** Реализуемо. `exec()` передаёт весь env дочернему процессу.

**2. DNS fallback chain (lib/proxy/validate.sh)**

```bash
# Bash: sequential fallback
getent hosts $domain || host $domain || dig +short $domain || nslookup $domain
```

```rust
// std::net::ToSocketAddrs заменяет getent (системный резолвер)
use std::net::ToSocketAddrs;
let ip = format!("{}:0", domain)
    .to_socket_addrs()?
    .next()
    .map(|a| a.ip().to_string());

// Если нужен расширенный fallback → hickory-resolver (бывший trust-dns-resolver)
// ВАЖНО: с 2023 пакет переименован: trust-dns-resolver → hickory-resolver
use hickory_resolver::TokioAsyncResolver;
```

**Вывод:** `std::net::ToSocketAddrs` покрывает 99% случаев. `hickory-resolver` (не `trust-dns-resolver` — устаревшее название!) нужен только для низкоуровневого DNS.

**3. chmod 600 + symlinks (lib/nvm/repair.sh)**

```rust
// Для chmod: std::os::unix::fs::PermissionsExt — без внешних crates
use std::os::unix::fs::PermissionsExt;
use std::fs;

let mut perms = fs::metadata(&cred_file)?.permissions();
perms.set_mode(0o600);  // rw-------
fs::set_permissions(&cred_file, perms)?;

// Для symlinks: уже в stdlib
use std::os::unix::fs::symlink;
if link_path.exists() {
    fs::remove_file(&link_path)?;  // ln -sf поведение
}
symlink(&target, &link_path)?;
```

**Вывод:** `PermissionsExt` из stdlib достаточно для chmod — `nix` crate не обязателен. `nix` нужен только для расширенных Unix операций (chown, extended attrs).

**4. Loop Mode — AI Merge Conflict Resolution (lib/loop/worktree.sh)**

```bash
# bash: вызов claude для разрешения конфликтов
"$claude_cmd" --print --no-chrome "$merge_prompt"
```

```rust
// Rust: прямой spawn (не exec, так как нужен output)
let output = Command::new(&claude_bin)
    .args(["--print", "--no-chrome"])
    .arg(&merge_prompt)
    .output()?;
let resolved = String::from_utf8_lossy(&output.stdout);
```

**Вывод:** Claude вызывается как обычный внешний процесс — реализуемо без изменений.

**5. Markdown task parsing (lib/loop/parser.sh)**

```rust
// pulldown-cmark для структурного парсинга
use pulldown_cmark::{Parser, Event, Tag, HeadingLevel};
// ИЛИ regex для секций ## TaskName
use regex::Regex;
let section_re = Regex::new(r"(?m)^## (.+)$")?;
```

**Вывод:** `pulldown-cmark` — стандартное решение. Версия `0.12.x` (не 0.11, как было в первоначальном плане).

**6. ⚠️ NVM установка — специфическая сложность**

```bash
# NVM устанавливается через curl + bash:
curl -o- https://raw.githubusercontent.com/.../nvm.sh | bash
```

В Rust нет прямого эквивалента NVM (это bash-скрипт). Варианты:
- **Вариант A:** Скачать nvm.sh через `reqwest`, сохранить, запустить через `bash nvm.sh` — сохраняет текущее поведение
- **Вариант B:** Скачать Node.js tarball напрямую с nodejs.org, распаковать (`flate2` + `tar` crates) — убирает зависимость от bash совсем

**Вывод:** NVM install — единственная функция где bash-зависимость сложно полностью убрать в Rust.

---

## Рекомендуемый стек Rust crates (скорректированный)

```toml
[dependencies]
# CLI и аргументы
clap = { version = "4.5", features = ["derive"] }

# JSON (замена jq) — КРИТИЧНО, заменяет 122 вызова jq
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# HTTP и прокси (замена curl для --test)
reqwest = { version = "0.12", features = ["json", "native-tls"] }

# Async runtime (только для loop parallel mode)
tokio = { version = "1.0", features = ["process", "rt-multi-thread", "macros"] }

# Markdown парсинг (loop mode tasks)
pulldown-cmark = "0.12"   # ИСПРАВЛЕНО: была 0.11

# Regex (замена sed/grep в парсерах)
regex = "1.10"

# Обработка ошибок
thiserror = "1.0"
anyhow = "1.0"

# Логирование с env-filter (замена DEBUG_* переменных)
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

# Временные файлы (state файлы loop mode)
tempfile = "3.10"

# Terminal — для statusline (ANSI, width detection)
crossterm = { version = "0.28", optional = true }

# Git worktree management (опционально — альтернатива shell git)
git2 = { version = "0.19", features = ["vendored-libgit2"], optional = true }

# DNS резолюция (ИСПРАВЛЕНО: hickory, НЕ trust-dns который устарел с 2023)
# hickory-resolver = { version = "0.24", optional = true }
# Примечание: std::net::ToSocketAddrs достаточно для большинства случаев

# Node.js tarball распаковка (замена nvm curl|bash — опционально)
flate2 = { version = "1.0", optional = true }
tar = { version = "0.4", optional = true }
```

**⚠️ Исправление:** В первоначальном плане указан `trust-dns-resolver` — этот crate устарел. С 2023 года проект переименован в **`hickory-resolver`** (`hickory-dns` monorepo). Использовать `hickory-resolver = "0.24"`.

**⚠️ Исправление:** `nix` crate НЕ обязателен для chmod 600 — достаточно `std::os::unix::fs::PermissionsExt` из stdlib. `nix` нужен только если потребуется `chown` или расширенные атрибуты.

**Примерный размер release binary (stripped):**
- Без `git2` (vendored): 8-12 MB
- С `git2` (vendored libgit2 ~5MB): 15-20 MB

**Время первой компиляции:** 50-90 сек (tokio + reqwest + git2 = медленные)

---

## Оценка усилий (человеко-недели)

| Компонент | Усилия | Сложность |
|-----------|--------|-----------|
| CLI parsing (clap) | 1 нед | Низкая — derive macros делают всё |
| Proxy management | 1.5 нед | Средняя — URL parsing, DNS, reqwest |
| NVM detection + PATH | 1.5 нед | Средняя — priority chain, binary search |
| Config/JSON/lockfile | 1 нед | Низкая — serde_json |
| OAuth token management | 0.5 нед | Низкая — файловый IO + арифметика |
| Process launcher | 0.5 нед | Низкая — std::process::Command |
| Loop Mode (sequential) | 2 нед | Высокая — parser + retry + git |
| Loop Mode (parallel) | 2 нед | Очень высокая — tokio + worktrees |
| Status Line | 2 нед | Средняя — multi-provider, ANSI |
| Context management | 1.5 нед | Средняя — tar/rsync operations |
| Tests + CI/CD | 2 нед | — |
| **ИТОГО** | **~16 нед** | |

---

## Сравнение подходов

### Подход 1: Полный Rust-переход (монолит)

**Плюсы:**
- Единый бинарик без runtime зависимостей
- Type safety, memory safety
- Кроссплатформенность (Linux + macOS ARM/x86_64)
- Скорость запуска: 1ms vs 1.5s у bash
- Управление зависимостями через Cargo.lock

**Минусы:**
- 16+ недель разработки
- Полный риск регрессий до достижения паритета
- Компиляция 45-70 сек (vs мгновенный редакт bash)
- Rust borrow checker — steep learning curve

### Подход 2: Гибрид — Rust Core + Bash Scripts

Rust реализует только критические компоненты:
- CLI argument parser (замена 839 строк dispatch logic)
- Proxy URL validation и credentials management
- JSON operations (замена jq зависимости)

Bash остаётся для:
- NVM management (curl install скрипты)
- Loop mode (git worktree логика)
- Status line

**Плюсы:** ~4 недели, частичные улучшения без полного регресса.
**Минусы:** Поддерживать два языка сложнее.

### Подход 3: Оставить bash (status quo)

**Плюсы:** Нет рисков, нет затрат на миграцию.
**Минусы:** Растущая сложность bash, зависимость от внешних утилит, нет type safety.

---

## Критические риски (дополненные по результатам верификации)

| Риск | Вероятность | Влияние | Митигация |
|------|-------------|---------|-----------|
| Неполный функциональный паритет при запуске | ВЫСОКАЯ | КРИТИЧНО | Поэтапная миграция + bash fallback |
| **exec() semantics**: неправильный переход от bash exec к Rust | НИЗКАЯ | ВЫСОКОЕ | Использовать `CommandExt::exec()` (Unix-only) + тест сигналов |
| NVM install требует bash даже в Rust-версии | ВЫСОКАЯ | СРЕДНЕЕ | Либо оставить как bash шаг, либо реализовать прямую загрузку Node.js tarball |
| Loop Mode рефактор занимает 2x дольше оценки | ВЫСОКАЯ | ВЫСОКОЕ | Оставить Loop Mode последним (он нестабилен в bash) |
| **git2** с vendored libgit2 сильно увеличивает размер бинарика (+5MB) | СРЕДНЯЯ | НИЗКОЕ | Опциональная фича или shell git вызовы |
| Cross-compilation проблемы для macOS | СРЕДНЯЯ | СРЕДНЕЕ | Настроить GitHub Actions matrix (Linux + macOS runners) |
| Регрессии в proxy handling (TLS, credentials) | СРЕДНЯЯ | ВЫСОКОЕ | Интеграционные тесты с реальным прокси |
| **hickory-resolver** vs системный DNS различаются на macOS/Linux | НИЗКАЯ | НИЗКОЕ | Использовать `std::net::ToSocketAddrs` по умолчанию |

---

## Альтернатива: Go вместо Rust

Для completeness — Go также часто рассматривается для CLI-инструментов такого типа:

| Критерий | Rust | Go |
|----------|------|----|
| Скорость компиляции | 50-90 сек | 3-10 сек |
| Размер бинарика | 8-15 MB | 12-20 MB |
| Learning curve | Крутая (borrow checker) | Пологая |
| Производительность | Максимальная | Хорошая (GC паузы, но незаметны для CLI) |
| exec() замена процесса | `CommandExt::exec()` | `syscall.Exec()` |
| JSON | `serde_json` | `encoding/json` (stdlib) |
| HTTP/proxy | `reqwest` | `net/http` (stdlib) |
| Время разработки | ~16 нед | ~10-12 нед |

**Если скорость разработки важнее максимальной производительности → Go предпочтительнее.**
**Если нужен type safety, zero-cost abstractions, меньший бинарик → Rust.**

---

## Рекомендация

**FEASIBILITY: ВЫСОКАЯ (8/10)**

Технически переход возможен. Все компоненты имеют прямые Rust-эквиваленты.

**Рекомендуемая стратегия: Поэтапная миграция**

```
Phase 1 (2-3 нед): MVP — CLI + Proxy + Config (JSON)
  → Rust бинарик "iclaude-core" рядом с bash
  → Измерить реальные преимущества

Phase 2 (2-3 нед): NVM Detection + OAuth + Launcher
  → Полная замена bash для "happy path" запуска

Phase 3 (4-5 нед): Loop Mode
  → Только если Phase 1-2 прошли успешно

Phase 4 (2 нед): Status Line + Context
  → Финальный переход

При каждой фазе: bash скрипт остаётся как fallback
```

**Когда переход ЦЕЛЕСООБРАЗЕН:**
- Нужна надёжная кроссплатформенная дистрибуция (один бинарик)
- Планируется активная разработка новых фич (type safety ускоряет итерации)
- Есть опыт Rust или готовность к learning curve 3-4 недели

**Когда лучше остаться на bash:**
- Проект стабилен, изменения редки
- Команда не знакома с Rust
- Приоритет — быстрые итерации (bash = мгновенный deploy)

---

## Структура будущего Rust проекта

```
iclaude-rs/
├── src/
│   ├── main.rs              # CLI dispatch (clap)
│   ├── cli.rs               # Аргументы (derive macros)
│   ├── proxy/
│   │   ├── validate.rs      # URL + DNS resolution
│   │   ├── credentials.rs   # Save/load chmod 600
│   │   └── test.rs          # reqwest proxy test
│   ├── nvm/
│   │   ├── detect.rs        # Priority chain detection
│   │   └── repair.rs        # Symlink repair (nix)
│   ├── config/
│   │   ├── lockfile.rs      # serde_json
│   │   └── isolated.rs      # Path management
│   ├── oauth/token.rs       # Token validation/refresh
│   ├── loop_mode/
│   │   ├── parser.rs        # pulldown-cmark
│   │   ├── retry.rs         # Exponential backoff
│   │   ├── executor.rs      # Claude invocation
│   │   └── parallel.rs      # tokio tasks + worktrees
│   ├── launcher.rs          # std::process::Command exec
│   └── error.rs             # thiserror types
├── tests/
│   ├── integration/         # End-to-end tests
│   └── unit/                # Per-module tests
├── Cargo.toml
└── .github/workflows/
    ├── ci.yml               # Linux + macOS matrix
    └── release.yml          # Build binaries
```

---

## Верификация (как проверить успех Phase 1)

```bash
# 1. Компилируется без ошибок
cargo build --release

# 2. Базовый запуск работает
./target/release/iclaude --check-config

# 3. Proxy validation идентична bash реализации
./target/release/iclaude --proxy https://user:pass@proxy:8118
# vs
./iclaude.sh --proxy https://user:pass@proxy:8118

# 4. Credentials сохраняются с правильными правами
ls -la .claude_proxy_credentials  # должен быть -rw-------

# 5. Запуск Claude идентичен
./target/release/iclaude  # эквивалентен ./iclaude.sh

# 6. Cross-compilation
cargo build --release --target aarch64-unknown-linux-gnu
cargo build --release --target x86_64-apple-darwin

# 7. Размер бинарика
ls -lh target/release/iclaude  # ожидаем < 20 MB
```
