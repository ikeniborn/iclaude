#!/bin/bash

# adaptive-architecture-parser.sh
# Адаптивный парсер для различных форматов архитектурной документации

# Загрузка schema-detector
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/schema-detector.sh"

# Конвертирует файл в JSON в зависимости от формата
convert_to_json() {
  local file_path="$1"
  local format="$2"

  case "$format" in
    yaml)
      # Попытка использовать yq, fallback на Python
      if command -v yq &>/dev/null; then
        yq eval -o=json "$file_path" 2>/dev/null
      elif command -v python3 &>/dev/null; then
        python3 -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(open('$file_path'))))" 2>/dev/null
      else
        echo '{"error": "No YAML parser available (install yq or Python PyYAML)"}' >&2
        return 1
      fi
      ;;
    json)
      # Просто читаем и валидируем JSON
      jq '.' "$file_path" 2>/dev/null
      ;;
    markdown)
      # Извлекаем YAML frontmatter
      local frontmatter=$(extract_frontmatter_yaml "$file_path")
      if [[ -n "$frontmatter" && "$frontmatter" != "{}" ]]; then
        echo "$frontmatter" | convert_to_json /dev/stdin yaml
      else
        echo '{"error": "No valid frontmatter found in Markdown"}' >&2
        return 1
      fi
      ;;
    *)
      echo '{"error": "Unsupported format"}' >&2
      return 1
      ;;
  esac
}

# Конвертация C4 model в нормализованный формат
convert_c4_to_normalized() {
  local json_content="$1"

  # Извлечение компонентов из C4 модели
  # C4: softwareSystems[] → components[]
  # C4: containers[] → components[]
  # C4: relationships[] → dependencies[]

  echo "$json_content" | jq '{
    components: (
      (.model.softwareSystems // [] | map({
        id: .id,
        name: .name,
        layer: "system",
        type: "system",
        file_path: (.file_path // ""),
        dependencies: []
      })) +
      (.model.containers // [] | map({
        id: .id,
        name: .name,
        layer: "container",
        type: "container",
        file_path: (.file_path // ""),
        dependencies: []
      }))
    ),
    layers: [
      {id: "system", name: "System Layer"},
      {id: "container", name: "Container Layer"}
    ],
    layer_levels: {
      "system": 1,
      "container": 2
    }
  } |
  # Добавляем зависимости из relationships
  . as $base |
  ($base.components | map({(.id): .}) | add) as $comp_map |
  .components |= map(
    . as $comp |
    ($base.model.relationships // [] |
     map(select(.source == $comp.id) | {component_id: .destination, type: "required"}) // []
    ) as $deps |
    . + {dependencies: $deps}
  )'
}

# Конвертация architecture-documentation skill формата в нормализованный формат
convert_arch_doc_to_normalized() {
  local json_content="$1"

  echo "$json_content" | jq '{
    components: .architecture.components,
    layers: (
      [.architecture.components[].layer | select(. != null)] | unique |
      to_entries | map({id: .value, name: (.value | gsub("-"; " ") | ascii_upcase)})
    ),
    layer_levels: (
      [.architecture.components[].layer | select(. != null)] | unique |
      to_entries | map({(.value): (.key + 1)}) | add
    ),
    project: {
      id: .architecture.metadata.project_name,
      name: .architecture.metadata.project_name,
      description: .architecture.metadata.description
    }
  }'
}

# Нормализует различные схемы в единый формат
normalize_schema() {
  local json_content="$1"
  local schema_type="$2"

  case "$schema_type" in
    iclaude)
      # iclaude уже в нужном формате, просто добавляем layer_levels если отсутствует
      echo "$json_content" | jq '
        .layer_levels = (
          if .layer_levels then .layer_levels
          else (.layers | to_entries | map({(.value.id): (.key + 1)}) | add)
          end
        )
      '
      ;;
    c4)
      # Конвертация C4 model → iclaude формат
      convert_c4_to_normalized "$json_content"
      ;;
    arch-doc)
      # Конвертация architecture-documentation skill формат → iclaude формат
      convert_arch_doc_to_normalized "$json_content"
      ;;
    generic)
      # Generic schema - предполагаем минимальную структуру
      echo "$json_content" | jq '{
        components: .components,
        layers: (.layers // []),
        layer_levels: (.layer_levels // {})
      }'
      ;;
    *)
      echo '{"error": "Cannot normalize unknown schema"}' >&2
      return 1
      ;;
  esac
}

