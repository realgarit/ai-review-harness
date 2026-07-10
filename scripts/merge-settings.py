#!/usr/bin/env python3
"""Merge the harness's PreToolUse/PostToolUse hooks into ~/.claude/settings.json
without touching anything else already configured there (e.g. an
existing Stop hook, other matchers).

Usage: merge-settings.py <settings.json path> <hooks dir path>
"""
import json
import os
import sys


def load_settings(path):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {}


def ensure_entry(hook_list, matcher, command):
    """Add {matcher, hooks: [{type: command, command}]} if not already present."""
    for entry in hook_list:
        if entry.get("matcher") == matcher:
            for h in entry.get("hooks", []):
                if h.get("command") == command:
                    return  # already installed
            entry.setdefault("hooks", []).append({"type": "command", "command": command})
            return
    hook_list.append({"matcher": matcher, "hooks": [{"type": "command", "command": command}]})


def main():
    settings_path, hooks_dir = sys.argv[1], sys.argv[2]
    settings = load_settings(settings_path)
    hooks = settings.setdefault("hooks", {})

    pre_tool_use = hooks.setdefault("PreToolUse", [])
    ensure_entry(pre_tool_use, "Edit|Write|MultiEdit", os.path.join(hooks_dir, "security-review-gate.sh"))

    post_tool_use = hooks.setdefault("PostToolUse", [])
    ensure_entry(post_tool_use, "Task", os.path.join(hooks_dir, "mark-security-reviewed.sh"))

    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")

    print(f"Merged hooks into {settings_path}")


if __name__ == "__main__":
    main()
