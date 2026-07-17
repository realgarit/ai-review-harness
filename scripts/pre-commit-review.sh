#!/usr/bin/env bash
# scripts/pre-commit-review.sh
# Advisory AI review of the staged diff. Never blocks the commit.
# Reads AI_MODEL from env (default: claude); delegates to
# scripts/invoke-model.sh for provider dispatch.
set -euo pipefail

# Source repo-level config if it exists.
CONFIG_FILE="$(dirname "$0")/../.ai-review.conf"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

set -m # job control: gives process group isolation for timeout kills.
       # timeout can kill it AND any children it spawns, not just the
       # single top-level PID (see the kill -TERM/-KILL calls below).
       # Monitor mode can print "[1]+ Terminated" job-status noise to
       # stderr in an interactive shell, but that notification is tied
       # to the interactive prompt-display loop - verified empirically
       # in this non-interactive script context (bash script.sh, no
       # prompt loop) that killing the backgrounded job produces none.

PROMPT_FILE=""
# This script must never cause the commit itself to fail, no matter what
# goes wrong inside (a full /tmp, `git diff` erroring, a kill racing a
# process exit, anything under `set -e`). This trap is the single source
# of truth for that guarantee - it runs on every exit path, including an
# unhandled `set -e` early exit from any command below, and forces 0.
trap 'rm -f "${PROMPT_FILE:-}"; exit 0' EXIT

if [ -n "${SKIP_REVIEW:-}" ]; then
  echo "SKIP_REVIEW set, skipping AI review."
  exit 0
fi

DIFF=$(git diff --cached)
if [ -z "$DIFF" ]; then
  exit 0
fi

CHANGED_FILES=$(git diff --cached --name-only)
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

MODEL_PROVIDER="${AI_MODEL:-claude}"
# Quick pre-flight: skip if the chosen provider's CLI isn't installed.
# For API-based providers (openai, deepseek, moonshot, openai-compat), we
# rely on curl+jq being available and API keys being set — the dispatcher
# will fail with a clear error if auth is missing.
case "$MODEL_PROVIDER" in
  claude|codex)
    if ! command -v "${MODEL_PROVIDER}" > /dev/null 2>&1; then
      echo "${MODEL_PROVIDER} CLI not found, skipping pre-commit review."
      exit 0
    fi
    ;;
  openai|deepseek|moonshot|openai-compat)
    if ! command -v curl > /dev/null 2>&1 || ! command -v jq > /dev/null 2>&1; then
      echo "curl or jq not found, skipping pre-commit review."
      exit 0
    fi
    ;;
esac

echo "Running advisory AI review (model=$MODEL_PROVIDER, sensitive=$IS_SENSITIVE, $DIFF_LINES diff lines)..."
PROMPT="Review this staged diff for security issues (injection, authz, secrets) and code quality issues (correctness, simplification). Be concise. If none, say 'No findings.'

$DIFF"

REVIEW_TIMEOUT_SECS="${REVIEW_TIMEOUT_SECS:-120}"
PROMPT_FILE=$(mktemp)
printf '%s' "$PROMPT" > "$PROMPT_FILE"

MODEL_DISPATCHER="$(dirname "$0")/invoke-model.sh"
"$MODEL_DISPATCHER" < "$PROMPT_FILE" &
MODEL_PID=$!
sleep "$REVIEW_TIMEOUT_SECS" &
SLEEP_PID=$!

# Poll both directly (no subshell wrapping either process, so killing the
# PID we track kills the actual command, not an orphan-prone wrapper).
while kill -0 "$MODEL_PID" 2>/dev/null && kill -0 "$SLEEP_PID" 2>/dev/null; do
  sleep 0.2
done

if kill -0 "$MODEL_PID" 2>/dev/null; then
  # Negative PID = signal the whole process group `set -m` gave this
  # background job, not just the top-level PID - catches any child
  # processes the model dispatcher spawned too.
  kill -TERM -"$MODEL_PID" 2>/dev/null || true
  echo "(AI review timed out after ${REVIEW_TIMEOUT_SECS}s, killed - commit proceeds regardless)"
  # Give it a brief grace period to exit on SIGTERM, then force-kill the
  # group unconditionally - not gated on the leader PID still being
  # alive, since the leader can exit/get reaped while a grandchild it
  # spawned keeps running and ignores SIGTERM. Killing an already-dead
  # group is harmless (just returns nonzero, which is ignored).
  for _ in 1 2 3 4 5; do
    kill -0 "$MODEL_PID" 2>/dev/null || break
    sleep 0.2
  done
  # Theoretically the OS could recycle $MODEL_PID for an unrelated new
  # process-group leader in the moment between the last check above and
  # this line, making this SIGKILL hit the wrong process. Accepted risk
  # for a short-lived, single-invocation local hook (not a long-running
  # process manager) - PID reuse within a sub-second window is
  # vanishingly unlikely, and a conditional check here would reintroduce
  # the bug this unconditional call fixed (a grandchild outliving a
  # reaped leader).
  kill -KILL -"$MODEL_PID" 2>/dev/null || true
fi
kill "$SLEEP_PID" 2>/dev/null || true
wait "$MODEL_PID" 2>/dev/null || true
wait "$SLEEP_PID" 2>/dev/null || true

echo "(advisory only - commit proceeds regardless. Set SKIP_REVIEW=1 to skip.)"
exit 0
