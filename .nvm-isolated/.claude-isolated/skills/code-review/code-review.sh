#!/bin/bash

# code-review.sh
# Главный исполняемый скрипт для автоматического code review с архитектурной валидацией

set -euo pipefail

# Определяем директории
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
PROJECT_ROOT="${1:-$PWD}"

# Загружаем библиотеки
source "$LIB_DIR/schema-detector.sh"
source "$LIB_DIR/adaptive-architecture-parser.sh"
source "$LIB_DIR/dependency-graph.sh"

# Глобальные переменные для результатов
BLOCKING_ISSUES=()
WARNINGS=()
SUGGESTIONS=()
ARCHITECTURE_AVAILABLE=false
ARCHITECTURE_GENERATED=false

# Цвета для вывода
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

# Проверка зависимостей
check_dependencies() {
    local missing_deps=()

    # Проверка jq (обязательно)
    if ! command -v jq &>/dev/null; then
        missing_deps+=("jq")
    fi

    # Проверка YAML парсера (хотя бы один)
    if ! command -v yq &>/dev/null && ! command -v python3 &>/dev/null; then
        missing_deps+=("yq or python3")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        BLOCKING_ISSUES+=("{\"category\":\"architecture_compliance\",\"severity\":\"BLOCKING\",\"rule\":\"missing_dependencies\",\"message\":\"Required tools not installed: ${missing_deps[*]}\",\"suggestion\":\"Install dependencies: npm install -g yq OR pip install PyYAML\"}")
        return 1
    fi

    return 0
}

# Запуск architecture-documentation skill для генерации
trigger_architecture_documentation() {
    log_info "Triggering @skill:architecture-documentation to generate architecture..."

    # Проверка существования architecture-documentation skill
    local arch_skill_dir="$SCRIPT_DIR/../architecture-documentation"
    if [[ ! -d "$arch_skill_dir" ]]; then
        log_error "architecture-documentation skill not found at $arch_skill_dir"
        return 1
    fi

    # Вызов skill (предполагается наличие исполняемого скрипта)
    if [[ -x "$arch_skill_dir/generate-architecture.sh" ]]; then
        "$arch_skill_dir/generate-architecture.sh" "$PROJECT_ROOT" || {
            log_error "Failed to generate architecture"
            return 1
        }
    else
        log_warning "architecture-documentation skill found but not executable"
        log_info "Please run: @skill:architecture-documentation --generate"
        return 1
    fi

    ARCHITECTURE_GENERATED=true
    log_success "Architecture generated successfully"
    return 0
}

