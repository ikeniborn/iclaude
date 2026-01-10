---
name: LSP Integration
description: Автоматическая установка и конфигурация LSP плагинов
version: 1.0.0
tags: [lsp, language-server, code-intelligence, auto-setup]
dependencies: [context-awareness]
user-invocable: false
---

# LSP Integration

Автоматическая установка Language Server Protocol плагинов для code intelligence (go-to-definition, find-references, type checking, auto-completion).

## Когда использовать

- После `@skill:context-awareness` в PHASE 0
- Когда обнаружен язык с поддержкой LSP
- Перед началом редактирования кода

**Auto-trigger:** Всегда активируется после context-awareness skill.

## Поддерживаемые языки

| Language | LSP Plugin | LSP Server | Prerequisites |
|----------|------------|------------|---------------|
| TypeScript/JavaScript | typescript-lsp | vtsls | Node.js, TypeScript |
| Python | pyright-lsp | pyright | Python 3.7+ |
| Go | gopls-lsp | gopls | Go 1.18+ |
| Rust | rust-analyzer-lsp | rust-analyzer | rustc, cargo |
| C# | csharp-lsp | OmniSharp | .NET SDK |
| Java | jdtls-lsp | Eclipse JDT LS | JDK 11+ |
| Kotlin | kotlin-lsp | kotlin-language-server | JDK |
| Lua | lua-lsp | lua-language-server | - |
| PHP | php-lsp | Intelephense | PHP 7+ |
| C/C++ | clangd-lsp | clangd | LLVM/Clang |
| Swift | swift-lsp | SourceKit-LSP | Swift 5.5+ |

**Unsupported:** bash, shell

## Алгоритм работы

### Phase 1: Detection
```
Input: project_context.language from context-awareness
Process: Map language → LSP plugin name using LSP_PLUGIN_MAP
Output: lsp_plugin name or null (if unsupported)
```

### Phase 2: Check Installation Status
```bash
# Read installed plugins JSON
PLUGINS_JSON=".claude-isolated/plugins/installed_plugins.json"
PLUGIN_NAME="<plugin-name>@claude-plugins-official"
CURRENT_PROJECT=$(pwd)

# Check if plugin installed for current project
jq -r ".plugins[\"${PLUGIN_NAME}\"][] | select(.projectPath == \"${CURRENT_PROJECT}\") | .version" "$PLUGINS_JSON"

# If output non-empty → plugin installed
# If empty → plugin not installed
```

### Phase 3: Verify Server Binary
```bash
# Check if LSP server binary available in PATH
command -v <lsp-server-name>

# Exit code 0 → server available
# Exit code 1 → server missing
```

### Final Status Decision
```
If language unsupported → NOT_SUPPORTED
Else if plugin not installed → NOT_INSTALLED
Else if plugin installed && server missing → SERVER_MISSING
Else → READY
```

## Language Detection Patterns

Map `project_context.language` to LSP plugin:

```javascript
const LSP_PLUGIN_MAP = {
  "typescript": "typescript-lsp@claude-plugins-official",
  "javascript": "typescript-lsp@claude-plugins-official",
  "python": "pyright-lsp@claude-plugins-official",
  "go": "gopls-lsp@claude-plugins-official",
  "rust": "rust-analyzer-lsp@claude-plugins-official",
  "csharp": "csharp-lsp@claude-plugins-official",
  "java": "jdtls-lsp@claude-plugins-official",
  "kotlin": "kotlin-lsp@claude-plugins-official",
  "lua": "lua-lsp@claude-plugins-official",
  "php": "php-lsp@claude-plugins-official",
  "c": "clangd-lsp@claude-plugins-official",
  "cpp": "clangd-lsp@claude-plugins-official",
  "swift": "swift-lsp@claude-plugins-official",
  "bash": null,  // No LSP support
  "shell": null  // No LSP support
};
```

## Plugin Installation Check

**Algorithm:**
```bash
# Example: Check if pyright-lsp installed for current project
CURRENT_PROJECT="/home/user/project"
PLUGIN_NAME="pyright-lsp@claude-plugins-official"
PLUGINS_JSON=".claude-isolated/plugins/installed_plugins.json"

# Read JSON and filter by projectPath
INSTALLED_VERSION=$(jq -r ".plugins[\"${PLUGIN_NAME}\"][] | select(.projectPath == \"${CURRENT_PROJECT}\") | .version" "$PLUGINS_JSON")

if [ -n "$INSTALLED_VERSION" ]; then
  echo "Plugin installed: version $INSTALLED_VERSION"
else
  echo "Plugin not installed"
fi
```

