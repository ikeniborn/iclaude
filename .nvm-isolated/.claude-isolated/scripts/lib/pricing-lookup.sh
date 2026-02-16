#!/bin/bash
# Pricing Lookup Module
# Calculates cost for non-Claude models based on hardcoded pricing
#
# Pricing data sources:
# - OpenAI: https://openai.com/api/pricing/
# - DeepSeek: https://platform.deepseek.com/api-docs/pricing/
# - Gemini: https://ai.google.dev/pricing
# - OpenRouter: https://openrouter.ai/models
#
# Prices are in USD per 1M tokens
# Updated: 2026-02-13

# Input token pricing (USD per 1M tokens)
declare -gA MODEL_PRICING_INPUT=(
    # OpenAI
    ["gpt-4"]="30.00"
    ["gpt-4-turbo"]="10.00"
    ["gpt-4o"]="2.50"
    ["gpt-4o-mini"]="0.15"
    ["gpt-3.5-turbo"]="0.50"
    ["o1"]="15.00"
    ["o1-mini"]="3.00"

    # DeepSeek
    ["deepseek-chat"]="0.27"
    ["deepseek-coder"]="0.27"
    ["deepseek-reasoner"]="0.55"
    ["deepseek-v3"]="0.27"
    ["deepseek-r1"]="0.55"

    # Google Gemini
    ["gemini-2.0-flash"]="0.10"
    ["gemini-1.5-flash"]="0.075"
    ["gemini-1.5-pro"]="1.25"
    ["gemini-2.5-flash"]="0.10"
    ["gemini-2.5-pro"]="1.25"

    # Anthropic (for reference, usually not needed via router)
    ["claude-opus-4"]="15.00"
    ["claude-sonnet-4"]="3.00"
    ["claude-sonnet-4.5"]="3.00"
    ["claude-haiku-4"]="0.25"

    # OpenRouter (popular models)
    ["anthropic/claude-sonnet-4"]="3.00"
    ["google/gemini-2.5-pro"]="1.25"
    ["meta-llama/llama-3.3-70b"]="0.35"
    ["qwen/qwen-2.5-72b"]="0.35"
)

# Output token pricing (USD per 1M tokens)
declare -gA MODEL_PRICING_OUTPUT=(
    # OpenAI
    ["gpt-4"]="60.00"
    ["gpt-4-turbo"]="30.00"
    ["gpt-4o"]="10.00"
    ["gpt-4o-mini"]="0.60"
    ["gpt-3.5-turbo"]="1.50"
    ["o1"]="60.00"
    ["o1-mini"]="12.00"

    # DeepSeek
    ["deepseek-chat"]="1.10"
    ["deepseek-coder"]="1.10"
    ["deepseek-reasoner"]="2.19"
    ["deepseek-v3"]="1.10"
    ["deepseek-r1"]="2.19"

    # Google Gemini
    ["gemini-2.0-flash"]="0.40"
    ["gemini-1.5-flash"]="0.30"
    ["gemini-1.5-pro"]="5.00"
    ["gemini-2.5-flash"]="0.40"
    ["gemini-2.5-pro"]="5.00"

    # Anthropic
    ["claude-opus-4"]="75.00"
    ["claude-sonnet-4"]="15.00"
    ["claude-sonnet-4.5"]="15.00"
    ["claude-haiku-4"]="1.25"

    # OpenRouter
    ["anthropic/claude-sonnet-4"]="15.00"
    ["google/gemini-2.5-pro"]="5.00"
    ["meta-llama/llama-3.3-70b"]="0.40"
    ["qwen/qwen-2.5-72b"]="0.40"
)

