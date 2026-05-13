# anthropic_base_url

> 36 nodes · cohesion 0.07

## Key Concepts

- **microVM unit test suite** (14 connections) — `tests/test_microvm.sh`
- **microVM dual-session integration test** (6 connections) — `tests/test-microvm-dual.sh`
- **PII proxy integration test suite (bash fns)** (6 connections) — `tests/test-pii-integration.sh`
- **init_environment()** (5 connections) — `lib/core/init.sh`
- **_free_microvm_slot()** (5 connections) — `lib/sandbox/microvm.sh`
- **_alloc_microvm_slot()** (4 connections) — `lib/sandbox/microvm.sh`
- **microVM workspace isolation mode test suite** (4 connections) — `tests/test_microvm_workspace.sh`
- **ICLAUDE_PII_ACTIVE env var** (3 connections) — `lib/core/init.sh`
- **start_pii_proxy_server()** (3 connections) — `lib/launcher/launch.sh`
- **_claim_microvm_slot()** (3 connections) — `lib/sandbox/microvm.sh`
- **configure_guest_environment()** (3 connections) — `lib/sandbox/microvm.sh`
- **pii-proxy-server.py** (3 connections) — `.nvm-isolated/.claude-isolated/pii-proxy-server.py`
- **_start_one_vm()** (3 connections) — `tests/test-microvm-dual.sh`
- **microVM integration test suite (CLI flags)** (3 connections) — `tests/test_microvm_integration.sh`
- **PII proxy parallel sessions + security test suite** (3 connections) — `tests/test-pii-parallel.sh`
- **ANTHROPIC_BASE_URL env var** (2 connections) — `lib/core/init.sh`
- **_stop_one_vm()** (2 connections) — `tests/test-microvm-dual.sh`
- **PII shared proxy setsid detach test suite** (2 connections) — `tests/test_pii_shared_detach.sh`
- **MICRO_VM_ENABLED env var** (1 connections) — `lib/core/init.sh`
- **MICRO_VM_NET_SUBNET env var** (1 connections) — `lib/core/init.sh`
- **cleanup_orphaned_pii_proxies()** (1 connections) — `lib/launcher/launch.sh`
- **stop_pii_proxy_server()** (1 connections) — `lib/launcher/launch.sh`
- **detect_pii_proxy()** (1 connections) — `lib/pii-proxy/detect.sh`
- **detect_virtiofsd()** (1 connections) — `lib/sandbox/detect.sh`
- **build_microvm_config()** (1 connections) — `lib/sandbox/microvm.sh`
- *... and 11 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `.nvm-isolated/.claude-isolated/pii-proxy-server.py`
- `lib/core/init.sh`
- `lib/launcher/launch.sh`
- `lib/pii-proxy/detect.sh`
- `lib/sandbox/detect.sh`
- `lib/sandbox/microvm.sh`
- `tests/test-microvm-dual.sh`
- `tests/test-pii-integration.sh`
- `tests/test-pii-parallel.sh`
- `tests/test_microvm.sh`
- `tests/test_microvm_integration.sh`
- `tests/test_microvm_workspace.sh`
- `tests/test_pii_shared_detach.sh`

## Audit Trail

- EXTRACTED: 88 (96%)
- INFERRED: 4 (4%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*