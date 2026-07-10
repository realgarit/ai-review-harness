#!/usr/bin/env bash
# scripts/run-ai-review.sh
# Renders prompts/review-prompt.md against pr.diff and runs it through the
# model CLI, writing ai-review.txt. Requires pr.diff (see compute-diff.sh)
# and CLAUDE_CODE_OAUTH_TOKEN in the environment.
#
# This is the one place a different model/CLI gets swapped in later - the
# rest of the harness (diff computation, Semgrep, comment formatting,
# posting) doesn't know or care which model produced ai-review.txt.
set -euo pipefail

PROMPT_TEMPLATE="$(dirname "$0")/../prompts/review-prompt.md"
python3 - "$PROMPT_TEMPLATE" << 'PYEOF'
import sys
diff = open("pr.diff").read()
template = open(sys.argv[1]).read()
open("prompt.txt", "w").write(template.replace("{{DIFF}}", diff))
PYEOF

set +e
claude -p --output-format text < prompt.txt > ai-review.txt 2> ai-review-stderr.txt
CLAUDE_EXIT=$?
set -e

echo "claude -p exited with code $CLAUDE_EXIT"
if [ -s ai-review-stderr.txt ]; then
  echo "--- claude stderr ---"
  cat ai-review-stderr.txt
fi
test -s ai-review.txt || echo "AI review step failed to produce output (exit $CLAUDE_EXIT). See job log for stderr." > ai-review.txt
