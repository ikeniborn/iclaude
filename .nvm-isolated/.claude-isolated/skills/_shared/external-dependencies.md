# External Dependencies - Shared Component

**Version:** 1.0.0
**Author:** iclaude Skills Team
**Purpose:** Документация внешних зависимостей (plugins, MCP servers, tools)

---

## Overview

Некоторые skills зависят от внешних компонентов, которые НЕ являются частью Claude Code CLI. Этот документ описывает:
- Какие skills требуют внешние зависимости
- Как установить эти зависимости
- Что происходит при их отсутствии (fallback behavior)

**Типы зависимостей:**
1. **Claude Code Plugins** - расширения для Claude Code CLI
2. **MCP Servers** - Model Context Protocol серверы для интеграции с внешними сервисами
3. **CLI Tools** - утилиты командной строки (gh, git)
4. **LSP Servers** - Language Server Protocol серверы для code intelligence

---

## 1. Claude Code Plugins

### Ralph-Loop Plugin

**Используется в:** pr-automation skill
**Назначение:** Итеративное исправление CI/CD ошибок через авто-коммиты
**Репозиторий:** https://github.com/MightyPhoenix/ralph-loop

**Установка:**
```bash
# Внутри Claude Code сессии
# Ralph-loop plugin removed (deprecated)
```

**Проверка установки:**
```bash
/plugin list
# Должен быть в списке: ralph-loop@claude-plugins-official
```

**Что делает:**
- Мониторит статус CI/CD checks после создания PR
- Анализирует ошибки тестов, линтера, type checker
- Автоматически создаёт fixup коммиты
- Повторяет до прохождения всех проверок (max 5 итераций)

**Fallback при отсутствии:**
- pr-automation создаст PR, но не будет мониторить CI/CD
- Пользователю нужно вручную исправлять ошибки

---

### LSP Plugins (Language Server Protocol)

**Используются в:** lsp-integration skill, code-review skill
**Назначение:** Enhanced code intelligence (type checking, go-to-definition, find references)

**Поддерживаемые языки и plugins:**

| Язык | Plugin | LSP Server |
|------|--------|-----------|
| TypeScript/JavaScript | typescript-lsp@claude-plugins-official | vtsls |
| Python | pyright-lsp@claude-plugins-official | pyright |
| Go | gopls-lsp@claude-plugins-official | gopls |
| Rust | rust-analyzer-lsp@claude-plugins-official | rust-analyzer |
| C# | csharp-lsp@claude-plugins-official | OmniSharp |
| Java | jdtls-lsp@claude-plugins-official | Eclipse JDT LS |
| Kotlin | kotlin-lsp@claude-plugins-official | kotlin-language-server |
| Lua | lua-lsp@claude-plugins-official | lua-language-server |
| PHP | php-lsp@claude-plugins-official | Intelephense |
| C/C++ | clangd-lsp@claude-plugins-official | clangd |
| Swift | swift-lsp@claude-plugins-official | SourceKit-LSP |

**Установка plugin (пример для Python):**
```bash
# Внутри Claude Code сессии
/plugin install pyright-lsp@claude-plugins-official
```

**Установка LSP server binary (обязательно после plugin):**
```bash
# Python
npm install -g pyright

# TypeScript
npm install -g @vtsls/language-server

# Go
go install golang.org/x/tools/gopls@latest

# Rust (via rustup)
rustup component add rust-analyzer
```

**Проверка установки:**
```bash
# Plugin
/plugin list

# LSP server binary
which pyright          # Python
which vtsls            # TypeScript
which gopls            # Go
which rust-analyzer    # Rust
```

**Что делают:**
- **Go-to-definition**: переход к определению символа
- **Find references**: поиск всех использований символа
- **Type checking**: детектирование type errors до runtime
- **Auto-completion**: умные подсказки кода

**Интеграция в skills:**
- **lsp-integration skill**: проверяет наличие LSP plugin и server, выводит `lsp_status`
- **code-review skill**: использует `lsp_status.status == "READY"` для enhanced type checking
- LSP diagnostics (errors, warnings) попадают в `code_review.lsp_diagnostics[]`

**Fallback при отсутствии:**
- lsp-integration пропускается (non-blocking)
- code-review использует regex-based проверки (базовые)
- Меньше детектируемых type errors и code smells

---

## 2. MCP Servers (Model Context Protocol)

### Context7 MCP Server

