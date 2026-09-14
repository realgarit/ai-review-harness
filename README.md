# ai-review-harness

Enforced AI + static-analysis code review, in three layers that catch
things at different points instead of relying on one gate:

1. **CI review** - every pull request gets a deterministic Semgrep scan,
   scoped to the diff, posted as a PR comment. GitHub pull requests also get
   native Codex Code Review through the Codex connector. No AI API key is
   needed in the repository workflow.
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
| `codex` (default) | ChatGPT subscription locally or native Codex review on GitHub | `codex exec` |
| `openai` | OpenAI API key | `curl` + `jq` (Chat API) |
| `deepseek` | DeepSeek API key | `curl` + `jq` |
| `moonshot` | Moonshot API key | `curl` + `jq` |
| `openai-compat` | API key + base URL | `curl` + `jq` (Ollama, vLLM, Azure, etc.) |

Set `AI_MODEL` in `.ai-review.conf` only when using the local dispatcher with
one of the supported providers. The GitHub workflow does not invoke a model.
See [docs/setup-new-repo.md](docs/setup-new-repo.md) for the setup steps.

For local use of the default ChatGPT-backed provider, run `codex login` and
choose **Sign in with ChatGPT**. For GitHub, install the Codex connector and
enable native Code Review in Codex settings. The connector uses the signed-in
Codex account and does not require an OpenAI API key in the repository.

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
pattern (an agent hook that blocks edits until a security-reviewer subagent
has run) is useful to someone else. The GitHub Actions path keeps only the
Semgrep scan; native Codex review is configured outside the repository. The
Gitea Actions path is unverified against a real Gitea instance and may need
adjustment.

Contributions/issues welcome, but this is maintained on a "when I have
time" basis, not a supported product.
