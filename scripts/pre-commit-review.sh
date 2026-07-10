#!/usr/bin/env bash
# scripts/pre-commit-review.sh
# Advisory AI review of the staged diff. Never blocks the commit.
set -euo pipefail
set -m # job control: gives claude -p its own process group, so a
       # timeout can kill it AND any children it spawns, not just the
       # single top-level PID (see the kill -TERM/-KILL calls below).

if [ -n "${SKIP_REVIEW:-}" ]; then
  echo "SKIP_REVIEW set, skipping AI review."
  exit 0
fi

DIFF=$(git diff --cached)
if [ -z "$DIFF" ]; then
  exit 0
fi

CHANGED_FILES=$(git diff --cached --name-only)
# Customize this per project - these patterns assume a Next.js + Prisma +
# Stripe stack. Add/remove patterns for your own sensitive-file shapes.
SENSITIVE_PATTERN='(prisma/schema\.prisma$|prisma/migrations/|(^|/)(auth|session|stripe)(/|[^/]*\.(ts|tsx|js)$)|middleware\.ts$|/api/.*webhook|/webhook|/api/.*\[[^/]+\])'
DIFF_LINES=$(echo "$DIFF" | wc -l | tr -d ' ')
SIZE_THRESHOLD=400

IS_SENSITIVE=false
if echo "$CHANGED_FILES" | grep -qiE "$SENSITIVE_PATTERN"; then
  IS_SENSITIVE=true
fi

if [ "$IS_SENSITIVE" = false ] && [ "$DIFF_LINES" -lt "$SIZE_THRESHOLD" ]; then
  exit 0
fi

if ! command -v claude > /dev/null 2>&1; then
  echo "claude CLI not found, skipping pre-commit review."
  exit 0
fi

echo "Running advisory AI review (sensitive=$IS_SENSITIVE, $DIFF_LINES diff lines)..."
PROMPT="Review this staged diff for security issues (injection, authz, secrets) and code quality issues (correctness, simplification). Be concise. If none, say 'No findings.'

$DIFF"

REVIEW_TIMEOUT_SECS="${REVIEW_TIMEOUT_SECS:-120}"
PROMPT_FILE=$(mktemp)
trap 'rm -f "$PROMPT_FILE"' EXIT
printf '%s' "$PROMPT" > "$PROMPT_FILE"

claude -p --output-format text < "$PROMPT_FILE" &
CLAUDE_PID=$!
sleep "$REVIEW_TIMEOUT_SECS" &
SLEEP_PID=$!

# Poll both directly (no subshell wrapping either process, so killing the
# PID we track kills the actual command, not an orphan-prone wrapper).
while kill -0 "$CLAUDE_PID" 2>/dev/null && kill -0 "$SLEEP_PID" 2>/dev/null; do
  sleep 0.2
done

if kill -0 "$CLAUDE_PID" 2>/dev/null; then
  # Negative PID = signal the whole process group `set -m` gave this
  # background job, not just the top-level PID - catches any child
  # processes claude -p spawned too.
  kill -TERM -"$CLAUDE_PID" 2>/dev/null
  echo "(claude -p timed out after ${REVIEW_TIMEOUT_SECS}s, killed - commit proceeds regardless)"
  # Give it a brief grace period to exit on SIGTERM, then force it - a
  # process that ignores or is slow to handle SIGTERM would otherwise
  # make the unconditional `wait` below block indefinitely, defeating
  # the whole point of the timeout (the commit must never hang).
  for _ in 1 2 3 4 5; do
    kill -0 "$CLAUDE_PID" 2>/dev/null || break
    sleep 0.2
  done
  kill -0 "$CLAUDE_PID" 2>/dev/null && kill -KILL -"$CLAUDE_PID" 2>/dev/null
fi
kill "$SLEEP_PID" 2>/dev/null || true
wait "$CLAUDE_PID" 2>/dev/null || true
wait "$SLEEP_PID" 2>/dev/null || true

echo "(advisory only - commit proceeds regardless. Set SKIP_REVIEW=1 to skip.)"
exit 0
