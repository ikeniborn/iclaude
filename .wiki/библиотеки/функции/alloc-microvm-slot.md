---
wiki_sources:
  - "lib/sandbox/microvm.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "_alloc_microvm_slot"
  - "_free_microvm_slot"
  - "_claim_microvm_slot"
  - "_ensure_slot_tap"
---

# _alloc_microvm_slot / _free_microvm_slot / _claim_microvm_slot

Группа функций для slot-based распределения сетевых ресурсов Firecracker microVM. Обеспечивают изоляцию между параллельными сессиями.

## Основные характеристики

Модуль: `lib/sandbox/microvm.sh`

**`_alloc_microvm_slot()`**:

Legacy mode (без `MICRO_VM_NET_SUBNET`): использует фиксированные IP из `MICRO_VM_NET_HOST_IP`/`MICRO_VM_NET_GUEST_IP`.

Slot mode (с `MICRO_VM_NET_SUBNET`, дефолт `172.16.0.0/26`):
1. Парсинг CIDR подсети → `MICROVM_SUBNET_INT`, `MICROVM_SUBNET_PREFIX`
2. Вычисление `max_slots = (subnet_size - 2) / 2`
3. Для каждого слота 0..max_slots-1:
   - Чтение lockfile `microvm-slots/slot-N.lock`
   - Если lock содержит живой PID → пропустить
   - Устаревший lock (PID не существует) → удалить
   - Атомарный захват: `(set -C; echo "$$-pending" > lock)` — noclobber
4. При успехе: экспорт `MICRO_VM_SLOT`, `MICRO_VM_NET_HOST_IP`, `MICRO_VM_NET_GUEST_IP`, `MICRO_VM_NET_TAP_IFACE`

Формула IP: Slot N → host=base+2N+1, guest=base+2N+2, tap=`{prefix}-{N+1}`.

**`_claim_microvm_slot()`**: заменяет `$$-pending` на реальный PID Firecracker после его запуска.

**`_free_microvm_slot()`**: удаляет lockfile при остановке VM.

**`_ensure_slot_tap()`**: создаёт/настраивает TAP интерфейс через sudo если отсутствует. Добавляет FORWARD правила iptables для NAT.

## Связанные концепции

- [[библиотека/паттерны/slot-based-resource-pools]]
- [[библиотека/категории/sandbox]]
- [[библиотека/функции/start-microvm]]
