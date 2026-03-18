# Ограничения элементов Excalidraw

## Критические ограничения (ломают файл)

### ID элементов
- Длина: 20 символов, только `[a-zA-Z0-9_-]`
- Уникальность: каждый ID встречается ровно один раз в `elements[]`
- Ссылки (binding, containerId) должны указывать на существующие ID

### Стрелки (arrow, line)
- `points` минимум 2 точки: `[[0, 0], [dx, dy]]`
- Первая точка ВСЕГДА `[0, 0]` — относительные координаты
- `startBinding.elementId` и `endBinding.elementId` должны существовать
- При отсутствии привязки: `"startBinding": null, "endBinding": null`
- `lastCommittedPoint: null` — обязательное поле на ВСЕХ стрелках

#### Elbowed arrows
- `elbowed: true` — ортогональная маршрутизация (Manhattan routing)
- ВСЕГДА использовать modern формат привязки (`mode` + `fixedPoint`)
- Дополнительные поля: `fixedSegments: null`, `startIsSpecial: null`, `endIsSpecial: null`, `moveMidPointsWithElement: false`

### Текст в контейнере
- `containerId` текста -> ID фигуры-контейнера
- Фигура должна иметь в `boundElements`: `[{"type": "text", "id": "<text-id>"}]`
- Если containerId указан — `textAlign: "center"`, `verticalAlign: "middle"` (или `"left"`/`"top"` для меток контейнеров)

### boundElements
- Если нет ни одного: `"boundElements": null` (предпочтительно)
- `"boundElements": []` — тоже валиден в Excalidraw 2025+
- Если есть: `"boundElements": [{"type": "...", "id": "..."}]`
- Типы в boundElements: `"text"`, `"arrow"`

## Ограничения значений

### Числовые поля
- `opacity`: 0-100 (целое число)
- `roughness`: 0, 1, 2 (целое число)
- `strokeWidth`: 1, 2, 4 (стандартные), любое положительное целое
- `fontSize`: стандартные 12, 16, 20, 28, 36; любое > 0
- `angle`: радианы (0 = без поворота, pi/2 = 90 и т.д.)
- `x`, `y`: любые числа (включая отрицательные)
- `width`, `height`: > 0

### strokeStyle значения
Допустимы: `"solid"`, `"dashed"`, `"dotted"`

### roundness объект
```json
{"type": 3}   // для прямоугольников (скруглённые углы)
{"type": 2}   // для стрелок (изогнутые)
{"type": 1}   // лёгкое скругление
null           // острые углы (без скругления)
```

### fontFamily значения
| Значение | Шрифт | Поддержка кириллицы |
|----------|-------|---------------------|
| `1` | Virgil (рукописный) | Частичная |
| `2` | Helvetica | Да |
| `3` | Cascadia Code | Да |
| `4` | Excalifont | Ограничена |
| `5` | Excalidraw Default | **Да (рекомендуется)** |

**Рекомендация для кириллицы**: `fontFamily: 5` (Excalidraw Default)

## Новые поля (2025+)

### `index` — z-ordering
- Фракционная строка, лексикографический порядок: `"Zo" < "a0" < "aG"`
- Определяет порядок отрисовки элементов
- Меньшее значение — отрисовывается раньше (на заднем плане)

### `hasTextLink`
- Булево поле (`false` по умолчанию)
- Присутствует на ВСЕХ элементах

### `rawText`
- Содержит "сырой" текст элемента (до обработки)
- Обычно совпадает с `text`; обязательное поле на текстовых элементах

### Привязка стрелок — modern формат
```json
"startBinding": {
  "elementId": "...",
  "mode": "orbit",
  "fixedPoint": [1.04, 0.5]
}
```
- `mode`: `"orbit"` — привязка к точке на периметре
- `fixedPoint`: `[x, y]` где `[0,0]`=top-left, `[1,1]`=bottom-right
- Значения > 1.0 или < 0.0 создают gap от фигуры

### Elbowed arrows
```json
{
  "elbowed": true,
  "fixedSegments": null,
  "startIsSpecial": null,
  "endIsSpecial": null,
  "moveMidPointsWithElement": false,
  "lastCommittedPoint": null
}
```

