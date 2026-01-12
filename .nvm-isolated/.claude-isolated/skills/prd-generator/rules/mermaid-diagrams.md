# Mermaid Diagram Templates for PRD

Этот документ содержит 5 стандартных шаблонов Mermaid диаграмм для Product Requirements Document (PRD).

## Overview

**Mermaid** - это язык диаграмм на основе текста, поддерживаемый GitHub, GitLab, VS Code и другими платформами.

**5 диаграмм для PRD:**
1. **Product Vision** - связь целей, функций и метрик (graph TD)
2. **User Journey** - путь пользователя через продукт (journey)
3. **System Context** - актеры и внешние системы (graph TD, C4-style)
4. **Feature Dependencies** - зависимости между функциями (graph TD)
5. **Roadmap Timeline** - временная шкала разработки (gantt)

---

## 1. Product Vision Diagram (graph TD)

### 1.1 Purpose

Визуализирует связь между бизнес-целями, ключевыми функциями и метриками успеха.

### 1.2 Template

```mermaid
graph TD
    %% 3 слоя: Goals → Features → Metrics

    %% Layer 1: Business Goals
    G1[Goal: Increase Revenue<br/>Target: +30% MRR]
    G2[Goal: Reduce Churn<br/>Target: <5%]
    G3[Goal: Expand Market<br/>Target: 3 new regions]

    %% Layer 2: Core Features
    F1[Feature: Advanced Analytics]
    F2[Feature: Automation Engine]
    F3[Feature: Multi-language Support]
    F4[Feature: Enterprise SSO]

    %% Layer 3: Success Metrics
    M1[Metric: ARR Growth<br/>Target: $2M]
    M2[Metric: Churn Rate<br/>Target: 4.5%]
    M3[Metric: User Satisfaction<br/>Target: NPS 60+]
    M4[Metric: Market Share<br/>Target: 15%]

    %% Connections
    G1 --> F1
    G1 --> F4
    G2 --> F2
    G3 --> F3

    F1 --> M1
    F1 --> M3
    F2 --> M2
    F3 --> M4
    F4 --> M1

    %% Styling
    classDef goalStyle fill:#e1f5ff,stroke:#1976d2,stroke-width:2px,color:#000
    classDef featureStyle fill:#fff4e1,stroke:#f57c00,stroke-width:2px,color:#000
    classDef metricStyle fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000

    class G1,G2,G3 goalStyle
    class F1,F2,F3,F4 featureStyle
    class M1,M2,M3,M4 metricStyle
```

### 1.3 Best Practices

- **Goals (Layer 1)**: 2-5 ключевых бизнес-целей
- **Features (Layer 2)**: 3-8 основных функций
- **Metrics (Layer 3)**: 3-6 измеримых показателей
- **Labels**: Используйте `<br/>` для многострочных надписей
- **Connections**: Показывайте только прямые связи (избегайте спагетти)
- **Colors**: Синий (goals), Оранжевый (features), Зеленый (metrics)

### 1.4 Validation Rules

```bash
✅ 5-15 нод (оптимально 8-12)
✅ 3 четких слоя (Goals → Features → Metrics)
✅ Все ноды имеют цветовую схему (classDef)
✅ Labels короткие (<50 символов на строку)
❌ Избегайте циклических связей
❌ Избегайте пересекающихся линий
```

---

## 2. User Journey Diagram (journey)

### 2.1 Purpose

Показывает эмоциональный опыт пользователя на разных этапах взаимодействия с продуктом.

### 2.2 Template

```mermaid
journey
    title User Journey: {Product Name}

    section Awareness
      Discover product via search: 3: Marketing
      Visit landing page: 4: User
      Read product description: 4: User
      Watch demo video: 5: User

    section Consideration
      Sign up for free trial: 5: User
      Complete onboarding: 4: User
      Explore core features: 4: User
      Contact support (question): 3: User, Support

    section Purchase
      Compare pricing plans: 4: User
      Select premium plan: 5: User
      Enter payment details: 3: User
      Receive confirmation email: 5: User

    section Retention
      Daily product usage: 5: User
      Invite team members: 4: User
      Upgrade to enterprise: 5: User
      Renew annual subscription: 5: User

    section Advocacy
      Write positive review: 5: User
      Recommend to colleagues: 5: User
      Participate in case study: 4: User, Marketing
```

### 2.3 Best Practices

- **Sections**: 4-6 этапов (Awareness → Consideration → Purchase → Retention → Advocacy)
- **Activities**: 3-5 действий на этап
- **Scores**: 1-5 (1 = очень плохо, 5 = отлично)
- **Actors**: User, Marketing, Support, Product, etc.
- **Pain Points**: Низкие scores (1-2) показывают проблемы
- **Highlights**: Высокие scores (4-5) - удачные моменты

