# Placeholder to JSON Schema Mapping Rules

## Supported Placeholder Formats

| Placeholder | JSON Schema | Example |
|-------------|-------------|---------|
| `{{name: string}}` | `{"type": "string"}` | `"name": "value"` |
| `{{name: string, min N chars}}` | `{"type": "string", "minLength": N}` | `"name": "abc"` |
| `{{name: string, max N chars}}` | `{"type": "string", "maxLength": N}` | `"name": "ab"` |
| `{{name: integer}}` | `{"type": "integer"}` | `"count": 42` |
| `{{name: integer, min N}}` | `{"type": "integer", "minimum": N}` | `"count": 10` |
| `{{name: integer, max N}}` | `{"type": "integer", "maximum": N}` | `"count": 100` |
| `{{name: enum: val1\|val2}}` | `{"type": "string", "enum": ["val1", "val2"]}` | `"type": "val1"` |
| `{{optional: type}}` | `{"type": "type"}` (not in required array) | `"optional_field": null` |
| `{{name: pattern: /regex/}}` | `{"type": "string", "pattern": "regex"}` | `"name": "abc-123"` |
| `{{name: boolean}}` | `{"type": "boolean"}` | `"enabled": true` |
| `{{name: number}}` | `{"type": "number"}` | `"price": 19.99` |
| `{{name: array}}` | `{"type": "array"}` | `"items": []` |

## Parsing Algorithm

1. Extract all `{{...}}` from template using regex `/\{\{([^}]+)\}\}/g`
2. Parse format: `name: type[, constraint]*`
3. Map type to JSON Schema type
4. Map constraints to JSON Schema properties
5. Detect optional fields (prefix `optional:` or suffix `?`)
6. Build required array (non-optional fields)
7. Generate JSON Schema Draft-7

## Constraint Mapping

### String Constraints

- `min N chars` → `"minLength": N`
- `max N chars` → `"maxLength": N`
- `pattern: /regex/` → `"pattern": "regex"` (without slashes)
- `kebab-case` → `"pattern": "^[a-z][a-z0-9-]*$"`

### Integer/Number Constraints

- `min N` → `"minimum": N`
- `max N` → `"maximum": N`

### Enum Constraints

- `enum: val1|val2|val3` → `"enum": ["val1", "val2", "val3"]`

### Boolean Constraints

- `default: true` → `"default": true`
- `default: false` → `"default": false`

### Array Constraints

- `min N items` → `"minItems": N`
- `max N items` → `"maxItems": N`

## Example

### Template:
```json
{
  "input": {
    "name": "{{name: string, min 3 chars}}",
    "type": "{{type: enum: system|user-invocable}}",
    "count": "{{count: integer, min 1}}",
    "optional_field": "{{optional: string}}"
  }
}
```

### Generated Schema:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "input": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string",
          "minLength": 3
        },
        "type": {
          "type": "string",
          "enum": ["system", "user-invocable"]
        },
        "count": {
          "type": "integer",
          "minimum": 1
        },
        "optional_field": {
          "type": "string"
        }
      },
      "required": ["name", "type", "count"]
    }
  },
  "required": ["input"]
}
```

## Special Cases

### Nested Objects

Placeholders in nested objects are processed recursively:

```json
{
  "nested": {
    "field": "{{field: string}}"
  }
}
```

→

```json
{
  "properties": {
    "nested": {
      "type": "object",
      "properties": {
        "field": {"type": "string"}
      },
      "required": ["field"]
    }
  }
}
```

### Arrays

Arrays with placeholder items:

```json
{
  "items": ["{{item: string}}"]
}
```

→

```json
{
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "type": "string"
      }
    }
  }
}
```

### Optional Fields

Fields with `optional:` prefix are NOT added to required array:

```json
{
  "required_field": "{{field: string}}",
  "optional_field": "{{optional: string}}"
}
```

→

```json
{
  "properties": {
    "required_field": {"type": "string"},
    "optional_field": {"type": "string"}
  },
  "required": ["required_field"]
}
```

## Validation Rules

1. **Placeholder format must be valid** - matches regex `/^{{([a-z_][a-z0-9_]*: .+)}}$/i`
2. **Type must be recognized** - one of: string, integer, number, boolean, array, object, enum
3. **Constraints must match type** - e.g., minLength only for string
4. **Enum values must be separated by |** - e.g., `enum: val1|val2|val3`
5. **Pattern must not include slashes** - e.g., `pattern: /abc/` → store as `"abc"`

## Error Handling

If placeholder parsing fails:
- E005: Invalid placeholder format → Show error with placeholder text
- Auto-fix: Remove invalid placeholders and warn user
- Fallback: Generate schema without that field (mark as warning)
