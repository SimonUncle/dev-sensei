#!/bin/bash
# test-ship-gate.sh
# Automated tests for hooks/ship-gate.sh
#
# Usage: bash tests/test-ship-gate.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHIP_GATE="$SCRIPT_DIR/../hooks/ship-gate.sh"

PASS=0
FAIL=0

assert_exit() {
  local test_name="$1"
  local expected_exit="$2"
  local actual_exit="$3"

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  PASS: $test_name (exit $actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected exit $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "================================"
echo " ship-gate.sh Test Suite"
echo "================================"
echo ""

# --------------------------------------------------
# Test 1: All empty answers -> exit 1
# --------------------------------------------------
echo "[Test 1] All empty answers should be rejected"
printf '\n\n\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "all empty answers" 1 $?

# --------------------------------------------------
# Test 2: All valid answers -> exit 0
# --------------------------------------------------
echo "[Test 2] All valid answers should be accepted"
printf 'chose simplicity\nno error handling\nprobably not\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "all valid answers" 0 $?

# --------------------------------------------------
# Test 3: Only first answer provided -> exit 1
# --------------------------------------------------
echo "[Test 3] Only first answer (others empty) should be rejected"
printf 'chose simplicity\n\n\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "only first answer" 1 $?

# --------------------------------------------------
# Test 4: Only second answer provided -> exit 1
# --------------------------------------------------
echo "[Test 4] Only second answer (others empty) should be rejected"
printf '\nno error handling\n\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "only second answer" 1 $?

# --------------------------------------------------
# Test 5: Only third answer provided -> exit 1
# --------------------------------------------------
echo "[Test 5] Only third answer (others empty) should be rejected"
printf '\n\nprobably not\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "only third answer" 1 $?

# --------------------------------------------------
# Test 6: First two answers provided, third empty -> exit 1
# --------------------------------------------------
echo "[Test 6] Two answers (third empty) should be rejected"
printf 'chose simplicity\nno error handling\n\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "first two answers only" 1 $?

# --------------------------------------------------
# Test 7: First and third provided, second empty -> exit 1
# --------------------------------------------------
echo "[Test 7] First and third (second empty) should be rejected"
printf 'chose simplicity\n\nprobably not\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "first and third only" 1 $?

# --------------------------------------------------
# Test 8: Valid answers with spaces -> exit 0
# --------------------------------------------------
echo "[Test 8] Valid answers with extra spaces should be accepted"
printf 'it was the simplest path\ncould fail on edge cases\nneeds horizontal scaling\n' | bash "$SHIP_GATE" > /dev/null 2>&1
assert_exit "valid answers with spaces" 0 $?

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo ""
echo "================================"
echo " Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
