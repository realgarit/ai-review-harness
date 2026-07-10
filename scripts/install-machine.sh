#!/usr/bin/env bash
# scripts/install-machine.sh
# One-time setup for Layer 2 on a machine (not per-repo). Copies the hook
# scripts to ~/.claude/hooks/ and merges the PreToolUse/PostToolUse
# entries into ~/.claude/settings.json without touching anything else
# already configured there.
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR/hooks"

cp "$HARNESS_DIR/hooks/security-review-gate.sh" "$CLAUDE_DIR/hooks/security-review-gate.sh"
cp "$HARNESS_DIR/hooks/mark-security-reviewed.sh" "$CLAUDE_DIR/hooks/mark-security-reviewed.sh"
chmod +x "$CLAUDE_DIR/hooks/security-review-gate.sh" "$CLAUDE_DIR/hooks/mark-security-reviewed.sh"

python3 "$HARNESS_DIR/scripts/merge-settings.py" "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/hooks"

echo "Layer 2 installed. Verify with:"
echo "  scripts/test-security-review-gate.sh"
echo "  scripts/test-mark-security-reviewed.sh"