### 2.4 Validation Rules

```bash
✅ 4-6 секций (lifecycle stages)
✅ 15-25 активностей (total)
✅ Scores в диапазоне 1-5
✅ Минимум 2 актера (User + другие)
❌ Избегайте слишком детализированных действий
❌ Избегайте пропусков в lifecycle
```

---

## 3. System Context Diagram (graph TD, C4-style)

### 3.1 Purpose

C4-уровень контекста: показывает актеров (люди) и внешние системы, взаимодействующие с продуктом.

### 3.2 Template

```mermaid
graph TD
    %% Actors (People)
    USER[👤 End User<br/>Uses product for<br/>daily tasks]
    ADMIN[👤 Administrator<br/>Manages users<br/>and settings]
    SUPPORT[👤 Support Agent<br/>Helps users with<br/>issues]

    %% System (Center)
    SYSTEM[📦 Product Name<br/>--<br/>Core business logic<br/>User management<br/>Data processing]

    %% External Systems
    EXT_AUTH[🔐 OAuth Provider<br/>Google/GitHub<br/>Authentication]
    EXT_PAYMENT[💳 Payment Gateway<br/>Stripe<br/>Subscription billing]
    EXT_EMAIL[📧 Email Service<br/>SendGrid<br/>Transactional emails]
    EXT_ANALYTICS[📊 Analytics Platform<br/>Google Analytics<br/>User tracking]
    EXT_STORAGE[☁️ Cloud Storage<br/>AWS S3<br/>File uploads]

    %% Connections
    USER -->|Uses| SYSTEM
    ADMIN -->|Manages| SYSTEM
    SUPPORT -->|Monitors| SYSTEM

    SYSTEM -->|Authenticates with| EXT_AUTH
    SYSTEM -->|Processes payments| EXT_PAYMENT
    SYSTEM -->|Sends emails via| EXT_EMAIL
    SYSTEM -->|Tracks events to| EXT_ANALYTICS
    SYSTEM -->|Stores files in| EXT_STORAGE

    %% Styling
    classDef actorStyle fill:#e1f5ff,stroke:#1976d2,stroke-width:2px,color:#000
    classDef systemStyle fill:#fff4e1,stroke:#f57c00,stroke-width:3px,color:#000
    classDef externalStyle fill:#f0f0f0,stroke:#616161,stroke-width:2px,color:#000

    class USER,ADMIN,SUPPORT actorStyle
    class SYSTEM systemStyle
    class EXT_AUTH,EXT_PAYMENT,EXT_EMAIL,EXT_ANALYTICS,EXT_STORAGE externalStyle
```

### 3.3 Best Practices

- **Actors**: 2-5 типов пользователей (с emoji 👤)
- **System**: ВСЕГДА один центральный узел (ваш продукт)
- **External Systems**: 3-8 внешних сервисов (с emoji 🔐💳📧)
- **Labels**: Многострочные (`<br/>`) с описанием роли
- **Connections**: Направленные стрелки с глаголами
- **Colors**: Синий (actors), Оранжевый (system), Серый (external)

### 3.4 Validation Rules

```bash
✅ 1 центральный узел (SYSTEM)
✅ 2-5 актеров (people)
✅ 3-8 внешних систем
✅ Все стрелки направлены (-->)
✅ Labels с глаголами ("Uses", "Manages", "Sends")
❌ Избегайте прямых связей между актерами
❌ Избегайте прямых связей между внешними системами
```

---

## 4. Feature Dependencies Diagram (graph TD)

### 4.1 Purpose

Показывает зависимости между функциями и их приоритет (P0 = Must Have, P1 = Should Have, P2 = Could Have).

### 4.2 Template