**JSON Structure Reference:**
```json
{
  "version": 2,
  "plugins": {
    "pyright-lsp@claude-plugins-official": [
      {
        "scope": "project",
        "projectPath": "/home/user/project",
        "installPath": "/path/to/cache/pyright-lsp/1.0.0",
        "version": "1.0.0",
        "installedAt": "2026-01-10T09:42:52.523Z",
        "gitCommitSha": "..."
      }
    ]
  }
}
```

## LSP Server Verification

**Commands by language:**

```bash
# TypeScript/JavaScript
command -v typescript-language-server || command -v vtsls

# Python
command -v pyright

# Go
command -v gopls

# Rust
command -v rust-analyzer

# C#
command -v OmniSharp || test -d ~/.omnisharp

# Java
test -d ~/.local/share/eclipse.jdt.ls/

# Kotlin
command -v kotlin-language-server

# Lua
command -v lua-language-server

# PHP
command -v intelephense

# C/C++
command -v clangd

# Swift
command -v sourcekit-lsp
```

## Output Format

**JSON Schema:**
```json
{
  "lsp_status": {
    "language": "python",
    "lsp_plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": true|false,
    "server_available": true|false,
    "status": "READY|NOT_INSTALLED|SERVER_MISSING|NOT_SUPPORTED",
    "recommendation": "LSP ready for use" | "Install plugin?" | "Install pyright" | null,
    "install_command": "/plugin install <plugin-name>" | null,
    "server_install_guide": "npm install -g <server>" | null
  }
}
```

**Status Values:**
- `READY`: Plugin installed, server available, LSP active
- `NOT_INSTALLED`: Plugin not installed for this project
- `SERVER_MISSING`: Plugin installed, but LSP server binary not found
- `NOT_SUPPORTED`: Language has no LSP plugin available

## User Interaction Patterns

### Scenario A: Plugin NOT Installed

**Claude Output:**
```
I detected this is a Python project. Would you like me to install the
pyright-lsp plugin for enhanced code intelligence? This provides:
- Go-to-definition
- Find references
- Type checking
- Auto-completion

Install command: /plugin install pyright-lsp@claude-plugins-official
```

**User Options:**
- `"yes"` → Claude runs `/plugin install pyright-lsp@claude-plugins-official`
- `"no"` → Claude continues without LSP (task not blocked)
- `"skip"` → Claude skips LSP for this session

**JSON Output:**
```json
{
  "lsp_status": {
    "language": "python",
    "lsp_plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": false,
    "server_available": false,
    "status": "NOT_INSTALLED",
    "recommendation": "Install pyright-lsp for type checking and code intelligence?",
    "install_command": "/plugin install pyright-lsp@claude-plugins-official",
    "server_install_guide": "npm install -g pyright"
  }
}
```

### Scenario B: Plugin Installed, Server Missing

**Claude Output:**
```
✓ pyright-lsp plugin is installed.
✗ pyright server not found in PATH.

To enable LSP features, install the pyright server:

npm install -g pyright

Or skip LSP features for this session.
```

**User Action:** Install server manually or continue without LSP

**JSON Output:**
```json
{
  "lsp_status": {
    "language": "python",
    "lsp_plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_available": false,
    "status": "SERVER_MISSING",
    "recommendation": "Install pyright server: npm install -g pyright",
    "install_command": null,
    "server_install_guide": "npm install -g pyright"
  }
}
```

### Scenario C: LSP Ready

**Claude Output:**
```
✓ LSP ready (pyright-lsp). Code intelligence active.
```

**No user interaction needed. Continues to PHASE 1.**

**JSON Output:**
```json
{
  "lsp_status": {
    "language": "python",
    "lsp_plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_available": true,
    "status": "READY",
    "recommendation": "LSP ready for use",
    "install_command": null,
    "server_install_guide": null
  }
}
```

### Scenario D: Language Not Supported

**Claude Output:**
```
(Silent - no LSP available for bash projects)
```

**JSON Output:**
```json
{
  "lsp_status": {
    "language": "bash",
    "lsp_plugin": null,
    "plugin_installed": false,
    "server_available": false,
    "status": "NOT_SUPPORTED",
    "recommendation": null,
    "install_command": null,
    "server_install_guide": null
  }
}
```

