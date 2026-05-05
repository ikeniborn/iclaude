---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/data-flow-microvm-launch.md"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - iclaude
aliases:
  - "microVM Security"
  - "Безопасность Firecracker"
---

# Безопасность microVM (Firecracker)

Меры безопасности и известные угрозы при работе Sandbox-слоя iclaude на базе Firecracker VMM.

## Основные характеристики

**Модель изоляции:**
- Kernel-level изоляция: Claude Code выполняется внутри guest-ядра Firecracker
- Host и guest разделены на уровне KVM-гипервизора
- Syscall-поверхность host-ядра изолирована от guest

**Меры защиты:**

| Угроза | Мера защиты |
|--------|-------------|
| TAP-интерфейс и iptables требуют sudo | Настройка выполняется один раз при `--install-microvm`; runtime-запуск без повышенных прав |
| Инъекция в имя интерфейса перед sudo-командами | Regex-проверка: `^[a-zA-Z0-9_-]{1,15}$` в `_setup_microvm_network_or_instruct()` |
| `guest-env.sh` содержит HTTPS_PROXY с credentials | Файл записывается в `session_dir` (mode 600), передаётся по SCP; исключён из host→guest и guest→host sync |
| Firecracker socket в `/tmp` (world-readable) | Socket создаётся с umask по умолчанию; удаляется при cleanup (EXIT-trap) |

## Что НЕ изолировано

- Сетевые соединения guest → internet (через TAP + iptables NAT)
- HTTPS_PROXY credentials передаются в guest через `guest-env.sh`

## Удалённые механизмы

- **bubblewrap (bwrap)** — удалён в марте 2026: создавал 0-байтные read-only stub-файлы в `.claude/` других открытых проектов

## Связанные концепции

- [[sandbox-слой]]
- [[microvm-launcher]]
- [[поток-microvm-запуска]]
- [[защита-данных-доступа]]
