# ai-review-harness — Agent instructions

> Canonical instructions for all coding agents (Claude Code, Codex, GitHub Copilot). Claude loads this via the CLAUDE.md stub.

Enforced AI + static-analysis code review, in three layers: native Codex Code
Review for GitHub pull requests, a deterministic Semgrep scan in CI, and an
advisory `lefthook` pre-commit review of the staged diff. A local Claude Code
`PreToolUse` hook also remains available for installations that use that
agent, but it is separate from the Codex review path. The default local review
provider is the OpenAI Codex CLI (`codex exec`) using a ChatGPT login.
Everything else (diff computation, Semgrep, comment formatting, posting) is
provider-agnostic.

- Language/stack: shell scripts (`scripts/`, `hooks/`) and Python
  (`scripts/format-review-comment.py`, `scripts/merge-settings.py`), no
  package manager/build step.
- Setup: machine-level hook install via `scripts/install-machine.sh`;
  per-repo CI/pre-commit setup documented in `docs/setup-new-repo.md`.
- Tests: `scripts/test-security-review-gate.sh` and
  `scripts/test-mark-security-reviewed.sh`.
- CI workflows: `.github/workflows/semgrep-review.yml` (production) and
  `.gitea/workflows/semgrep-review.yml` (unverified against a real Gitea
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

- 2026-08-27 — The default local review provider is Codex/ChatGPT. Local CLI
  use authenticates with `codex login`; GitHub pull-request review is handled
  by the native Codex connector, not an Actions API-key workflow. Local
  fallback invocation is `codex exec --ephemeral --sandbox read-only -` for
  review-only stdin.
- 2026-09-15 — The GitHub and Gitea templates are Semgrep-only. Native Codex
  handles GitHub PR review through the connected repository settings, so these
  workflows do not request model credentials or pretend a subscription login
  is available on an ephemeral runner.