## Integration with Task Template v7.0

### PHASE 0 Enhancement

**Data Flow:**
```
PHASE 0 → @skill:context-awareness → {project_context}
        → @skill:lsp-integration → {lsp_status}  [NEW]
        → @skill:adaptive-workflow → {complexity}
```

**Workflow:**
1. context-awareness detects language
2. lsp-integration checks LSP availability
3. If LSP missing, prompts user (non-blocking)
4. Outputs lsp_status for subsequent phases
5. adaptive-workflow continues regardless of LSP status

### PHASE 3 Enhancement (Code Review)

When `lsp_status.status == "READY"`:
- Code review mentions LSP-detected type errors
- Claude uses go-to-definition to trace dependencies
- Better understanding of code structure

### PHASE 4 Enhancement (Validation)

When LSP available:
- Validation includes LSP diagnostics
- Type errors caught before runtime
- More comprehensive syntax checking

## Language-Specific Gotchas

### TypeScript/JavaScript
- **Prerequisite:** Node.js, TypeScript installed locally
- **Config:** `tsconfig.json` required for optimal LSP
- **LSP Server:** vtsls (successor of typescript-language-server)
- **Common issue:** Missing `@types/*` packages causes incomplete type information
- **Fix:** Install missing types: `npm install -D @types/node @types/react`

### Python
- **Prerequisite:** Python 3.7+
- **Config:** Pyright reads `pyrightconfig.json` or `pyproject.toml`
- **LSP Server:** pyright
- **Common issue:** Virtual environment not activated
- **Fix:** Activate venv before starting Claude Code, or configure pyrightconfig.json with `venvPath`

### Go
- **Prerequisite:** Go 1.18+ (go modules required)
- **Config:** gopls reads `go.mod`
- **LSP Server:** gopls
- **Common issue:** GOPATH vs Go modules confusion
- **Fix:** Ensure project has go.mod: `go mod init <module-name>`

### Rust
- **Prerequisite:** rustc, cargo
- **Config:** rust-analyzer reads `Cargo.toml`
- **LSP Server:** rust-analyzer
- **Common issue:** Slow initial indexing on large projects (can take 1-2 minutes)
- **Fix:** Wait for indexing to complete, shown in editor status bar

### C#
- **Prerequisite:** .NET SDK
- **Config:** OmniSharp reads `.csproj` or `.sln`
- **LSP Server:** OmniSharp
- **Common issue:** Multiple framework versions cause confusion
- **Fix:** Ensure correct .NET SDK version matches project target

### Java
- **Prerequisite:** JDK 11+
- **Config:** Eclipse JDT LS reads `pom.xml` or `build.gradle`
- **LSP Server:** Eclipse JDT Language Server
- **Common issue:** Maven/Gradle not configured properly
- **Fix:** Run `mvn install` or `gradle build` first

### Kotlin
- **Prerequisite:** JDK
- **Config:** kotlin-language-server reads `build.gradle.kts`
- **LSP Server:** kotlin-language-server
- **Common issue:** Kotlin version mismatch with LSP server
- **Fix:** Update Kotlin compiler version in build.gradle.kts

### Lua
- **Prerequisite:** None (pure LSP implementation)
- **Config:** lua-language-server reads `.luarc.json`
- **LSP Server:** lua-language-server
- **Common issue:** Lua version detection (5.1, 5.2, 5.3, 5.4, LuaJIT)
- **Fix:** Specify Lua version in `.luarc.json`

### PHP
- **Prerequisite:** PHP 7+
- **Config:** Intelephense reads `.intelephense/config.json`
- **LSP Server:** Intelephense
- **Common issue:** Composer autoload not found
- **Fix:** Run `composer install` to generate autoload files

### C/C++
- **Prerequisite:** LLVM/Clang installed
- **Config:** clangd reads `compile_commands.json`
- **LSP Server:** clangd
- **Common issue:** Missing compile_commands.json
- **Fix:** Generate with CMake: `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .`

### Swift
- **Prerequisite:** Swift 5.5+
- **Config:** SourceKit-LSP reads `Package.swift`
- **LSP Server:** sourcekit-lsp
- **Common issue:** Xcode command line tools not installed
- **Fix:** Run `xcode-select --install`

## Verification Checklist

