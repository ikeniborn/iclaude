# Example: Add PRD to Sphinx documentation

## Scenario

`@skill:prd-generator` создал новый PRD в `docs/prd/`.
Нужно включить его в Sphinx документацию.

## Trigger

После завершения prd-generator docs-builder вызывается автоматически:
```
@skill:docs-builder add-prd
```

## Steps

1. **Verify PRD exists:**
   ```bash
   ls docs/prd/
   # README.md  overview.md  requirements.md  ...
   ```

2. **Add PRD section to docs/index.md** (if not already present):

   Edit `docs/index.md` to add:
   ````markdown
   ```{toctree}
   :maxdepth: 1
   :caption: Product Requirements

   prd/README
   ```
   ````

3. **Rebuild:**
   ```bash
   ./iclaude.sh --build-docs
   ```

## Result

PRD появится в навигации Sphinx сайта под секцией "Product Requirements".
`llms.txt` будет включать ссылки на PRD документы.
