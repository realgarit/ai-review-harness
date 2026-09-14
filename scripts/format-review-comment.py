#!/usr/bin/env python3
"""Format Semgrep JSON into a PR comment body.

Usage: format-review-comment.py <semgrep.json>
Prints the formatted comment to stdout.
"""
import json
import sys


def format_semgrep(path):
    with open(path) as f:
        data = json.load(f)
    results = data.get("results", [])
    if not results:
        return "No Semgrep findings."
    lines = []
    for r in results:
        path_ = r.get("path", "?")
        line = r.get("start", {}).get("line", "?")
        severity = r.get("extra", {}).get("severity", "?")
        check_id = r.get("check_id", "?")
        message = r.get("extra", {}).get("message", "").strip()
        lines.append(f"- **{path_}:{line}** ({severity}, `{check_id}`) - {message}")
    return "\n".join(lines)


def main():
    semgrep_path = sys.argv[1]
    semgrep_section = format_semgrep(semgrep_path)
    print("## Automated security review\n")
    print("### Semgrep (deterministic)\n")
    print(semgrep_section)


if __name__ == "__main__":
    main()
