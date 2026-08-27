# ai-review-harness — Agent instructions

> Canonical instructions for all coding agents (Claude Code, Codex, GitHub Copilot). Claude loads this via the CLAUDE.md stub.

Enforced AI + static-analysis code review, in three layers: a CI review
(Semgrep scan plus an AI review posted as a PR comment, on GitHub Actions
or Gitea Actions), a local Claude Code `PreToolUse` hook that blocks
edits to security-sensitive files until a security-reviewer subagent has
run that session, and an advisory `lefthook` pre-commit hook that runs an
AI review of the staged diff. The default review provider is the OpenAI
Codex CLI (`codex exec`), using a local ChatGPT login or a CI API key;
Claude (`claude -p`) and other API providers remain selectable. Everything
else (diff computation, Semgrep, comment formatting, posting) is
model-agnostic.

- Language/stack: shell scripts (`scripts/`, `hooks/`) and Python
  (`scripts/format-review-comment.py`, `scripts/merge-settings.py`), no
  package manager/build step.
- Setup: machine-level hook install via `scripts/install-machine.sh`;
  per-repo CI/pre-commit setup documented in `docs/setup-new-repo.md`.
- Tests: `scripts/test-security-review-gate.sh` and
  `scripts/test-mark-security-reviewed.sh`.
- CI workflows: `.github/workflows/ai-review.yml` (production) and
  `.gitea/workflows/ai-review.yml` (unverified against a real Gitea
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

- 2026-08-27 — The default AI review provider is Codex/ChatGPT. Local CLI
  use authenticates with `codex login`; CI uses a step-scoped
  `CODEX_API_KEY`. The dispatcher invokes
  `codex exec --ephemeral --sandbox read-only -` for review-only stdin.
