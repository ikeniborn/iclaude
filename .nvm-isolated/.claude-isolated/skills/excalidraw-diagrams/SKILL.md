---
name: excalidraw-diagrams
description: Создание и редактирование Excalidraw диаграмм в Obsidian — правила, ограничения, шаблоны JSON
user-invocable: false
context: fork
agent: general-purpose
model: sonnet
# version: 2.0.0
# tags: [excalidraw, obsidian, diagrams, architecture, flowchart, visualization, json, hld]
# dependencies: []
# files: {templates: ./templates/*.json, rules: ./rules/*.md, examples: ./examples/*.md}
---

# Excalidraw Diagrams 2.0

Правила и ограничения для создания и редактирования Excalidraw диаграмм в Obsidian.

---

## Quick Reference

| Аспект | Детали |
|--------|--------|
| Формат файла | `.excalidraw` (основной), `.excalidraw.md` (Obsidian legacy) |
| Структура JSON | `type`, `version: 2`, `elements[]`, `appState`, `files` |
| Типы элементов | `rectangle`, `diamond`, `ellipse`, `text`, `arrow`, `line`, `image`, `frame` |
| Шрифты кириллицы | `fontFamily: 5` (Excalidraw Default) — полная поддержка |
| Стрелки | `points[0]` всегда `[0,0]`, остальные — смещения |
| Привязки | `containerId` <-> `boundElements` — взаимные ссылки |
| Z-ordering | `index` (фракционная строка: "a0", "aG") — порядок отрисовки |

---

## Когда использовать

- Создание нового `.excalidraw` файла для Obsidian vault
- Редактирование существующей диаграммы (добавление/удаление элементов)
- Генерация архитектурных, HLD, flow, sequence или других диаграмм

---

## Форматы файлов в Obsidian

### `.excalidraw.md` — Obsidian формат

```markdown
---
excalidraw-plugin: parsed
tags: [excalidraw]
---
==!  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. !==

# Excalidraw Data

## Text Elements
[текст] ^[id]

%%
# Drawing
```json
{ "type": "excalidraw", "version": 2, ... }
```
%%
```

**Правила:**
- JSON диаграммы — в последнем `` ```json `` блоке внутри `%% ... %%`
- Секция `## Text Elements` — дубликат текстов для поиска Obsidian: `Текст ^id-элемента`
- Frontmatter: `excalidraw-plugin: parsed`
- Legacy формат с `# Text Elements` (без `# Excalidraw Data`) тоже работает в старых версиях плагина

**Поле `source`:** Obsidian Excalidraw plugin автоматически перезаписывает `source` на URL плагина. Значение `"https://excalidraw.com"` — дефолт; плагин заменит на свой URL при первом сохранении.

---

