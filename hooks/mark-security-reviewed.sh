#!/usr/bin/env bash
# hooks/mark-security-reviewed.sh
# PostToolUse hook (Task). Marks this session as having run a
# security-reviewer subagent, unblocking security-review-gate.sh.
set -euo pipefail

INPUT=$(cat)
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [ "$SUBAGENT_TYPE" = "security-reviewer" ]; then
  touch "/tmp/claude-security-reviewed-${SESSION_ID}"
fi
