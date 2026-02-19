# status

> **Module:** `docs` | **File:** `lib/docs/status.sh`

lib/docs/status.sh
Sphinx Documentation - Status Check
Checks installation status of Sphinx documentation environment

---

### `check_docs_status`

Check Sphinx documentation environment status for a project Verifies python3, venv, sphinx installation and build output

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - Sphinx fully operational
-   1 - Not installed or partially installed

**Example:**

```bash
check_docs_status /path/to/project
```