## Структура JSON

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [],
  "appState": { "gridSize": null, "viewBackgroundColor": "#ffffff" },
  "files": {}
}
```

---

## Базовые поля элемента

```json
{
  "id": "уникальный-20-символов",
  "type": "rectangle",
  "x": 100, "y": 100,
  "width": 200, "height": 80,
  "angle": 0,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a0",
  "roundness": null,
  "seed": 123456789,
  "version": 1,
  "versionNonce": 987654321,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1700000000000,
  "link": null,
  "locked": false,
  "hasTextLink": false
}
```

---

## Типы элементов

### Текст (`text`)

Дополнительные поля:
```json
{
  "text": "Заголовок",
  "rawText": "Заголовок",
  "fontSize": 20,
  "fontFamily": 5,
  "textAlign": "center",
  "verticalAlign": "middle",
  "containerId": "id-фигуры-или-null",
  "originalText": "Заголовок",
  "autoResize": true,
  "lineHeight": 1.25
}
```

**fontFamily:** `1`=Virgil (рукописный), `2`=Helvetica, `3`=Cascadia (mono), `4`=Excalifont, `5`=Excalidraw Default (**рекомендуется, полная кириллица**)

### Стрелка/линия (`arrow`, `line`)

Дополнительные поля:
```json
{
  "points": [[0, 0], [200, 0]],
  "lastCommittedPoint": null,
  "startBinding": { "elementId": "source-id", "mode": "orbit", "fixedPoint": [1.04, 0.5] },
  "endBinding":   { "elementId": "target-id", "mode": "orbit", "fixedPoint": [-0.04, 0.5] },
  "startArrowhead": null,
  "endArrowhead": "arrow",
  "elbowed": false
}
```

**Два формата привязки (binding):**

**Legacy:**
```json
"startBinding": { "elementId": "...", "focus": 0, "gap": 5, "fixedPoint": null }
```

**Modern (рекомендуется):**
```json
"startBinding": { "elementId": "...", "mode": "orbit", "fixedPoint": [1.04, 0.5] }
```

- `fixedPoint`: `[0,0]`=top-left, `[1,1]`=bottom-right; значения >1 или <0 создают gap от фигуры
- `mode`: `"orbit"` — стрелка привязана к точке на периметре фигуры
- Для `elbowed: true` — ВСЕГДА использовать modern формат

**endArrowhead:** `null`, `"arrow"`, `"bar"`, `"dot"`, `"triangle"`, `"circle"`

### Elbowed arrows (ортогональные стрелки)

Для HLD и архитектурных диаграмм рекомендуются elbowed стрелки — Manhattan routing (только горизонтальные/вертикальные сегменты):

```json
{
  "type": "arrow",
  "elbowed": true,
  "fixedSegments": null,
  "startIsSpecial": null,
  "endIsSpecial": null,
  "moveMidPointsWithElement": false,
  "lastCommittedPoint": null,
  "startBinding": { "elementId": "...", "mode": "orbit", "fixedPoint": [1.04, 0.5] },
  "endBinding":   { "elementId": "...", "mode": "orbit", "fixedPoint": [-0.04, 0.5] }
}
```

**Паттерн:** `elbowed: true` для привязанных стрелок (startBinding/endBinding), `elbowed: false` для свободных (легенда, декорация).

### Скругление (`roundness`)

```json
{ "type": 3 }   // прямоугольники
{ "type": 2 }   // стрелки
null             // острые углы
```

---

## Критические правила

| # | Правило | Нарушение |
|---|---------|-----------|
| 1 | ID уникален (20 символов `[a-zA-Z0-9_-]`) | Элемент двоится/пропадает |
| 2 | `points[0]` всегда `[0, 0]` | Стрелка не отображается |
| 3 | Минимум 2 точки в `points` | Стрелка не отображается |
| 4 | `containerId` -> `boundElements` взаимны | Текст плавает над фигурой |
| 5 | `boundElements: null` предпочтительно (но `[]` тоже валиден) | — |
| 6 | `"version": 2` в корне JSON | Файл не открывается |
| 7 | Стрелки ОБЯЗАНЫ иметь `startBinding` и `endBinding` | Стрелка висит в воздухе, не прикреплена к блокам |
| 8 | `x,y` стрелки = точка выхода из фигуры-источника | Стрелка смещена, визуально не соединяет блоки |
| 9 | ID в `startBinding.elementId`/`endBinding.elementId` должны существовать в `elements[]` | Стрелка отображается без привязки |
| 10 | Стрелки должны быть в `boundElements` обоих эндпоинтов | Excalidraw не обновляет положение стрелки при перемещении блока |
| 11 | `lastCommittedPoint: null` на ВСЕХ стрелках | Стрелка может не отрисовываться |

### Правило привязки стрелок (КРИТИЧНО)

**Каждая стрелка ДОЛЖНА иметь:**

**Modern формат (рекомендуется для новых диаграмм):**
```json
{
  "startBinding": {
    "elementId": "id-фигуры-источника",
    "mode": "orbit",
    "fixedPoint": [1.04, 0.5]
  },
  "endBinding": {
    "elementId": "id-фигуры-цели",
    "mode": "orbit",
    "fixedPoint": [-0.04, 0.5]
  },
  "lastCommittedPoint": null
}
```

**Legacy формат (поддерживается):**
```json
{
  "startBinding": {
    "elementId": "id-фигуры-источника",
    "focus": 0,
    "gap": 5,
    "fixedPoint": null
  },
  "endBinding": {
    "elementId": "id-фигуры-цели",
    "focus": 0,
    "gap": 5,
    "fixedPoint": null
  }
}
```

**Обе фигуры (источник и цель) ДОЛЖНЫ включать стрелку в `boundElements`:**
```json
// Фигура-источник:
"boundElements": [
  { "type": "arrow", "id": "id-стрелки" }
]

