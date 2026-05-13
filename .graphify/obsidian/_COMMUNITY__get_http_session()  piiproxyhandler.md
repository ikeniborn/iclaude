---
type: community
cohesion: 0.11
members: 30
---

# _get_http_session() / piiproxyhandler

**Cohesion:** 0.11 - loosely connected
**Members:** 30 nodes

## Members
- [[._build_upstream_headers()]] - code - lib/pii-proxy/server.py
- [[._error_response()]] - code - lib/pii-proxy/server.py
- [[._forward()]] - code - lib/pii-proxy/server.py
- [[._health()]] - code - lib/pii-proxy/server.py
- [[._health_head()]] - code - lib/pii-proxy/server.py
- [[._metrics()]] - code - lib/pii-proxy/server.py
- [[._proxy_head()]] - code - lib/pii-proxy/server.py
- [[._proxy_messages()]] - code - lib/pii-proxy/server.py
- [[._proxy_passthrough()]] - code - lib/pii-proxy/server.py
- [[._read_body()]] - code - lib/pii-proxy/server.py
- [[.do_DELETE()]] - code - lib/pii-proxy/server.py
- [[.do_GET()]] - code - lib/pii-proxy/server.py
- [[.do_HEAD()]] - code - lib/pii-proxy/server.py
- [[.do_OPTIONS()]] - code - lib/pii-proxy/server.py
- [[.do_PATCH()]] - code - lib/pii-proxy/server.py
- [[.do_POST()]] - code - lib/pii-proxy/server.py
- [[.do_PUT()]] - code - lib/pii-proxy/server.py
- [[.log_message()]] - code - lib/pii-proxy/server.py
- [[Build request headers for upstream forwarding.          In API-key mode (ANTHROP]] - rationale - lib/pii-proxy/server.py
- [[Forward HEAD request and relay status + headers without body (RFC 7231 §4.3.2).]] - rationale - lib/pii-proxy/server.py
- [[Forward non-messages requests as-is.]] - rationale - lib/pii-proxy/server.py
- [[Forward request to upstream and stream response back.          Uses requests (no]] - rationale - lib/pii-proxy/server.py
- [[GET apimetrics — return live masking metrics for statusline integration.]] - rationale - lib/pii-proxy/server.py
- [[HEAD apihealth — return headers only, no body (RFC 7231 §4.3.2).]] - rationale - lib/pii-proxy/server.py
- [[HTTP request handler for PII-proxy.      Design asymmetric masking — only REQUE]] - rationale - lib/pii-proxy/server.py
- [[Intercept, mask PII, and forward v1messages.]] - rationale - lib/pii-proxy/server.py
- [[PIIProxyHandler]] - code - lib/pii-proxy/server.py
- [[Read request body with Content-Length validation.          Handles both Content-]] - rationale - lib/pii-proxy/server.py
- [[Return this thread's requests.Session, creating it on first access.]] - rationale - lib/pii-proxy/server.py
- [[_get_http_session()]] - code - lib/pii-proxy/server.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/_get_http_session_/_piiproxyhandler
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_cluster_3]]

## Top bridge nodes
- [[PIIProxyHandler]] - degree 20, connects to 1 community
- [[._proxy_messages()]] - degree 6, connects to 1 community
- [[_get_http_session()]] - degree 4, connects to 1 community