# Валидация архитектуры
validate_architecture() {
    log_info "Starting architecture validation for $PROJECT_ROOT"

    # Проверка зависимостей
    if ! check_dependencies; then
        return 1
    fi

    # Парсинг архитектуры
    log_info "Parsing architecture..."
    local arch_data
    arch_data=$(parse_architecture_adaptive "$PROJECT_ROOT" 2>&1)
    local parse_status=$?

    if [[ $parse_status -ne 0 ]]; then
        # Парсинг не удался
        local reason=$(echo "$arch_data" | jq -r '.reason // "unknown"' 2>/dev/null || echo "unknown")
        local action=$(echo "$arch_data" | jq -r '.action // ""' 2>/dev/null || echo "")

        case "$reason" in
            no_architecture_files)
                log_warning "No architecture files found"
                if [[ "$action" == "generate" ]]; then
                    # Автоматически запускаем генерацию
                    if trigger_architecture_documentation; then
                        # Повторная попытка парсинга
                        arch_data=$(parse_architecture_adaptive "$PROJECT_ROOT" 2>&1)
                        parse_status=$?
                        if [[ $parse_status -ne 0 ]]; then
                            log_error "Architecture parsing failed after generation"
                            BLOCKING_ISSUES+=("{\"category\":\"architecture_compliance\",\"severity\":\"BLOCKING\",\"rule\":\"generation_failed\",\"message\":\"Architecture generation completed but parsing still fails\",\"suggestion\":\"Check generated docs/architecture/overview.yaml\"}")
                            return 1
                        fi
                    else
                        BLOCKING_ISSUES+=("{\"category\":\"architecture_compliance\",\"severity\":\"BLOCKING\",\"rule\":\"architecture_required\",\"message\":\"No architecture documentation found\",\"suggestion\":\"Run @skill:architecture-documentation to generate\",\"action\":\"trigger_skill\"}")
                        return 1
                    fi
                fi
                ;;
            unknown_schema)
                log_error "Architecture file found but structure not recognized"
                BLOCKING_ISSUES+=("{\"category\":\"architecture_compliance\",\"severity\":\"BLOCKING\",\"rule\":\"unknown_schema\",\"message\":\"Architecture file found but structure not recognized\",\"suggestion\":\"Run @skill:architecture-documentation to standardize\",\"action\":\"trigger_skill\"}")
                return 1
                ;;
            *)
                log_error "Architecture parsing failed: $reason"
                return 1
                ;;
        esac
    fi

    # Успешный парсинг
    ARCHITECTURE_AVAILABLE=true
    local schema_type=$(echo "$arch_data" | jq -r '.schema_type')
    local source_file=$(echo "$arch_data" | jq -r '.source_file')
    local component_count=$(echo "$arch_data" | jq -r '.components | length')
    local layer_count=$(echo "$arch_data" | jq -r '.layers | length')

    log_success "Parsed $source_file ($schema_type format)"
    log_info "Found $component_count components, $layer_count layers"

    # Определение scope (гибридный режим)
    log_info "Determining scope (hybrid mode)..."
    local modified_components
    modified_components=$(get_modified_components "$arch_data")
    local modified_count=$(echo "$modified_components" | jq 'length')

    local dependent_components
    dependent_components=$(get_dependent_components "$arch_data" "$modified_components")
    local dependent_count=$(echo "$dependent_components" | jq 'length')

    local total_scope=$((modified_count + dependent_count))

    log_info "Scope: $modified_count modified + $dependent_count dependents = $total_scope components"

    # Запуск проверок
    local components=$(echo "$arch_data" | jq -c '.components')
    local layer_levels=$(echo "$arch_data" | jq -c '.layer_levels')

    # 1. Referential Integrity
    log_info "Checking referential integrity..."
    local ref_violations
    ref_violations=$(check_referential_integrity "$components")
    local ref_count=$(echo "$ref_violations" | jq 'length')

    if [[ $ref_count -gt 0 ]]; then
        log_error "Referential integrity: FAILED ($ref_count violations)"
        while IFS= read -r violation; do
            local comp=$(echo "$violation" | jq -r '.component')
            local dep=$(echo "$violation" | jq -r '.dependency')
            BLOCKING_ISSUES+=("{\"category\":\"architecture_compliance\",\"severity\":\"BLOCKING\",\"rule\":\"referential_integrity\",\"component\":\"$comp\",\"dependency\":\"$dep\",\"message\":\"Dependency '$dep' not found in components list\",\"suggestion\":\"Add component '$dep' or remove from dependencies\"}")
        done < <(echo "$ref_violations" | jq -c '.[]')
    else
        log_success "Referential integrity: PASSED"
    fi

    # 2. Circular Dependencies
    log_info "Detecting circular dependencies..."
    local cycles
    cycles=$(detect_circular_dependencies "$components")
    local cycle_count=$(echo "$cycles" | jq 'length')

    if [[ $cycle_count -gt 0 ]]; then
        log_error "Circular dependencies: FAILED ($cycle_count cycles)"
        while IFS= read -r cycle; do
            BLOCKING_ISSUES+=("{\"category\":\"architecture_compliance\",\"severity\":\"BLOCKING\",\"rule\":\"circular_dependency\",\"cycle_path\":\"$cycle\",\"message\":\"Circular dependency detected\",\"suggestion\":\"Break cycle using dependency injection or mediator pattern\"}")
        done < <(echo "$cycles" | jq -r '.[]')
    else
        log_success "Circular dependencies: PASSED"
    fi

    # 3. Layer Boundaries
    log_info "Validating layer boundaries..."
    local layer_violations
    layer_violations=$(validate_layer_boundaries "$components" "$layer_levels")
    local layer_count=$(echo "$layer_violations" | jq 'length')

    if [[ $layer_count -gt 0 ]]; then
        log_error "Layer boundaries: FAILED ($layer_count violations)"
        while IFS= read -r violation; do
            local comp=$(echo "$violation" | jq -r '.component')
            local layer=$(echo "$violation" | jq -r '.layer')
            local dep=$(echo "$violation" | jq -r '.depends_on')
            local dep_layer=$(echo "$violation" | jq -r '.depends_on_layer')
            BLOCKING_ISSUES+=("{\"category\":\"architecture_compliance\",\"severity\":\"BLOCKING\",\"rule\":\"layer_violation\",\"component\":\"$comp\",\"layer\":\"$layer\",\"depends_on\":\"$dep\",\"depends_on_layer\":\"$dep_layer\",\"message\":\"Layer violation: $layer depends on $dep_layer (upward dependency)\",\"suggestion\":\"Move component or introduce adapter pattern\"}")
        done < <(echo "$layer_violations" | jq -c '.[]')
    else
        log_success "Layer boundaries: PASSED"
    fi

    # 4. Component File Path Validation
    log_info "Validating component file paths..."
    local modified_files
    modified_files=$(git diff --name-only HEAD 2>/dev/null || git diff --name-only --cached 2>/dev/null || echo "")

    if [[ -n "$modified_files" ]]; then
        local file_violations
        file_violations=$(validate_component_file_paths "$components" "$modified_files")
        local file_count=$(echo "$file_violations" | jq 'length')

        if [[ $file_count -gt 0 ]]; then
            log_warning "Component validation: FAILED ($file_count undocumented files)"
            while IFS= read -r violation; do
                local file=$(echo "$violation" | jq -r '.file')
                WARNINGS+=("{\"category\":\"architecture_compliance\",\"severity\":\"WARNING\",\"rule\":\"undocumented_component\",\"file\":\"$file\",\"message\":\"Modified file not documented in architecture\",\"suggestion\":\"Add component to docs/architecture/overview.yaml\"}")
            done < <(echo "$file_violations" | jq -c '.[]')
        else
            log_success "Component validation: PASSED"
        fi
    else
        log_info "Component validation: SKIPPED (no modified files)"
    fi

    return 0
}

