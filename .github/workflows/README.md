# GitHub Actions Workflows

## Auto-update Claude Code

Автоматическое обновление Claude Code CLI в изолированной среде через CI/CD.

### Как это работает

1. **Расписание**: Запускается каждый день в 03:00 UTC
2. **Проверка версии**: Сравнивает `.nvm-isolated-lockfile.json` с npm registry
3. **Обновление**: Если доступна новая версия → `./iclaude.sh --update`
4. **Коммит**: Автоматически коммитит изменения в master
5. **Push**: Изменения доступны всем через `git pull`

### Что обновляется

- `.nvm-isolated-lockfile.json` - версия в lockfile
- `.nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/` - файлы пакета
  - `cli.js` - основной исполняемый файл
  - `package.json` - версия и метаданные
  - `sdk-tools.d.ts` - TypeScript определения
  - остальные файлы при необходимости

### Ручной запуск

Можно запустить вручную через GitHub UI:

1. Перейти в **Actions** → **Auto-update Claude Code**
2. Нажать **Run workflow** → **Run workflow**
3. Дождаться завершения (~2-3 минуты)

### Преимущества CI/CD подхода

✅ **Централизованные обновления** - не нужно каждому обновлять локально
✅ **Консистентность** - все работают с одной версией
✅ **Портативность** - node_modules остаются в git для систем без Node.js
✅ **Автоматизация** - не нужно вручную коммитить гигантские диффы
✅ **Lockfile актуален** - всегда синхронизирован с фактической версией

### Локальные обновления (не рекомендуется)

Если вы обновили локально через `./iclaude.sh --update`:

```bash
# Вариант 1: Откатить и получить версию из CI/CD
git checkout .nvm-isolated/
git pull

# Вариант 2: Закоммитить локальное обновление
git add .nvm-isolated-lockfile.json
git add .nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/
git commit -m "chore(deps): update Claude Code to vX.Y.Z [skip ci]"
git push
```

**Рекомендация**: Доверьте обновления CI/CD, локально только `git pull`

### Workflow на другом ПК

```bash
# Утром проверить обновления
git pull

# Запустить с обновлённой версией
./iclaude.sh
```

**Всё!** Не нужно устанавливать Node.js, npm или вручную обновлять Claude Code.

### Мониторинг обновлений

- **GitHub Actions** → вкладка **Actions** → просмотр истории запусков
- **Git log**: `git log --oneline --grep="auto-update Claude Code"`
- **Lockfile**: `jq '.claudeCodeVersion' .nvm-isolated-lockfile.json`

### Troubleshooting

**Workflow не запускается автоматически:**
- Проверить, что в репозитории включены Actions (Settings → Actions → Allow all actions)
- GitHub может отключать scheduled workflows в неактивных репозиториях (> 60 дней)

**Конфликт при push:**
- Если кто-то закоммитил изменения одновременно с CI/CD
- Решение: workflow упадёт, следующий запуск подтянет изменения и повторит

**Обновление сломало окружение:**
- Откатиться на предыдущий коммит: `git checkout HEAD~1 .nvm-isolated/`
- Или откатить весь репозиторий: `git reset --hard HEAD~1`

### Будущие улучшения

- [ ] Тестирование перед коммитом (`./iclaude.sh --test`)
- [ ] Уведомления при обновлении (GitHub Issues, Telegram)
- [ ] Откат при неудачном обновлении
- [ ] Обновление других компонентов (router, LSP servers)
- [ ] Release notes в коммите
