# Basic Usage Example - isolated-environment

## Scenario

Когда вам нужно установить или управлять изолированной установкой NVM и Claude Code в директории проекта (`.nvm-isolated/`) без затрагивания системных установок.

**Use cases:**
- Первая установка изолированной среды
- Проверка статуса изолированной установки
- Repair broken symlinks после git clone

---

## Input

```json
{
  "action": "install",
  "directory": ".nvm-isolated",
  "versions": {
    "nvm": "0.39.7",
    "node": "18.20.8",
    "claude_code": "2.1.7"
  }
}
```

---

## Execution

isolated-environment skill выполняет следующие шаги:

### Step 1: Скачивание NVM
- Download NVM v0.39.7 via curl
- Install в `.nvm-isolated/`
- Set `NVM_DIR=.nvm-isolated`

### Step 2: Установка Node.js
- `nvm install 18.20.8`
- Verify installation
- Set as default version

### Step 3: Установка Claude Code
- `npm install -g @anthropic-ai/claude-code`
- Create symlinks: `npm-global/bin/claude` → `cli.js`
- Verify binary availability

### Step 4: Сохранение lockfile
- Create `.nvm-isolated-lockfile.json` with versions
- Timestamp installation

---

## Output

```
✓ NVM v0.39.7 установлен в .nvm-isolated/
✓ Node.js v18.20.8 установлен
✓ Claude Code v2.1.7 установлен
✓ Symlinks созданы:
  - npm-global/bin/npm → ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
  - npm-global/bin/npx → ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npx-cli.js
  - npm-global/bin/claude → ../../versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/cli.js
✓ Lockfile создан: .nvm-isolated-lockfile.json

📊 Размер установки: ~278MB
📍 Claude binary: .nvm-isolated/npm-global/bin/claude
```

**Lockfile content:**
```json
{
  "nodeVersion": "18.20.8",
  "claudeCodeVersion": "2.1.7",
  "routerVersion": "not installed",
  "ghCliVersion": "not installed",
  "lspServers": {},
  "lspPlugins": {},
  "installedAt": "2026-01-15T14:30:00Z",
  "nvmVersion": "0.39.7"
}
```

---

## Explanation

### Преимущества изолированной установки:

1. **Портабельность:** Весь environment в одной директории (можно коммитить в git)
2. **Reproducibility:** Lockfile гарантирует одинаковые версии на всех машинах
3. **Изоляция:** Не конфликтует с системными Node.js/NVM установками
4. **No sudo:** Установка без root прав
5. **Git-friendly:** После git clone достаточно `--repair-isolated`

### Repair после git clone:

```bash
# После git clone symlinks сломаны
./iclaude.sh --repair-isolated

# Output:
# ✓ npm symlink восстановлен
# ✓ npx symlink восстановлен
# ✓ claude symlink восстановлен
```

### Проверка статуса:

```bash
./iclaude.sh --check-isolated

# Output:
# Isolated Environment Status
# ────────────────────────────
# Node.js: v18.20.8
# Claude Code: v2.1.7
# NVM: v0.39.7
# Lockfile: ✓ (2026-01-15T14:30:00Z)
# Symlinks: ✓ Valid
```

---

## Related

- [isolated-environment/SKILL.md](../SKILL.md)
- [iclaude.sh functions](../../../CLAUDE.md#isolated-environment)
