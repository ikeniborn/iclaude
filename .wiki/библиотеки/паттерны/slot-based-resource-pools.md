---
wiki_sources:
  - "lib/sandbox/microvm.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - patterns
  - lib
  - iclaude
aliases:
  - "slot-based resource pools"
  - "slot pool"
  - "subnet allocation"
---

# Slot-based resource pools

Паттерн распределения конечного пула ресурсов (IP-адресов, TAP-интерфейсов) между параллельными сессиями. Реализован в `lib/sandbox/microvm.sh` для многосессионного запуска Firecracker.

## Основные характеристики

Модель: из CIDR-подсети вычисляются слоты. Каждый слот — атомарно захватываемая пара ресурсов.

Пример с `172.16.0.0/26` (62 usable hosts → 31 slot):

| Slot | Host IP | Guest IP | TAP |
|------|---------|----------|-----|
| 0 | 172.16.0.1 | 172.16.0.2 | tap-iclaude-1 |
| 1 | 172.16.0.3 | 172.16.0.4 | tap-iclaude-2 |
| N | base+2N+1 | base+2N+2 | {prefix}-{N+1} |

Атомарный захват через bash noclobber:

```bash
(set -C; echo "$$-pending" > "$lock") 2>/dev/null
```

`set -C` включает noclobber: если файл существует — `>` завершается с ошибкой. Два процесса не могут захватить один слот одновременно.

Двухфазный захват:
1. `_alloc_microvm_slot()` записывает `$$-pending` (PID shell, не Firecracker)
2. `_claim_microvm_slot()` заменяет на реальный PID Firecracker

Это предотвращает ситуацию когда конкурирующая сессия видит lock без живого Firecracker и считает его осиротевшим.

Освобождение: `_free_microvm_slot()` при остановке VM.

Cleanup осиротевших слотов: `cleanup_orphaned_microvm_sessions()` проверяет `kill -0 $lock_pid` и удаляет мёртвые locks.

## Связанные концепции

- [[библиотека/функции/alloc-microvm-slot]]
- [[библиотека/паттерны/per-session-isolation]]
- [[библиотека/паттерны/orphan-cleanup]]
- [[библиотека/категории/sandbox]]