# Адаптивный парсер - автоматически определяет формат и структуру
parse_architecture_adaptive() {
  local project_root="${1:-$PWD}"

  # 1. Найти файлы архитектуры
  local arch_files=$(detect_architecture_files "$project_root")

  if [[ $(echo "$arch_files" | jq 'length') -eq 0 ]]; then
    # Архитектура не найдена → запустить architecture-documentation skill
    echo '{"available": false, "reason": "no_architecture_files", "action": "generate"}' >&2
    return 1
  fi

  # 2. Попробовать парсить каждый файл
  local parsed_data=""
  local schema_type="unknown"
  local successful_file=""

  while IFS= read -r file_path; do
    [[ -z "$file_path" ]] && continue

    local format=$(detect_file_format "$file_path")
    local json_content=$(convert_to_json "$file_path" "$format" 2>/dev/null)

    if [[ $? -eq 0 && -n "$json_content" ]]; then
      schema_type=$(detect_schema_type "$json_content")

      if [[ "$schema_type" != "unknown" ]]; then
        # Успешно распознали!
        parsed_data="$json_content"
        successful_file="$file_path"
        break
      fi
    fi
  done < <(echo "$arch_files" | jq -r '.[]')

  # 3. Проверка успешности парсинга
  if [[ "$schema_type" == "unknown" ]]; then
    # Не удалось распознать структуру → запустить architecture-documentation skill
    echo "{\"available\": false, \"reason\": \"unknown_schema\", \"action\": \"generate\", \"files_found\": $arch_files}" >&2
    return 1
  fi

  # 4. Извлечь компоненты и зависимости из распознанной схемы
  local normalized=$(normalize_schema "$parsed_data" "$schema_type")

  if [[ $? -ne 0 ]]; then
    echo '{"available": false, "reason": "normalization_failed", "action": "generate"}' >&2
    return 1
  fi

  # 5. Добавляем метаданные
  echo "$normalized" | jq --arg file "$successful_file" --arg type "$schema_type" '. + {
    available: true,
    source_file: $file,
    schema_type: $type
  }'
}

# Получает список измененных компонентов из git diff
get_modified_components() {
  local arch_data="$1"
  local components=$(echo "$arch_data" | jq -c '.components')

  # Получить измененные файлы
  local modified_files=$(git diff --name-only HEAD 2>/dev/null || git diff --name-only --cached 2>/dev/null)

  if [[ -z "$modified_files" ]]; then
    echo '[]'
    return 0
  fi

  local modified_component_ids=()

  # Для каждого измененного файла найти соответствующий компонент
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Поиск компонента с matching file_path
    # Формат file_path: "iclaude.sh:60-88" → проверяем префикс
    local comp_id=$(echo "$components" | jq -r ".[] | select(.file_path | startswith(\"$file:\")) | .id" | head -1)

    if [[ -n "$comp_id" ]]; then
      modified_component_ids+=("$comp_id")
    fi
  done <<< "$modified_files"

  # Вывод как JSON array
  if [[ ${#modified_component_ids[@]} -gt 0 ]]; then
    printf '%s\n' "${modified_component_ids[@]}" | jq -R . | jq -s 'unique'
  else
    echo '[]'
  fi
}

# Получает все компоненты, зависящие от указанного списка (рекурсивно)
get_dependent_components() {
  local arch_data="$1"
  local target_ids="$2"  # JSON array
  local components=$(echo "$arch_data" | jq -c '.components')

  local all_dependents=()

  # Для каждого target компонента
  while IFS= read -r target_id; do
    [[ -z "$target_id" ]] && continue

    # Найти все компоненты, которые зависят от target_id (прямые зависимости)
    # Поддержка обоих форматов: dependencies[] (строки) и dependencies[].component_id (объекты)
    while IFS= read -r comp_id; do
      [[ -z "$comp_id" ]] && continue
      all_dependents+=("$comp_id")
    done < <(echo "$components" | jq -r --arg target "$target_id" '.[] | select(.dependencies[]? | if type == "string" then . == $target else .component_id == $target end) | .id')
  done < <(echo "$target_ids" | jq -r '.[]')

  # Убрать дубликаты и вывести
  if [[ ${#all_dependents[@]} -gt 0 ]]; then
    printf '%s\n' "${all_dependents[@]}" | sort -u | jq -R . | jq -s .
  else
    echo '[]'
  fi
}

# Экспорт функций
export -f convert_to_json
export -f convert_c4_to_normalized
export -f convert_arch_doc_to_normalized
export -f normalize_schema
export -f parse_architecture_adaptive
export -f get_modified_components
export -f get_dependent_components
