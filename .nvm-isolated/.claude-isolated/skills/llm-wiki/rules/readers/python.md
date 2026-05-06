# Reader: Python

Правила извлечения сущностей из `.py` файлов.

## 1. Что искать

| Категория | Паттерны |
|-----------|---------|
| `public_api` | `def имя(` без ведущего `_`, `class Имя:` без ведущего `_`, имена в `__all__` |
| `docstrings` | `"""..."""` или `'''...'''` сразу после `def`/`class` |
| `types` | `@dataclass`, `class X(TypedDict)`, `class X(BaseModel)`, `class X(Protocol)`, `TypeAlias` |
| `imports` | `import X`, `from X import Y` — внешние зависимости и внутренние модули |

**Игнорировать:**
- Приватные объекты: `_func`, `__func`, `__func__` (кроме `__init__`, `__call__`)
- Тело функций (только сигнатура + docstring)
- Тестовые файлы (`test_*.py`, `*_test.py`) — если не указаны явно в source_paths

## 2. Правила именования

| Код | Wiki-страница |
|-----|--------------|
| `def calculate_revenue(` | `calculate-revenue` |
| `class DataPipeline:` | `data-pipeline` |
| `class UserConfig(TypedDict):` | `user-config` (тип — в разделе "Тип") |
| `class MyError(Exception):` | `my-error` |
| `async def fetch_data(` | `fetch-data` |

Модуль (`module.py`) → отдельная wiki-страница `module` только если содержит ≥ 3 публичных объекта.

## 3. Правила синтеза

**Для функции/метода:**
```
# {имя-функции}

{первая строка docstring или вывод из имени}

## Сигнатура
\`\`\`python
def имя(param1: Тип, param2: Тип = default) -> ВозвращаемыйТип:
\`\`\`

## Описание
{полный docstring, если есть; иначе — вывод по имени и параметрам}

## Параметры
| Имя | Тип | Описание |
|-----|-----|---------|
| param1 | Тип | ... |

## Возвращает
{тип + описание из docstring или type hint}

## Использует
{WikiLinks на импортированные модули, если они есть в wiki}
```

**Для класса:**
```
# {имя-класса}

{первая строка docstring}

## Назначение
{полный docstring класса}

## Поля/Атрибуты
| Имя | Тип | Описание |
|-----|-----|---------|

## Методы
- [[имя-метода]] — краткое описание (если создаётся отдельная страница)
- `метод()` — краткое описание (если не создаётся отдельная страница)

## Зависимости
{WikiLinks на родительские классы и ключевые импорты}
```

**Для dataclass / TypedDict / BaseModel:**
Страница создаётся как для класса, но раздел "Поля" — обязательный и подробный (типы + описания полей).

**Порог создания страницы:**
- Функция: создать если ≥ 1 упоминание и есть docstring ИЛИ ≥ 3 упоминания
- Класс: всегда создать если публичный
- Тип (dataclass/TypedDict/BaseModel): всегда создать если публичный

## 4. Пример

**Вход** (`lib/oauth/token.py`):
```python
"""OAuth token management for Claude Code."""

from pathlib import Path
import json

class TokenManager:
    """Manages OAuth token lifecycle: load, refresh, save.
    
    Tokens are stored in .credentials.json with 5-minute refresh threshold.
    """
    
    def __init__(self, credentials_path: Path):
        self.credentials_path = credentials_path
    
    def is_expired(self, threshold_minutes: int = 5) -> bool:
        """Check if token expires within threshold_minutes."""
        ...
    
    def refresh(self) -> str:
        """Refresh OAuth token and save to credentials file.
        
        Returns:
            New access token string.
        
        Raises:
            TokenRefreshError: If refresh request fails.
        """
        ...
```

**Выход** (`.wiki/функции/oauth/token-manager.md`):
```markdown
---
wiki_sources: ["lib/oauth/token.py"]
wiki_updated: 2026-05-06
wiki_status: stub
---
# TokenManager

Управляет жизненным циклом OAuth-токена: загрузка, обновление, сохранение.

## Назначение
Токены хранятся в `.credentials.json` с порогом обновления 5 минут.

## Поля/Атрибуты
| Имя | Тип | Описание |
|-----|-----|---------|
| credentials_path | Path | Путь к файлу .credentials.json |

## Методы
- `is_expired(threshold_minutes=5) → bool` — проверить, истекает ли токен в ближайшие N минут
- `refresh() → str` — обновить токен и сохранить; возвращает новый access token

## Зависимости
[[функции/oauth/token-refresh-error]] · [[функции/возможности/oauth]]
```
```
