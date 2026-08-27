#!/usr/bin/env bash
set -euo pipefail

printf '%s' "$*" > "${CODEX_TEST_ARGS_FILE:?CODEX_TEST_ARGS_FILE is required}"
cat > "${CODEX_TEST_STDIN_FILE:?CODEX_TEST_STDIN_FILE is required}"
cat "${CODEX_TEST_STDIN_FILE}"
