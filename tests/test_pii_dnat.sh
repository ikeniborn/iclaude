#!/usr/bin/env bash
# Test runner for PII proxy + microVM DNAT hardening.
# Invokes three test layers: mock unit (L1), real iptables (L2), full E2E (L3).
# Each layer self-gates and skips when prerequisites are missing.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
bash "$DIR/test_pii_dnat_unit.sh"      || fail=1
bash "$DIR/test_pii_dnat_iptables.sh"  || fail=1
bash "$DIR/test_pii_dnat_e2e.sh"       || fail=1
exit "$fail"
