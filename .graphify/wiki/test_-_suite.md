# test / suite

> 12 nodes · cohesion 0.18

## Key Concepts

- **iclaude.sh** (5 connections) — `iclaude.sh`
- **PII DNAT mock unit test suite (L1)** (4 connections) — `tests/test_pii_dnat_unit.sh`
- **PII DNAT test runner (L1+L2+L3)** (3 connections) — `tests/test_pii_dnat.sh`
- **iclaude Project** (2 connections) — `CLAUDE.md`
- **_pii_dnat_sweep_stale()** (2 connections) — `lib/sandbox/microvm.sh`
- **PII DNAT E2E L3 test suite** (2 connections) — `tests/test_pii_dnat_e2e.sh`
- **PII DNAT iptables L2 test suite** (2 connections) — `tests/test_pii_dnat_iptables.sh`
- **Claude Code CLI** (1 connections) — `CLAUDE.md`
- **_pii_dnat_preflight()** (1 connections) — `lib/sandbox/microvm.sh`
- **Phase 0 Regression Test Suite** (1 connections) — `tests/regression-phase0.sh`
- **CCR integration test suite** (1 connections) — `tests/test_ccr_integration.sh`
- **make_mocks()** (1 connections) — `tests/test_pii_dnat_unit.sh`

## Relationships

- No strong cross-community connections detected

## Source Files

- `CLAUDE.md`
- `iclaude.sh`
- `lib/sandbox/microvm.sh`
- `tests/regression-phase0.sh`
- `tests/test_ccr_integration.sh`
- `tests/test_pii_dnat.sh`
- `tests/test_pii_dnat_e2e.sh`
- `tests/test_pii_dnat_iptables.sh`
- `tests/test_pii_dnat_unit.sh`

## Audit Trail

- EXTRACTED: 23 (92%)
- INFERRED: 2 (8%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*