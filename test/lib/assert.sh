#!/usr/bin/env bash
# test/lib/assert.sh — Shared assertion helpers for xcind test suites.
#
# Source from each test runner; updates PASS/FAIL in the caller's shell.

# Counters live in the caller. Initialize them before sourcing.
: "${PASS:=0}"
: "${FAIL:=0}"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ $haystack == *"$needle"* ]]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected to contain: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ $haystack != *"$needle"* ]]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected NOT to contain: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (file not found: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_missing() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (file exists: $path)"
    FAIL=$((FAIL + 1))
  fi
}

# Capture exit status of a command without triggering set -e.
# Usage: status=$(capture_status cmd args...)
capture_status() {
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}