## Deprecated поля

### `baseline`
- Ранее использовалось в текстовых элементах
- Deprecated в Excalidraw 2025+ — не включать в новые диаграммы
- Старые файлы с `baseline` продолжают работать

## Ограничения производительности

### Количество элементов
- До 200 элементов: нет ограничений
- 200-500: может тормозить на слабых устройствах
- 500+: рекомендуется разбить на несколько диаграмм

### Размер файла
- Рекомендуемый максимум: 1-2 MB
- Встроенные изображения (`files: {...}`): увеличивают размер в разы
- Base64 изображения: избегать если не нужно

## КРИТИЧЕСКОЕ ПРАВИЛО: Формат файла для Obsidian

### `.excalidraw` vs `.excalidraw.md` — ОБЯЗАТЕЛЬНЫЙ ВЫБОР

**ВСЕГДА использовать `.excalidraw` (чистый JSON) для программно создаваемых диаграмм.**

**ЗАПРЕЩЕНО** использовать `.excalidraw.md` (markdown+JSON гибрид) при programmatic generation.

**Почему `.excalidraw.md` сломан для programmatic generation:**
1. Obsidian Excalidraw plugin при каждом открытии регенерирует `## Text Elements`
2. Регенерированные записи вида `ТЕКСТ ^elementId` читаются обратно плагином
3. Плагин создаёт НОВЫЕ элементы с текстом `"ТЕКСТ ^elementId"` (включая `^id` в тексте)
4. На каждом открытии — новые дублирующиеся элементы -> **бесконечный рост файла**

**Формат `.excalidraw` — чистый JSON:**
```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [...],
  "appState": {"gridSize": null, "viewBackgroundColor": "#ffffff"},
  "files": {}
}
```
- Нет frontmatter, нет `## Text Elements`, нет markdown
- Obsidian Excalidraw plugin открывает его напрямую без `## Text Elements` обработки
- Стабилен: никаких авто-модификаций при открытии

**Вложение в Obsidian:**
```markdown
![[diagram.excalidraw]]
![[diagram.excalidraw|600]]
```

### Дублирующиеся ID — критический баг

**Симптом:** Элементы двоятся, пропадают, файл растёт с каждым открытием.
**Причина:** Два элемента с одинаковым `id` в массиве `elements[]`.
**Диагностика перед записью файла:**
```python
from collections import Counter
ids = Counter(e['id'] for e in elements)
dups = {k: v for k, v in ids.items() if v > 1}
assert not dups, f"Duplicate IDs: {dups}"
```
**Правило:** ID должны быть уникальны глобально. При генерации использовать уникальные
суффиксы или случайные строки.

### Запрещённые символы в текстах

- `--` в тексте -> преобразуется в arrow-символы плагином. Использовать `—` (U+2014 em dash)
- Пустые строки внутри multi-line текста -> разрывают парсер `## Text Elements` в `.excalidraw.md`

## Частые ошибки

| Ошибка | Симптом | Исправление |
|--------|---------|-------------|
| Использован `.excalidraw.md` для programmatic generation | Дублирование элементов при каждом открытии | Перейти на `.excalidraw` формат |
| Дублирующийся ID | Элемент пропадает или двоится, файл растёт | Проверить уникальность всех ID перед записью |
| points: `[[0,0]]` | Стрелка не отображается | Добавить вторую точку `[dx, dy]` |
| containerId без boundElements | Текст плавает поверх | Добавить `{"type":"text","id":"..."}` в boundElements фигуры |
| Отсутствует `"version": 2` | Файл не открывается | Добавить в корень JSON |
| `source` отсутствует | Предупреждение в плагине | Добавить `"source": "https://excalidraw.com"` |
| `--` в тексте | Отображается как стрелочные символы | Заменить на em dash |
| Отсутствует `lastCommittedPoint` на стрелке | Стрелка может не отрисовываться | Добавить `"lastCommittedPoint": null` |
| Отсутствует `index` | Z-ordering не определён | Добавить фракционную строку `"a0"`, `"a1"`, ... |