# Normalize model name for pricing lookup
# Removes version suffixes, dates, and other variations
# Args: $1 - raw model name
# Returns: normalized model name
normalize_model_name() {
    local model="$1"

    # Convert to lowercase
    model=$(echo "$model" | tr '[:upper:]' '[:lower:]')

    # Remove common suffixes
    # - Date versions: -20231106, -0125, etc.
    # - Snapshot versions: -1106-preview, -latest, -preview
    # - Size indicators: -8k, -32k, -128k
    model=$(echo "$model" | sed -E 's/-[0-9]{4,8}(-preview)?$//')
    model=$(echo "$model" | sed -E 's/-(latest|preview|turbo)$//')
    model=$(echo "$model" | sed -E 's/-(8|16|32|128)k$//')

    echo "$model"
}

# Calculate cost for given model and token counts
# Args: $1 - model name
#       $2 - input tokens
#       $3 - output tokens
# Returns: cost in USD (string, e.g., "0.0042")
calculate_cost() {
    local model="$1"
    local input_tokens="${2:-0}"
    local output_tokens="${3:-0}"

    # Guard: empty model
    if [[ -z "$model" ]]; then
        echo "0"
        return 0
    fi

    # Normalize model name
    local normalized_model
    normalized_model=$(normalize_model_name "$model")

    # Lookup pricing
    local input_price="${MODEL_PRICING_INPUT[$normalized_model]:-0}"
    local output_price="${MODEL_PRICING_OUTPUT[$normalized_model]:-0}"

    # If pricing not found, try partial match (for versioned models)
    if [[ "$input_price" == "0" ]] || [[ "$output_price" == "0" ]]; then
        for key in "${!MODEL_PRICING_INPUT[@]}"; do
            if [[ "$normalized_model" == "$key"* ]] || [[ "$key" == "$normalized_model"* ]]; then
                input_price="${MODEL_PRICING_INPUT[$key]}"
                output_price="${MODEL_PRICING_OUTPUT[$key]}"
                break
            fi
        done

        # Debug: log if model still not found after partial match
        if [[ "$input_price" == "0" ]] && [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
            echo "[DEBUG] Model not in pricing DB: $normalized_model (original: $model)" >&2
        fi
    fi

    # Calculate cost
    # Formula: (input_tokens / 1M) * input_price + (output_tokens / 1M) * output_price
    local cost
    cost=$(awk -v input="$input_tokens" \
                -v output="$output_tokens" \
                -v iprice="$input_price" \
                -v oprice="$output_price" \
                'BEGIN {
                    input_cost = (input / 1000000.0) * iprice
                    output_cost = (output / 1000000.0) * oprice
                    total = input_cost + output_cost
                    printf "%.6f", total
                }')

    echo "$cost"
    return 0
}

# Get display name for model (optional, for better UX)
# Args: $1 - model name
# Returns: friendly display name
get_model_display_name() {
    local model="$1"

    case "$model" in
        gpt-4o) echo "GPT-4o" ;;
        gpt-4o-mini) echo "GPT-4o Mini" ;;
        gpt-4-turbo) echo "GPT-4 Turbo" ;;
        gpt-4) echo "GPT-4" ;;
        gpt-3.5-turbo) echo "GPT-3.5 Turbo" ;;
        o1) echo "OpenAI o1" ;;
        o1-mini) echo "OpenAI o1-mini" ;;
        deepseek-chat) echo "DeepSeek Chat" ;;
        deepseek-coder) echo "DeepSeek Coder" ;;
        deepseek-reasoner) echo "DeepSeek R1" ;;
        deepseek-v3) echo "DeepSeek V3" ;;
        deepseek-r1) echo "DeepSeek R1" ;;
        gemini-2.0-flash) echo "Gemini 2.0 Flash" ;;
        gemini-1.5-flash) echo "Gemini 1.5 Flash" ;;
        gemini-1.5-pro) echo "Gemini 1.5 Pro" ;;
        gemini-2.5-flash) echo "Gemini 2.5 Flash" ;;
        gemini-2.5-pro) echo "Gemini 2.5 Pro" ;;
        *) echo "$model" ;;
    esac
}

# Export functions
export -f normalize_model_name
export -f calculate_cost
export -f get_model_display_name
