# Setting up a new repo

Layer 2 (the edit-blocking hook) is machine-level - see the main
[README](../README.md) for the one-time `scripts/install-machine.sh` setup.
This checklist is everything else, done once per repo.

## Layer 1: CI review

1. Copy into the new repo:
   - `.github/workflows/ai-review.yml` (GitHub) or
     `.gitea/workflows/ai-review.yml` (Gitea)
   - `scripts/compute-diff.sh`
   - `scripts/run-semgrep.sh`
   - `scripts/run-ai-review.sh`
   - `scripts/invoke-model.sh`
   - `scripts/format-review-comment.py`
   - `prompts/review-prompt.md`
2. Choose your AI model. The harness supports multiple providers — add
   the corresponding secrets to the repo (Settings > Secrets and
   variables > Actions, or Gitea's equivalent):

   | `AI_MODEL`     | Secrets needed                                        | Notes                                    |
   | -------------- | ----------------------------------------------------- | ---------------------------------------- |
   | `codex`        | `OPENAI_API_KEY` in GitHub CI                         | Default. Local ChatGPT login; GitHub uses the pinned Codex Action and API key. |
   | `claude`       | `CLAUDE_CODE_OAUTH_TOKEN`                             | Optional. Generate with `claude setup-token`. |
   | `openai`       | `OPENAI_API_KEY`                                      | OpenAI API usage; plus optional `OPENAI_MODEL` repo variable. |
   | `deepseek`     | `DEEPSEEK_API_KEY`                                    | Plus optional `DEEPSEEK_MODEL` variable.  |
   | `moonshot`     | `MOONSHOT_API_KEY`                                    | Plus optional `MOONSHOT_MODEL` variable.  |
   | `openai-compat`| `OPENAI_COMPAT_BASE_URL`, `OPENAI_COMPAT_API_KEY`     | Generic endpoint. Optional `OPENAI_COMPAT_MODEL`. |

   Set `AI_MODEL` as a repo variable (GitHub Actions) or in the workflow
   YAML to switch providers. For GitHub Actions, use:
   - `vars.AI_MODEL` to set the model name
   - optional `vars.OPENAI_MODEL`, `vars.DEEPSEEK_MODEL`, etc. to
     override the specific model within a provider family

   The default provider is `codex`. For local, subscription-backed use,
   install the Codex CLI and run `codex login`, then choose **Sign in with
   ChatGPT**. `codex exec` reuses that saved login. The GitHub workflow uses
   the pinned `openai/codex-action` with a read-only permission profile and
   needs the `OPENAI_API_KEY` repository secret; this is API-key usage billed
   through the OpenAI Platform, not a developer's local ChatGPT session. The
   action keeps the key inside its proxy instead of passing it to the
   checkout's shell dispatcher. `CODEX_API_KEY` remains an accepted fallback
   name for existing direct-CLI CI setups. Never commit or copy
   `~/.codex/auth.json` into a public or untrusted runner. The Gitea template
   has no bundled equivalent proxy and is therefore for trusted runners only
   until its installation provides one.

   See OpenAI's [Codex authentication documentation](https://learn.chatgpt.com/docs/auth)
   and [non-interactive mode documentation](https://learn.chatgpt.com/docs/non-interactive-mode)
   for the current login and automation options.

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
