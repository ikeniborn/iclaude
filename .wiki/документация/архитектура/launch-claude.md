---
wiki_sources:
  - "lib/launcher/launch.sh"
  - "docs/superpowers/specs/2026-05-11-ccr-integration-verify-design.md"
wiki_updated: 2026-05-11
wiki_status: stub
wiki_outgoing_links:
  - "[[pii-прокси|PII-прокси]]"
  - "[[маршрутизатор-ccr|Маршрутизатор CCR]]"
  - "[[microvm-firecracker|microVM Firecracker]]"
  - "[[модульная-структура|Модульная структура iclaude]]"
wiki_external_links: []
tags:
  - iclaude
  - documentation
aliases:
  - "launch_claude"
  - "launcher"
  - "lib/launcher/launch.sh"
---

# launch_claude (lib/launcher/launch.sh)

Финальная точка запуска Claude Code в iclaude. `launch_claude()` — последняя функция в цепочке инициализации: она получает управление после разбора всех флагов и запускает Claude Code (через `exec`, либо через процесс, если нужен lifecycle для прокси).

## Сигнатура

```bash
launch_claude [skip_isolated] [claude_args...]
```

| Позиция | Имя | Описание |
|---------|-----|---------|
| `$1` | `skip_isolated` | `"true"` — пропустить изолированное окружение (--system режим) |
| `$@` | claude_args | Аргументы, передаваемые в claude binary |

## Порядок действий

```
1. _sync_graphify_env_to_settings   — GRAPHIFY_OUT → settings.json env-блок
2. unset CHROME_DESKTOP              — исправить wrong-browser в VS Code terminal
3. check_oauth_token                 — проверить истечение OAuth токена
4. cleanup_stale_session_env         — фоновая уборка stale session-env/ директорий
5. Определить флаги: use_router / use_microvm / use_pii_proxy
6. Отключить attribution header (router mode / --no-attribution-header)
7. Ветви запуска (см. ниже)
```

## Ветви запуска

### microVM (приоритет 1)

Если `use_microvm=true`:
- Если нужен router → `start_ccr_server` (host-side daemon)
- Если нужен pii-proxy → `start_pii_proxy_server` (host-side, guest достигает через TAP NAT)
- `start_microvm` → Firecracker запускает guest
- SSH ControlMaster (`-M -N -f`) — мультиплексирование, overhead 5ms вместо 200ms
- Host→Guest sync: rsync (v7+ rootfs) или tar-over-SSH (fallback)
- Периодический фоновый sync guest→host если `MICRO_VM_SYNC_INTERVAL > 0`
- `ssh … /mnt/nvm/npm-global/bin/claude${quoted_args}` — запуск claude в guest
- Guest→Host sync-back при выходе (режим `full`)

Флаги `--chrome` и `--ide` не пробрасываются в guest (расширение и IDE на хосте, не в VM).

### Router (приоритет 2, solo mode)

Если `use_router=true` и `use_pii_proxy=false`:
```bash
HOME="$ccr_home" exec "$ccr_cmd" code "$@"
```
Заменяет процесс iclaude на CCR. `CCR_HOME` указывает на isolated env чтобы CCR хранил state в `.nvm-isolated/.claude-isolated/` вместо `~/.claude-code-router/`.

### Router + PII proxy (combined mode)

`exec ccr code` невозможен — нужно держать оба процесса живыми:
1. `start_ccr_server` → CCR демон на фоне; `ANTHROPIC_BASE_URL=http://CCR:PORT`; экспортирует `CCR_UPSTREAM_ACTIVE=true` (в обоих путях: свежий старт и переиспользование)
2. `start_pii_proxy_server` → проверяет `CCR_UPSTREAM_ACTIVE` для выбора режима (per-session vs shared); читает `ANTHROPIC_BASE_URL` как upstream, переписывает на `http://127.0.0.1:PII_PORT`
3. `trap 'stop_pii_proxy_server; stop_ccr_server' EXIT INT TERM`
4. Запуск claude binary (без `exec`) → `exit $?`

### PII proxy solo

1. `start_pii_proxy_server`
2. `trap 'stop_pii_proxy_server' EXIT INT TERM`
3. `"${claude_cmd_arr[@]}" "$@"` + `exit $?` (без `exec` — trap должен сработать)

### Стандартный путь

```bash
exec "${claude_cmd_arr[@]}" "$@"
```

`exec` заменяет процесс — EXIT trap не нужен, shell освобождается.

## Переменные окружения (читает)

| Переменная | Описание |
|------------|----------|
| `USE_ROUTER_FLAG` | `true` — включить router |
| `NO_ATTRIBUTION_HEADER` | `true` — отключить billing header |
| `USE_MICRO_VM_FLAG` | `true` — запустить в microVM |
| `USE_PII_PROXY_FLAG` | `true` — включить PII proxy |
| `CLAUDE_CODE_ATTRIBUTION_HEADER` | Если уже установлен — не перезаписывать |
| `MICRO_VM_WORKSPACE_MODE` | `full`/`isolated` — режим sync workspace |
| `MICRO_VM_SYNC_INTERVAL` | Секунды между периодическими sync (0=выкл) |
| `ICLAUDE_E2E_*` | E2E-тесты headless (kill/exit после boot) |

## Переменные окружения (экспортирует)

| Переменная | Когда |
|------------|-------|
| `CLAUDE_CODE_ATTRIBUTION_HEADER=0` | router mode или --no-attribution-header |
| `ICLAUDE_ROUTER_ACTIVE=1` | router mode (statusline скрывает RL) |
| `ICLAUDE_MICROVM_ACTIVE=1` | microVM launch |
| `PII_PROXY_*` | см. [[pii-прокси]] |

## Обнаружение claude binary

Приоритет поиска после всех ветвей:
1. NVM isolated env (`detect_nvm` + `get_nvm_claude_path`)
2. `/usr/local/bin/claude`, `/usr/bin/claude`
3. `command -v claude` (кроме `.nvm` и локальных путей)
4. npm global prefix (`npm prefix -g`)
5. `npx @anthropic-ai/claude-code` (fallback)

`claude_cmd` разбивается в массив `read -ra claude_cmd_arr <<< "$claude_cmd"` — поддержка legacy `"node /path/cli.js"`.

## Связанные функции в файле

- `_sync_graphify_env_to_settings` — синхронизирует `GRAPHIFY_OUT` в settings.json
- `cleanup_orphaned_pii_proxies` — убирает stale PID-файлы PII proxy
- `cleanup_stale_session_env` — убирает stale session-env/ директории
- `start_pii_proxy_server` — запускает PII proxy (shared/per-session)
- `stop_pii_proxy_server` — останавливает PII proxy по ownership
- `start_ccr_server` — запускает CCR daemon (combined mode)
- `stop_ccr_server` — останавливает CCR daemon
