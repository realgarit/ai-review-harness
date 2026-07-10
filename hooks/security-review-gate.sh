#!/usr/bin/env bash
# hooks/security-review-gate.sh
# PreToolUse hook (Edit|Write|MultiEdit). Blocks edits to sensitive files
# in this session until a security-reviewer subagent has run at least
# once (see mark-security-reviewed.sh). Reads hook JSON from stdin.
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Customize this per project - these patterns assume a Next.js + Prisma +
# Stripe stack. Add/remove patterns for your own sensitive-file shapes.
SENSITIVE_PATTERN='(prisma/schema\.prisma$|prisma/migrations/|(^|/)(auth|session|stripe)(/|[^/]*\.(ts|tsx|js)$)|middleware\.ts$|/api/.*webhook|/webhook|/api/.*\[[^/]+\])'

if ! echo "$FILE_PATH" | grep -qiE "$SENSITIVE_PATTERN"; then
  exit 0
fi

MARKER="/tmp/claude-security-reviewed-${SESSION_ID}"
if [ -f "$MARKER" ]; then
  exit 0
fi

REASON="$FILE_PATH looks security-sensitive. Run the security-reviewer subagent on this change first, then retry the edit."
jq -n --arg reason "$REASON" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
