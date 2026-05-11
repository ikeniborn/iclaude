# PII DNAT Hardening Design

> 50 nodes · cohesion 0.05

## Key Concepts

- **PII Proxy + microVM DNAT Hardening Design** (13 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **iclaude** (13 connections) — `README.md`
- **microVM Sandbox (Firecracker v2)** (11 connections) — `docs/functions/MICROVM.md`
- **lib/graphify/ module** (5 connections) — `docs/functions/GRAPHIFY.md`
- **graphify issue #777 (absolute paths break portability)** (5 connections) — `docs/functions/UPSTREAM_ISSUE.md`
- **tests/test_pii_dnat.sh runner** (4 connections) — `docs/superpowers/plans/2026-05-08-pii-microvm-dnat-hardening.md`
- **_pii_dnat_sweep_stale()** (3 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **L3 full E2E test (KVM + sudo + firecracker)** (3 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **Graphify portability patches (4 patches)** (3 connections) — `docs/functions/GRAPHIFY.md`
- **PII DNAT troubleshooting (MICROVM.md)** (3 connections) — `docs/functions/MICROVM.md`
- **PII Proxy + microVM DNAT Hardening Plan** (3 connections) — `docs/superpowers/plans/2026-05-08-pii-microvm-dnat-hardening.md`
- **Upstream Issue / PR Tracker** (3 connections) — `docs/functions/UPSTREAM_ISSUE.md`
- **normalize-paths.py hook** (3 connections) — `docs/functions/UPSTREAM_ISSUE.md`
- **iptables comment marker (iclaude-pii-dnat:<tap>)** (2 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **_pii_dnat_preflight()** (2 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **P1: Silent failure when passwordless sudo unavailable** (2 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **P2: Stale iptables rules after crash** (2 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **L1 mock unit tests** (2 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **L2 real iptables tests on dummy iface** (2 connections) — `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`
- **lib/graphify/apply_patches.sh** (2 connections) — `docs/functions/GRAPHIFY.md`
- **Graphify integration** (2 connections) — `docs/functions/GRAPHIFY.md`
- **lib/graphify/install.sh** (2 connections) — `docs/functions/GRAPHIFY.md`
- **start_microvm()** (2 connections) — `docs/functions/MICROVM.md`
- **E2E debug flags (--e2e-exit-after-boot, --e2e-kill-after-boot)** (2 connections) — `docs/superpowers/plans/2026-05-08-pii-microvm-dnat-hardening.md`
- **Graphify knowledge graph** (2 connections) — `README.md`
- *... and 25 more nodes in this community*

## Relationships

- [[Skills & Architecture Docs]] (2 shared connections)
- [[Community 70]] (1 shared connections)

## Source Files

- `README.md`
- `docs/functions/GRAPHIFY.md`
- `docs/functions/MICROVM.md`
- `docs/functions/UPSTREAM_ISSUE.md`
- `docs/superpowers/plans/2026-05-08-pii-microvm-dnat-hardening.md`
- `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`

## Audit Trail

- EXTRACTED: 112 (90%)
- INFERRED: 13 (10%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*