#!/bin/bash
# Context Management Skill Handler
# Вызывает iclaude.sh --context-* команды

# Get script directory
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find iclaude root (5 levels up)
ICLAUDE_ROOT="$(cd "$SKILL_DIR/../../../.." && pwd)"
ICLAUDE_SH="$ICLAUDE_ROOT/iclaude.sh"

# Check if iclaude.sh exists
if [[ ! -f "$ICLAUDE_SH" ]]; then
    echo "❌ Error: iclaude.sh not found" >&2
    echo "   Expected: $ICLAUDE_SH" >&2
    exit 1
fi

# Parse subcommand
SUBCOMMAND="${1:-help}"
shift

# Execute via iclaude.sh
case "$SUBCOMMAND" in
    export)
        # /context-management export [path]
        echo "📤 Экспортирую контекст..."
        "$ICLAUDE_SH" --context-export "${1:-$(pwd)}"
        ;;

    import)
        # /context-management import <archive> [path]
        if [[ -z "$1" ]]; then
            echo "❌ Требуется путь к архиву" >&2
            echo "   Usage: /context-management import <archive.tar.gz> [path]" >&2
            exit 1
        fi
        echo "📥 Импортирую контекст..."
        "$ICLAUDE_SH" --context-import "$1" "${2:-$(pwd)}"
        ;;

    sync)
        # /context-management sync [pull|push] [path]
        direction="${1:-pull}"
        if [[ "$direction" != "pull" && "$direction" != "push" ]]; then
            echo "❌ Неверное направление: $direction" >&2
            echo "   Используйте: pull или push" >&2
            exit 1
        fi
        echo "🔄 Синхронизирую worktree ($direction)..."
        "$ICLAUDE_SH" --context-sync "$direction" "${2:-$(pwd)}"
        ;;

    clean)
        # /context-management clean [days]
        days="${1:-30}"
        if [[ ! "$days" =~ ^[0-9]+$ ]]; then
            echo "❌ Неверное количество дней: $days" >&2
            exit 1
        fi
        echo "🧹 Очищаю данные (старше $days дней)..."
        "$ICLAUDE_SH" --context-clean "$days"
        ;;

    backup)
        # /context-management backup [mode]
        mode="${1:-manual}"
        if [[ "$mode" != "manual" && "$mode" != "daily" && "$mode" != "weekly" ]]; then
            echo "❌ Неверный режим: $mode" >&2
            echo "   Используйте: manual, daily, weekly" >&2
            exit 1
        fi
        echo "💾 Создаю backup ($mode)..."
        "$ICLAUDE_SH" --context-backup "$mode"
        ;;

    status)
        # /context-management status [path]
        "$ICLAUDE_SH" --context-status "${1:-$(pwd)}"
        ;;

    memory-init)
        # /context-management memory-init [path]
        echo "🧠 Инициализация Auto Memory..."
        "$ICLAUDE_SH" --context-memory-init "${1:-$(pwd)}"
        ;;

    memory-validate)
        # /context-management memory-validate [path]
        "$ICLAUDE_SH" --context-memory-validate "${1:-$(pwd)}"
        ;;

    memory-organize)
        # /context-management memory-organize [path]
        "$ICLAUDE_SH" --context-memory-organize "${1:-$(pwd)}"
        ;;

    memory-add)
        # /context-management memory-add "text" [path]
        if [[ -z "$1" ]]; then
            echo "❌ Требуется текст записи" >&2
            echo "   Usage: /context-management memory-add \"Entry text\" [path]" >&2
            exit 1
        fi
        "$ICLAUDE_SH" --context-memory-add "$1" "${2:-$(pwd)}"
        ;;

    memory-status)
        # /context-management memory-status [path]
        "$ICLAUDE_SH" --context-memory-status "${1:-$(pwd)}"
        ;;

    help|--help|-h)
        cat << EOF
📚 Context Management Skill

Управление контекстом Claude Code из сессии.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Storage Commands (Export/Import/Sync):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /context-management export [path]        - Экспорт контекста в архив
  /context-management import <archive>     - Импорт контекста из архива
  /context-management sync [pull|push]     - Синхронизация worktree memory
  /context-management clean [days]         - Очистка старых данных (default: 30)
  /context-management backup [mode]        - Создание backup (manual/daily/weekly)
  /context-management status [path]        - Статус контекста проекта

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Auto Memory Commands (Best Practices):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /context-management memory-init [path]   - Создать MEMORY.md шаблон
  /context-management memory-validate      - Проверить 200 строк лимит
  /context-management memory-organize      - Предложить топик-файлы
  /context-management memory-add "text"    - Добавить запись
  /context-management memory-status        - Статус Auto Memory

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Примеры:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Storage:
  /context-management status               - Показать статус контекста
  /context-management export               - Экспортировать в архив
  /context-management sync pull            - Подтянуть memory из main

Auto Memory:
  /context-management memory-init          - Создать MEMORY.md
  /context-management memory-validate      - Проверить best practices
  /context-management memory-add "Use 2-space YAML indent"

Best Practices: https://code.claude.com/docs/en/memory
EOF
        ;;

    *)
        echo "❌ Неизвестная команда: $SUBCOMMAND" >&2
        echo "" >&2
        echo "Доступные команды:" >&2
        echo "  Storage: export, import, sync, clean, backup, status" >&2
        echo "  Memory:  memory-init, memory-validate, memory-organize, memory-add, memory-status" >&2
        echo "  help - показать помощь" >&2
        exit 1
        ;;
esac
