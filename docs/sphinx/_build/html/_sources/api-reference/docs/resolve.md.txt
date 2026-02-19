# resolve

> **Module:** `docs` | **File:** `lib/docs/resolve.sh`

lib/docs/resolve.sh
Sphinx Documentation - Path Resolution
Per-project helper functions: resolve paths, detect project type.
All functions accept $1=project_path (default: pwd).
Pattern: analogous to lib/context/init.sh

---

### `get_docs_project_dir`

Get absolute project directory

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - prints absolute path

**Example:**

```bash
get_docs_project_dir /path/to/project
```

### `get_docs_project_name`

Get project name from git remote or directory basename

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - prints project name

**Example:**

```bash
get_docs_project_name /path/to/project
```

### `get_docs_venv_dir`

Get global Sphinx venv directory (shared across all projects)

**Arguments:**

- `  None`

**Returns:**

-   0 - prints venv path

**Example:**

```bash
get_docs_venv_dir
```

### `get_docs_sphinx_dir`

Get project Sphinx source directory (docs/sphinx/)

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - prints sphinx dir path

**Example:**

```bash
get_docs_sphinx_dir /path/to/project
```

### `get_docs_build_dir`

Get Sphinx HTML build output directory

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - prints build dir path

**Example:**

```bash
get_docs_build_dir /path/to/project
```

### `get_docs_api_ref_dir`

Get API reference directory inside sphinx source

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - prints api-reference dir path

**Example:**

```bash
get_docs_api_ref_dir /path/to/project
```

### `detect_project_type`

Detect project type based on files present

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - prints one of: bash|python|node|generic

**Example:**

```bash
detect_project_type /path/to/project
```

### `get_docs_src_for_api_ref`

Get source directory for API reference generation (bash projects only)

**Arguments:**

- `  $1 - project path (default: pwd)`

**Returns:**

-   0 - prints lib/ path for bash projects, empty string otherwise

**Example:**

```bash
get_docs_src_for_api_ref /path/to/project
```

