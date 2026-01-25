---
name: LSP Integration
description: Автоматическая установка и конфигурация LSP плагинов
version: 1.1.0
tags: [lsp, language-server, code-intelligence, plugins]
dependencies: [context-awareness]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
user-invocable: false
changelog:
  - version: 1.1.0
    date: 2026-01-25
    changes:
      - "Добавлено: 3 примера (Python LSP setup, TypeScript LSP, LSP not available)"
      - "Обновлены references на @shared:"
      - "Улучшена документация manual fallback"
---

# LSP Integration

Автоматическая установка и конфигурация Language Server Protocol (LSP) плагинов для code intelligence.

## Когда использовать

- **Автоматически** в начале КАЖДОЙ задачи (PHASE 0)
- После `@skill:context-awareness` и перед `@skill:context7-integration`
- Когда обнаружен язык с доступным LSP plugin
- Перед началом планирования (до `@skill:structured-planning`)

**Auto-trigger:** Всегда активируется после context-awareness в PHASE 0.

**Условия активации:**
- Claude Code LSP plugin доступен для detected language
- LSP server binary установлен (или доступна автоматическая установка)
- Не блокирует workflow при недоступности plugin/server

## Supported Languages

### Tier 1: Full Auto-Install Support

| Language | Plugin | LSP Server | Install Command | Binary Path |
|----------|--------|------------|-----------------|-------------|
| TypeScript/JavaScript | typescript-lsp@claude-plugins-official | vtsls | `npm install -g @vtsls/language-server` | `vtsls` |
| Python | pyright-lsp@claude-plugins-official | pyright | `npm install -g pyright` | `pyright` |
| Go | gopls-lsp@claude-plugins-official | gopls | `go install golang.org/x/tools/gopls@latest` | `gopls` |
| Rust | rust-analyzer-lsp@claude-plugins-official | rust-analyzer | `rustup component add rust-analyzer` | `rust-analyzer` |

### Tier 2: Manual Install Recommended

| Language | Plugin | LSP Server | Prerequisites |
|----------|--------|------------|---------------|
| C# | csharp-lsp@claude-plugins-official | OmniSharp | .NET SDK |
| Java | jdtls-lsp@claude-plugins-official | Eclipse JDT LS | JDK 11+ |
| Kotlin | kotlin-lsp@claude-plugins-official | kotlin-language-server | Kotlin compiler |
| Lua | lua-lsp@claude-plugins-official | lua-language-server | Lua runtime |
| PHP | php-lsp@claude-plugins-official | Intelephense | PHP 7.4+ |
| C/C++ | clangd-lsp@claude-plugins-official | clangd | LLVM/Clang |
| Swift | swift-lsp@claude-plugins-official | SourceKit-LSP | Swift toolchain |

## Algorithm

### 3-Phase Detection & Setup

```
PHASE 0: Language Detection (from context-awareness)
├─ Get project_context.language
├─ Get project_context.framework
└─ Determine LSP plugin name

PHASE 1: Check LSP Plugin Installation
├─ Run: claude plugin list (via Claude Code CLI)
├─ Parse output for LSP plugin
└─ If not installed → Prompt user (non-blocking)

PHASE 2: Verify LSP Server Binary
├─ Check PATH for LSP server binary
│   - TypeScript: which vtsls
│   - Python: which pyright
│   - Go: which gopls
│   - Rust: which rust-analyzer
├─ If binary not found → Prompt user with install command
└─ Return lsp_status to workflow
```

## Detection Logic

### Plugin Name Mapping

**From context-awareness language:**
```javascript
const LSP_PLUGIN_MAP = {
  'typescript': 'typescript-lsp@claude-plugins-official',
  'javascript': 'typescript-lsp@claude-plugins-official',
  'python': 'pyright-lsp@claude-plugins-official',
  'go': 'gopls-lsp@claude-plugins-official',
  'rust': 'rust-analyzer-lsp@claude-plugins-official',
  'csharp': 'csharp-lsp@claude-plugins-official',
  'java': 'jdtls-lsp@claude-plugins-official',
  'kotlin': 'kotlin-lsp@claude-plugins-official',
  'lua': 'lua-lsp@claude-plugins-official',
  'php': 'php-lsp@claude-plugins-official',
  'c': 'clangd-lsp@claude-plugins-official',
  'cpp': 'clangd-lsp@claude-plugins-official',
  'swift': 'swift-lsp@claude-plugins-official'
};

function detectLSPPlugin(language) {
  return LSP_PLUGIN_MAP[language.toLowerCase()] || null;
}
```

