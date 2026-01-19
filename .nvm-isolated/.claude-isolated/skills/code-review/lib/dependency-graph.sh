#!/bin/bash

# dependency-graph.sh
# Проверка графа зависимостей архитектуры

# Проверяет, что все зависимости существуют
check_referential_integrity() {
  local components="$1"
  local violations=()

  # Получить все component IDs
  local all_ids=$(echo "$components" | jq -r '.[].id')

  # Для каждого компонента проверить зависимости
  while IFS= read -r component; do
    local comp_id=$(echo "$component" | jq -r '.id')
    local comp_file=$(echo "$component" | jq -r '.file_path // ""')

    # Проверить каждую зависимость
    # Поддержка обоих форматов: dependencies[] (строки) и dependencies[].component_id (объекты)
    while IFS= read -r dep_id; do
      [[ -z "$dep_id" ]] && continue

      # Проверить существование зависимости
      if ! echo "$all_ids" | grep -qx "$dep_id"; then
        violations+=("{\"component\": \"$comp_id\", \"dependency\": \"$dep_id\", \"file\": \"$comp_file\"}")
      fi
    done < <(echo "$component" | jq -r '.dependencies[] | if type == "string" then . else .component_id end')
  done < <(echo "$components" | jq -c '.[]')

  # Вывод нарушений
  if [[ ${#violations[@]} -gt 0 ]]; then
    printf '%s\n' "${violations[@]}" | jq -s '.'
  else
    echo '[]'
  fi
}

# Рекурсивная DFS для обнаружения циклов
dfs_cycle_check() {
  local current="$1"
  local components="$2"
  local path="$3"       # Arrow-separated path
  local visited="$4"    # Comma-separated list of visited in current path

  # Проверка, если current уже в текущем пути (цикл найден!)
  if [[ ",$visited," == *",$current,"* ]]; then
    # Найден цикл - выводим путь от first occurrence до current
    echo "${path}${current}"
    return 0
  fi

  # Добавить в путь
  local new_path="${path}${current} → "
  local new_visited="${visited:+$visited,}${current}"

  # Получить зависимости текущего компонента
  # Поддержка обоих форматов: dependencies[] (строки) и dependencies[].component_id (объекты)
  local deps=$(echo "$components" | jq -r ".[] | select(.id==\"$current\") | .dependencies[]? | if type == \"string\" then . else .component_id end")

  # Рекурсивно проверить зависимости
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    local cycle=$(dfs_cycle_check "$dep" "$components" "$new_path" "$new_visited")
    if [[ -n "$cycle" ]]; then
      echo "$cycle"
      return 0
    fi
  done <<< "$deps"

  # Цикл не найден в этой ветке
  return 1
}

# Обнаруживает циклические зависимости используя DFS
detect_circular_dependencies() {
  local components="$1"
  local cycles=()
  local seen_cycles=()

  # Запуск DFS для каждого компонента как стартовой точки
  while IFS= read -r comp_id; do
    local cycle=$(dfs_cycle_check "$comp_id" "$components" "" "")
    if [[ -n "$cycle" ]]; then
      # Нормализация цикла для избежания дубликатов
      # Сортируем компоненты в цикле и начинаем с минимального
      local cycle_normalized=$(echo "$cycle" | tr '→' '\n' | sed 's/^ //g' | sed 's/ $//g' | sort | tr '\n' '→' | sed 's/→$//')

      # Проверяем, не видели ли мы этот цикл раньше
      local already_seen=false
      for seen in "${seen_cycles[@]}"; do
        if [[ "$seen" == "$cycle_normalized" ]]; then
          already_seen=true
          break
        fi
      done

      if [[ "$already_seen" == "false" ]]; then
        cycles+=("$cycle")
        seen_cycles+=("$cycle_normalized")
      fi
    fi
  done < <(echo "$components" | jq -r '.[].id')

  # Вывести уникальные циклы
  if [[ ${#cycles[@]} -gt 0 ]]; then
    printf '%s\n' "${cycles[@]}" | jq -R . | jq -s .
  else
    echo '[]'
  fi
}

# Проверяет соблюдение границ слоев (нельзя зависеть от вышестоящего слоя)
validate_layer_boundaries() {
  local components="$1"
  local layer_levels="$2"  # JSON object: {"cli": 1, "core": 2, ...}
  local violations=()

  # Для каждого компонента
  while IFS= read -r component; do
    local comp_id=$(echo "$component" | jq -r '.id')
    local comp_layer=$(echo "$component" | jq -r '.layer // ""')

    # Пропускаем компоненты без слоя
    [[ -z "$comp_layer" ]] && continue

    local comp_level=$(echo "$layer_levels" | jq -r ".[\"$comp_layer\"] // null")

    # Пропускаем если уровень не определен
    [[ "$comp_level" == "null" ]] && continue

    # Для каждой зависимости
    while IFS= read -r dep_id; do
      [[ -z "$dep_id" ]] && continue

      # Найти слой зависимости
      local dep_layer=$(echo "$components" | jq -r ".[] | select(.id==\"$dep_id\") | .layer // \"\"")

      # Пропускаем если слой не определен
      [[ -z "$dep_layer" ]] && continue

      local dep_level=$(echo "$layer_levels" | jq -r ".[\"$dep_layer\"] // null")

      # Пропускаем если уровень не определен
      [[ "$dep_level" == "null" ]] && continue

      # Нарушение: зависимость от вышестоящего слоя (меньший level number)
      if [[ $dep_level -lt $comp_level ]]; then
        violations+=("{\"component\": \"$comp_id\", \"layer\": \"$comp_layer\", \"depends_on\": \"$dep_id\", \"depends_on_layer\": \"$dep_layer\"}")
      fi
    done < <(echo "$component" | jq -r '.dependencies[]? | if type == "string" then . else .component_id end')
  done < <(echo "$components" | jq -c '.[]')

  # Вывод нарушений
  if [[ ${#violations[@]} -gt 0 ]]; then
    printf '%s\n' "${violations[@]}" | jq -s '.'
  else
    echo '[]'
  fi
}

# Проверка, что измененные файлы соответствуют документированным компонентам
validate_component_file_paths() {
  local components="$1"
  local modified_files="$2"  # Newline-separated list
  local violations=()

  # Для каждого измененного файла
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Поиск компонента с matching file_path
    local matching_comp=$(echo "$components" | jq -r ".[] | select(.file_path | startswith(\"$file:\")) | .id" | head -1)

    if [[ -z "$matching_comp" ]]; then
      # Файл не документирован
      violations+=("{\"file\": \"$file\", \"message\": \"Modified file not documented in architecture\"}")
    fi
  done <<< "$modified_files"

  # Вывод нарушений
  if [[ ${#violations[@]} -gt 0 ]]; then
    printf '%s\n' "${violations[@]}" | jq -s '.'
  else
    echo '[]'
  fi
}

# Экспорт функций
export -f check_referential_integrity
export -f dfs_cycle_check
export -f detect_circular_dependencies
export -f validate_layer_boundaries
export -f validate_component_file_paths
