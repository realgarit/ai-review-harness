#!/usr/bin/env bash
# scripts/test-security-review-gate.sh
# Sanity-checks hooks/security-review-gate.sh in isolation (no Claude Code
# session needed). Run from the repo root.
set -euo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/security-review-gate.sh"
SESSION="test-session-$$"
MARKER="/tmp/claude-security-reviewed-${SESSION}"
rm -f "$MARKER"

pass=0
fail=0

check() {
  local desc="$1" expect_deny="$2" output="$3"
  if [ "$expect_deny" = "true" ]; then
    if echo "$output" | grep -q '"permissionDecision": *"deny"'; then
      echo "PASS: $desc"; pass=$((pass+1))
    else
      echo "FAIL: $desc (expected deny, got: $output)"; fail=$((fail+1))
    fi
  else
    if [ -z "$output" ]; then
      echo "PASS: $desc"; pass=$((pass+1))
    else
      echo "FAIL: $desc (expected no output/allow, got: $output)"; fail=$((fail+1))
    fi
  fi
}

# 1. Non-sensitive file -> allowed (no output)
out=$(echo "{\"session_id\": \"$SESSION\", \"tool_input\": {\"file_path\": \"src/foo.ts\"}}" | bash "$HOOK")
check "non-sensitive file allowed" false "$out"

# 2. Sensitive file, no marker -> denied
out=$(echo "{\"session_id\": \"$SESSION\", \"tool_input\": {\"file_path\": \"src/lib/auth.ts\"}}" | bash "$HOOK")
check "sensitive file denied without review marker" true "$out"

# 3. Sensitive file, with marker -> allowed
touch "$MARKER"
out=$(echo "{\"session_id\": \"$SESSION\", \"tool_input\": {\"file_path\": \"src/lib/auth.ts\"}}" | bash "$HOOK")
check "sensitive file allowed with review marker" false "$out"
rm -f "$MARKER"

# 4. Dynamic tenant route -> denied
out=$(echo "{\"session_id\": \"$SESSION\", \"tool_input\": {\"file_path\": \"src/app/api/[orgId]/route.ts\"}}" | bash "$HOOK")
check "dynamic api route denied without review marker" true "$out"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
