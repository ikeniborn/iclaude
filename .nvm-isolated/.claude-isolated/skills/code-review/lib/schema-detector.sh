#!/bin/bash

# schema-detector.sh
# Автоопределение формата и структуры архитектурной документации

# Загрузка пользовательских путей из конфигурации
load_custom_search_paths() {
  local project_root="${1:-$PWD}"
  local custom_paths=()

  # 1. Из переменной окружения CODE_REVIEW_ARCH_PATHS
  if [[ -n "$CODE_REVIEW_ARCH_PATHS" ]]; then
    IFS=':' read -ra custom_paths <<< "$CODE_REVIEW_ARCH_PATHS"
  fi

  # 2. Из .clauderc файла в корне проекта
  local clauderc="$project_root/.clauderc"
  if [[ -f "$clauderc" ]]; then
    local arch_paths=$(jq -r '.codeReview.architecturePaths[]? // empty' "$clauderc" 2>/dev/null)
    if [[ -n "$arch_paths" ]]; then
      while IFS= read -r path; do
        custom_paths+=("$path")
      done <<< "$arch_paths"
    fi
  fi

  # 3. Из .claude/config.json в изолированной конфигурации
  local claude_config="$CLAUDE_DIR/config.json"
  if [[ -f "$claude_config" ]]; then
    local config_paths=$(jq -r '.skills.codeReview.architecturePaths[]? // empty' "$claude_config" 2>/dev/null)
    if [[ -n "$config_paths" ]]; then
      while IFS= read -r path; do
        custom_paths+=("$path")
      done <<< "$config_paths"
    fi
  fi

  printf '%s\n' "${custom_paths[@]}"
}

# Поиск файлов архитектуры в стандартных локациях
detect_architecture_files() {
  local project_root="${1:-$PWD}"
  local found_files=()

  # Загрузка пользовательских путей
  local custom_paths=()
  while IFS= read -r path; do
    [[ -n "$path" ]] && custom_paths+=("$path")
  done < <(load_custom_search_paths "$project_root")

  # Объединение стандартных и пользовательских путей
  local search_paths=(
    # Сначала пользовательские пути (высший приоритет)
    "${custom_paths[@]}"
    # Priority 1: Explicit architecture directories
    "docs/architecture"           # GitHub, Python, JS/TS standard
    "doc/architecture"            # Java, Go standard (without 's')
    "documentation/architecture"  # Enterprise projects
    ".github/docs/architecture"   # GitHub-centric (Next.js, Vercel)

    # Priority 2: Short names
    "docs/arch"                   # Current pattern
    "doc/arch"                    # Java/Go variant
    "architecture"                # Root-level
    ".arch"                       # Hidden root-level

    # Priority 3: Alternative naming conventions
    "design/architecture"         # Embedded systems, Hardware
    "design/docs"                 # Alternative design docs
    "adr"                         # Architecture Decision Records (Spotify, Netflix)
    "wiki/architecture"           # Wiki-based documentation
    "_docs/architecture"          # Jekyll-based documentation

    # Priority 4: Fallback to parent directories
    "docs/design"                 # Design-focused (Kubernetes)
    "docs/internals"              # Internals documentation (Django)
    "docs"                        # Last resort
  )

  # Поддерживаемые имена файлов
  local file_patterns=(
    # Priority 1: iclaude native formats (YAML preferred)
    "overview.yaml"
    "overview.yml"
    "architecture.yaml"
    "architecture.yml"

    # Priority 2: JSON formats
    "architecture.json"
    "components.json"
    "c4-model.json"              # C4 architecture (Simon Brown)
    "system-design.json"         # Facebook/Google style

    # Priority 3: Markdown formats
    "ARCHITECTURE.md"            # Uppercase convention
    "architecture.md"            # Lowercase convention
    "README.md"                  # Common in architecture/ directories
    "index.md"                   # Documentation index
    "system-design.md"           # Tech companies standard
    "tech-spec.md"               # Microsoft style
    "design-doc.md"              # Google style
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
    # Fallback: рекурсивный поиск
    echo "⚠ Standard paths not found, trying recursive search..." >&2
    recursive_architecture_search "$project_root" 3
  fi
}

# Рекурсивный поиск как последний fallback (с ограничением глубины)
recursive_architecture_search() {
  local project_root="${1:-$PWD}"
  local max_depth="${2:-3}"  # Ограничение глубины (безопасность)

  # Поиск файлов архитектуры рекурсивно
  find "$project_root" \
    -maxdepth "$max_depth" \
    -type f \
    \( -name "overview.yaml" -o \
       -name "overview.yml" -o \
       -name "architecture.yaml" -o \
       -name "architecture.yml" -o \
       -name "architecture.json" -o \
       -name "c4-model.json" -o \
       -name "system-design.json" -o \
       -name "ARCHITECTURE.md" -o \
       -name "architecture.md" -o \
       -name "README.md" -o \
       -name "index.md" -o \
       -name "system-design.md" -o \
       -name "tech-spec.md" -o \
       -name "design-doc.md" \) \
    2>/dev/null | jq -R . | jq -s '.'
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

  # architecture-documentation skill format: architecture.metadata + architecture.components[]
  if echo "$json_content" | jq -e '.architecture.metadata.project_name and .architecture.components' &>/dev/null; then
    echo "arch-doc"
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
export -f load_custom_search_paths
export -f detect_architecture_files
export -f recursive_architecture_search
export -f detect_file_format
export -f detect_schema_type
export -f extract_frontmatter_yaml