**Используется в:** context7-integration skill, structured-planning skill
**Назначение:** Загрузка официальной документации библиотек для code examples
**Репозиторий:** https://github.com/modelcontextprotocol/servers/tree/main/src/context7

**Установка:**
```bash
# Установка MCP server
npx @modelcontextprotocol/create-server context7

# Добавить в Claude Code MCP config (~/.claude/mcp.json или .nvm-isolated/.claude-isolated/mcp.json)
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-context7"]
    }
  }
}
```

**Проверка установки:**
```bash
# Внутри Claude Code сессии
/mcp list
# Должен быть: context7
```

**Что делает:**
- Загружает официальную документацию 100+ популярных библиотек
- Предоставляет API для поиска code examples, API references, best practices
- Поддерживает: FastAPI, Django, Flask, React, Vue, pandas, numpy, pytest и т.д.

**Интеграция в skills:**
- **context7-integration skill**: загружает library docs, выводит `library_docs.loaded == true`
- **structured-planning skill**: enriches execution_steps с code examples из docs
- execution_steps содержат `library_reference` field (code_example, docs_url, framework, pattern)

**Fallback при отсутствии:**
- context7-integration пропускается (non-blocking)
- structured-planning генерирует базовые инструкции без code examples
- Меньше контекста для реализации (нужно самому искать примеры в доках)

---

## 3. CLI Tools

### GitHub CLI (gh)

**Используется в:** pr-automation skill, git-workflow skill
**Назначение:** Создание PR, управление issues, проверка CI/CD статуса
**Сайт:** https://cli.github.com/

**Установка:**
```bash
# Ubuntu/Debian
sudo apt install gh

# macOS (Homebrew)
brew install gh

# Windows (Winget)
winget install GitHub.cli
```

**Аутентификация:**
```bash
gh auth login
# Выбрать: GitHub.com → HTTPS → Login with browser
```

**Проверка установки:**
```bash
gh --version
# Должно быть: gh version 2.0.0 или выше
```

**Что делает:**
- Создание PR: `gh pr create --title "..." --body "..."`
- Проверка статуса PR: `gh pr checks <PR_NUMBER>`
- Управление issues: `gh issue create`, `gh issue close`
- Просмотр CI/CD runs: `gh run list`, `gh run view`

**Интеграция в skills:**
- **pr-automation skill**: создаёт PR через `gh pr create`, мониторит CI/CD через `gh pr checks`
- **git-workflow skill**: может ссылаться на issues через `gh issue view`

**Fallback при отсутствии:**
- pr-automation выдаст ошибку и предложит создать PR вручную
- Пользователю нужно зайти на GitHub UI

---

### Git

**Используется в:** git-workflow skill, pr-automation skill
**Назначение:** Version control operations
**Сайт:** https://git-scm.com/

**Установка:**
```bash
# Ubuntu/Debian
sudo apt install git

# macOS (Homebrew)
brew install git

# Windows
winget install Git.Git
```

**Проверка установки:**
```bash
git --version
# Должно быть: git version 2.0.0 или выше
```

**Что делает:**
- Создание веток: `git checkout -b feature/...`
- Коммиты: `git commit -m "..."`
- Push: `git push origin <branch>`
- Diff: `git diff`, `git log`

**Интеграция в skills:**
- **git-workflow skill**: создаёт ветки, коммиты, push
- **pr-automation skill**: push изменений перед созданием PR

**Fallback при отсутствии:**
- Невозможно работать с git репозиториями
- Skills выдадут ошибку

---

## 4. Skill Dependencies Matrix

Таблица зависимостей skills от внешних компонентов:

| Skill | Claude Plugins | MCP Servers | CLI Tools | LSP Servers |
|-------|----------------|-------------|-----------|-------------|
| lsp-integration | ✅ LSP plugins (11 lang) | - | - | ✅ LSP binaries |
| code-review | 🔶 LSP plugins (optional) | - | - | 🔶 LSP binaries (optional) |
| context7-integration | - | ✅ Context7 | - | - |
| structured-planning | - | 🔶 Context7 (optional) | - | - |
| pr-automation | - | - | ✅ gh, git | - |
| git-workflow | - | - | ✅ git | - |

**Легенда:**
- ✅ **Required** - skill не работает без этой зависимости
- 🔶 **Optional** - skill работает без зависимости (fallback mode)
- `-` Не требуется

---

## 5. Installation Workflow

**Рекомендуемая последовательность установки:**

