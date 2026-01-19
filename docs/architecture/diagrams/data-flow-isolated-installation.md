# Поток изолированной установки

Показывает процесс установки изолированного окружения с NVM, Node.js и Claude Code.

## Создаваемые артефакты

| Путь | Описание |
|------|----------|
| `.nvm-isolated/` | Корневая директория окружения |
| `.nvm-isolated/nvm.sh` | Скрипт NVM |
| `.nvm-isolated/versions/node/v18.x.x/` | Установка Node.js |
| `.nvm-isolated/npm-global/bin/claude` | Симлинк на CLI |
| `.nvm-isolated/.claude-isolated/` | Изолированная конфигурация |
| `.nvm-isolated-lockfile.json` | Файл версий |

## Диаграмма

```mermaid
graph TD
    %% Isolated Installation Flow
    USER[User] -->|1. Execute --isolated-install| CLI[CLI Main]
    CLI -->|2. Create directory| DIR[.nvm-isolated/]

    DIR -->|3. Download NVM| NVM_DOWNLOAD[Download NVM<br/>install.sh]
    NVM_DOWNLOAD -->|4. Install NVM| NVM_INST[NVM Installer]

    NVM_INST -->|5. Set NVM_DIR| NVM_ENV[NVM Environment]
    NVM_ENV -->|6. Install Node.js| NODE_INST[Node.js Installer]

    NODE_INST -->|7. nvm install 18.20.8| NODE_BIN[Node.js v18.20.8<br/>in .nvm-isolated/]

    NODE_BIN -->|8. npm install -g| CLAUDE_INST[Claude Code Installer]
    CLAUDE_INST -->|9. Install @anthropic-ai/claude-code| CLAUDE_PKG[Claude Code Package]

    CLAUDE_PKG -->|10. Create symlink| SYMLINK[Symlink Manager]
    SYMLINK -->|11. Link claude binary| CLAUDE_BIN[.nvm-isolated/npm-global/bin/claude]

    CLAUDE_BIN -->|12. Detect versions| VERSION_DETECT[Version Detector]
    VERSION_DETECT -->|13. Get Node version| NODE_VER[node --version]
    VERSION_DETECT -->|14. Get Claude version| CLAUDE_VER[claude --version]

    NODE_VER -->|15. Save to lockfile| LOCKFILE[Lockfile Saver]
    CLAUDE_VER -->|15. Save to lockfile| LOCKFILE

    LOCKFILE -->|16. Write JSON| LOCK_FILE[.nvm-isolated-lockfile.json]
    LOCK_FILE -->|17. Success message| USER

    %% Styling
    classDef userClass fill:#e1f5ff,stroke:#1976d2,stroke-width:2px
    classDef processClass fill:#fff4e1,stroke:#f57c00,stroke-width:2px
    classDef storageClass fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    classDef binaryClass fill:#f0f0f0,stroke:#616161,stroke-width:2px

    class USER userClass
    class CLI,NVM_INST,NODE_INST,CLAUDE_INST,SYMLINK,VERSION_DETECT,LOCKFILE processClass
    class DIR,NVM_ENV,LOCK_FILE storageClass
    class NVM_DOWNLOAD,NODE_BIN,CLAUDE_PKG,CLAUDE_BIN,NODE_VER,CLAUDE_VER binaryClass
```

## Этапы установки

### 1. Создание директории
```bash
mkdir -p .nvm-isolated
```

### 2-4. Установка NVM
- Скачивание `install.sh` с GitHub
- Установка в `.nvm-isolated/`
- Конфигурация `NVM_DIR`

### 5-7. Установка Node.js
```bash
nvm install 18.20.8
```

### 8-9. Установка Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### 10-11. Создание симлинков
```bash
ln -s ../../versions/node/v18.x.x/lib/node_modules/@anthropic-ai/claude-code/cli.js \
      .nvm-isolated/npm-global/bin/claude
```

### 12-16. Сохранение версий
Lockfile записывается в формате JSON:
```json
{
  "nodeVersion": "18.20.8",
  "claudeCodeVersion": "2.1.7",
  "installedAt": "2026-01-14T10:39:51Z",
  "nvmVersion": "0.39.7"
}
```

## Восстановление после git clone

После клонирования репозитория симлинки могут быть сломаны. Для восстановления:

```bash
./iclaude.sh --repair-isolated
```

Это пересоздаст все необходимые симлинки.
