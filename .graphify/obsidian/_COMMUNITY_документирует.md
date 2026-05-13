---
type: community
cohesion: 0.24
members: 14
---

# документирует

**Cohesion:** 0.24 - loosely connected
**Members:** 14 nodes

## Members
- [[assert_clean()]] - code - tests/test-quality-analysis.py
- [[assert_masked()]] - code - tests/test-quality-analysis.py
- [[assert_missed()]] - code - tests/test-quality-analysis.py
- [[assert_pii_missed()]] - code - tests/test-quality-analysis.py
- [[get_masked()]] - code - tests/test-quality-analysis.py
- [[record()]] - code - tests/test-quality-analysis.py
- [[run_hook()]] - code - tests/test-quality-analysis.py
- [[test-quality-analysis.py]] - code - tests/test-quality-analysis.py
- [[Возвращает маскированное содержимое или None если не изменено.]] - rationale - tests/test-quality-analysis.py
- [[Документирует PII, который хук НЕ покрывает по дизайну.]] - rationale - tests/test-quality-analysis.py
- [[Документирует ПРОПУЩЕННЫЙ секрет (false negative — дыра в защите).]] - rationale - tests/test-quality-analysis.py
- [[Запускает хук и возвращает (stdout, stderr).]] - rationale - tests/test-quality-analysis.py
- [[Утверждает что контент ДОЛЖЕН быть замаскирован с указанным плейсхолдером.]] - rationale - tests/test-quality-analysis.py
- [[Утверждает что контент НЕ должен быть изменён хуком.]] - rationale - tests/test-quality-analysis.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/
SORT file.name ASC
```