### Minimal Setup (только required):
```bash
# CLI tools (обязательны для git-workflow, pr-automation)
sudo apt install git gh
gh auth login

# Готово для базовой работы
```

### Enhanced Setup (с optional dependencies):
```bash
# 1. Minimal setup (см. выше)

# 2. LSP для Python и TypeScript (самые популярные)
/plugin install pyright-lsp@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
npm install -g pyright @vtsls/language-server

# 3. Context7 для library docs
npx @modelcontextprotocol/create-server context7
# Добавить в mcp.json (см. секцию Context7 выше)

# 4. Ralph-loop для авто-фиксов PR
# Ralph-loop plugin removed (deprecated)

# Готово для полнофункциональной работы
```

### Full Setup (все языки):
```bash
# Enhanced setup + LSP для остальных языков
/plugin install gopls-lsp@claude-plugins-official
/plugin install rust-analyzer-lsp@claude-plugins-official
# ... и т.д. (см. таблицу LSP Plugins)

# Установить LSP server binaries для каждого языка
```

---

## 6. Troubleshooting

### Problem: LSP plugin installed but not working

**Symptoms:**
- `lsp_status.status == "NOT_READY"`
- code-review не показывает LSP diagnostics

**Solution:**
1. Проверить, что LSP **server binary** установлен (не только plugin):
   ```bash
   which pyright  # Должен вернуть путь
   ```
2. Если не установлен:
   ```bash
   npm install -g pyright
   ```
3. Перезапустить Claude Code

---

### Problem: Context7 not loading library docs

**Symptoms:**
- `library_docs.loaded == false`
- structured-planning не enriches execution_steps

**Solution:**
1. Проверить, что Context7 MCP server запущен:
   ```bash
   /mcp list
   # Должен быть: context7
   ```
2. Проверить mcp.json config (см. секцию Context7)
3. Перезапустить Claude Code

---

### Problem: gh pr create fails with auth error

**Symptoms:**
- `gh: authentication required`
- pr-automation не может создать PR

**Solution:**
```bash
gh auth login
# Повторить login через browser
```

---

### Problem: Ralph-loop not auto-fixing CI errors

**Symptoms:**
- PR создан, но CI errors не исправляются автоматически

**Solution:**
1. Проверить, что plugin установлен:
   ```bash
   /plugin list
   ```
2. Если нет:
   ```bash
   # Ralph-loop plugin removed (deprecated)
   ```
3. Перезапустить pr-automation skill

---

## 7. FAQ

**Q: Обязательно ли устанавливать все зависимости?**
A: Нет. Только CLI tools (git, gh) обязательны для git-workflow и pr-automation. Остальные (LSP, Context7) опциональны - skills работают без них в fallback режиме.

**Q: Как проверить, какие зависимости установлены?**
A: Запустить:
```bash
# Plugins
/plugin list

# MCP servers
/mcp list

# CLI tools
git --version
gh --version

# LSP servers
which pyright vtsls gopls rust-analyzer
```

**Q: Что если у меня нет прав sudo для установки CLI tools?**
A: Используйте версии без sudo:
```bash
# gh без sudo (в user space)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=$HOME/.local/share/keyrings/githubcli-archive-keyring.gpg
```

**Q: Можно ли использовать system-wide LSP servers вместо npm -g?**
A: Да, если они в PATH. Например, на Ubuntu:
```bash
sudo apt install pyright  # Вместо npm install -g pyright
```

**Q: Работают ли LSP plugins с удалённым SSH?**
A: Да, но LSP server должен быть установлен на удалённой машине.

---

## 8. Version History

- **1.0.0** (2026-01-15): Initial version
  - Документация для LSP plugins, Context7, gh, git
  - Installation workflow
  - Troubleshooting guide
  - Skills dependency matrix

---

## References

- [Loop Mode Documentation](../../CLAUDE.md#loop-mode-commands)
- [Context7 MCP Server](https://github.com/modelcontextprotocol/servers/tree/main/src/context7)
- [GitHub CLI](https://cli.github.com/)
- [Git](https://git-scm.com/)
- [LSP Specification](https://microsoft.github.io/language-server-protocol/)
- [Claude Code Plugins Official](https://github.com/anthropics/claude-code/tree/main/plugins)
- [lsp-integration/SKILL.md](../lsp-integration/SKILL.md)
- [context7-integration/SKILL.md](../context7-integration/SKILL.md)
- [pr-automation/SKILL.md](../pr-automation/SKILL.md)