After LSP setup:
- [ ] Plugin exists in `installed_plugins.json`
- [ ] LSP server binary available: `command -v <server>`
- [ ] Project config file exists (tsconfig.json, pyproject.toml, go.mod, etc.)
- [ ] LSP responds to basic request (hover test in Claude Code)
- [ ] No LSP errors in Claude Code console

## Known Limitations

**Claude Code LSP v2.0.74 (December 2025):**
- LSP support is "raw" with bugs
- No UI indication of LSP status in editor
- No documentation for LSP operations
- Some LSP operations may fail silently
- No error reporting when LSP servers crash

**Mitigation:**
- Always verify LSP server availability before relying on it
- Provide fallback to basic syntax checking
- Don't block workflow on LSP failures
- Warn user about potential LSP instability

## Usage Examples

### Example 1: Python Project (Plugin Not Installed)

**Input (from context-awareness):**
```json
{"project_context": {"language": "python", "framework": "fastapi"}}
```

**LSP Integration Processing:**
1. Detect language: "python"
2. Map to plugin: "pyright-lsp@claude-plugins-official"
3. Check installed_plugins.json: NOT FOUND
4. Status: NOT_INSTALLED

**Output:**
```json
{
  "lsp_status": {
    "language": "python",
    "lsp_plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": false,
    "server_available": false,
    "status": "NOT_INSTALLED",
    "recommendation": "Install pyright-lsp for type checking and code intelligence?",
    "install_command": "/plugin install pyright-lsp@claude-plugins-official",
    "server_install_guide": "npm install -g pyright"
  }
}
```

**Claude Action:** Prompts user to install pyright-lsp

### Example 2: TypeScript Project (LSP Ready)

**Input:**
```json
{"project_context": {"language": "typescript", "framework": "react"}}
```

**LSP Integration Processing:**
1. Detect language: "typescript"
2. Map to plugin: "typescript-lsp@claude-plugins-official"
3. Check installed_plugins.json: FOUND (installed for familyBudget project)
4. Check server: `command -v vtsls` → SUCCESS
5. Status: READY

**Output:**
```json
{
  "lsp_status": {
    "language": "typescript",
    "lsp_plugin": "typescript-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_available": true,
    "status": "READY",
    "recommendation": "LSP ready for use",
    "install_command": null,
    "server_install_guide": null
  }
}
```

**Claude Action:** Silent activation, continues to PHASE 1

### Example 3: Bash Project (No LSP Support)

**Input:**
```json
{"project_context": {"language": "bash"}}
```

**LSP Integration Processing:**
1. Detect language: "bash"
2. Map to plugin: null (no LSP support)
3. Status: NOT_SUPPORTED

**Output:**
```json
{
  "lsp_status": {
    "language": "bash",
    "lsp_plugin": null,
    "plugin_installed": false,
    "server_available": false,
    "status": "NOT_SUPPORTED",
    "recommendation": null,
    "install_command": null,
    "server_install_guide": null
  }
}
```

**Claude Action:** Skip LSP integration entirely, no prompt

## FAQ

**Q: Should LSP installation be automatic or ask user?**
A: Ask user (non-blocking). Respects user preference and avoids surprise npm installs. Installation requires user consent via interactive prompt.

**Q: What if LSP server is slow or hanging?**
A: Timeout after 5 seconds, continue without LSP. User can retry manually. LSP failures never block task execution.

**Q: Should LSP be project-scoped or global?**
A: Project-scoped (default). Each project can have different LSP versions and configurations. User can install globally with `/plugin install --global` if desired.

**Q: How to handle multiple projects with same language?**
A: Plugin installed per-project in `installed_plugins.json`. Each project maintains independent LSP state and configuration.

**Q: What if user has custom LSP config?**
A: Respect existing config files. Don't overwrite user's `tsconfig.json`, `pyrightconfig.json`, etc. LSP integration only checks availability, doesn't modify configuration.

**Q: Can I disable LSP integration temporarily?**
A: Yes, respond "no" or "skip" when prompted for LSP installation. LSP skill will not prompt again in the same session.

**Q: How to debug LSP issues?**
A: Check Claude Code console for LSP errors. Verify server binary with `command -v <server>`. Check installed_plugins.json for plugin status. Review LSP server logs if available.

## Related Skills

- **context-awareness**: Provides language detection that drives LSP plugin selection
- **validation-framework**: Can leverage LSP diagnostics for enhanced validation (type errors, unused imports)
- **code-review**: Benefits from LSP-detected errors and type information during code quality checks
