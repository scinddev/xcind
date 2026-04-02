#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install dev tools required by `make check` (lint + test)
missing=()
command -v shfmt >/dev/null 2>&1 || missing+=(shfmt)
command -v shellcheck >/dev/null 2>&1 || missing+=(shellcheck)

if [ ${#missing[@]} -gt 0 ]; then
  apt-get update -qq
  apt-get install -y -qq "${missing[@]}" >/dev/null 2>&1
fi