### Server Binary Mapping

**From language to binary:**
```javascript
const LSP_SERVER_MAP = {
  'typescript-lsp@claude-plugins-official': 'vtsls',
  'pyright-lsp@claude-plugins-official': 'pyright',
  'gopls-lsp@claude-plugins-official': 'gopls',
  'rust-analyzer-lsp@claude-plugins-official': 'rust-analyzer',
  'csharp-lsp@claude-plugins-official': 'omnisharp',
  'jdtls-lsp@claude-plugins-official': 'jdtls',
  'kotlin-lsp@claude-plugins-official': 'kotlin-language-server',
  'lua-lsp@claude-plugins-official': 'lua-language-server',
  'php-lsp@claude-plugins-official': 'intelephense',
  'clangd-lsp@claude-plugins-official': 'clangd',
  'swift-lsp@claude-plugins-official': 'sourcekit-lsp'
};
```

## Installation Check

### Plugin Installation Status

**Method: Claude Code CLI**
```bash
# Check if plugin installed
claude plugin list | grep -q "typescript-lsp@claude-plugins-official"

# Exit code 0 = installed
# Exit code 1 = not installed
```

**Alternative: Parse plugin list output**
```bash
# Full plugin list
claude plugin list

# Example output:
# ✓ pyright-lsp@claude-plugins-official v1.0.0
# ✓ typescript-lsp@claude-plugins-official v1.0.0
#   Available: gopls-lsp@claude-plugins-official
```

### Server Binary Check

**Method: which command**
```bash
# TypeScript
which vtsls >/dev/null 2>&1 && echo "installed" || echo "not_found"

# Python
which pyright >/dev/null 2>&1 && echo "installed" || echo "not_found"

# Go
which gopls >/dev/null 2>&1 && echo "installed" || echo "not_found"

# Rust
which rust-analyzer >/dev/null 2>&1 && echo "installed" || echo "not_found"
```

**Cross-platform compatibility:**
```bash
# Linux/macOS
which vtsls

# Windows (PowerShell)
Get-Command vtsls -ErrorAction SilentlyContinue

# Windows (CMD)
where vtsls
```

## User Prompts (Non-Blocking)

### Scenario A: Plugin Not Installed

**Condition:** LSP plugin available but not installed

**Prompt:**
```
ℹ️ LSP plugin available for Python: pyright-lsp

To enable code intelligence (go-to-definition, type checking):
  /plugin install pyright-lsp@claude-plugins-official

Continue without LSP? (workflow will not block)
```

**Action:** Display prompt, continue to next skill immediately (non-blocking)

### Scenario B: Server Binary Not Found

**Condition:** Plugin installed but LSP server binary missing

**Prompt:**
```
⚠️ pyright-lsp plugin installed, but pyright server not found.

Install LSP server:
  npm install -g pyright

Or continue without LSP server (limited functionality)
```

**Action:** Display prompt, continue to next skill immediately (non-blocking)

### Scenario C: Both Missing

**Condition:** Neither plugin nor server available

**Prompt:**
```
ℹ️ LSP support available for Python

Setup (2 steps):
  1. /plugin install pyright-lsp@claude-plugins-official
  2. npm install -g pyright

Continue without LSP? (workflow will not block)
```

**Action:** Display prompt, continue immediately

### Scenario D: Fully Configured

**Condition:** Plugin installed AND server binary found

**Output:** (silent, no prompt)

**Status:**
```json
{
  "lsp_status": {
    "plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_binary": "pyright",
    "server_available": true,
    "capabilities": ["go_to_definition", "find_references", "hover", "diagnostics"],
    "status": "READY"
  }
}
```

## Output Format

### JSON Schema

