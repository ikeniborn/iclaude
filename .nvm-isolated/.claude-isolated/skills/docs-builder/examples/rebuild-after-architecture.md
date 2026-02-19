# Example: Rebuild after architecture-documentation

## Scenario

Пользователь обновил архитектуру через `@skill:architecture-documentation`.
Новый файл `docs/architecture/overview.yaml` содержит обновлённые компоненты.
Нужно обновить Sphinx документацию с новой архитектурой.

## Trigger

```
@skill:docs-builder
Архитектура обновлена, пересобери документацию
```

## Steps

1. **Check Sphinx installed:**
   ```bash
   ./iclaude.sh --check-docs
   ```

2. **Build with updated architecture:**
   ```bash
   ./iclaude.sh --build-docs
   ```

3. **Verify llms.txt updated:**
   ```bash
   cat docs/_build/html/llms.txt | head -20
   ```

## Expected Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Building Sphinx Documentation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[info] Generating API reference from lib/*.sh...
[info] API reference: 18 modules, 133 functions → docs/api-reference/

[info] Running sphinx-build...

✓ Documentation built successfully

  HTML:     docs/_build/html/index.html
✓ llms.txt generated for AI agents
  llms.txt: docs/_build/html/llms.txt

  View: ./iclaude.sh --serve-docs
```
