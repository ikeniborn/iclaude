# Basic Usage Example - lsp-integration

## Scenario

Когда проект использует TypeScript и Python, lsp-integration автоматически проверяет наличие LSP plugins и серверов, устанавливает их при необходимости и выводит `lsp_status` для других skills.

**Use cases:**
- Настройка LSP для нового проекта
- Проверка статуса LSP перед code-review
- Auto-install LSP plugins

---

## Input

```json
{
  "project_context": {
    "languages": ["typescript", "python"],
    "package_json": true,
    "requirements_txt": true
  }
}
```

---

## Execution

lsp-integration skill выполняет следующие шаги:

### Step 1: Language Detection
- Обнаружено: TypeScript (package.json), Python (requirements.txt)

### Step 2: Check LSP Plugins
- TypeScript: проверка `typescript-lsp@claude-plugins-official`
- Python: проверка `pyright-lsp@claude-plugins-official`

### Step 3: Check LSP Servers
- TypeScript: проверка `vtsls` binary
- Python: проверка `pyright` binary

### Step 4: Recommendations
- Если plugin отсутствует → предложить `/plugin install`
- Если server отсутствует → предложить `npm install -g`

---

## Output

```json
{
  "lsp_status": {
    "status": "READY",
    "languages": [
      {
        "language": "typescript",
        "plugin": "typescript-lsp@claude-plugins-official",
        "plugin_installed": true,
        "server": "vtsls",
        "server_installed": true,
        "server_version": "0.2.3"
      },
      {
        "language": "python",
        "plugin": "pyright-lsp@claude-plugins-official",
        "plugin_installed": true,
        "server": "pyright",
        "server_installed": true,
        "server_version": "1.1.347"
      }
    ]
  }
}
```

**Console output:**
```
✓ LSP Integration: READY
✓ TypeScript: vtsls v0.2.3
✓ Python: pyright v1.1.347

🎯 Available features:
  - Go-to-definition
  - Find references
  - Type checking
  - Auto-completion
```

---

## Explanation

### LSP Status Values:

- **READY:** Все plugins и servers установлены
- **PARTIAL:** Некоторые languages имеют LSP, другие нет
- **NOT_READY:** LSP недоступен ни для одного language

### Integration with other skills:

**code-review skill:**
```
IF lsp_status.status == "READY":
  - Use LSP diagnostics for type checking
  - Merge LSP errors into code_review.warnings[]
ELSE:
  - Fallback to regex-based checks
```

**structured-planning skill:**
```
IF lsp_status.languages contains "typescript":
  - Suggest using TypeScript strict mode
  - Add type checking validation steps
```

### Missing LSP example:

```json
{
  "lsp_status": {
    "status": "NOT_READY",
    "languages": [
      {
        "language": "typescript",
        "plugin": "typescript-lsp@claude-plugins-official",
        "plugin_installed": false,
        "server": "vtsls",
        "server_installed": false,
        "recommendation": "/plugin install typescript-lsp@claude-plugins-official && npm install -g @vtsls/language-server"
      }
    ]
  }
}
```

**Console output:**
```
⚠️  LSP Integration: NOT_READY
✗ TypeScript: LSP plugin not installed

📝 Recommendations:
  /plugin install typescript-lsp@claude-plugins-official
  npm install -g @vtsls/language-server
```

---

## Related

- [lsp-integration/SKILL.md](../SKILL.md)
- [External Dependencies](./../_shared/external-dependencies.md#lsp-plugins-language-server-protocol)