Используй шаблон: `@template:lsp-output`

Валидация: `@schema:lsp-output`

**Структура:**
```json
{
  "lsp_status": {
    "plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_binary": "pyright",
    "server_available": true,
    "capabilities": [
      "go_to_definition",
      "find_references",
      "hover",
      "document_symbol",
      "diagnostics"
    ],
    "status": "READY"
  }
}
```

### Status Values

- `READY`: Plugin + server обнаружены и работают
- `PLUGIN_MISSING`: Plugin не установлен (prompt shown)
- `SERVER_MISSING`: Plugin установлен, но server binary отсутствует (prompt shown)
- `NOT_AVAILABLE`: LSP не доступен для этого языка
- `SKIPPED`: Language не обнаружен context-awareness

### Field Descriptions

**plugin:**
- Plugin name в формате `<name>@<registry>`
- Пример: `pyright-lsp@claude-plugins-official`

**plugin_installed:**
- `true`: Plugin установлен через `/plugin install`
- `false`: Plugin не найден в `claude plugin list`

**server_binary:**
- Имя binary для LSP server (`pyright`, `vtsls`, etc.)
- `null` если LSP не доступен для языка

**server_available:**
- `true`: Binary найден в PATH (`which <binary>` успешен)
- `false`: Binary не найден

**capabilities:**
- Массив доступных LSP features
- Возможные значения: `go_to_definition`, `find_references`, `hover`, `document_symbol`, `diagnostics`, `code_action`, `rename`

**status:**
- См. "Status Values" выше

## Integration with Workflow

### PHASE 0 Data Flow

```
context-awareness → {project_context}
                ↓
lsp-integration → {lsp_status}  [NEW]
                ↓
context7-integration → {library_docs}
                ↓
adaptive-workflow → {complexity}
```

### Input from context-awareness

```json
{
  "project_context": {
    "language": "python",
    "framework": "fastapi",
    "syntax_command": "python -m py_compile"
  }
}
```

### Output to structured-planning

```json
{
  "lsp_status": {
    "plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_binary": "pyright",
    "server_available": true,
    "capabilities": ["go_to_definition", "find_references", "hover", "diagnostics"],
    "status": "READY"
  }
}
```

### Benefits for Code Review (PHASE 3)

**code-review может использовать lsp_status для:**

1. **Type checking:** LSP diagnostics вместо syntax_command
   ```
   if lsp_status.status == "READY":
     use LSP diagnostics (более точные type errors)
   else:
     fallback to syntax_command
   ```

2. **Go-to-definition:** Navigate symbol definitions
   ```
   LSP.goToDefinition(filePath="auth.py", line=42, character=15)
   → Returns: {uri: "services/user.py", range: {start: {line: 10, character: 6}}}
   ```

3. **Find references:** Locate all usages
   ```
   LSP.findReferences(filePath="user.py", line=10, character=6)
   → Returns: [{uri: "auth.py", range: ...}, {uri: "api.py", range: ...}]
   ```

4. **Hover documentation:** Get type info
   ```
   LSP.hover(filePath="auth.py", line=42, character=15)
   → Returns: {contents: "function validate_token(token: str) -> bool"}
   ```

## Installation Commands Reference

### TypeScript/JavaScript
```bash
# LSP plugin
/plugin install typescript-lsp@claude-plugins-official

# LSP server
npm install -g @vtsls/language-server

# Verify
which vtsls
```

### Python
```bash
# LSP plugin
/plugin install pyright-lsp@claude-plugins-official

# LSP server
npm install -g pyright

# Verify
which pyright
```

### Go
```bash
# LSP plugin
/plugin install gopls-lsp@claude-plugins-official

# LSP server (requires Go toolchain)
go install golang.org/x/tools/gopls@latest

# Verify
which gopls
```

### Rust
```bash
# LSP plugin
/plugin install rust-analyzer-lsp@claude-plugins-official

# LSP server (via rustup)
rustup component add rust-analyzer

# Verify
which rust-analyzer
```

### C#
```bash
# LSP plugin
/plugin install csharp-lsp@claude-plugins-official

# LSP server (via .NET SDK)
dotnet tool install -g OmniSharp

# Verify
which omnisharp
```

