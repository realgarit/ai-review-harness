# ai-review-harness

Enforced AI + static-analysis code review, in three layers that catch
things at different points instead of relying on one gate:

1. **CI review** - every pull request gets a Semgrep scan (deterministic,
   scoped to the diff) plus an AI review (security + code quality),
   posted as a PR comment. Works on GitHub Actions or Gitea Actions.
2. **Local edit-blocking hook** - a Claude Code `PreToolUse` hook blocks
   edits to security-sensitive files in a session until a
   `security-reviewer`-style subagent has actually run once that session.
   Machine-level, not per-repo.
3. **Pre-commit advisory hook** - a `lefthook` pre-commit step runs an AI
   review of the staged diff before every commit. Advisory only, never
   blocks - a fast, cheap early signal.

Nothing here is tied to a specific model — `scripts/run-ai-review.sh` and
`scripts/pre-commit-review.sh` are model-agnostic. Both delegate to
`scripts/invoke-model.sh`, the single dispatch point that supports
multiple AI providers based on the `AI_MODEL` environment variable:

| Provider | Auth method | Transport |
|---|---|---|
| `codex` (default) | ChatGPT subscription locally; `OPENAI_API_KEY` for GitHub CI | `codex exec` / pinned Codex Action |
| `claude` | Claude Code CLI (subscription) | `claude -p` |
| `openai` | OpenAI API key | `curl` + `jq` (Chat API) |
| `deepseek` | DeepSeek API key | `curl` + `jq` |
| `moonshot` | Moonshot API key | `curl` + `jq` |
| `openai-compat` | API key + base URL | `curl` + `jq` (Ollama, vLLM, Azure, etc.) |

Set `AI_MODEL` in CI workflow variables or `.ai-review.conf` to choose.
See [docs/setup-new-repo.md](docs/setup-new-repo.md) for per-provider
secret requirements.

For local use of the default ChatGPT-backed provider, run `codex login` and
choose **Sign in with ChatGPT**. The GitHub workflow uses the pinned
`openai/codex-action` with a read-only permission profile and requires an
`OPENAI_API_KEY` repository secret; a local ChatGPT login is not automatically
available on an ephemeral runner. That secret is OpenAI Platform API usage, not
subscription usage. The Gitea workflow remains a direct-CLI compatibility path
for trusted runners only because its runtime has no bundled equivalent proxy.

## Quickstart

**Layer 2 (once per machine):**

```sh
scripts/install-machine.sh
```

Verify it worked:

```sh
scripts/test-security-review-gate.sh
scripts/test-mark-security-reviewed.sh
scripts/test-codex-default.sh
```

**Layers 1 and 3 (once per repo):** see
[docs/setup-new-repo.md](docs/setup-new-repo.md).

## Status

Personal-use tooling, made public (MIT-licensed) in case the Layer 2
pattern (a Claude Code hook that blocks edits until a security-reviewer
subagent has run) is useful to someone else. The GitHub Actions path
(`.github/workflows/`) is used in production; the Gitea Actions path
(`.gitea/workflows/`) is unverified against a real Gitea instance and
may need adjustment - see the comment at the top of that file.

Contributions/issues welcome, but this is maintained on a "when I have
time" basis, not a supported product.
