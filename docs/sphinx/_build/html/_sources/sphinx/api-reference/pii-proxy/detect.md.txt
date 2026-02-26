# detect

> **Module:** `pii-proxy` | **File:** `lib/pii-proxy/detect.sh`

PII-Proxy detection module
Provides functions for detecting PII-proxy installation

---

## `detect_pii_proxy`

Detect if PII-proxy is available Checks Python 3.8+ and server script existence

**Arguments:**

- `  $1 - skip_isolated (optional): "true" to skip isolated environment`

**Returns:**

-   0 - PII-proxy available
-   1 - not available

## `get_pii_proxy_python`

Get PII-proxy Python interpreter path

**Returns:**

-   path to python3 in venv, or empty string

