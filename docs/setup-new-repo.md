# Setting up a new repo

Layer 2 (the edit-blocking hook) is machine-level - see the main
[README](../README.md) for the one-time `scripts/install-machine.sh` setup.
This checklist is everything else, done once per repo.

## Layer 1: CI review

1. Copy into the new repo:
   - `.github/workflows/claude-review.yml` (GitHub) or
     `.gitea/workflows/claude-review.yml` (Gitea)
   - `scripts/compute-diff.sh`
   - `scripts/run-semgrep.sh`
   - `scripts/run-ai-review.sh`
   - `scripts/format-review-comment.py`
   - `prompts/review-prompt.md`
2. Add a `CLAUDE_CODE_OAUTH_TOKEN` secret to the repo (Settings > Secrets
   and variables > Actions, or Gitea's equivalent). Generate the token
   with `claude setup-token` on a machine with a Claude subscription -
   this uses your subscription, not pay-per-token API billing.
3. On GitHub, the workflow's `docker run semgrep/semgrep` step needs
   Docker on the runner - `ubuntu-latest` GitHub-hosted runners have it
   by default. On Gitea, confirm your runner has Docker before relying
   on this step.
4. Open a test PR and confirm the bot comment shows up.

## Layer 3: pre-commit advisory hook

1. Copy `scripts/pre-commit-review.sh` and `lefthook.yml` into the repo.
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
