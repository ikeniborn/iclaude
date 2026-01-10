# Context7 Integration Examples

Real-world examples demonstrating context7-integration skill behavior in different scenarios.

## Example 1: Python FastAPI Project (PARTIAL - Budget Exhausted)

### Setup

**Task:** "Add JWT authentication to FastAPI app"

**requirements.txt:**
```
fastapi==0.104.1
pytest>=7.4.0
pydantic~=2.5.0
jose>=3.3.0
uvicorn>=0.24.0
```

**Detected libraries:** [fastapi, pytest, pydantic, jose, uvicorn]

**Framework:** fastapi (from context-awareness)

### Scoring

```
fastapi:  10 (framework) + 5 (in task) + 3 (common) + 2 (prod) = 20
jose:     5 (JWT keyword match) + 2 (prod) = 7
pydantic: 3 (common) + 2 (prod) = 5
pytest:   0 (dev dependency) = 0
uvicorn:  2 (prod) = 2
```

**Priority (top 3):** `[fastapi, jose, pydantic]`

### Execution Flow

```
Budget: 3 calls available

Call 1: resolve-library-id("fastapi", "FastAPI web framework for Python")
Result: /tiangolo/fastapi
Status: calls_used=1, calls_remaining=2

Call 2: query-docs("/tiangolo/fastapi", "How to implement JWT authentication in FastAPI")
Result: Documentation fetched
Status: calls_used=2, calls_remaining=1
Warning: "Context7 budget: 2/3 calls used"

Call 3: resolve-library-id("jose", "Python JOSE library for JWT")
Result: /mpdavis/python-jose
Status: calls_used=3, calls_remaining=0, exhausted=true

BUDGET EXHAUSTED - Cannot call query-docs for jose
Skipped: jose (resolved but no budget for docs), pydantic, pytest, uvicorn
```

### JSON Output

```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 3,
      "calls_remaining": 0,
      "exhausted": true,
      "warning": "Context7 budget exhausted (3/3 calls)"
    },
    "libraries": [
      {
        "library_id": "/tiangolo/fastapi",
        "library_name": "fastapi",
        "docs_summary": "FastAPI provides a dependency injection system that makes it easy to implement authentication. Use Depends() for dependency injection and create authentication dependencies that verify JWT tokens.",
        "code_examples": [
          "from fastapi import Depends, HTTPException, status",
          "from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials",
          "@app.get('/protected', dependencies=[Depends(verify_token)])",
          "async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security))"
        ],
        "relevant_sections": [
          "Security",
          "Dependencies",
          "OAuth2 with Password and Bearer"
        ],
        "query_used": "How to implement JWT authentication in FastAPI"
      }
    ],
    "skipped_libraries": [
      {
        "library_name": "jose",
        "reason": "Budget exhausted"
      },
      {
        "library_name": "pydantic",
        "reason": "Budget exhausted"
      },
      {
        "library_name": "pytest",
        "reason": "Low priority"
      },
      {
        "library_name": "uvicorn",
        "reason": "Budget exhausted"
      }
    ],
    "status": "PARTIAL"
  }
}
```

### User Message

```
✓ Context7 Integration (3/3 calls used)

Fetched docs: fastapi (/tiangolo/fastapi)
Skipped: jose, pydantic (budget exhausted), pytest, uvicorn

Proceeding to planning...
```

---

## Example 2: React TypeScript Project (SUCCESS)

### Setup

**Task:** "Add dark mode toggle to Settings"

**package.json:**
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "typescript": "^5.0.0",
    "vite": "^5.0.0"
  }
}
```

**Detected libraries:** [react, react-dom, @types/react, typescript, vite]

**Framework:** react

### Scoring

```
react:       10 (framework) + 5 (in task) + 3 (common) + 2 (prod) = 20
react-dom:   3 (common) + 2 (prod) = 5
@types/react: 0 (dev dependency) = 0
typescript:  0 (dev dependency) = 0
vite:        0 (dev dependency) = 0
```

**Priority (top 3):** `[react, react-dom, @types/react]` (only 2 have positive scores)

### Execution Flow

```
Budget: 3 calls available

