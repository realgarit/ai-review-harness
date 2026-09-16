# ai-review-harness — Agent instructions

> Canonical instructions for all coding agents (Claude Code, Codex, GitHub Copilot). Codex reads this directly; Claude and GitHub Copilot use pointer files when present.

Enforced AI + static-analysis code review, in three layers: (1) a GitHub CI
Semgrep scan posted as a PR comment plus native Codex Code Review configured
in Codex Cloud, or a trusted-runner Gitea CI review using the configurable
dispatcher; (2) a local Claude Code `PreToolUse` hook that blocks edits to
security-sensitive files until a security-reviewer subagent has run that
session; and (3) an advisory `lefthook` pre-commit hook that runs an AI
review of the staged diff. The default review provider is the OpenAI
Codex CLI (`codex exec`), using a local ChatGPT login or provider-specific
credentials on trusted CI runners;
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
- CI workflows: `.github/workflows/ai-review.yml` runs the deterministic
  GitHub Semgrep gate; native Codex Code Review supplies contextual findings.
  `.gitea/workflows/ai-review.yml` remains the unverified trusted-runner
  dispatcher path.
- Status: personal-use tooling, MIT-licensed, maintained on a
  when-I-have-time basis.

## Cross-agent conventions

- This file (`AGENTS.md`) is the single source of truth for agent instructions in this repo. `CLAUDE.md` and `.github/copilot-instructions.md` are pointers to it — never edit them, never duplicate content into them.
- Shared repository skills live in `.agents/skills/` (one folder per skill with a `SKILL.md`). Codex scans this location natively. Keep any `.claude/skills/` compatibility bridge pointer-only or generated from this directory; never maintain two independent sources. New shared skills always go in `.agents/skills/`.
- Claude-specific subagent definitions live in `.claude/agents/`. If you are not Claude Code, you may read them as role/process guidance.
- Session continuity across tools: before ending substantial work in ANY tool (Claude Code, Codex, Copilot), record durable context — decisions made, gotchas discovered, in-progress state worth resuming — in the "Working notes" section below, or fold it into the relevant section above. This is the shared memory between agents.

## Working notes

<!-- Any agent: append short dated notes here (YYYY-MM-DD — note). Prune notes when stale or once folded into the sections above. -->

- 2026-08-27 — The default AI review provider is Codex/ChatGPT. Local CLI
  use authenticates with `codex login`; GitHub CI uses the pinned Codex Action
  with an OpenAI API-key proxy, while trusted Gitea CI may use the direct
  dispatcher. Local fallback invocation is
  `codex exec --ephemeral --sandbox read-only -` for review-only stdin.
- 2026-08-27 — GitHub CI now routes the default provider through the pinned
  `openai/codex-action` with `:read-only` permissions and an API-key proxy;
  only alternate providers use the checked-out dispatcher with step-scoped
  credentials. Gitea remains direct CLI and trusted-runner-only until an
  equivalent proxy is configured.

- 2026-09-16 — GitHub CI now keeps only the deterministic Semgrep gate in the
  checked-in workflow. Native Codex Code Review supplies the contextual AI
  review in Codex Cloud, matching the fuenf-labs production pattern; Gitea and
  local hooks retain the configurable direct dispatcher.

- 2026-09-16 — Codex-first layout sweep: repository-local shared skills use `.agents/skills/` as the canonical source. Any `.claude/skills/` path is only a compatibility bridge or generated mirror.
