#!/bin/bash
# Validate all TOON blocks in SKILL.md files
#
# This script validates TOON blocks across all skills that use them.
# It checks syntax, token savings, and round-trip conversion.
#
# Usage: ./validate-toon-blocks.sh

set -e

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOON_CONVERTER="$SKILLS_DIR/toon-skill/converters/toon-converter.mjs"

echo "=========================================="
echo "Validating TOON Blocks in SKILL.md Files"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for statistics
TOTAL_SKILLS=0
SKILLS_WITH_TOON=0
TOTAL_BLOCKS=0
VALID_BLOCKS=0
INVALID_BLOCKS=0

# Skills to validate (skills known to have TOON blocks)
SKILLS_TO_CHECK=(
  "skill-generator"
  "architecture-documentation"
  "code-review"
  "docker-skill"
  "error-handling"
  "context7-integration"
  "lsp-integration"
  "thinking-framework"
)

# Function to validate a single SKILL.md file
validate_skill() {
  local skill_name="$1"
  local skill_md="$SKILLS_DIR/$skill_name/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    echo -e "${YELLOW}⚠️  $skill_name: SKILL.md not found${NC}"
    return 1
  fi

  TOTAL_SKILLS=$((TOTAL_SKILLS + 1))

  echo "Validating: $skill_name"
  echo "---"

  # Run validation using toon-converter.mjs
  local output
  if output=$(node "$TOON_CONVERTER" validate-skill-md "$skill_md" 2>&1); then
    local exit_code=$?

    # Count TOON blocks
    local block_count=$(echo "$output" | grep -c "^✅\|^❌" || true)

    if [ "$block_count" -eq 0 ]; then
      echo -e "${YELLOW}  No TOON blocks found${NC}"
      echo ""
      return 0
    fi

    SKILLS_WITH_TOON=$((SKILLS_WITH_TOON + 1))
    TOTAL_BLOCKS=$((TOTAL_BLOCKS + block_count))

    # Check if all blocks are valid
    local invalid_count=$(echo "$output" | grep -c "^❌" || true)

    if [ "$invalid_count" -eq 0 ]; then
      echo -e "${GREEN}$output${NC}"
      VALID_BLOCKS=$((VALID_BLOCKS + block_count))
      echo ""
      return 0
    else
      echo -e "${RED}$output${NC}"
      INVALID_BLOCKS=$((INVALID_BLOCKS + invalid_count))
      VALID_BLOCKS=$((VALID_BLOCKS + block_count - invalid_count))
      echo ""
      return 1
    fi
  else
    echo -e "${RED}❌ Validation failed: $output${NC}"
    echo ""
    return 1
  fi
}

# Main validation loop
FAILED_SKILLS=()

for skill in "${SKILLS_TO_CHECK[@]}"; do
  if ! validate_skill "$skill"; then
    FAILED_SKILLS+=("$skill")
  fi
done

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo ""
echo "Skills checked: $TOTAL_SKILLS"
echo "Skills with TOON blocks: $SKILLS_WITH_TOON"
echo "Total TOON blocks: $TOTAL_BLOCKS"
echo ""

if [ "$INVALID_BLOCKS" -eq 0 ]; then
  echo -e "${GREEN}✅ All $VALID_BLOCKS TOON blocks are valid!${NC}"
  echo ""
else
  echo -e "${RED}❌ $INVALID_BLOCKS invalid block(s) found${NC}"
  echo -e "${GREEN}✅ $VALID_BLOCKS valid block(s)${NC}"
  echo ""
  echo "Failed skills:"
  for skill in "${FAILED_SKILLS[@]}"; do
    echo "  - $skill"
  done
  echo ""
  exit 1
fi

# Token savings summary
echo "Token Savings Summary:"
echo "---"

for skill in "${SKILLS_TO_CHECK[@]}"; do
  skill_md="$SKILLS_DIR/$skill/SKILL.md"
  if [ -f "$skill_md" ]; then
    echo ""
    echo "$skill:"
    node "$TOON_CONVERTER" validate-skill-md "$skill_md" 2>&1 | grep "^✅" || true
  fi
done

echo ""
echo "=========================================="
echo "✅ Validation Complete"
echo "=========================================="
