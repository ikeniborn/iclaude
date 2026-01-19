#!/bin/bash

# schema-detector.test.sh
# Тесты для расширенного поиска архитектурной документации

# Загрузка функций из schema-detector.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/schema-detector.sh"

# Счетчик тестов
TESTS_PASSED=0
TESTS_FAILED=0

# Вспомогательная функция для вывода результата
test_result() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$expected" == "$actual" ]]; then
    echo "[PASS] $test_name"
    ((TESTS_PASSED++))
  else
    echo "[FAIL] $test_name"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    ((TESTS_FAILED++))
  fi
}

# Тест 1: Расширенный поиск путей (doc/architecture)
test_extended_search_paths() {
  echo "=== Test 1: Extended search paths ==="

  # Setup
  local test_project="/tmp/test-code-review-$$"
  mkdir -p "$test_project/doc/architecture"
  echo '{"project":{"id":"test"},"components":[],"layers":[]}' > "$test_project/doc/architecture/overview.yaml"

  # Execute
  local result=$(detect_architecture_files "$test_project")

  # Assert
  if echo "$result" | jq -e '.[0] | contains("doc/architecture/overview.yaml")' &>/dev/null; then
    test_result "Extended search paths work" "true" "true"
  else
    test_result "Extended search paths work" "true" "false"
  fi

  # Cleanup
  rm -rf "$test_project"
}

# Тест 2: Пользовательская конфигурация через .clauderc
test_custom_config() {
  echo ""
  echo "=== Test 2: Custom config via .clauderc ==="

  # Setup
  local test_project="/tmp/test-code-review-custom-$$"
  mkdir -p "$test_project/custom/arch"
  cat > "$test_project/.clauderc" <<'EOF'
{
  "codeReview": {
    "architecturePaths": ["custom/arch"]
  }
}
EOF
  echo '{"project":{"id":"test"},"components":[],"layers":[]}' > "$test_project/custom/arch/architecture.yaml"

  # Execute
  local result=$(detect_architecture_files "$test_project")

  # Assert
  if echo "$result" | jq -e '.[0] | contains("custom/arch/architecture.yaml")' &>/dev/null; then
    test_result "Custom config via .clauderc works" "true" "true"
  else
    test_result "Custom config via .clauderc works" "true" "false"
  fi

  # Cleanup
  rm -rf "$test_project"
}

# Тест 3: Рекурсивный fallback поиск
test_recursive_fallback() {
  echo ""
  echo "=== Test 3: Recursive fallback search ==="

  # Setup
  local test_project="/tmp/test-code-review-recursive-$$"
  mkdir -p "$test_project/some/deep/path"
  echo '{"project":{"id":"test"},"components":[],"layers":[]}' > "$test_project/some/deep/architecture.yaml"

  # Execute
  local result=$(detect_architecture_files "$test_project" 2>/dev/null)

  # Assert
  if echo "$result" | jq -e '.[0] | contains("architecture.yaml")' &>/dev/null; then
    test_result "Recursive fallback works" "true" "true"
  else
    test_result "Recursive fallback works" "true" "false"
  fi

  # Cleanup
  rm -rf "$test_project"
}

# Тест 4: Backward compatibility (docs/architecture)
test_backward_compatibility() {
  echo ""
  echo "=== Test 4: Backward compatibility ==="

  # Setup
  local test_project="/tmp/test-code-review-bc-$$"
  mkdir -p "$test_project/docs/architecture"
  echo '{"project":{"id":"test"},"components":[],"layers":[]}' > "$test_project/docs/architecture/overview.yaml"

  # Execute
  local result=$(detect_architecture_files "$test_project")

  # Assert
  if echo "$result" | jq -e '.[0] | contains("docs/architecture/overview.yaml")' &>/dev/null; then
    test_result "Backward compatibility works" "true" "true"
  else
    test_result "Backward compatibility works" "true" "false"
  fi

  # Cleanup
  rm -rf "$test_project"
}

# Тест 5: Приоритет пользовательских путей
test_custom_paths_priority() {
  echo ""
  echo "=== Test 5: Custom paths priority ==="

  # Setup
  local test_project="/tmp/test-code-review-priority-$$"
  mkdir -p "$test_project/custom/arch"
  mkdir -p "$test_project/docs/architecture"

  # Создаем .clauderc с пользовательским путем
  cat > "$test_project/.clauderc" <<'EOF'
{
  "codeReview": {
    "architecturePaths": ["custom/arch"]
  }
}
EOF

  # Создаем файлы в обоих местах
  echo '{"project":{"id":"custom"},"components":[],"layers":[]}' > "$test_project/custom/arch/architecture.yaml"
  echo '{"project":{"id":"standard"},"components":[],"layers":[]}' > "$test_project/docs/architecture/overview.yaml"

  # Execute
  local result=$(detect_architecture_files "$test_project")

  # Assert: Первый найденный файл должен быть из custom/arch
  local first_file=$(echo "$result" | jq -r '.[0]')
  if echo "$first_file" | grep -q "custom/arch"; then
    test_result "Custom paths have higher priority" "true" "true"
  else
    test_result "Custom paths have higher priority" "true" "false"
  fi

  # Cleanup
  rm -rf "$test_project"
}

# Тест 6: Расширенные форматы файлов (c4-model.json, system-design.md)
test_extended_file_formats() {
  echo ""
  echo "=== Test 6: Extended file formats ==="

  # Setup
  local test_project="/tmp/test-code-review-formats-$$"
  mkdir -p "$test_project/docs/architecture"
  echo '{"project":{"id":"test"},"components":[],"layers":[]}' > "$test_project/docs/architecture/c4-model.json"

  # Execute
  local result=$(detect_architecture_files "$test_project")

  # Assert
  if echo "$result" | jq -e '.[0] | contains("c4-model.json")' &>/dev/null; then
    test_result "Extended file formats (c4-model.json) work" "true" "true"
  else
    test_result "Extended file formats (c4-model.json) work" "true" "false"
  fi

  # Cleanup
  rm -rf "$test_project"
}

# Запуск всех тестов
test_extended_search_paths
test_custom_config
test_recursive_fallback
test_backward_compatibility
test_custom_paths_priority
test_extended_file_formats

# Итоговый результат
echo ""
echo "======================================"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "======================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
else
  exit 0
fi