# Генерация JSON output
generate_output() {
    local blocking_count=${#BLOCKING_ISSUES[@]}
    local warning_count=${#WARNINGS[@]}
    local suggestion_count=${#SUGGESTIONS[@]}

    # Расчет score
    local arch_score=25
    local security_score=25
    local quality_score=25
    local error_score=15
    local type_score=10

    # Architecture score
    if [[ $ARCHITECTURE_AVAILABLE == true ]]; then
        arch_score=$((25 - (blocking_count * 10)))
        [[ $arch_score -lt 0 ]] && arch_score=0
    else
        # Rescale без архитектуры
        security_score=33
        quality_score=33
        error_score=20
        type_score=14
        arch_score=0
    fi

    local total_score=$((arch_score + security_score + quality_score + error_score + type_score))

    local passed="false"
    [[ $blocking_count -eq 0 ]] && passed="true"

    # Формирование blocking_issues array
    local blocking_json="[]"
    if [[ ${#BLOCKING_ISSUES[@]} -gt 0 ]]; then
        blocking_json=$(printf '%s\n' "${BLOCKING_ISSUES[@]}" | jq -s '.')
    fi

    # Формирование warnings array
    local warnings_json="[]"
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        warnings_json=$(printf '%s\n' "${WARNINGS[@]}" | jq -s '.')
    fi

    # Формирование suggestions array
    local suggestions_json="[]"
    if [[ ${#SUGGESTIONS[@]} -gt 0 ]]; then
        suggestions_json=$(printf '%s\n' "${SUGGESTIONS[@]}" | jq -s '.')
    fi

    # Генерация итогового JSON
    jq -n \
        --argjson score "$total_score" \
        --argjson passed "$passed" \
        --argjson blocking "$blocking_json" \
        --argjson warnings "$warnings_json" \
        --argjson suggestions "$suggestions_json" \
        --argjson arch_available "$ARCHITECTURE_AVAILABLE" \
        --argjson arch_generated "$ARCHITECTURE_GENERATED" \
        --argjson arch_score "$arch_score" \
        --argjson blocking_count "$blocking_count" \
        '{
            code_review: {
                score: $score,
                passed: $passed,
                blocking_issues: $blocking,
                warnings: $warnings,
                suggestions: $suggestions,
                metrics: {
                    architecture_compliance: {
                        score: $arch_score,
                        max: 25,
                        issues: $blocking_count,
                        checks_run: [
                            "referential_integrity",
                            "circular_dependencies",
                            "layer_boundaries",
                            "component_validation"
                        ]
                    }
                },
                architecture_available: $arch_available,
                architecture_generated: $arch_generated
            }
        }'
}

# Main execution
main() {
    log_info "Code Review - Architecture Validation"
    log_info "Project: $PROJECT_ROOT"
    echo ""

    # Валидация архитектуры
    if validate_architecture; then
        log_success "Architecture validation completed"
    else
        log_error "Architecture validation failed"
    fi

    echo ""
    log_info "Generating results..."

    # Генерация JSON output
    local output
    output=$(generate_output)

    # Вывод результата
    echo "$output" | jq '.'

    # Возвращаем код выхода на основе passed
    local passed=$(echo "$output" | jq -r '.code_review.passed')
    if [[ "$passed" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Запуск
main "$@"
