# Plan: Переработка lib/docs/ под per-project Sphinx

## Контекст

Текущая реализация (Phase 16) жёстко привязана к iclaude и хранит
всё в `docs/`. Нужно:

1. **Per-project**: Sphinx работает в любом проекте (не только iclaude)
2. **Изолированная поддиректория**: Sphinx размещается в `docs/sphinx/`
   (не захламляет корневой `docs/` существующими конфигами)
3. **Паттерн**: все функции принимают
   `$1=project_path` (default: `$(pwd)`)

---

## Итоговая структура per-project

```
<любой-проект>/
├── docs/
│   ├── STATUSLINE.md         ← существующая документация (без изменений)
│   ├── README.md             ←    "          "
│   ├── ...
│   └── sphinx/               ← ВСЁ Sphinx-специфичное здесь (НОВАЯ поддиректория)
│       ├── conf.py           ← генерируется --init-docs
│       ├── index.md          ← корневой toctree (ссылается через ../ на docs/*.md)
│       ├── api-reference/    ← автогенерация из src (bash-проекты)
│       └── _build/html/      ← gitignore (.gitignore += docs/sphinx/_build/)
~/ (глобально)
└── .nvm-isolated/.python-docs/   ← Shared Python venv (один раз, shared)
    или ~/.local/share/sphinx-docs/   ← если нет isolated env
```

---

## Ключевые архитектурные решения

