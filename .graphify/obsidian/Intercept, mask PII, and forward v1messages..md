---
source_file: "lib/pii-proxy/server.py"
type: "rationale"
community: "_get_http_session() / piiproxyhandler"
location: "L842"
tags:
  - graphify/rationale
  - graphify/EXTRACTED
  - community/_get_http_session_/_piiproxyhandler
---

# Intercept, mask PII, and forward /v1/messages.

## Connections
- [[._proxy_messages()]] - `rationale_for` [EXTRACTED]

#graphify/rationale #graphify/EXTRACTED #community/_get_http_session_/_piiproxyhandler