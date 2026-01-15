#!/bin/bash
# validate-template-skills.sh
# Валидация ссылок @skill:* в Template файлах

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/.nvm-isolated/.claude-isolated/skills"
TEMPLATE_DIR="/home/UF.RT.RU/i.y.tischenko/Документы/Notes/Work/ИИ/Claude code/Template"

# Project-specific skills (игнорируем их)
PROJECT_SPECIFIC_SKILLS=(
    "api-development"
    "clickhouse-sql"
    "frontend-development"
    "pihole-admin"
    "vless-deploy"
)

echo "🔍 Валидация ссылок на skills в Template файлах..."
echo ""

# Проверка существования Template директории
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo -e "${RED}❌ Template директория не найдена: $TEMPLATE_DIR${NC}"
    exit 1
fi

# Поиск всех @skill:* ссылок в Template файлах
echo "📂 Сканирование Template файлов..."
SKILL_REFS=$(grep -roh '@skill:[a-z][a-z0-9-]*' "$TEMPLATE_DIR" 2>/dev/null | sort -u | sed 's/@skill://')

if [[ -z "$SKILL_REFS" ]]; then
    echo -e "${YELLOW}⚠️  Не найдено ссылок @skill:* в Template файлах${NC}"
    exit 0
fi

echo "Найдено уникальных ссылок: $(echo "$SKILL_REFS" | wc -l)"
echo ""

# Валидация каждой ссылки
MISSING_SKILLS=()
FOUND_SKILLS=()
PROJECT_SKILLS=()

while IFS= read -r skill_name; do
    # Проверка на project-specific skill
    is_project_specific=false
    for ps_skill in "${PROJECT_SPECIFIC_SKILLS[@]}"; do
        if [[ "$skill_name" == "$ps_skill" ]]; then
            is_project_specific=true
            PROJECT_SKILLS+=("$skill_name")
            echo -e "${YELLOW}⏭️  $skill_name - project-specific (игнорируется)${NC}"
            break
        fi
    done

    if [[ "$is_project_specific" == true ]]; then
        continue
    fi

    # Проверка существования глобального skill
    if [[ -f "$SKILLS_DIR/$skill_name/SKILL.md" ]]; then
        FOUND_SKILLS+=("$skill_name")
        echo -e "${GREEN}✓ $skill_name${NC}"
    else
        MISSING_SKILLS+=("$skill_name")
        echo -e "${RED}✗ $skill_name - SKILL.md не найден в глобальных skills${NC}"
    fi
done <<< "$SKILL_REFS"

echo ""
echo "───────────────────────────────────────"
echo "📊 Результаты валидации:"
echo ""
echo "✓ Найдено глобальных skills: ${#FOUND_SKILLS[@]}"
echo "⏭️  Пропущено project-specific: ${#PROJECT_SKILLS[@]}"
echo "✗ Отсутствующих глобальных skills: ${#MISSING_SKILLS[@]}"

if [[ ${#MISSING_SKILLS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Отсутствующие глобальные skills:${NC}"
    for skill in "${MISSING_SKILLS[@]}"; do
        echo "  - $skill"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Все ссылки на глобальные skills валидны!${NC}"
exit 0
