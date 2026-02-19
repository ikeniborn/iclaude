# serve

> **Module:** `docs` | **File:** `lib/docs/serve.sh`

lib/docs/serve.sh
Sphinx Documentation - Live Preview Server
Serves built documentation on localhost

---

### `serve_sphinx_docs`

Serve Sphinx documentation with live preview Builds if needed, then starts HTTP server

**Arguments:**

- `  $1 - project path (default: pwd)`
- `  $2 - port number (default: 8000)`

**Returns:**

-   0 - Server started (or stopped by user)
-   1 - Build failed or python3 not available

**Example:**

```bash
serve_sphinx_docs /path/to/project 8080
```

