# Example: Multi-Example Skill - API Client Generator

## Scenario

Create a skill that generates API client code with multiple usage scenarios, demonstrating proper decomposition structure with:
- 3 examples (basic, advanced, error-handling)
- rules/best-practices.md
- Templates with @references in SKILL.md

This example shows the **correct way** to structure a skill with decomposed components.

---

## Generated Files

### Directory Structure

```
.claude/skills/api-client-generator/
├── SKILL.md                           # Main file with @references
├── examples/
│   ├── basic-rest-api.md             # Basic usage scenario
│   ├── graphql-client.md             # Advanced scenario
│   └── error-handling.md             # Error handling scenario
├── rules/
│   └── best-practices.md             # Best practices + pitfalls
├── templates/
│   ├── input.json                    # Input structure template
│   └── output.json                   # Output structure template
└── schemas/
    ├── input.schema.json             # Auto-generated schema
    └── output.schema.json            # Auto-generated schema
```

---

### 1. SKILL.md (with @references)

```yaml
---
name: api-client-generator
description: Generate type-safe API client code from OpenAPI/GraphQL schemas
version: 1.0.0
tags:
  - codegen
  - api
  - automation
dependencies: []
user-invocable: true
files:
  examples: ./examples/*.md
  rules: ./rules/*.md
  templates: ./templates/*.json
  schemas: ./schemas/*.schema.json
---

# API Client Generator

Automatically generates type-safe API client code from OpenAPI specifications or GraphQL schemas.

## When to Use

- Setting up new API integrations with type safety
- Migrating from manual API calls to generated clients
- Ensuring API schema and client code stay in sync

## How It Works

### Step 1: Schema Analysis
Parse OpenAPI/GraphQL schema and extract endpoints, types, authentication methods.

### Step 2: Code Generation
Generate client code with:
- Type-safe request/response interfaces
- Authentication handling
- Error handling with retries
- Request/response interceptors

### Step 3: Validation
Validate generated code against schema and run type checks.

## Output Format

### Workflow Integration (JSON)

```json
{
  "api_client": {
    "language": "typescript",
    "generated_files": ["src/api/client.ts", "src/api/types.ts"],
    "test_files": ["src/api/client.test.ts"],
    "authentication": "bearer_token"
  }
}
```

## Examples

- **@example:basic-rest-api.md** - Generate client for simple REST API with CRUD operations
- **@example:graphql-client.md** - Generate client for GraphQL API with queries and mutations
- **@example:error-handling.md** - Handle API errors, retries, and rate limiting

## Rules

- **@rules:best-practices.md** - API client design patterns, common pitfalls, performance tips

## Templates

- **@template:input.json** - Input structure (schema URL, language, options)
- **@template:output.json** - Output structure (generated files, validation results)

## Schemas

Auto-generated from templates:
- `input.schema.json`
- `output.schema.json`

## Workflow Integration

### Input Dependencies
- Schema URL (OpenAPI/GraphQL endpoint)
- Target language (TypeScript, Python, Go)

### Output Consumers
- `code-review` - Reviews generated client code
- `validation-framework` - Validates type safety
```

---

### 2. examples/basic-rest-api.md

```markdown
# Example: Basic REST API Client

## Scenario
Generate a TypeScript client for a simple REST API with CRUD operations for a Todo application.

## Input

### API Schema (OpenAPI 3.0)
```yaml
openapi: 3.0.0
info:
  title: Todo API
  version: 1.0.0
paths:
  /todos:
    get:
      summary: List todos
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Todo'
    post:
      summary: Create todo
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TodoInput'
      responses:
        '201':
          description: Created
components:
  schemas:
    Todo:
      type: object
      properties:
        id: { type: string }
        title: { type: string }
        completed: { type: boolean }
    TodoInput:
      type: object
      required: [title]
      properties:
        title: { type: string }
```

### Skill Input (JSON)
```json
{
  "schema_url": "https://api.example.com/openapi.yaml",
  "language": "typescript",
  "output_dir": "src/api",
  "options": {
    "authentication": "bearer_token",
    "include_tests": true
  }
}
```

## Generated Output

### src/api/client.ts
```typescript
export interface Todo {
  id: string;
  title: string;
  completed: boolean;
}