// Фигура-цель:
"boundElements": [
  { "type": "arrow", "id": "id-стрелки" }
]
```

**`x, y` стрелки** = координата точки выхода из фигуры-источника:
- Выход снизу: `x = source.x + source.width/2`, `y = source.y + source.height`
- Выход справа: `x = source.x + source.width`, `y = source.y + source.height/2`
- Выход слева: `x = source.x`, `y = source.y + source.height/2`
- Выход сверху: `x = source.x + source.width/2`, `y = source.y`

**fixedPoint для modern формата:**

| Выход из | fixedPoint |
|----------|-----------|
| Правый край (середина) | `[1.04, 0.5]` |
| Левый край (середина) | `[-0.04, 0.5]` |
| Нижний край (середина) | `[0.5, 1.04]` |
| Верхний край (середина) | `[0.5, -0.04]` |

> Значения > 1.0 или < 0.0 создают визуальный gap между стрелкой и фигурой.

**Контрольный чеклист перед записью файла:**
```
Для каждой стрелки:
  startBinding.elementId -> существующий ID
  endBinding.elementId   -> существующий ID
  source.boundElements включает {"type":"arrow","id":"..."}
  target.boundElements включает {"type":"arrow","id":"..."}
  x,y стрелки = точка выхода из source (не произвольные координаты)
  points[0] = [0,0], points[-1] = [dx,dy] до target
  lastCommittedPoint: null
```

---

## Z-ordering через `index`

Поле `index` — фракционная строка, определяющая порядок отрисовки элементов (z-order). Лексикографический порядок: `"Zo" < "a0" < "a1" < "aG"`.

**Заменяет старое правило "фоновые прямоугольники ПЕРВЫМИ в elements[]"** — теперь порядок в массиве `elements[]` не важен, z-order определяется `index`.

### Стратегия генерации

Для N элементов назначай последовательные значения:
```
"a0", "a1", "a2", ..., "a9", "aA", "aB", ..., "aZ", "aa", "ab", ...
```

**Правила z-ordering:**
- Фоновые контейнеры/слои — меньшие значения `index` (отрисовываются первыми)
- Компоненты поверх контейнеров — средние значения
- Стрелки и метки — наибольшие значения (поверх всего)

**Пример:**
```
index "a0" — фоновый контейнер (слой)
index "a1" — подпись контейнера
index "a2"..."a5" — компоненты внутри
index "a6"..."a9" — стрелки между компонентами
index "aA" — легенда
```

---

## Координатная система

```
(0,0) --X+-->
  |
  Y+
  v
