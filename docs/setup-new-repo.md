# Setting up a new repo

Layer 2 (the edit-blocking hook) is machine-level - see the main
[README](../README.md) for the one-time `scripts/install-machine.sh` setup.
This checklist is everything else, done once per repo.

## Layer 1: CI scan and native Codex review

1. Copy into the new repo:
   - `.github/workflows/semgrep-review.yml` (GitHub) or
     `.gitea/workflows/semgrep-review.yml` (Gitea)
   - `scripts/compute-diff.sh`
   - `scripts/run-semgrep.sh`
   - `scripts/format-review-comment.py`
2. On GitHub, install the ChatGPT Codex Connector for the repository and
   enable native Code Review in Codex settings. Use the personal setting
   `Auto review: on` and `Review trigger: On PR open` when the review should
   cover your pull requests automatically. Keep exhaustive review and credit
   use off until you have a reason to broaden usage.

   For local Layer 3 reviews, install the Codex CLI and run `codex login`,
   then choose **Sign in with ChatGPT**. `codex exec` reuses that saved login.
   Do not copy `~/.codex/auth.json` into a repository or CI runner.

   See OpenAI's [Codex GitHub review documentation](https://learn.chatgpt.com/docs/third-party/github)
   and [Codex authentication documentation](https://learn.chatgpt.com/docs/auth)
   for the current setup.

3. On GitHub, the workflow's `docker run semgrep/semgrep` step needs
   Docker on the runner - `ubuntu-latest` GitHub-hosted runners have it
   by default. On Gitea, confirm your runner has Docker before relying
   on this step.
4. For GitHub, open a test PR and confirm both the Semgrep comment and the
   native Codex review appear. Gitea users should confirm the Semgrep comment;
   native Codex review is not available through the Gitea template.

## Layer 3: pre-commit advisory hook

1. Copy `scripts/pre-commit-review.sh`, `scripts/invoke-model.sh`, and
   `lefthook.yml` into the repo. The pre-commit hook uses the dispatcher to
   run the local Codex CLI.
2. Install [lefthook](https://github.com/evilmartians/lefthook) (`brew
   install lefthook`, `npm install -D lefthook`, or the install script -
   whichever fits the project) and run `lefthook install`.
3. `SKIP_REVIEW=1 git commit ...` skips the advisory check for a single
   commit (genuine WIP, not routine skipping).

## Customizing the sensitive-file pattern

`SENSITIVE_PATTERN` appears in three places and should stay in sync:
`hooks/security-review-gate.sh`, `scripts/pre-commit-review.sh`, and
implicitly in what you'd want a `security-reviewer`-style subagent to
focus on. The shipped pattern assumes a Next.js + Prisma + Stripe stack
(auth/session/stripe files, Prisma schema/migrations, webhook and
dynamic-route API handlers) - adjust for your own stack's sensitive
surface (e.g. a different ORM, a different payment provider, or none).
