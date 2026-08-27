#!/usr/bin/env bash
# Regression tests for the default ChatGPT/Codex provider and its
# non-interactive stdin contract. Run from any working directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp "$ROOT/scripts/test-fixtures/fake-codex.sh" "$TMP/codex"
chmod +x "$TMP/codex"
if ! python3 -c 'pass' > /dev/null 2>&1; then
  cp "$(command -v python)" "$TMP/python3.exe"
fi
export PATH="$TMP:$PATH"
export CODEX_TEST_ARGS_FILE="$TMP/args"
export CODEX_TEST_STDIN_FILE="$TMP/stdin"

pass=0
fail=0

check_equal() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected: [$expected], got: [$actual])"
    fail=$((fail + 1))
  fi
}

check_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -Fq "$needle" "$file"; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (missing [$needle] in $file)"
    fail=$((fail + 1))
  fi
}

check_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -Fq "$needle" "$file"; then
    echo "FAIL: $desc (unexpected [$needle] in $file)"
    fail=$((fail + 1))
  else
    echo "PASS: $desc"
    pass=$((pass + 1))
  fi
}

run_codex() {
  local prompt="$1"
  : > "$CODEX_TEST_ARGS_FILE"
  : > "$CODEX_TEST_STDIN_FILE"
  printf '%s' "$prompt" | bash "$ROOT/scripts/invoke-model.sh"
}

unset AI_MODEL CLAUDE_CODE_OAUTH_TOKEN CODEX_API_KEY
set +e
default_output="$(run_codex 'default prompt')"
default_status=$?
set -e
check_equal "unset AI_MODEL invokes Codex successfully" "0" "$default_status"
check_equal "unset AI_MODEL uses Codex" "default prompt" "$default_output"
check_equal "default Codex invocation is read-only and ephemeral" \
  "exec --ephemeral --sandbox read-only -" "$(cat "$CODEX_TEST_ARGS_FILE")"

AI_MODEL=codex
export AI_MODEL
explicit_output="$(run_codex 'explicit prompt')"
check_equal "explicit codex provider accepts stdin" "explicit prompt" "$explicit_output"
check_equal "explicit Codex invocation matches the default" \
  "exec --ephemeral --sandbox read-only -" "$(cat "$CODEX_TEST_ARGS_FILE")"

unset AI_MODEL
pushd "$TMP" > /dev/null
printf '%s\n' 'diff --git a/example.txt b/example.txt' '++ test diff' > pr.diff
set +e
bash "$ROOT/scripts/run-ai-review.sh" > run-stdout 2> run-stderr
review_status=$?
set -e
popd > /dev/null
check_equal "run-ai-review uses the default Codex provider" "0" "$review_status"
check_contains "run-ai-review sends the rendered diff to Codex" \
  'test diff' "$TMP/ai-review.txt"

# A config-only provider selection must reach the child dispatcher. This
# mirrors a real repo-level .ai-review.conf without contacting a provider.
CONFIG_HARNESS="$TMP/config-harness"
mkdir -p "$CONFIG_HARNESS/scripts" "$CONFIG_HARNESS/prompts"
cp "$ROOT/scripts/run-ai-review.sh" "$CONFIG_HARNESS/scripts/run-ai-review.sh"
cp "$ROOT/prompts/review-prompt.md" "$CONFIG_HARNESS/prompts/review-prompt.md"
printf '%s\n' 'AI_MODEL=claude' 'OPENAI_MODEL=configured-model' > "$CONFIG_HARNESS/.ai-review.conf"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s|%s\n" "${AI_MODEL-unset}" "${OPENAI_MODEL-unset}" > "${CONFIG_TEST_ENV_FILE:?CONFIG_TEST_ENV_FILE is required}"' \
  'cat' > "$CONFIG_HARNESS/scripts/invoke-model.sh"
chmod +x "$CONFIG_HARNESS/scripts/invoke-model.sh"
export CONFIG_TEST_ENV_FILE="$TMP/config-env"
pushd "$CONFIG_HARNESS" > /dev/null
printf '%s\n' 'config diff' > pr.diff
set +e
bash scripts/run-ai-review.sh > run-stdout 2> run-stderr
config_status=$?
set -e
popd > /dev/null
check_equal "config-selected provider review succeeds" "0" "$config_status"
check_equal "config-selected provider reaches dispatcher" \
  "claude|configured-model" "$(cat "$CONFIG_TEST_ENV_FILE")"
check_contains "config-selected provider receives the rendered diff" \
  'config diff' "$CONFIG_HARNESS/ai-review.txt"

check_contains "dispatcher documents Codex as the default" \
  'AI_MODEL="${AI_MODEL:-codex}"' "$ROOT/scripts/invoke-model.sh"
check_contains "run-ai-review initializes the Codex default" \
  'AI_MODEL="${AI_MODEL:-codex}"' "$ROOT/scripts/run-ai-review.sh"
check_contains "pre-commit initializes the Codex default" \
  'MODEL_PROVIDER="$AI_MODEL"' "$ROOT/scripts/pre-commit-review.sh"
check_contains "GitHub workflow defaults to Codex" \
  "vars.AI_MODEL || 'codex'" "$ROOT/.github/workflows/ai-review.yml"
check_contains "GitHub resolves repo provider configuration" \
  'id: resolve_model' "$ROOT/.github/workflows/ai-review.yml"
check_contains "GitHub Codex path follows the resolved provider" \
  "steps.resolve_model.outputs.model == 'codex'" "$ROOT/.github/workflows/ai-review.yml"
check_contains "Gitea workflow defaults to Codex" \
  "vars.AI_MODEL || 'codex'" "$ROOT/.gitea/workflows/ai-review.yml"
check_contains "repo config documents Codex as the default" \
  '# AI_MODEL=codex' "$ROOT/.ai-review.conf"
check_contains "run-ai-review exports provider configuration" \
  'export AI_MODEL OPENAI_MODEL' "$ROOT/scripts/run-ai-review.sh"
check_contains "pre-commit exports provider configuration" \
  'export AI_MODEL OPENAI_MODEL' "$ROOT/scripts/pre-commit-review.sh"
check_contains "GitHub uses the pinned Codex Action" \
  'openai/codex-action@f367b1e9572fd064ea71ef925ca24ee0f01080af' \
  "$ROOT/.github/workflows/ai-review.yml"
check_contains "GitHub uses Codex read-only permissions" \
  'permission-profile: ":read-only"' "$ROOT/.github/workflows/ai-review.yml"
check_contains "GitHub disables checkout credential persistence" \
  'persist-credentials: false' "$ROOT/.github/workflows/ai-review.yml"
check_contains "GitHub pins the Codex CLI version" \
  'codex-version: "0.150.0-alpha.8"' "$ROOT/.github/workflows/ai-review.yml"
check_contains "GitHub uses ephemeral Codex sessions" \
  '"--ephemeral"' "$ROOT/.github/workflows/ai-review.yml"
check_not_contains "GitHub does not expose CODEX_API_KEY to checkout scripts" \
  'CODEX_API_KEY: ${{' "$ROOT/.github/workflows/ai-review.yml"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