```

Фигуры позиционируются по левому верхнему углу (`x`, `y`).

### Расчёт стрелок

**Горизонтальная (A -> B слева направо):**
```
arrow.x = A.x + A.width        (правый край A)
arrow.y = A.y + A.height/2     (середина A)
points  = [[0,0], [gap, 0]]    (gap = B.x - arrow.x)
```

**Вертикальная (A -> B сверху вниз):**
```
arrow.x = A.x + A.width/2      (середина A)
arrow.y = A.y + A.height       (нижний край A)
points  = [[0,0], [0, gap]]    (gap = B.y - arrow.y)
```

---

## Цветовые схемы

### Для архитектурных диаграмм

| Категория | strokeColor | backgroundColor |
|-----------|-------------|-----------------|
| Сервис/компонент | `"#1971c2"` | `"#e3f2fd"` |
| База данных | `"#2f9e44"` | `"#e8f5e9"` |
| Внешняя система | `"#6741d9"` | `"#f3e5f5"` |
| Пользователь/актор | `"#f08c00"` | `"#fff3e0"` |
| Ошибка/удаление | `"#e03131"` | `"#fce4ec"` |

### Для HLD диаграмм

| Статус | strokeColor | strokeStyle |
|--------|-------------|-------------|
| Без изменений | `"#1971c2"` blue | `"solid"` |
| Изменяемый | `"#f08c00"` orange | `"solid"` |
| Новый | `"#e03131"` red | `"solid"` |
| Исключаемый | `"#1e1e1e"` dark | `"dotted"` |
| Канал передачи | `"#2f9e44"` green | `"dashed"` |
| Витринный слой | `"#0c8599"` teal | `"dashed"` |

### Для flowchart

| Тип | Фигура | strokeColor | backgroundColor |
|-----|--------|-------------|-----------------|
| Старт/Стоп | `ellipse` | `"#2f9e44"` | `"#e8f5e9"` |
| Процесс | `rectangle` | `"#1971c2"` | `"#e3f2fd"` |
| Решение | `diamond` | `"#f08c00"` | `"#fff3e0"` |

---

## Паттерны диаграмм

| Тип | Фигуры | Направление |
|-----|--------|-------------|
| Architecture | rectangle + arrow | Слева направо |
| HLD | rectangle (layers) + elbowed arrow + rectangle legend | По потоку данных |
| Flowchart | ellipse + rectangle + diamond + arrow | Сверху вниз |
| Sequence | rectangle (колонки) + arrow | Горизонтально |
| MindMap | ellipse (центр) + rectangle + arrow | Радиально |
| ERD | rectangle (секции) + line | Свободное |

---

## Непересекающиеся линии и кривые стрелки

### Правило 1: Планирование маршрутов ДО генерации стрелок

Перед созданием стрелок составь **маршрутную таблицу**:
```
От          -> До             Маршрут           Конфликт?
------------------------------------------------------------
A (x=100)   -> C (x=500)     горизонталь       нет
B (x=300)   -> D (x=500)     диагональ         пересекает A->C
```
Если обнаружен конфликт — выбери обходной маршрут (см. ниже).

### Правило 2: Кривые стрелки (`elbowed: false` + `points`)

Для обхода пересечений используй многоточечные стрелки:

```json
{
  "type": "arrow",
  "elbowed": false,
  "lastCommittedPoint": null,
  "points": [
    [0, 0],
    [0, 40],
    [200, 40],
    [200, 0]
  ]
}
```

**Паттерны обхода:**

```
Прямая (нет конфликта):
  A -----------------> B
  points: [[0,0], [dx, 0]]

Г-образная (обход по горизонтали):
  A --> |
        +---> B
  points: [[0,0], [midX,0], [midX,dy], [dx,dy]]

U-образная (обратная стрелка, обход снизу):
  A <--------------+
                    |
  B ----------------+
  points: [[0,0], [0,gap], [-offsetX,gap], [-offsetX,-height], [dx,-height]]

Диагональная смещённая (не пересекает соседей):
  Смести x или y начала стрелки от центра элемента на 20-30px
  используя startBinding.focus: 0.3 или -0.3
```

### Правило 3: `focus` для смещения точки привязки (legacy формат)

`focus: 0` = центр грани, `focus: -1`/`1` = крайние точки грани.

Для стрелок из одного элемента к нескольким — разноси точки привязки:
```json
{ "focus": -0.5 }   // левее центра
{ "focus":  0.0 }   // центр
{ "focus":  0.5 }   // правее центра
```

### Правило 4: Порядок приоритета маршрутов

1. **Прямая линия** — если нет конфликтов
2. **Г-образная** — для 90 поворотов без пересечений
3. **Смещение `focus`** — для веера стрелок из одного источника
4. **Диагональ** — только если элементы не выровнены по оси
5. **U-образная/обратная** — для петель и обратных связей

### Правило 5: Минимальный зазор между параллельными стрелками

Если два элемента связаны параллельными стрелками — смести их на 10-15px по Y:
```
Стрелка 1: y = elementA.centerY - 8
Стрелка 2: y = elementA.centerY + 8
```

---

## Группировка элементов

### Pattern A: Визуальный контейнер — прямоугольник (свободный текст)

**Основной способ группировки для архитектурных слоёв** — прямоугольник с пунктирной границей, расположенный позади компонентов (через меньший `index`). Подпись в верхнем левом углу как отдельный текстовый элемент.

```json
// 1. Фоновый прямоугольник (меньший index для z-ordering)
{
  "id": "grpInit",
  "type": "rectangle",
  "x": 40, "y": 185, "width": 880, "height": 155,
  "index": "a0",
  "strokeColor": "#1971c2",
  "backgroundColor": "#e3f2fd",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "dashed",
  "roughness": 0,
  "opacity": 40,
  "boundElements": null,
  "hasTextLink": false
}

