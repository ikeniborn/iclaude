#!/usr/bin/env bash
# lib/docs/bash-parser.sh
# Sphinx Documentation - Bash Function Parser
#
# Parses #######...####### comment blocks from lib/*.sh files
# and generates structured Markdown API reference documentation

#######################################
# Generate API reference Markdown from bash module comments
# Parses structured comments (#####...##### blocks) from lib/ files
# Arguments:
#   $1 - Source directory (default: $SCRIPT_DIR/lib)
#   $2 - Output directory (default: $SCRIPT_DIR/docs/api-reference)
# Returns:
#   0 - Success
#   1 - Source directory not found
# Example: generate_api_reference lib/ docs/api-reference/
#######################################
if ! declare -F generate_api_reference &>/dev/null; then
generate_api_reference() {
    local src_dir="${1:-${SCRIPT_DIR}/lib}"
    local out_dir="${2:-${SCRIPT_DIR}/docs/api-reference}"

    if [[ ! -d "$src_dir" ]]; then
        print_error "Source directory not found: $src_dir"
        return 1
    fi

    mkdir -p "$out_dir"

    local module_count=0
    local func_count=0

    # Process each module directory
    for module_dir in "$src_dir"/*/; do
        [[ -d "$module_dir" ]] || continue
        local module_name
        module_name=$(basename "$module_dir")

        # Skip README
        [[ "$module_name" == "README.md" ]] && continue

        local module_out_dir="$out_dir/$module_name"
        mkdir -p "$module_out_dir"

        local module_file_count=0

        for sh_file in "$module_dir"*.sh; do
            [[ -f "$sh_file" ]] || continue
            local file_name
            file_name=$(basename "$sh_file" .sh)

            local out_file="$module_out_dir/$file_name.md"
            _parse_bash_module "$sh_file" "$file_name" "$module_name" > "$out_file"

            local file_funcs
            file_funcs=$(grep -c "^## \`" "$out_file" 2>/dev/null || true)
            func_count=$((func_count + file_funcs))
            module_file_count=$((module_file_count + 1))
        done

        # Write module index
        _write_module_index "$module_out_dir" "$module_name" "$module_dir"

        module_count=$((module_count + 1))
    done

    # Write top-level API reference index
    _write_api_index "$out_dir" "$src_dir"

    print_info "API reference: $module_count modules, $func_count functions → $out_dir"
    return 0
}
fi

#######################################
# Parse a single bash module file into Markdown
# Arguments:
#   $1 - Input .sh file path
#   $2 - File name (without .sh)
#   $3 - Module name (parent directory)
# Returns:
#   Markdown output to stdout
# Example: _parse_bash_module lib/proxy/validate.sh validate proxy
#######################################
if ! declare -F _parse_bash_module &>/dev/null; then
_parse_bash_module() {
    local sh_file="$1"
    local file_name="$2"
    local module_name="$3"

    echo "# $file_name"
    echo ""
    echo "> **Module:** \`$module_name\` | **File:** \`lib/$module_name/$file_name.sh\`"
    echo ""

    # Extract file-level description (comment lines at top, after shebang)
    local in_header=true
    local found_desc=false
    while IFS= read -r line; do
        [[ "$line" =~ ^#!/ ]] && continue
        if [[ "$in_header" == true ]]; then
            if [[ "$line" =~ ^#[^!] ]]; then
                local stripped="${line:2}"
                # Skip separator lines
                [[ "$stripped" =~ ^#+$ ]] && continue
                # Skip empty comment lines at start
                [[ -z "$stripped" ]] && [[ "$found_desc" == false ]] && continue
                echo "$stripped"
                found_desc=true
            elif [[ -z "$line" ]] && [[ "$found_desc" == true ]]; then
                in_header=false
            elif [[ -n "$line" ]] && ! [[ "$line" =~ ^# ]]; then
                in_header=false
            fi
        fi
    done < "$sh_file"

    echo ""
    echo "---"
    echo ""

    # Extract functions
    _extract_functions_from_file "$sh_file"
}
fi

#######################################
# Extract and format all documented functions from a bash file
# Arguments:
#   $1 - Input .sh file path
# Returns:
#   Markdown function documentation to stdout
# Example: _extract_functions_from_file lib/proxy/validate.sh
#######################################
if ! declare -F _extract_functions_from_file &>/dev/null; then
_extract_functions_from_file() {
    local sh_file="$1"

    local in_comment=false
    local comment_lines=()

    while IFS= read -r line; do
        # Detect start/end of #####...##### block (38+ hashes)
        if [[ "$line" =~ ^#{38,}[[:space:]]*$ ]]; then
            if [[ "$in_comment" == false ]]; then
                in_comment=true
                comment_lines=()
            else
                in_comment=false
            fi
            continue
        fi

        if [[ "$in_comment" == true ]]; then
            comment_lines+=("$line")
            continue
        fi

        # Detect function definition after comment block
        if [[ ${#comment_lines[@]} -gt 0 ]]; then
            local func_name=""
            if [[ "$line" =~ ^([a-z_][a-z0-9_]*)\(\)[[:space:]]*\{ ]]; then
                func_name="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^function[[:space:]]+([a-z_][a-z0-9_]*) ]]; then
                func_name="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^if[[:space:]] ]] || [[ -z "$line" ]]; then
                # Skip guard patterns and blank lines, keep comment
                continue
            else
                # Not a function — discard comment
                comment_lines=()
                continue
            fi

            if [[ -n "$func_name" ]]; then
                _format_function_doc "$func_name" "${comment_lines[@]}"
                comment_lines=()
            fi
        fi
    done < "$sh_file"
}
fi

#######################################
# Format function documentation as Markdown
# Arguments:
#   $1 - Function name
#   $2+ - Comment lines (from #####...##### block)
# Returns:
#   Formatted Markdown to stdout
# Example: _format_function_doc my_func "# Description" "# Arguments:"
#######################################
if ! declare -F _format_function_doc &>/dev/null; then
_format_function_doc() {
    local func_name="$1"
    shift
    local comment_lines=("$@")

    echo "## \`$func_name\`"
    echo ""

    local description=""
    local section=""
    local args_lines=()
    local returns_lines=()
    local globals_lines=()
    local example_lines=()

    for line in "${comment_lines[@]}"; do
        # Strip leading "# " or "#"
        local stripped
        if [[ "$line" =~ ^#[[:space:]] ]]; then
            stripped="${line:2}"
        elif [[ "$line" =~ ^# ]]; then
            stripped="${line:1}"
        else
            stripped="$line"
        fi

        # Detect section headers
        if [[ "$stripped" =~ ^Arguments:[[:space:]]*$ ]]; then
            section="args"
        elif [[ "$stripped" =~ ^Returns:[[:space:]]*$ ]]; then
            section="returns"
        elif [[ "$stripped" =~ ^Globals:[[:space:]]*$ ]]; then
            section="globals"
        elif [[ "$stripped" =~ ^Example[^:]*:[[:space:]]*(.*) ]]; then
            section="example"
            local ex="${BASH_REMATCH[1]}"
            [[ -n "$ex" ]] && example_lines+=("$ex")
        elif [[ "$stripped" =~ ^Design:[[:space:]]*$ ]] || [[ "$stripped" =~ ^NOTE:[[:space:]] ]]; then
            section="skip"
        elif [[ -z "$stripped" ]]; then
            # Empty line — stay in current section
            :
        else
            case "$section" in
                "")         description+=" $stripped" ;;
                "args")     args_lines+=("$stripped") ;;
                "returns")  returns_lines+=("$stripped") ;;
                "globals")  globals_lines+=("$stripped") ;;
                "example")  example_lines+=("$stripped") ;;
            esac
        fi
    done

    # Output description
    echo "${description# }"
    echo ""

    # Arguments table
    if [[ ${#args_lines[@]} -gt 0 ]]; then
        echo "**Arguments:**"
        echo ""
        for arg in "${args_lines[@]}"; do
            [[ -n "$arg" ]] && echo "- \`$arg\`"
        done
        echo ""
    fi

    # Returns table
    if [[ ${#returns_lines[@]} -gt 0 ]]; then
        echo "**Returns:**"
        echo ""
        for ret in "${returns_lines[@]}"; do
            [[ -n "$ret" ]] && echo "- $ret"
        done
        echo ""
    fi

    # Example
    if [[ ${#example_lines[@]} -gt 0 ]]; then
        echo "**Example:**"
        echo ""
        echo '```bash'
        for ex in "${example_lines[@]}"; do
            echo "$ex"
        done
        echo '```'
        echo ""
    fi
}
fi

#######################################
# Write module index page
# Arguments:
#   $1 - Output directory for this module
#   $2 - Module name
#   $3 - Source module directory
# Returns:
#   0 - Success
# Example: _write_module_index docs/api-reference/proxy proxy lib/proxy/
#######################################
if ! declare -F _write_module_index &>/dev/null; then
_write_module_index() {
    local out_dir="$1"
    local module_name="$2"
    local src_dir="$3"

    local index_file="$out_dir/index.md"
    local toc_files=()

    # Collect file names and build visible list
    local list_output=""
    for sh_file in "$src_dir"*.sh; do
        [[ -f "$sh_file" ]] || continue
        local file_name
        file_name=$(basename "$sh_file" .sh)
        toc_files+=("$file_name")
        local func_count
        func_count=$(grep -c "^## \`" "$out_dir/$file_name.md" 2>/dev/null || true)
        list_output+="- [$file_name]($file_name.md) — $func_count functions"$'\n'
    done

    {
        echo "# Module: $module_name"
        echo ""
        echo "> Source: \`lib/$module_name/\`"
        echo ""
        echo "$list_output"

        # Hidden toctree so Sphinx includes all files (avoids "not in toctree" warnings)
        if [[ ${#toc_files[@]} -gt 0 ]]; then
            printf '%s\n' '```{toctree}' ':hidden:' ''
            printf '%s\n' "${toc_files[@]}"
            printf '%s\n' '```' ''
        fi
    } > "$index_file"
}
fi

#######################################
# Write top-level API reference index
# Arguments:
#   $1 - API reference output directory
#   $2 - Source lib directory
# Returns:
#   0 - Success
# Example: _write_api_index docs/api-reference lib/
#######################################
if ! declare -F _write_api_index &>/dev/null; then
_write_api_index() {
    local out_dir="$1"
    local src_dir="$2"

    local index_file="$out_dir/index.md"
    {
        echo "# API Reference"
        echo ""
        echo "Auto-generated from bash module comments in \`lib/\`."
        echo ""
        echo "| Module | Description |"
        echo "|--------|-------------|"

        for module_dir in "$src_dir"/*/; do
            [[ -d "$module_dir" ]] || continue
            local module_name
            module_name=$(basename "$module_dir")
            [[ "$module_name" == "README.md" ]] && continue

            # Extract module description from first .sh file
            local desc=""
            for sh_file in "$module_dir"*.sh; do
                [[ -f "$sh_file" ]] || continue
                desc=$(grep -m1 "^# " "$sh_file" 2>/dev/null | sed 's/^# //' | grep -v "^lib/" || true)
                [[ -n "$desc" ]] && break
            done

            echo "| [$module_name]($module_name/index.md) | ${desc:-—} |"
        done

        echo ""
        printf '%s\n' '```{toctree}' ':hidden:' ''
        for module_dir in "$src_dir"/*/; do
            [[ -d "$module_dir" ]] || continue
            local module_name
            module_name=$(basename "$module_dir")
            [[ "$module_name" == "README.md" ]] && continue
            echo "$module_name/index"
        done
        printf '%s\n' '```'
    } > "$index_file"
}
fi