| Аспект | Решение | Обоснование |
|--------|---------|-------------|
| Sphinx директория | `docs/sphinx/` | Отделена от исходных .md — не захламляет |
| Python venv | Глобальный (`get_docs_venv_dir()`) | Экономия ~50MB × N проектов |
| API ref | Только bash-проекты (если есть `lib/*.sh`) | bash-parser не применим к python/node |
| conf.py | Генерируется `--init-docs` | Адаптируется к типу проекта |
| Существующие docs/*.md | Включаются через `../` пути в index.md | Без перемещения файлов |

---

## Файловая структура lib/docs/ (итог)

```
lib/docs/
├── resolve.sh     # НОВЫЙ: get_docs_*(), detect_project_type()
├── init.sh        # НОВЫЙ: init_project_docs() → conf.py + index.md
├── install.sh     # ПРАВКА: venv_dir через get_docs_venv_dir()
├── build.sh       # ПРАВКА: $1=project_path, $2=--clean; новые пути
├── serve.sh       # ПРАВКА: $1=project_path, $2=port
├── status.sh      # ПРАВКА: $1=project_path
└── bash-parser.sh # БЕЗ ИЗМЕНЕНИЙ
```

---

## 1. lib/docs/resolve.sh (новый — path helper модуль)

Все 7 helper-функций с `$1=project_path (default: pwd)`:

```bash
get_docs_project_dir(path)     # resolve → absolute path
get_docs_project_name(path)    # git remote URL basename → или dirname
get_docs_venv_dir()            # ГЛОБАЛЬНЫЙ: $ISOLATED_NVM_DIR/.python-docs
                               #   fallback: $HOME/.local/share/sphinx-docs
get_docs_sphinx_dir(path)      # $path/docs/sphinx/       ← КЛЮЧЕВОЕ ИЗМЕНЕНИЕ
get_docs_build_dir(path)       # $path/docs/sphinx/_build/html
get_docs_api_ref_dir(path)     # $path/docs/sphinx/api-reference/
detect_project_type(path)      # bash|python|node|generic
get_docs_src_for_api_ref(path) # bash→lib/, иначе "" (не генерировать)
```

**detect_project_type** логика:
- `bash`: есть `lib/**/*.sh` или `*.sh` в корне
- `python`: есть `pyproject.toml` / `setup.py`
- `node`: есть `package.json`
- `generic`: иначе

---

## 2. lib/docs/init.sh (новый)

```bash
init_project_docs(project_path) {
    sphinx_dir=$(get_docs_sphinx_dir "$project_path")
    mkdir -p "$sphinx_dir"

    # Guard: не перезаписывать существующий conf.py
    if [[ -f "$sphinx_dir/conf.py" ]]; then
        print_warning "docs/sphinx/conf.py already exists."
        return 0
    fi

    _generate_conf_py "$sphinx_dir/conf.py" "$project_name" "$project_type"
    _generate_index_md "$sphinx_dir/index.md" "$project_name" "$project_path"
    _update_project_gitignore "$project_path"   # добавить docs/sphinx/_build/

    print_success "Sphinx initialized: $sphinx_dir"
}
```

**_generate_conf_py**: heredoc с подстановкой переменных.
Bash-тип → включает комментарий про API reference из lib/*.sh.
Python-тип → включает `sphinx-autoapi` в extensions (с комментарием об установке).

**_generate_index_md**: сканирует `$project_path/docs/*.md` и включает
их в toctree через относительные пути `../FILENAME` (без `.md`).

**_update_project_gitignore**: добавляет `docs/sphinx/_build/` в
`.gitignore` если ещё нет.

---

## 3. lib/docs/install.sh — одна строка

```bash
# БЫЛО:  local venv_dir="${ISOLATED_NVM_DIR:-.nvm-isolated}/.python-docs"
# СТАЛО:
local venv_dir
venv_dir=$(get_docs_venv_dir)
```

---

## 4. lib/docs/build.sh — новая сигнатура

```bash
# БЫЛО:  build_sphinx_docs($1=--clean)
# СТАЛО: build_sphinx_docs($1=project_path, $2=--clean)
build_sphinx_docs() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local clean_flag="${2:-}"
    local venv_dir; venv_dir=$(get_docs_venv_dir)
    local sphinx_dir; sphinx_dir=$(get_docs_sphinx_dir "$project_path")
    local build_dir; build_dir=$(get_docs_build_dir "$project_path")

    # conf.py в sphinx_dir (не docs_dir)
    if [[ ! -f "$sphinx_dir/conf.py" ]]; then
        print_error "Not initialized. Run: ./iclaude.sh --init-docs $project_path"
        return 1
    fi

    # API ref только для bash-проектов
    local src_dir
    src_dir=$(get_docs_src_for_api_ref "$project_path")
    if [[ -n "$src_dir" ]]; then
        generate_api_reference "$src_dir" "$(get_docs_api_ref_dir "$project_path")"
    fi

    # sphinx-build -b html "$sphinx_dir" "$build_dir"
}
```

---

## 5. lib/docs/serve.sh — новая сигнатура

```bash
# БЫЛО:  serve_sphinx_docs($1=port)
# СТАЛО: serve_sphinx_docs($1=project_path, $2=port)
serve_sphinx_docs() {
    local project_path; project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local port="${2:-8000}"
    local build_dir; build_dir=$(get_docs_build_dir "$project_path")

    if [[ ! -f "$build_dir/index.html" ]]; then
        build_sphinx_docs "$project_path"     # ← передаём project_path
    fi
    # python3 -m http.server "$port" --directory "$build_dir"
}
```

---

## 6. lib/docs/status.sh — новая сигнатура

```bash
# БЫЛО:  check_docs_status() — без аргументов
# СТАЛО: check_docs_status($1=project_path)
check_docs_status() {
    local project_path; project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local venv_dir; venv_dir=$(get_docs_venv_dir)
    local sphinx_dir; sphinx_dir=$(get_docs_sphinx_dir "$project_path")
    local build_dir; build_dir=$(get_docs_build_dir "$project_path")

    # Заголовок: PROJECT: $project_path
    # Секция 1: глобальное (Python, Sphinx venv) — не зависит от проекта
    # Секция 2: project-specific (conf.py в sphinx_dir, HTML build)
}
```

---

## 7. Обновление iclaude.sh

### Загрузка модулей (Phase 16 блок)
```bash
if [[ -d "$LIB_DIR/docs" ]]; then
    source "${LIB_DIR}/docs/resolve.sh"     # НОВЫЙ (первым!)
    source "${LIB_DIR}/docs/init.sh"        # НОВЫЙ
    source "${LIB_DIR}/docs/bash-parser.sh"
    source "${LIB_DIR}/docs/install.sh"
    source "${LIB_DIR}/docs/build.sh"
    source "${LIB_DIR}/docs/serve.sh"
    source "${LIB_DIR}/docs/status.sh"
fi
```

### Флаги (1 новый + 4 правки)
```bash
--init-docs)
    init_project_docs "${2:-$(pwd)}"
    exit $?
    ;;
--install-docs)
    install_sphinx_docs                        # без изменений
    exit $?
    ;;
--build-docs)
    build_sphinx_docs "${2:-$(pwd)}" "${3:-}"  # $2=path, $3=--clean
    exit $?
    ;;
--serve-docs)
    serve_sphinx_docs "${2:-$(pwd)}" "${3:-8000}"  # $2=path, $3=port
    exit $?
    ;;
--check-docs)
    check_docs_status "${2:-$(pwd)}"           # $2=path
    exit 0
    ;;
```

---

## 8. docs/conf.py iclaude — обновить путь

Текущий `docs/conf.py` нужно **переместить** в `docs/sphinx/conf.py`.
Аналогично `docs/index.md` → `docs/sphinx/index.md`.
Текущие файлы в `docs/*.md` — остаются на месте, ссылаются через `../`.

---

## 9. Обновление SKILL.md docs-builder

Обновить команды, пути и примеры с `docs/sphinx/` вместо `docs/`.

---

## Полный список изменяемых файлов (9 файлов)

| Файл | Действие |
|------|----------|
| `lib/docs/resolve.sh` | Создать |
| `lib/docs/init.sh` | Создать |
| `lib/docs/install.sh` | Одна строка (venv_dir) |
| `lib/docs/build.sh` | Переписать сигнатуру |
| `lib/docs/serve.sh` | Переписать сигнатуру |
| `lib/docs/status.sh` | Переписать сигнатуру |
| `iclaude.sh` | +2 source; --init-docs; обновить 4 флага |
| `docs/conf.py` → `docs/sphinx/conf.py` | Переместить |
| `docs/index.md` → `docs/sphinx/index.md` | Переместить + обновить пути |
| `.claude/skills/docs-builder/SKILL.md` | Обновить примеры |

---

## Верификация

```bash
# 1. Синтаксис
bash -n lib/docs/resolve.sh && bash -n lib/docs/init.sh && bash -n iclaude.sh

# 2. iclaude как проект (CWD = iclaude root)
./iclaude.sh --check-docs               # = --check-docs $(pwd)
./iclaude.sh --build-docs               # = --build-docs $(pwd)
./iclaude.sh --serve-docs               # = --serve-docs $(pwd)

# 3. Другой bash-проект
./iclaude.sh --init-docs /tmp/myproj
ls /tmp/myproj/docs/sphinx/             # conf.py, index.md
./iclaude.sh --build-docs /tmp/myproj
ls /tmp/myproj/docs/sphinx/_build/html/ # index.html, llms.txt

# 4. --clean флаг (третий аргумент)
./iclaude.sh --build-docs $(pwd) --clean

# 5. Пользовательский порт (третий аргумент)
./iclaude.sh --serve-docs $(pwd) 9000
```