### Java
```bash
# LSP plugin
/plugin install jdtls-lsp@claude-plugins-official

# LSP server (manual download required)
# Download from: https://download.eclipse.org/jdtls/snapshots/
# Extract to ~/.local/share/eclipse.jdt.ls/

# Add to PATH
export PATH="$HOME/.local/share/eclipse.jdt.ls/bin:$PATH"

# Verify
which jdtls
```

### Kotlin
```bash
# LSP plugin
/plugin install kotlin-lsp@claude-plugins-official

# LSP server (via SDKMAN or manual)
sdk install kotlin
git clone https://github.com/fwcd/kotlin-language-server.git
cd kotlin-language-server
./gradlew :server:installDist

# Add to PATH
export PATH="$HOME/kotlin-language-server/server/build/install/server/bin:$PATH"

# Verify
which kotlin-language-server
```

### Lua
```bash
# LSP plugin
/plugin install lua-lsp@claude-plugins-official

# LSP server (via LuaRocks)
luarocks install --server=https://luarocks.org/dev lua-lsp

# Or via binary release
# Download from: https://github.com/LuaLS/lua-language-server/releases

# Verify
which lua-language-server
```

### PHP
```bash
# LSP plugin
/plugin install php-lsp@claude-plugins-official

# LSP server
npm install -g intelephense

# Verify
which intelephense
```

### C/C++
```bash
# LSP plugin
/plugin install clangd-lsp@claude-plugins-official

# LSP server (via LLVM/Clang)
# Ubuntu/Debian
sudo apt install clangd

# macOS
brew install llvm

# Verify
which clangd
```

### Swift
```bash
# LSP plugin
/plugin install swift-lsp@claude-plugins-official

# LSP server (included with Swift toolchain)
# Install Swift toolchain from: https://swift.org/download/
# SourceKit-LSP included automatically

# Verify
which sourcekit-lsp
```

## Examples

### Example 1: Python LSP Setup (Plugin Installed, Server Available)

**Scenario:** Python project, pyright plugin + server установлены

**Input from context-awareness:**
```json
{
  "project_context": {
    "language": "python",
    "framework": "fastapi",
    "syntax_command": "python -m py_compile"
  }
}
```

**Detection:**
```bash
# Check plugin
claude plugin list | grep "pyright-lsp@claude-plugins-official"
# Output: ✓ pyright-lsp@claude-plugins-official v1.0.0

# Check server
which pyright
# Output: /usr/local/bin/pyright
```

**Output:**
```json
{
  "lsp_status": {
    "plugin": "pyright-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_binary": "pyright",
    "server_available": true,
    "capabilities": [
      "go_to_definition",
      "find_references",
      "hover",
      "document_symbol",
      "diagnostics",
      "code_action"
    ],
    "status": "READY"
  }
}
```

**User message:** (silent, no output)

**Result:** code-review может использовать LSP diagnostics вместо `python -m py_compile` для более точных type errors.

---

### Example 2: TypeScript LSP (Plugin Missing)

**Scenario:** TypeScript project, LSP plugin не установлен

**Input from context-awareness:**
```json
{
  "project_context": {
    "language": "typescript",
    "framework": "react",
    "syntax_command": "tsc --noEmit"
  }
}
```

**Detection:**
```bash
# Check plugin
claude plugin list | grep "typescript-lsp@claude-plugins-official"
# Exit code: 1 (not found)

# Check server (skip if plugin missing)
which vtsls
# (not checked)
```

**Output:**
```json
{
  "lsp_status": {
    "plugin": "typescript-lsp@claude-plugins-official",
    "plugin_installed": false,
    "server_binary": "vtsls",
    "server_available": null,
    "capabilities": [],
    "status": "PLUGIN_MISSING"
  }
}
```

**User message:**
```
ℹ️ LSP plugin available for TypeScript: typescript-lsp

To enable code intelligence (go-to-definition, type checking):
  /plugin install typescript-lsp@claude-plugins-official

After installing plugin, install LSP server:
  npm install -g @vtsls/language-server

Continue without LSP? (workflow will not block)
```

