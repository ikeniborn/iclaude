# PRD Best Practices

Этот документ содержит best practices для создания качественного Product Requirements Document (PRD).

## 1. SMART Goals

### 1.1 Definition

**SMART** - акроним для эффективных бизнес-целей:
- **S**pecific - Конкретная (четкая формулировка)
- **M**easurable - Измеримая (количественный показатель)
- **A**chievable - Достижимая (реалистичная)
- **R**elevant - Релевантная (связана с бизнесом)
- **T**ime-bound - Ограниченная во времени (дедлайн)

### 1.2 Examples

**❌ Плохо** (не SMART):
```
- Улучшить продукт
- Привлечь больше клиентов
- Повысить удовлетворенность пользователей
```

**✅ Хорошо** (SMART):
```
- Увеличить месячный recurring revenue (MRR) на 30% ($150K → $195K) к концу Q2 2025
- Привлечь 5,000 активных пользователей в течение первых 3 месяцев после запуска
- Достичь Net Promoter Score (NPS) 60+ через 6 месяцев после запуска
- Снизить churn rate с 8% до 5% к концу Q4 2025 через улучшение onboarding
```

### 1.3 Template

```markdown
## Business Goals

1. **[Action Verb] [Metric] by [Amount] from [Baseline] to [Target] by [Deadline]**
   - Example: Increase conversion rate by 50% from 2% to 3% by Q3 2025

2. **[Achieve/Reach] [Metric] of [Target Value] by [Deadline]**
   - Example: Achieve user retention rate of 75% by Q4 2025

3. **[Reduce/Decrease] [Metric] from [Current] to [Target] within [Timeframe]**
   - Example: Reduce customer acquisition cost (CAC) from $200 to $120 within 6 months
```

### 1.4 Validation Checklist

- [ ] Specific: Цель ясна без дополнительных объяснений?
- [ ] Measurable: Есть численный показатель (%, $, количество)?
- [ ] Achievable: Цель реалистична с учетом ресурсов?
- [ ] Relevant: Цель связана с бизнес-стратегией?
- [ ] Time-bound: Указан конкретный дедлайн (Q2 2025, 6 months)?

---

## 2. Success Metrics (KPIs)

### 2.1 Categories

**Acquisition Metrics:**
- Monthly Active Users (MAU)
- Sign-ups / Registrations
- Conversion Rate (visitor → sign-up)
- Customer Acquisition Cost (CAC)

**Engagement Metrics:**
- Daily Active Users (DAU)
- Session Duration
- Feature Adoption Rate
- Stickiness (DAU/MAU ratio)

**Retention Metrics:**
- Churn Rate
- Customer Lifetime Value (LTV)
- Retention Rate (Day 1, Day 7, Day 30)
- Net Promoter Score (NPS)

**Revenue Metrics:**
- Monthly Recurring Revenue (MRR)
- Annual Recurring Revenue (ARR)
- Average Revenue Per User (ARPU)
- LTV:CAC Ratio

### 2.2 Examples

```markdown
## Success Metrics

| Metric | Baseline | Target | Timeframe | Measurement |
|--------|----------|--------|-----------|-------------|
| MAU | 0 | 5,000+ | 3 months | Google Analytics |
| Conversion Rate | N/A | 3% | 6 months | Internal tracking |
| Churn Rate | 8% | <5% | Q4 2025 | Stripe webhooks |
| NPS | N/A | 60+ | 6 months | User surveys |
| MRR | $150K | $195K | Q2 2025 | Financial reporting |
```

### 2.3 Best Practices

- **North Star Metric**: Выберите 1 главный показатель (например, MAU для роста)
- **Leading Indicators**: Метрики, предсказывающие будущий успех
- **Lagging Indicators**: Метрики, отражающие прошлые результаты
- **Actionable**: Каждая метрика должна влиять на решения

---

## 3. User Personas

### 3.1 Template

```markdown
## Persona: [Name], [Age], [Job Title]

**Photo**: [Optional headshot or icon]

**Demographics:**
- Age: [Age range]
- Location: [City/Country/Region]
- Education: [Degree/Level]
- Industry: [Industry sector]

**Professional:**
- Role: [Current job title]
- Company Size: [Startup/SMB/Enterprise]
- Seniority: [Junior/Mid/Senior/Executive]
- Team Size: [Number of reports]

**Goals:**
- [Goal 1: What they want to achieve]
- [Goal 2: Career or personal objective]
- [Goal 3: Related to product usage]

**Pain Points:**
- [Pain 1: Frustration or problem]
- [Pain 2: Inefficiency or blocker]
- [Pain 3: Unmet need]

**Behaviors:**
- [Behavior 1: How they work]
- [Behavior 2: Decision-making process]

**Technology Usage:**
- Tools: [Tools they use daily]
- Platforms: [Desktop/Mobile/Both]
- Tech Savviness: [Low/Medium/High]

**Quote:**
> "[Motivational or descriptive quote that captures their mindset]"

**Product Usage:**
- Use Case: [Primary use case for your product]
- Frequency: [Daily/Weekly/Monthly]
- Key Features: [3-5 features they care about most]
```

