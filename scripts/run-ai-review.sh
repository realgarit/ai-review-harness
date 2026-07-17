#!/usr/bin/env bash
# scripts/run-ai-review.sh
# Renders prompts/review-prompt.md against pr.diff and runs it through the
# AI model, writing ai-review.txt. Requires pr.diff (see compute-diff.sh).
#
# Set AI_MODEL to choose the provider (default: claude). Each provider
# needs its own auth env var — see scripts/invoke-model.sh for the full
# list. This script is model-agnostic; invoke-model.sh handles dispatch.
set -euo pipefail

# Source repo-level config if it exists (allows overriding AI_MODEL and
# model-specific settings without touching the scripts).
CONFIG_FILE="$(dirname "$0")/../.ai-review.conf"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

PROMPT_TEMPLATE="$(dirname "$0")/../prompts/review-prompt.md"
python3 - "$PROMPT_TEMPLATE" << 'PYEOF'
import sys
diff = open("pr.diff").read()
template = open(sys.argv[1]).read()
open("prompt.txt", "w").write(template.replace("{{DIFF}}", diff))
PYEOF

MODEL_DISPATCHER="$(dirname "$0")/invoke-model.sh"

set +e
"$MODEL_DISPATCHER" < prompt.txt > ai-review.txt 2> ai-review-stderr.txt
MODEL_EXIT=$?
set -e

echo "invoke-model ($AI_MODEL) exited with code $MODEL_EXIT"
if [ -s ai-review-stderr.txt ]; then
  echo "--- model stderr ---"
  cat ai-review-stderr.txt
fi
test -s ai-review.txt || echo "AI review step failed to produce output (exit $MODEL_EXIT). See job log for stderr." > ai-review.txt
