# Security Rules

## SQL Injection

**Pattern:**
```python
# BAD
query = f"SELECT * FROM users WHERE id = {user_id}"
cursor.execute(query)

# GOOD
query = "SELECT * FROM users WHERE id = %s"
cursor.execute(query, (user_id,))
```

## Command Injection

**Pattern:**
```python
# BAD
os.system(f"ls {user_input}")
subprocess.call(user_input, shell=True)

# GOOD
subprocess.run(["ls", user_input], shell=False)
```

## Hardcoded Secrets

**Detect:**
```
- API_KEY = "..."
- password = "..."
- secret = "..."
- token = "sk-..."
```

**Fix:** Use environment variables

## XSS (JavaScript/HTML)

**Pattern:**
```javascript
// BAD
element.innerHTML = userInput;

// GOOD
element.textContent = userInput;
// or sanitize with DOMPurify
```

## Path Traversal

**Pattern:**
```python
# BAD
file_path = f"/uploads/{filename}"
open(file_path)

# GOOD
safe_path = os.path.join("/uploads", os.path.basename(filename))
```
