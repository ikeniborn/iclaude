---
source_file: "lib/pii-proxy/server.py"
type: "rationale"
community: "_get_http_session() / piiproxyhandler"
location: "L768"
tags:
  - graphify/rationale
  - graphify/EXTRACTED
  - community/_get_http_session_/_piiproxyhandler
---

# HEAD /api/health — return headers only, no body (RFC 7231 §4.3.2).

## Connections
- [[._health_head()]] - `rationale_for` [EXTRACTED]

#graphify/rationale #graphify/EXTRACTED #community/_get_http_session_/_piiproxyhandler