```mermaid
graph TD
    %% P0 Features (Must Have for MVP)
    P0_AUTH[P0: User Authentication<br/>Login/Signup/Password Reset]
    P0_DASHBOARD[P0: Dashboard<br/>Overview metrics]
    P0_CRUD[P0: Core CRUD Operations<br/>Create/Read/Update/Delete]

    %% P1 Features (Should Have)
    P1_SEARCH[P1: Advanced Search<br/>Full-text search + filters]
    P1_EXPORT[P1: Data Export<br/>CSV/PDF export]
    P1_NOTIF[P1: Notifications<br/>Email/Push alerts]

    %% P2 Features (Could Have)
    P2_COLLAB[P2: Collaboration<br/>Team sharing + comments]
    P2_API[P2: Public API<br/>REST API for integrations]
    P2_MOBILE[P2: Mobile App<br/>iOS/Android native]

    %% Dependencies
    P0_AUTH --> P0_DASHBOARD
    P0_AUTH --> P0_CRUD

    P0_DASHBOARD --> P1_SEARCH
    P0_CRUD --> P1_SEARCH
    P0_CRUD --> P1_EXPORT

    P0_AUTH --> P1_NOTIF
    P0_DASHBOARD --> P1_NOTIF

    P0_CRUD --> P2_COLLAB
    P0_AUTH --> P2_COLLAB

    P0_CRUD --> P2_API
    P2_API --> P2_MOBILE

    %% Styling
    classDef p0Style fill:#ffebee,stroke:#c62828,stroke-width:3px,color:#000,font-weight:bold
    classDef p1Style fill:#fff4e1,stroke:#f57c00,stroke-width:2px,color:#000
    classDef p2Style fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000

    class P0_AUTH,P0_DASHBOARD,P0_CRUD p0Style
    class P1_SEARCH,P1_EXPORT,P1_NOTIF p1Style
    class P2_COLLAB,P2_API,P2_MOBILE p2Style
```

### 4.3 Best Practices

- **P0 (Red)**: 3-5 критичных функций для MVP
- **P1 (Orange)**: 3-6 важных функций для полноценного продукта
- **P2 (Green)**: 2-5 "приятных дополнений"
- **Labels**: Приоритет + название + короткое описание
- **Dependencies**: Стрелки от зависимости к зависимому (P0 → P1 → P2)
- **Layout**: P0 сверху, P1 в центре, P2 снизу (top-down flow)

### 4.4 Validation Rules

```bash
✅ 8-16 функций (total)
✅ P0: 3-5 критичных функций
✅ Все P1 зависят от P0
✅ Все P2 зависят от P0 или P1
✅ Цветовая схема: Red (P0), Orange (P1), Green (P2)
❌ Избегайте циклических зависимостей
❌ P2 не должны блокировать P0/P1
```

---

## 5. Roadmap Timeline Diagram (gantt)

### 5.1 Purpose

Временная шкала разработки с фазами, функциями и вехами (milestones).

### 5.2 Template

```mermaid
gantt
    title Product Roadmap: {Product Name}
    dateFormat YYYY-MM-DD

    section Phase 1: MVP
    User Authentication           :done,    auth, 2025-01-01, 2025-01-15
    Dashboard (Basic)             :done,    dash, 2025-01-10, 2025-01-25
    CRUD Operations               :done,    crud, 2025-01-20, 2025-02-10
    MVP Testing & Bug Fixes       :active,  test1, 2025-02-10, 2025-02-20
    MVP Launch                    :milestone, m1, 2025-02-28, 0d

    section Phase 2: Beta
    Advanced Search               :         search, 2025-03-01, 2025-03-20
    Data Export (CSV/PDF)         :         export, 2025-03-15, 2025-04-05
    Email Notifications           :         notif, 2025-03-20, 2025-04-10
    Beta Testing                  :         test2, 2025-04-10, 2025-04-25
    Beta Release                  :milestone, m2, 2025-04-30, 0d

    section Phase 3: v1.0
    Team Collaboration            :         collab, 2025-05-01, 2025-05-30
    Public API (REST)             :         api, 2025-05-15, 2025-06-10
    Mobile App (MVP)              :         mobile, 2025-06-01, 2025-07-15
    v1.0 Launch                   :milestone, m3, 2025-07-31, 0d

    section Phase 4: Growth
    Advanced Analytics            :         analytics, 2025-08-01, 2025-09-15
    Enterprise Features (SSO)     :         enterprise, 2025-09-01, 2025-10-15
    Internationalization (i18n)   :         i18n, 2025-10-01, 2025-11-15
    v2.0 Launch                   :milestone, m4, 2025-12-01, 0d
```

### 5.3 Best Practices

- **Phases**: 3-5 фаз (MVP → Beta → v1.0 → Growth)
- **Features**: 3-6 функций на фазу
- **Milestones**: Ключевые события (launches, releases)
- **Status**: `done` (завершено), `active` (в процессе), пусто (запланировано)
- **Dependencies**: Implicit (последовательность в gantt)
- **Duration**: Реалистичные сроки (недели/месяцы, не дни)

### 5.4 Validation Rules

```bash
✅ 3-5 секций (phases)
✅ 12-25 задач (total)
✅ 3-5 milestones (key events)
✅ Даты в формате YYYY-MM-DD
✅ Последовательность фаз (no overlap of phases)
❌ Избегайте слишком коротких задач (<1 week)
❌ Избегайте overlap между критичными функциями
```

