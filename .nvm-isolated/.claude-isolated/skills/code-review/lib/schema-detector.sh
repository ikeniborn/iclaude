#!/bin/bash

# schema-detector.sh
# Автоопределение формата и структуры архитектурной документации

# Поиск файлов архитектуры в стандартных локациях
detect_architecture_files() {
  local project_root="${1:-$PWD}"
  local found_files=()

  # Поиск в стандартных директориях
  local search_paths=(
    "docs/architecture"
    "docs/arch"
    "architecture"
    ".arch"
    "docs"
  )

  # Поддерживаемые имена файлов
  local file_patterns=(
    "overview.yaml"
    "overview.yml"
    "architecture.yaml"
    "architecture.yml"
    "architecture.json"
    "components.json"
    "ARCHITECTURE.md"
    "architecture.md"
  )

  # Поиск файлов
  for dir in "${search_paths[@]}"; do
    for pattern in "${file_patterns[@]}"; do
      local file_path="$project_root/$dir/$pattern"
      if [[ -f "$file_path" ]]; then
        found_files+=("$file_path")
      fi
    done
  done

  # Вывод найденных файлов как JSON array
  if [[ ${#found_files[@]} -gt 0 ]]; then
    printf '%s\n' "${found_files[@]}" | jq -R . | jq -s '.'
  else
    echo '[]'
  fi
}

# Определяет формат файла (YAML, JSON, Markdown)
detect_file_format() {
  local file_path="$1"

  # Проверка расширения
  case "${file_path##*.}" in
    yaml|yml)
      echo "yaml"
      ;;
    json)
      echo "json"
      ;;
    md)
      echo "markdown"
      ;;
    *)
      # Попытка определить по содержимому
      local first_line=$(head -1 "$file_path")
      if [[ "$first_line" =~ ^\{ ]]; then
        echo "json"
      elif [[ "$first_line" =~ ^--- ]]; then
        echo "yaml"
      elif [[ "$first_line" =~ ^# ]]; then
        echo "markdown"
      else
        echo "unknown"
      fi
      ;;
  esac
}

# Определяет тип схемы архитектуры (iclaude, C4, ADR, custom)
detect_schema_type() {
  local json_content="$1"

  # Проверка наличия ключевых полей для разных схем

  # iclaude schema: project.id, components[], layers[]
  if echo "$json_content" | jq -e '.project.id and .components and .layers' &>/dev/null; then
    echo "iclaude"
    return 0
  fi

  # C4 model: model.people[], model.softwareSystems[], model.containers[]
  if echo "$json_content" | jq -e '.model.people or .model.softwareSystems or .model.containers' &>/dev/null; then
    echo "c4"
    return 0
  fi

  # ADR (Architecture Decision Records): decision[], status, context
  if echo "$json_content" | jq -e '.decision or (.status and .context)' &>/dev/null; then
    echo "adr"
    return 0
  fi

  # Generic schema: components[] и dependencies[] присутствуют
  if echo "$json_content" | jq -e '.components' &>/dev/null; then
    echo "generic"
    return 0
  fi

  # Не распознано
  echo "unknown"
}

# Извлекает YAML frontmatter из Markdown файла
extract_frontmatter_yaml() {
  local file_path="$1"

  # Проверяем наличие frontmatter (начинается с ---)
  if ! head -1 "$file_path" | grep -q '^---$'; then
    echo '{}' # Пустой JSON объект
    return 1
  fi

  # Извлекаем содержимое между --- и ---
  awk '/^---$/{flag=!flag;next}flag' "$file_path" 2>/dev/null || echo '{}'
}

# Экспорт функций для использования в других скриптах
export -f detect_architecture_files
export -f detect_file_format
export -f detect_schema_type
export -f extract_frontmatter_yaml
