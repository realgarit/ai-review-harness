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

Nothing here is tied to a specific model - `scripts/run-ai-review.sh` is
the one place that invokes a model CLI (`claude -p` today); everything
else (diff computation, Semgrep, comment formatting, posting) doesn't
know or care which model produced the review text.

## Quickstart

**Layer 2 (once per machine):**

```sh
scripts/install-machine.sh
```

Verify it worked:

```sh
scripts/test-security-review-gate.sh
scripts/test-mark-security-reviewed.sh
```

**Layers 1 and 3 (once per repo):** see
[docs/setup-new-repo.md](docs/setup-new-repo.md).

## Status

Private, personal-use tooling. The GitHub Actions path (`.github/workflows/`)
is used in production; the Gitea Actions path (`.gitea/workflows/`) is
unverified against a real Gitea instance and may need adjustment - see
the comment at the top of that file.