Call 1: resolve-library-id("react", "React library for building UIs")
Result: /facebook/react
Status: calls_used=1, calls_remaining=2

Call 2: query-docs("/facebook/react", "React state management dark mode toggle")
Result: Documentation fetched
Status: calls_used=2, calls_remaining=1

No more high-priority libraries with positive scores
Remaining budget: 1 call
```

### JSON Output

```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 2,
      "calls_remaining": 1,
      "exhausted": false,
      "warning": "Context7 budget: 2/3 calls used"
    },
    "libraries": [
      {
        "library_id": "/facebook/react",
        "library_name": "react",
        "docs_summary": "React useState and useContext hooks are ideal for managing theme state. Create a ThemeContext to provide dark mode state throughout your component tree.",
        "code_examples": [
          "const [darkMode, setDarkMode] = useState(false)",
          "const ThemeContext = createContext({ darkMode: false, toggleDarkMode: () => {} })",
          "<ThemeContext.Provider value={{ darkMode, toggleDarkMode }}>"
        ],
        "relevant_sections": [
          "State Management",
          "Context",
          "Hooks"
        ],
        "query_used": "React state management dark mode toggle"
      }
    ],
    "skipped_libraries": [
      {
        "library_name": "react-dom",
        "reason": "Low priority"
      },
      {
        "library_name": "@types/react",
        "reason": "Low priority"
      }
    ],
    "status": "SUCCESS"
  }
}
```

### User Message

```
✓ Context7 Integration (2/3 calls used)

Fetched docs: react (/facebook/react)
Budget: 1 call remaining

Proceeding to planning...
```

---

## Example 3: Bash Project (NO_LIBRARIES_DETECTED)

### Setup

**Task:** "Add error handling to backup script"

**Project structure:**
```
backup.sh
restore.sh
README.md
```

**No manifest files** (no package.json, requirements.txt, etc.)

### Execution Flow

```
1. Search for manifests: Not found
2. Detected libraries: []
3. Return NO_LIBRARIES_DETECTED (silent skip)
```

### JSON Output

```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 0,
      "calls_remaining": 0,
      "exhausted": false
    },
    "libraries": [],
    "skipped_libraries": [],
    "status": "NO_LIBRARIES_DETECTED"
  }
}
```

### User Message

**(Silent - no output)**

Workflow continues to adaptive-workflow without any messages.

---

## Example 4: Plugin Not Available (PLUGIN_NOT_AVAILABLE)

### Setup

**Task:** "Add Express middleware for logging"

**package.json:**
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "morgan": "^1.10.0"
  }
}
```

**Context7 MCP plugin:** Not installed

### Execution Flow

```
1. Check plugin availability
2. Try test call: mcp__plugin_context7__resolve_library_id()
3. Error: "function not found"
4. Return PLUGIN_NOT_AVAILABLE
```

### JSON Output

```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 0,
      "calls_remaining": 0,
      "exhausted": false
    },
    "libraries": [],
    "skipped_libraries": [],
    "status": "PLUGIN_NOT_AVAILABLE"
  }
}
```

### User Message

```
ℹ️ Context7 plugin not installed. Continuing without library docs.

To enable: Install Context7 MCP server
```

Workflow continues to adaptive-workflow.

---

## Example 5: Network Error During query-docs (PARTIAL)

### Setup

**Task:** "Add GraphQL endpoint to Express app"

**package.json:**
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "apollo-server-express": "^3.12.0"
  }
}
```

### Execution Flow

```
Call 1: resolve-library-id("express") → /expressjs/express
Status: Success, calls_used=1

Call 2: query-docs("/expressjs/express", "Express GraphQL endpoint")
Error: Network timeout after 30s
Status: calls_used=2 (failed call still counts!)

Call 3: resolve-library-id("apollo-server-express")
Result: /apollographql/apollo-server
Status: calls_used=3, exhausted=true
```

### JSON Output

```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 3,
      "calls_remaining": 0,
      "exhausted": true,
      "warning": "Context7 budget exhausted (3/3 calls)"
    },
    "libraries": [],
    "skipped_libraries": [
      {
        "library_name": "express",
        "reason": "Network error: timeout after 30s"
      },
      {
        "library_name": "apollo-server-express",
        "reason": "Budget exhausted"
      }
    ],
    "status": "PARTIAL"
  }
}
```

### User Message

```
⚠️ Context7 budget exhausted (3/3 calls)