// 2. Подпись в верхнем левом углу (свободный текст, НЕ containerId)
{
  "id": "tGrpInit",
  "type": "text",
  "x": 55, "y": 192,
  "index": "a1",
  "text": "ИНИЦИАЛИЗАЦИЯ",
  "rawText": "ИНИЦИАЛИЗАЦИЯ",
  "fontSize": 13, "fontFamily": 5,
  "textAlign": "left", "verticalAlign": "top",
  "containerId": null,
  "strokeColor": "#1971c2",
  "hasTextLink": false
}
```

**Правила фоновых групп:**
- `opacity: 30-50` — полупрозрачный фон, компоненты видны поверх
- `roughness: 0` — чёткие края без "рукописного" стиля
- `boundElements: null` — стрелки НЕ привязываются к группе
- Подпись: `containerId: null`, `textAlign: "left"`, `verticalAlign: "top"`, позиция x+15, y+7 от угла группы
- Цвет подписи совпадает с цветом рамки группы

### Pattern B: Контейнер с привязанной меткой (containerId)

Текст привязан к контейнеру через `containerId` — двигается вместе с ним. Подходит для HLD диаграмм.

```json
// Контейнер
{
  "id": "layer-01",
  "type": "rectangle",
  "x": 40, "y": 185, "width": 880, "height": 155,
  "index": "a0",
  "boundElements": [
    {"type": "text", "id": "label-layer-01"}
  ],
  "opacity": 40
}

// Привязанная метка
{
  "id": "label-layer-01",
  "type": "text",
  "containerId": "layer-01",
  "textAlign": "left",
  "verticalAlign": "top",
  "text": "Слой обработки",
  "rawText": "Слой обработки",
  "fontFamily": 5,
  "hasTextLink": false
}
```

### groupIds — логические группы (вспомогательный способ)

Элементы одной группы выделяются/перемещаются вместе в Excalidraw. Используется в дополнение к визуальным прямоугольникам или самостоятельно.

```json
{ "groupIds": ["group-init-layer"] }
```

**Правила:**
- Стрелки между группами — `"groupIds": []`
- Один элемент может входить в несколько групп

### frame — тип элемента Excalidraw

`frame` — прямоугольник с заголовком внутри элемента (не текстовый отдельный элемент):

```json
{
  "id": "frame-security",
  "type": "frame",
  "name": "Security Hooks (PreToolUse)",
  "strokeColor": "#e03131",
  "strokeStyle": "dashed",
  "roughness": 0
}
```

Элементы внутри фрейма указывают `"frameId": "frame-security"`.

**Когда использовать:**
| Ситуация | Инструмент |
|----------|-----------|
| Архитектурный слой с фоном | Pattern A или B (rectangle + opacity) |
| Визуальный контейнер с названием | `frame` |
| Логическое группирование без границы | `groupIds` |
| Слой + перемещение вместе | Pattern B (containerId) или rectangle + `groupIds` |

---

## Легенда

Легенда — отдельная группа элементов в правом нижнем (или правом верхнем) углу диаграммы.

### Структура легенды

```
+-----------------------------+
| Легенда                     |
| [] синий   -- Сервис        |
| [] зелёный -- Запуск        |
| [] красный -- Security      |
| --> зависимость             |
| - -> опциональная связь     |
+-----------------------------+
```

### Реализация в JSON (основной паттерн: rectangle)

Легенда = rectangle-контейнер с привязанным заголовком + маленькие прямоугольники (образцы цветов) + текст:

```json
// Rectangle-контейнер легенды с привязанной меткой
{
  "id": "rect-legend",
  "type": "rectangle",
  "x": 900, "y": 600,
  "width": 220, "height": 200,
  "index": "aM",
  "strokeColor": "#868e96",
  "backgroundColor": "#ffffff",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "boundElements": [
    {"type": "text", "id": "text-legend-title"}
  ],
  "hasTextLink": false
}

// Заголовок легенды (привязан к контейнеру)
{
  "type": "text",
  "id": "text-legend-title",
  "text": "Легенда",
  "rawText": "Легенда",
  "containerId": "rect-legend",
  "textAlign": "left",
  "verticalAlign": "top",
  "fontFamily": 5,
  "fontSize": 16,
  "hasTextLink": false
}

