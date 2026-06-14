#!/bin/bash
# Smoke test for receipton (Foundry/bash port, v2.0.0).
# Verifies the CLI parses, help text works offline, and error paths are clear.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$SKILL_DIR/scripts/receipt.sh"

PASS=0
FAIL=0

run() {
  local name="$1"
  local expected="$2"
  shift 2
  local out
  out=$(bash "$SCRIPT" "$@" 2>&1 || true)
  if echo "$out" | grep -qF -- "$expected"; then
    echo "  OK: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "       expected substring: $expected"
    echo "       actual: $(echo "$out" | head -3)"
    FAIL=$((FAIL + 1))
  fi
}

echo "Test 1: --help works (no cast required)"
run "help text present" "Usage:" --help

echo "Test 2: no args shows usage"
run "no-args shows usage" "Usage:"

echo "Test 3: unknown flag rejected"
run "unknown flag rejected" "Unknown flag" --foo

echo "Test 4: bad format rejected"
run "bad format rejected" "Invalid format" \
  0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7 --format xml

echo "Test 5: bad template rejected"
run "bad template rejected" "Invalid template" \
  0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7 --template bogus

echo "Test 6: bad network rejected"
run "bad network rejected" "Unknown network" \
  0x9606bcfd027b28e6783ca8b5fef1c3311476a1c30e5bf4464d0340a0d24ba7f7 --network foo

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" = "0" ] || exit 1