Errors: express (network timeout)
Skipped: apollo-server-express (budget exhausted)

Proceeding with available information...
```

---

## Example 6: Library Not Found in Context7 (PARTIAL)

### Setup

**Task:** "Add custom validation library"

**requirements.txt:**
```
fastapi==0.104.1
my-custom-validator==1.0.0
```

### Execution Flow

```
Priority: [fastapi, my-custom-validator]

Call 1: resolve-library-id("fastapi") → /tiangolo/fastapi
Status: calls_used=1

Call 2: query-docs("/tiangolo/fastapi", "FastAPI validation") → docs
Status: calls_used=2

Call 3: resolve-library-id("my-custom-validator") → NOT FOUND
Status: calls_used=3 (failed call counts!)
```

### JSON Output

```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 3,
      "calls_remaining": 0,
      "exhausted": true
    },
    "libraries": [
      {
        "library_id": "/tiangolo/fastapi",
        "library_name": "fastapi",
        "docs_summary": "FastAPI provides built-in validation using Pydantic models...",
        "code_examples": ["class Item(BaseModel):", "    name: str"],
        "relevant_sections": ["Validation"],
        "query_used": "FastAPI validation"
      }
    ],
    "skipped_libraries": [
      {
        "library_name": "my-custom-validator",
        "reason": "Not found in Context7"
      }
    ],
    "status": "PARTIAL"
  }
}
```

---

## Example 7: Version-Specific Query (SUCCESS)

### Setup

**Task:** "Migrate to Next.js 14"

**package.json:**
```json
{
  "dependencies": {
    "next": "13.5.0",
    "react": "^18.2.0"
  }
}
```

**Version detection:** Task mentions "Next.js 14" explicitly

### Execution Flow

```
Priority: [next, react]

Call 1: resolve-library-id("next", "Next.js 14 upgrade guide")
Result: /vercel/next.js/v14.0.0 (version-specific!)
Status: calls_used=1

Call 2: query-docs("/vercel/next.js/v14.0.0", "Next.js 14 new features migration")
Result: Version-specific docs fetched
Status: calls_used=2

Remaining budget: 1 call (sufficient for react if needed)
```

### JSON Output

```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 2,
      "calls_remaining": 1,
      "exhausted": false
    },
    "libraries": [
      {
        "library_id": "/vercel/next.js/v14.0.0",
        "library_name": "next",
        "docs_summary": "Next.js 14 introduces Server Actions, Partial Prerendering, and improved performance. Migration guide highlights breaking changes in app router and metadata API.",
        "code_examples": [
          "export async function serverAction() { 'use server'; }",
          "export const metadata = { title: 'New format' }"
        ],
        "relevant_sections": [
          "Migration Guide",
          "Server Actions",
          "Breaking Changes"
        ],
        "query_used": "Next.js 14 new features migration"
      }
    ],
    "skipped_libraries": [
      {
        "library_name": "react",
        "reason": "Low priority"
      }
    ],
    "status": "SUCCESS"
  }
}
```

---

## Summary Table

| Example | Task | Libraries Detected | Calls Used | Status | Key Takeaway |
|---------|------|-------------------|------------|--------|-------------|
| 1 | FastAPI JWT | 5 | 3/3 | PARTIAL | Budget exhausted, got framework docs |
| 2 | React dark mode | 5 | 2/3 | SUCCESS | Only 1 high-priority library |
| 3 | Bash script | 0 | 0/3 | NO_LIBRARIES_DETECTED | Silent skip, no manifests |
| 4 | Express logging | 2 | 0/3 | PLUGIN_NOT_AVAILABLE | Graceful degradation |
| 5 | Express GraphQL | 2 | 3/3 | PARTIAL | Network error counts toward budget |
| 6 | Custom validator | 2 | 3/3 | PARTIAL | Not found counts toward budget |
| 7 | Next.js 14 migration | 2 | 2/3 | SUCCESS | Version-specific query worked |