// Образец цвета (маленький прямоугольник 24x16)
{
  "type": "rectangle",
  "width": 24, "height": 16,
  "strokeColor": "#1971c2",
  "backgroundColor": "#e3f2fd",
  "fillStyle": "solid",
  "hasTextLink": false
}

// Подпись рядом (текст без containerId)
{
  "type": "text",
  "text": "Сервис / модуль",
  "rawText": "Сервис / модуль",
  "fontSize": 14,
  "fontFamily": 5,
  "containerId": null,
  "hasTextLink": false
}

// Стрелка в легенде (с привязанной текстовой меткой)
{
  "id": "legend-arrow-id",
  "type": "arrow",
  "elbowed": false,
  "lastCommittedPoint": null,
  "boundElements": [{"type": "text", "id": "legend-arrow-label"}],
  "hasTextLink": false
}
{
  "type": "text",
  "id": "legend-arrow-label",
  "containerId": "legend-arrow-id",
  "text": "зависимость",
  "rawText": "зависимость",
  "fontFamily": 5,
  "hasTextLink": false
}
```

**Альтернативный паттерн: frame**

```json
{
  "id": "frame-legend",
  "type": "frame",
  "name": "Легенда"
}
```
Элементы внутри указывают `"frameId": "frame-legend"`.

**Правила легенды:**
- Размещать в правом нижнем углу, не перекрывая основную диаграмму
- Отступ от края диаграммы: 40-60px
- Образцы цветов: 24x16px, отступ 8px между строками
- Включать только цвета и типы линий, реально используемые в диаграмме
- `elbowed: false` для стрелок-образцов в легенде (свободные, без привязки)

---

## HLD диаграмма (High-Level Design)

### Структура

1. **Вложенные контейнеры** (opacity 30-50) — архитектурные слои
2. **Компоненты** — прямоугольники внутри контейнеров
3. **Elbowed arrows** — ортогональные связи между компонентами
4. **Rectangle-based легенда** — цветовая схема HLD

### Цветовая схема HLD

| Статус | strokeColor | strokeStyle | Пример |
|--------|-------------|-------------|--------|
| Без изменений | `#1971c2` | solid | Существующие компоненты |
| Изменяемый | `#f08c00` | solid | Компоненты с доработками |
| Новый | `#e03131` | solid | Новые компоненты |
| Исключаемый | `#1e1e1e` | dotted | Удаляемые компоненты |
| Канал передачи | `#2f9e44` | dashed | Каналы данных |
| Витринный слой | `#0c8599` | dashed | Слой представления |

### Шаблон

См. **@template:hld-diagram.json** — готовый шаблон HLD с вложенными контейнерами, elbowed arrows и rectangle-based легендой.

---

## Эффективное расположение элементов

### Принцип 1: Сетка выравнивания

Все элементы одного уровня выровнены по базовой линии (X или Y):
```
Слой N: все элементы имеют одинаковый Y
Колонка K: все элементы имеют одинаковый X
```

### Принцип 2: Стандартные отступы

| Отступ | Значение |
|--------|---------|
| Между элементами одного слоя (X) | 40-60px |
| Между слоями (Y) | 80-100px |
| От края canvas до первого элемента | 60-80px |
| Зазор стрелки до/от фигуры (`gap`) | 5-8px |

### Принцип 3: Центрирование слоёв

Если слой содержит N элементов — центрируй блок относительно вертикальной оси:
```
totalWidth = N * elemWidth + (N-1) * gap
startX = canvasCenterX - totalWidth / 2
```

### Принцип 4: Размещение по потоку данных

Направление потока данных = направление чтения:
- **Слева -> Право**: входные данные слева, выходные справа
- **Сверху -> Вниз**: инициализация сверху, результат снизу
- **Смешанный**: основной поток вертикальный, ответвления — горизонтальные

### Принцип 5: Минимизация пересечений (размещение)

Перед расстановкой элементов:
1. Определи **все связи** (граф)
2. Расставь элементы так, чтобы большинство стрелок шло **в одном направлении**
3. Элементы с большим количеством входящих связей — **в центр**
4. Элементы только с исходящими — **слева/сверху**
5. Элементы только с входящими — **справа/снизу**

### Принцип 6: Ширина canvas

Для диаграмм с N слоями по горизонтали:
```
canvasWidth  = N * (elemWidth + gap) + 2 * margin  (обычно 800-1400px)
canvasHeight = layers * (elemHeight + layerGap) + legendHeight + margin
```