### 3.2 Example

```markdown
## Persona: Anna, 32, Marketing Manager

**Demographics:**
- Age: 30-35
- Location: Moscow, Russia
- Education: MBA in Marketing
- Industry: SaaS / Technology

**Professional:**
- Role: Marketing Manager
- Company Size: 50-200 employees (SMB)
- Seniority: Mid-level
- Team Size: Manages 3 direct reports

**Goals:**
- Increase marketing ROI by 25% this year
- Streamline campaign reporting (save 5 hours/week)
- Gain real-time visibility into marketing performance

**Pain Points:**
- Spends 10+ hours/week manually compiling reports from multiple tools
- Lacks real-time data to make quick marketing decisions
- Struggles to prove marketing impact to C-level executives

**Behaviors:**
- Checks analytics 3-5 times per day
- Prefers visual dashboards over raw data
- Makes data-driven decisions but needs insights fast

**Technology Usage:**
- Tools: Google Analytics, HubSpot, Slack, Asana
- Platforms: Desktop (80%), Mobile (20%)
- Tech Savviness: High (early adopter)

**Quote:**
> "I need to show the CEO that our campaigns are driving real revenue, not just vanity metrics."

**Product Usage:**
- Use Case: Marketing analytics dashboard for real-time campaign performance
- Frequency: Daily (morning and before meetings)
- Key Features: Automated reporting, ROI tracking, multi-channel attribution
```

### 3.3 Best Practices

- **2-5 personas**: Не создавайте слишком много (фокус размывается)
- **Real data**: Используйте интервью с реальными пользователями
- **Jobs-to-be-Done**: Фокус на задачах, а не демографии
- **Negative personas**: Опишите, кто НЕ ваш клиент

---

## 4. Functional Requirements

### 4.1 User Story Format

```markdown
**As a** [role/persona],
**I want** [action/feature],
**So that** [benefit/outcome].
```

### 4.2 Examples

```markdown
**User Story:**
As a marketing manager,
I want to create automated weekly reports,
So that I can save 5 hours per week on manual reporting.

**User Story:**
As a product owner,
I want to track feature adoption by user segment,
So that I can prioritize roadmap based on real usage data.
```

### 4.3 Acceptance Criteria (Given-When-Then)

```markdown
**Acceptance Criteria:**
- [ ] **Given** user is logged in and has admin role,
      **When** they navigate to Settings → Users,
      **Then** they see a list of all users with email, role, and last login.

- [ ] **Given** user clicks "Add User" button,
      **When** they fill in email and select role,
      **Then** new user receives invite email within 5 minutes.

- [ ] **Given** user enters invalid email format,
      **When** they click "Save",
      **Then** error message "Invalid email format" is displayed.
```

### 4.4 Priority (MoSCoW Method)

