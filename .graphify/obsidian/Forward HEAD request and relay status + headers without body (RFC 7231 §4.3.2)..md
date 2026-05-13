---
source_file: "lib/pii-proxy/server.py"
type: "rationale"
community: "_get_http_session() / piiproxyhandler"
location: "L883"
tags:
  - graphify/rationale
  - graphify/EXTRACTED
  - community/_get_http_session_/_piiproxyhandler
---

# Forward HEAD request and relay status + headers without body (RFC 7231 §4.3.2).

## Connections
- [[._proxy_head()]] - `rationale_for` [EXTRACTED]

#graphify/rationale #graphify/EXTRACTED #community/_get_http_session_/_piiproxyhandler