---

## 6. Color Scheme Standards

### 6.1 Unified Palette

Используйте эту палитру для всех диаграмм:

```css
/* Primary Colors */
Blue:   #1976d2  /* Goals, Actors, High Priority */
Orange: #f57c00  /* Features, System, Medium Priority */
Green:  #388e3c  /* Metrics, External, Low Priority */
Red:    #c62828  /* P0/Critical, Risks */
Gray:   #616161  /* External Systems, Inactive */

/* Background Colors (Light) */
Light Blue:   #e1f5ff
Light Orange: #fff4e1
Light Green:  #e8f5e9
Light Red:    #ffebee
Light Gray:   #f0f0f0
```

### 6.2 ClassDef Syntax

```mermaid
classDef styleName fill:#e1f5ff,stroke:#1976d2,stroke-width:2px,color:#000

class NODE1,NODE2 styleName
```

---

## 7. Common Syntax Patterns

### 7.1 Node Definitions

```mermaid
NODE_ID[Label Text]                  %% Rectangle
NODE_ID(Rounded Rectangle)           %% Rounded
NODE_ID([Stadium])                   %% Stadium-shaped
NODE_ID[[Subroutine]]                %% Double-border
NODE_ID{Diamond}                     %% Decision
NODE_ID{{Hexagon}}                   %% Hexagon
```

### 7.2 Edge Definitions

```mermaid
A --> B          %% Arrow
A --- B          %% Line (no arrow)
A -.-> B         %% Dotted arrow
A ==> B          %% Thick arrow
A -->|Label| B   %% Labeled arrow
```

### 7.3 Multiline Labels

```mermaid
NODE[Line 1<br/>Line 2<br/>Line 3]

NODE[Feature: Auth<br/>--<br/>Login/Signup]
```

### 7.4 Comments

```mermaid
%% This is a comment
graph TD
    A[Node A]  %% Inline comment
```

---

## 8. Validation Checklist

Перед финализацией диаграмм проверьте:

### 8.1 Syntax Validation
- [ ] Все ноды имеют уникальные ID
- [ ] Все связи используют валидные ID
- [ ] Multiline labels используют `<br/>`
- [ ] Comments начинаются с `%%`

### 8.2 Visual Quality
- [ ] Цветовая схема применена (classDef)
- [ ] Количество нод оптимально (5-15 для graph, 15-25 для journey)
- [ ] Labels читаемы (<50 символов на строку)
- [ ] Нет пересекающихся линий (насколько возможно)

### 8.3 Content Quality
- [ ] Диаграмма отражает реальные требования (не placeholder)
- [ ] Все термины согласованы с глоссарием
- [ ] Зависимости логичны (нет циклов в feature dependencies)
- [ ] Даты реалистичны (gantt)

### 8.4 Integration
- [ ] Диаграммы встроены в соответствующие PRD разделы
- [ ] README.md содержит ссылки на все диаграммы
- [ ] Файлы названы правильно (`product-vision.mmd`, etc.)

---

## 9. Common Mistakes

### ❌ Плохо
```mermaid
graph TD
    A[VeryLongLabelWithoutLineBreaksMakingItHardToRead]
    B --> C
    D[Node D]
    %% Missing connection for D (orphaned node)
```

### ✅ Хорошо
```mermaid
graph TD
    A[Very Long Label<br/>Split Into<br/>Multiple Lines]
    B[Node B] --> C[Node C]
    D[Node D] --> B

    classDef myStyle fill:#e1f5ff,stroke:#1976d2
    class A,B,C,D myStyle
```

---

## 10. Rendering Tools

Mermaid поддерживается в:
- ✅ GitHub/GitLab (native rendering)
- ✅ VS Code (Mermaid Preview extension)
- ✅ Obsidian, Notion
- ✅ Mermaid Live Editor (https://mermaid.live)

**Testing**: Всегда проверяйте диаграммы в [Mermaid Live Editor](https://mermaid.live) перед коммитом.

---

## Summary

Эти 5 шаблонов покрывают все ключевые визуализации для PRD:
1. **Product Vision** - стратегия (Goals → Features → Metrics)
2. **User Journey** - UX опыт (Awareness → Advocacy)
3. **System Context** - архитектура (Actors + System + External)
4. **Feature Dependencies** - планирование (P0 → P1 → P2)
5. **Roadmap Timeline** - выполнение (Phases + Milestones)

Используйте эти шаблоны в Phase 5 (Mermaid Diagram Generation) для автоматической генерации диаграмм на основе собранных требований.