export interface TodoInput {
  title: string;
}

export class TodoApiClient {
  constructor(private baseUrl: string, private token: string) {}

  async listTodos(): Promise<Todo[]> {
    const response = await fetch(`${this.baseUrl}/todos`, {
      headers: { Authorization: `Bearer ${this.token}` }
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  }

  async createTodo(input: TodoInput): Promise<Todo> {
    const response = await fetch(`${this.baseUrl}/todos`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.token}`
      },
      body: JSON.stringify(input)
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  }
}
```

### src/api/client.test.ts
```typescript
import { TodoApiClient } from './client';

describe('TodoApiClient', () => {
  it('lists todos', async () => {
    const client = new TodoApiClient('https://api.example.com', 'test-token');
    const todos = await client.listTodos();
    expect(Array.isArray(todos)).toBe(true);
  });
});
```

## Validation

- ✅ TypeScript compilation successful
- ✅ All endpoints covered
- ✅ Authentication headers included
- ✅ Tests generated
```

---

### 3. examples/graphql-client.md

```markdown
# Example: GraphQL Client

## Scenario
Generate a TypeScript client for GraphQL API with queries and mutations.

## Input

### GraphQL Schema
```graphql
type User {
  id: ID!
  name: String!
  email: String!
  posts: [Post!]!
}

type Post {
  id: ID!
  title: String!
  content: String!
  author: User!
}

type Query {
  user(id: ID!): User
  posts: [Post!]!
}

type Mutation {
  createPost(title: String!, content: String!): Post!
}
```

### Skill Input
```json
{
  "schema_url": "https://api.example.com/graphql",
  "language": "typescript",
  "output_dir": "src/graphql",
  "options": {
    "authentication": "bearer_token",
    "include_tests": true,
    "generate_hooks": true
  }
}
```

## Generated Output

### src/graphql/client.ts
```typescript
import { GraphQLClient } from 'graphql-request';

export interface User {
  id: string;
  name: string;
  email: string;
  posts: Post[];
}

export interface Post {
  id: string;
  title: string;
  content: string;
  author: User;
}

export class ApiClient {
  private client: GraphQLClient;

  constructor(endpoint: string, token: string) {
    this.client = new GraphQLClient(endpoint, {
      headers: { Authorization: `Bearer ${token}` }
    });
  }

  async getUser(id: string): Promise<User> {
    const query = `
      query GetUser($id: ID!) {
        user(id: $id) {
          id name email
          posts { id title }
        }
      }
    `;
    const data = await this.client.request<{ user: User }>(query, { id });
    return data.user;
  }

  async createPost(title: string, content: string): Promise<Post> {
    const mutation = `
      mutation CreatePost($title: String!, $content: String!) {
        createPost(title: $title, content: $content) {
          id title content
        }
      }
    `;
    const data = await this.client.request<{ createPost: Post }>(mutation, { title, content });
    return data.createPost;
  }
}
```

## Validation

- ✅ TypeScript compilation successful
- ✅ GraphQL schema validated
- ✅ All queries and mutations covered
- ✅ Type-safe request/response
```

---

### 4. examples/error-handling.md

```markdown
# Example: Error Handling

## Scenario
Generate API client with comprehensive error handling, retries, and rate limiting.

## Input

```json
{
  "schema_url": "https://api.example.com/openapi.yaml",
  "language": "typescript",
  "output_dir": "src/api",
  "options": {
    "authentication": "bearer_token",
    "error_handling": {
      "retry_attempts": 3,
      "retry_delay": 1000,
      "rate_limit": {
        "max_requests": 100,
        "per_seconds": 60
      }
    }
  }
}
```

## Generated Output

### src/api/client-with-errors.ts
```typescript
import axios, { AxiosError } from 'axios';
import axiosRetry from 'axios-retry';
import rateLimit from 'axios-rate-limit';

export class RobustApiClient {
  private client;

  constructor(baseUrl: string, token: string) {
    this.client = rateLimit(axios.create({
      baseURL: baseUrl,
      headers: { Authorization: `Bearer ${token}` }
    }), { maxRequests: 100, perMilliseconds: 60000 });

    axiosRetry(this.client, {
      retries: 3,
      retryDelay: axiosRetry.exponentialDelay,
      retryCondition: (error: AxiosError) => {
        return axiosRetry.isNetworkOrIdempotentRequestError(error) ||
               error.response?.status === 429; // Rate limit
      }
    });
  }

  async get<T>(path: string): Promise<T> {
    try {
      const response = await this.client.get<T>(path);
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        if (error.response?.status === 401) {
          throw new Error('Authentication failed');
        }
        if (error.response?.status === 429) {
          throw new Error('Rate limit exceeded');
        }
        throw new Error(`API error: ${error.message}`);
      }
      throw error;
    }
  }
}
```

## Validation

- ✅ Retry logic with exponential backoff
- ✅ Rate limiting (100 req/min)
- ✅ Handles 401 (auth), 429 (rate limit)
- ✅ Network error retries
```

---

### 5. rules/best-practices.md

```markdown
# Best Practices: API Client Generator

## Best Practices

### ✅ Use Type-Safe Clients
**Rationale:** Type safety catches errors at compile time, not runtime

Always generate TypeScript/type-safe clients instead of plain JavaScript. This ensures:
- Request/response types are validated
- Autocomplete in IDE
- Refactoring safety

### ✅ Include Authentication by Default
**Rationale:** Most APIs require authentication

Always generate clients with authentication support:
- Bearer tokens
- API keys
- OAuth flows

### ✅ Generate Tests Alongside Client
**Rationale:** Tests serve as documentation and validation

Include test files with:
- Example requests
- Mock responses
- Error scenarios

## Common Pitfalls

### ❌ Hardcoding Base URLs
**Consequence:** Client breaks in different environments (dev/staging/prod)
**Solution:** Accept base URL as constructor parameter

```typescript
// ❌ Bad
class Client {
  private url = 'https://api.production.com';
}

// ✅ Good
class Client {
  constructor(private url: string) {}
}
```

### ❌ No Error Handling
**Consequence:** App crashes on network errors or API failures
**Solution:** Wrap all requests in try/catch with specific error types

```typescript
// ❌ Bad
async get(path: string) {
  return await fetch(path);
}

// ✅ Good
async get(path: string) {
  try {
    const response = await fetch(path);
    if (!response.ok) throw new ApiError(response.status);
    return response;
  } catch (error) {
    throw new NetworkError(error.message);
  }
}
```

### ❌ Ignoring Rate Limits
**Consequence:** API blocks your requests, users see errors
**Solution:** Implement rate limiting with retry logic

## Performance Tips

### ⚡ Use Request Batching
**Impact:** Reduces network roundtrips by 50-90%

Batch multiple requests into single API call when schema supports it:
```typescript
// Instead of 10 individual requests
await Promise.all(ids.map(id => client.getUser(id)));

// Use batch endpoint
await client.getUsersBatch(ids);
```

### ⚡ Cache GET Requests
**Impact:** Reduces API calls by 30-70%

Implement caching for GET requests with TTL:
```typescript
const cache = new Map();
async get(path: string) {
  if (cache.has(path)) return cache.get(path);
  const data = await fetch(path);
  cache.set(path, data);
  return data;
}
```

### ⚡ Use HTTP/2 Connection Pooling
**Impact:** Improves latency by 20-40%

Configure client to reuse connections:
```typescript
const client = axios.create({
  httpAgent: new http.Agent({ keepAlive: true }),
  httpsAgent: new https.Agent({ keepAlive: true })
});
```
```

---

## Key Takeaways

This example demonstrates:

1. **Decomposed Structure**: 3 examples + rules file (not all inline in SKILL.md)
2. **@references Syntax**: SKILL.md uses `@example:filename.md`, `@rules:best-practices.md`
3. **Multiple Scenarios**: basic (REST), advanced (GraphQL), edge-case (error-handling)
4. **Comprehensive Rules**: Best practices + pitfalls + performance tips
5. **Token Efficiency**: SKILL.md is concise (~50 lines), details are in referenced files

**Token Savings**: ~60% compared to monolithic structure (all content inline)