**Result:** Workflow продолжается к context7-integration, code-review использует `tsc --noEmit` fallback.

---

### Example 3: Go LSP (Plugin Installed, Server Missing)

**Scenario:** Go project, gopls plugin установлен, но server binary отсутствует

**Input from context-awareness:**
```json
{
  "project_context": {
    "language": "go",
    "framework": "none",
    "syntax_command": "go build -o /dev/null"
  }
}
```

**Detection:**
```bash
# Check plugin
claude plugin list | grep "gopls-lsp@claude-plugins-official"
# Output: ✓ gopls-lsp@claude-plugins-official v1.0.0

# Check server
which gopls
# Exit code: 1 (not found)
```

**Output:**
```json
{
  "lsp_status": {
    "plugin": "gopls-lsp@claude-plugins-official",
    "plugin_installed": true,
    "server_binary": "gopls",
    "server_available": false,
    "capabilities": [],
    "status": "SERVER_MISSING"
  }
}
```

**User message:**
```
⚠️ gopls-lsp plugin installed, but gopls server not found.

Install LSP server:
  go install golang.org/x/tools/gopls@latest

Make sure $GOPATH/bin is in your PATH:
  export PATH="$GOPATH/bin:$PATH"

Or continue without LSP server (limited functionality)
```

**Result:** Workflow продолжается, code-review использует `go build -o /dev/null` fallback.

---

## Manual Fallback

**Если LSP недоступен**, other skills используют fallback:

**code-review:**
```
if lsp_status.status == "READY":
  diagnostics = LSP.diagnostics(filePath)
else:
  # Fallback to syntax_command
  result = run(project_context.syntax_command + " " + filePath)
```

**validation-framework:**
```
if lsp_status.status == "READY":
  type_errors = LSP.diagnostics(filePath, severity="error")
else:
  # Fallback to language-specific compiler
  type_errors = run_type_checker(filePath)
```

**structured-planning:**
```
if lsp_status.status == "READY":
  references = LSP.findReferences(filePath, line, character)
  # Use references для impact analysis
else:
  # Fallback to grep-based search
  references = grep_for_symbol(symbol_name)
```

## FAQ

**Q: Что происходит, если LSP plugin не установлен?**
A: Skill показывает non-blocking prompt с инструкцией `/plugin install`, workflow продолжается к следующему skill. Other skills используют fallback methods (syntax_command, grep, etc.).

**Q: Можно ли пропустить LSP integration?**
A: Да, skill полностью optional и non-blocking. Если plugin/server отсутствуют, workflow продолжается нормально с fallback методами.

**Q: Какие LSP capabilities наиболее важны?**
A: Для code-review: `diagnostics` (type errors). Для refactoring: `find_references`, `rename`. Для navigation: `go_to_definition`.

**Q: Работает ли LSP для всех языков?**
A: Нет. Только для языков с available Claude Code LSP plugins (см. "Supported Languages"). Для других языков skill возвращает `NOT_AVAILABLE`.

**Q: Как узнать, установлен ли plugin?**
A: Внутри Claude Code сессии: `/plugin list`. CLI: `claude plugin list | grep <plugin-name>`.

**Q: Что делать, если server binary не в PATH?**
A: Добавить директорию server binary в PATH environment variable. Пример для Go: `export PATH="$GOPATH/bin:$PATH"`. Для npm globals: `export PATH="$(npm bin -g):$PATH"`.

**Q: Можно ли использовать LSP без Claude Code plugin?**
A: Нет. LSP integration требует Claude Code LSP plugin (`<lang>-lsp@claude-plugins-official`) для communication с LSP server.

**Q: Блокирует ли LSP setup workflow?**
A: Нет. LSP integration полностью non-blocking. Prompts информационные, workflow продолжается независимо от LSP availability.

## Related Skills

- **context-awareness**: Предоставляет `language` для LSP plugin detection
- **code-review**: Использует `lsp_status` для enhanced type checking и diagnostics
- **validation-framework**: Fallback to `syntax_command` если LSP недоступен
- **structured-planning**: Может использовать LSP find_references для impact analysis

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
