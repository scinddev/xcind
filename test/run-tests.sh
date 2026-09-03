#!/usr/bin/env bash
# test/run-tests.sh — Run every test file in parallel.
#
# Each file runs as its own background process with output buffered to a
# per-file log, so parallel runs never interleave. Logs replay in the
# fixed order below once each file finishes. Exits non-zero when any
# file failed. Bash 3.2 compatible (no wait -n, no associative arrays).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEST_FILES=(
  test-xcind.sh
  test-xcind-proxy.sh
  test-xcind-prompt.sh
  test-xcind-completion.sh
)

LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

pids=()
i=0
for f in "${TEST_FILES[@]}"; do
  bash "$SCRIPT_DIR/$f" >"$LOG_DIR/$i.log" 2>&1 &
  pids[i]=$!
  i=$((i + 1))
done

overall=0
failed=""
i=0
for f in "${TEST_FILES[@]}"; do
  rc=0
  wait "${pids[i]}" || rc=$?
  echo "##### $f (exit $rc) #####"
  cat "$LOG_DIR/$i.log"
  echo ""
  if [ "$rc" -ne 0 ]; then
    overall=1
    failed="$failed $f"
  fi
  i=$((i + 1))
done

if [ "$overall" -ne 0 ]; then
  echo "FAILED:$failed" >&2
fi
exit "$overall"
