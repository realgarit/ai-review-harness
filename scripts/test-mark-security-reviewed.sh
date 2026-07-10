#!/usr/bin/env bash
# scripts/test-mark-security-reviewed.sh
set -euo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/mark-security-reviewed.sh"
SESSION="test-session-$$"
MARKER="/tmp/claude-security-reviewed-${SESSION}"
rm -f "$MARKER"

pass=0
fail=0

# 1. Non-security subagent -> no marker
echo "{\"session_id\": \"$SESSION\", \"tool_input\": {\"subagent_type\": \"general-purpose\"}}" | bash "$HOOK"
if [ ! -f "$MARKER" ]; then
  echo "PASS: general-purpose subagent doesn't mark reviewed"; pass=$((pass+1))
else
  echo "FAIL: general-purpose subagent incorrectly marked reviewed"; fail=$((fail+1))
fi

# 2. security-reviewer subagent -> marker created
echo "{\"session_id\": \"$SESSION\", \"tool_input\": {\"subagent_type\": \"security-reviewer\"}}" | bash "$HOOK"
if [ -f "$MARKER" ]; then
  echo "PASS: security-reviewer subagent marks reviewed"; pass=$((pass+1))
else
  echo "FAIL: security-reviewer subagent did not mark reviewed"; fail=$((fail+1))
fi
rm -f "$MARKER"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