- **P0 (Must Have)**: Критично для MVP, без этого продукт не работает
- **P1 (Should Have)**: Важно, но MVP может запуститься без этого
- **P2 (Could Have)**: Желательно, но низкий приоритет
- **P3 (Won't Have)**: Не будет в этой версии

```markdown
| Feature | Priority | Effort | Dependencies |
|---------|----------|--------|--------------|
| User Authentication | P0 | M | None |
| Dashboard | P0 | L | Authentication |
| Data Export (CSV) | P1 | S | Dashboard |
| Mobile App | P2 | XL | API |
```

### 4.5 Effort Estimation (T-shirt Sizing)

- **XS**: 1-2 hours
- **S**: 1-3 days
- **M**: 1 week
- **L**: 2 weeks
- **XL**: 3+ weeks

---

## 5. Non-Functional Requirements (NFR)

### 5.1 Performance

```markdown
## Performance Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| Page Load Time | <2 seconds (p95) | Lighthouse, WebPageTest |
| API Response Time | <500ms (p95) | APM (New Relic, Datadog) |
| Time to Interactive (TTI) | <3 seconds | Lighthouse |
| Database Query Time | <100ms (p95) | Query profiler |
| Concurrent Users | 10,000+ | Load testing (k6, JMeter) |
```

**Best Practices:**
- Используйте p95/p99 percentiles (не average)
- Определите acceptable degradation (graceful degradation)
- Планируйте capacity: Peak load = Average × 3

### 5.2 Security

```markdown
## Security Requirements

**Authentication & Authorization:**
- [ ] Multi-factor authentication (MFA) support
- [ ] OAuth 2.0 integration (Google, GitHub)
- [ ] Role-based access control (RBAC)
- [ ] Session timeout after 30 minutes of inactivity

**Data Protection:**
- [ ] All data encrypted at rest (AES-256)
- [ ] All data encrypted in transit (TLS 1.3)
- [ ] PII (Personally Identifiable Information) anonymized in logs
- [ ] GDPR/CCPA compliance for user data deletion

**Infrastructure:**
- [ ] Regular security audits (quarterly)
- [ ] Automated vulnerability scanning (Snyk, Dependabot)
- [ ] DDoS protection (Cloudflare, AWS Shield)
- [ ] OWASP Top 10 compliance
```

### 5.3 Scalability

```markdown
## Scalability Requirements

**Horizontal Scaling:**
- Application servers: Auto-scaling (2-10 instances)
- Database: Read replicas (1 primary + 2 replicas)
- Cache: Redis cluster (3 nodes)

**Data Growth:**
- Support 100 million records by Year 2
- Database partitioning strategy (sharding by user_id)

**Geographic Distribution:**
- CDN for static assets (CloudFront, Cloudflare)
- Multi-region deployment (US-East, EU-West)
```

### 5.4 Availability & Reliability

```markdown
## Availability Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| Uptime SLA | 99.9% (43 min/month downtime) | Pingdom, StatusPage |
| Recovery Time Objective (RTO) | <1 hour | Incident response time |
| Recovery Point Objective (RPO) | <15 minutes | Backup frequency |
| Error Rate | <0.1% | APM error tracking |

**Disaster Recovery:**
- Automated backups (hourly incremental, daily full)
- Backup retention: 30 days
- Multi-region failover (active-passive)
```

---

## 6. Risk Assessment

### 6.1 Risk Register Template

```markdown
| ID | Risk | Probability | Impact | Severity | Mitigation | Owner |
|----|------|------------|--------|----------|------------|-------|
| R01 | Security breach of user data | Low | Critical | High | Encryption, audits, penetration testing | Security Lead |
| R02 | Third-party API downtime (Stripe) | Medium | High | High | Retry logic, fallback payment provider | Backend Lead |
| R03 | Low user adoption rate | Medium | Medium | Medium | User research, beta testing, onboarding | Product Manager |
| R04 | Database performance degradation | Low | Medium | Low | Query optimization, caching, monitoring | Database Admin |
```

### 6.2 Severity Calculation

**Severity = Probability × Impact**

| Probability | Impact | Severity |
|------------|--------|----------|
| High (3) × Critical (3) | = 9 | **Critical** |
| High (3) × High (2) | = 6 | **High** |
| Medium (2) × High (2) | = 4 | **Medium** |
| Low (1) × Medium (1) | = 1 | **Low** |

### 6.3 Mitigation Strategies

- **Avoid**: Change plan to eliminate risk
- **Mitigate**: Reduce probability or impact
- **Transfer**: Outsource or insure against risk
- **Accept**: Acknowledge and monitor risk

---

## 7. Out of Scope

Явно определите, что **НЕ входит** в эту версию:

```markdown
## Out of Scope (Not in v1.0)

- ❌ Mobile native apps (iOS/Android) - planned for v2.0
- ❌ Offline mode - requires significant architecture changes
- ❌ Multi-language support (i18n) - planned for v1.5
- ❌ White-label/custom branding - enterprise feature for v2.0
- ❌ Integration with CRM systems - low priority, future consideration
```

**Best Practices:**
- Помогает управлять ожиданиями
- Предотвращает scope creep
- Документирует отложенные функции

---

## 8. Validation Checklist

### 8.1 Goals & Metrics
- [ ] Все бизнес-цели соответствуют SMART критериям
- [ ] Определены 3-6 ключевых метрик успеха
- [ ] Метрики измеримы (есть baseline и target)
- [ ] Указан North Star Metric

### 8.2 User Personas
- [ ] Создано 2-5 персон (не слишком много)
- [ ] Каждая персона имеет goals, pain points, behaviors
- [ ] Персоны основаны на реальных интервью (не выдуманы)
- [ ] Указаны key features для каждой персоны

### 8.3 Functional Requirements
- [ ] Все user stories в формате "As a...I want...So that..."
- [ ] Acceptance criteria в Given-When-Then формате
- [ ] Указан приоритет (P0/P1/P2) для каждой функции
- [ ] Effort estimation (S/M/L/XL) для планирования

### 8.4 Non-Functional Requirements
- [ ] Performance targets определены (page load, API response)
- [ ] Security requirements покрывают OWASP Top 10
- [ ] Scalability планирование на 2-3 года вперед
- [ ] Availability SLA определена (uptime %)

### 8.5 Risks
- [ ] Идентифицировано 5-10 ключевых рисков
- [ ] Для каждого риска указан probability, impact, severity
- [ ] Определены mitigation стратегии
- [ ] Назначены owners для каждого риска

---

## Summary

Эти best practices обеспечивают:
- ✅ **Clarity**: Четкие, измеримые цели
- ✅ **User-Centricity**: Фокус на реальных пользователях (personas)
- ✅ **Actionability**: Конкретные требования с acceptance criteria
- ✅ **Quality**: NFR обеспечивают production-ready продукт
- ✅ **Risk Management**: Проактивная идентификация и mitigation рисков

Используйте этот документ как референс в Phase 2 (Requirements Analysis) и Phase 4 (Content Generation) для создания качественного PRD контента.