---

## Алгоритм создания диаграммы

```
1. Определить тип -> выбрать паттерн
2. Перечислить элементы и связи
3. СГЕНЕРИРОВАТЬ ВСЕ ID ЗАРАНЕЕ (шаг обязателен до написания JSON)
3.5. Назначить index значения (z-ordering)
4. Вычислить координаты (сверху вниз / слева направо)
5. Создать фигуры (rectangle, diamond, ellipse)
6. Создать текстовые элементы (containerId + boundElements)
7. Создать стрелки (points + startBinding + endBinding + lastCommittedPoint)
   - Для HLD: добавить elbowed: true
8. Добавить labels на стрелки при необходимости
9. Проверить взаимные ссылки boundElements <-> containerId
10. Записать файл; обновить секцию ## Text Elements (если .excalidraw.md)
```

---

## Генерация уникальных ID (КРИТИЧНО)

Дублирование ID — самая частая ошибка при итеративной генерации. Excalidraw молча перезаписывает или теряет элементы.

### Правило: ID-таблица перед генерацией

**ОБЯЗАТЕЛЬНО** перед созданием JSON составить таблицу всех ID:

```
Элемент                    -> ID
-----------------------------------------
rect: Client               -> rA1bC2dE3fG4hI5j
text: Client               -> tA1bC2dE3fG4hI5j
rect: API Gateway          -> rK6lM7nO8pQ9rS0t
text: API Gateway          -> tK6lM7nO8pQ9rS0t
arrow: Client->API          -> wU1vW2xY3zA4bC5d
```

### Схема именования (рекомендуется)

Используй префикс типа + случайный суффикс:

| Тип | Префикс | Пример |
|-----|---------|--------|
| rectangle | `r` | `rA1bC2dE3fG4hI5j` |
| diamond | `d` | `dX9yZ0aB1cD2eF3g` |
| ellipse | `e` | `eP4qR5sT6uV7wX8y` |
| text | `t` | `tA1bC2dE3fG4hI5j` |
| arrow | `w` | `wU1vW2xY3zA4bC5d` |
| line | `l` | `lN9oP0qR1sT2uV3w` |

**Для пары фигура+текст**: используй одинаковый суффикс с разным префиксом:
- фигура `rA1bC2dE3fG4hI5j` -> текст `tA1bC2dE3fG4hI5j`

### Запрещённые паттерны (при генерации новых диаграмм)

```
  "id1", "id2", "id3"    -- коллизии при повторной генерации
  "rect1", "rect2"       -- слишком короткие, плохо различимы
```

**Примечание:** шаблоны в `templates/` используют читаемые IDs (`rect-client-01`) для
наглядности — это допустимо только в шаблонах. При создании реальной диаграммы
**заменяй все IDs** из шаблона на уникальные по схеме выше.

### Проверка уникальности перед записью

Перед финальной записью JSON проверь — каждый ID встречается ровно один раз:
```
ids = [элемент.id для каждого элемента]
assert len(ids) == len(set(ids))   // нет дубликатов
```

Если обнаружен дубль — регенерировать суффикс конфликтующего элемента.

---

## Типичные размеры

| Элемент | Width | Height |
|---------|-------|--------|
| Компонент | 160-200 | 60-80 |
| Ромб (решение) | 120-160 | 80-100 |
| Эллипс (старт/стоп) | 120-140 | 60-70 |
| Отступ между элементами | 40-60 | 40-60 |

---

## Шаблоны и примеры

- **@template:architecture-diagram.json** — 3 сервиса + БД + стрелки (готовый JSON)
- **@template:hld-diagram.json** — HLD с вложенными контейнерами + elbowed arrows + легенда
- **@template:obsidian-wrapper.md** — пустой `.excalidraw.md` с правильной структурой
- **@rules:element-constraints.md** — полные ограничения и частые ошибки
- **@example:flowchart-example.md** — блок-схема аутентификации (полный JSON)

---

## Output при создании диаграммы

```
Создана диаграмма: [название]
Элементов: [N] (прямоугольников: X, стрелок: Y, текстов: Z)
Файл: [путь]
```

---

*Version: 2.0.0 | Author: ikeniborn | License: MIT*
