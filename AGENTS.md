# ai-review-harness — Agent instructions

> Canonical instructions for all coding agents (Claude Code, Codex, GitHub Copilot). Claude loads this via the CLAUDE.md stub.

Enforced AI + static-analysis code review, in three layers: a CI review
(Semgrep scan plus an AI review posted as a PR comment, on GitHub Actions
or Gitea Actions), a local Claude Code `PreToolUse` hook that blocks
edits to security-sensitive files until a security-reviewer subagent has
run that session, and an advisory `lefthook` pre-commit hook that runs an
AI review of the staged diff. `scripts/run-ai-review.sh` is the one place
that invokes a model CLI (`claude -p` today); everything else (diff
computation, Semgrep, comment formatting, posting) is model-agnostic.

- Language/stack: shell scripts (`scripts/`, `hooks/`) and Python
  (`scripts/format-review-comment.py`, `scripts/merge-settings.py`), no
  package manager/build step.
- Setup: machine-level hook install via `scripts/install-machine.sh`;
  per-repo CI/pre-commit setup documented in `docs/setup-new-repo.md`.
- Tests: `scripts/test-security-review-gate.sh` and
  `scripts/test-mark-security-reviewed.sh`.
- CI workflows: `.github/workflows/claude-review.yml` (production) and
  `.gitea/workflows/claude-review.yml` (unverified against a real Gitea
  instance).
- Status: personal-use tooling, MIT-licensed, maintained on a
  when-I-have-time basis.

## Cross-agent conventions

- This file (`AGENTS.md`) is the single source of truth for agent instructions in this repo. `CLAUDE.md` and `.github/copilot-instructions.md` are pointers to it — never edit them, never duplicate content into them.
- Reusable skills live in `.claude/skills/` (one folder per skill with a `SKILL.md`). GitHub Copilot reads that directory natively; Codex sees it via the `.agents/skills` symlink. New skills always go in `.claude/skills/`.
- Claude-specific subagent definitions live in `.claude/agents/`. If you are not Claude Code, you may read them as role/process guidance.
- Session continuity across tools: before ending substantial work in ANY tool (Claude Code, Codex, Copilot), record durable context — decisions made, gotchas discovered, in-progress state worth resuming — in the "Working notes" section below, or fold it into the relevant section above. This is the shared memory between agents.

## Working notes

<!-- Any agent: append short dated notes here (YYYY-MM-DD — note). Prune notes when stale or once folded into the sections above. -->

- 2026-07-17 — Multi-model support: `scripts/invoke-model.sh` is now the single dispatch point for all AI models (claude, openai, codex, deepseek, moonshot, openai-compat). `run-ai-review.sh` and `pre-commit-review.sh` both delegate to it. CI workflows renamed from `claude-review.yml` to `ai-review.yml`. Repos configure their model via `AI_MODEL` env var or `.ai-review.conf`. Backward compatible: defaults to claude when AI_MODEL is unset.
