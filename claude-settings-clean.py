#!/usr/bin/env python3
"""Git clean filter for claude/.claude/settings.json.

Claude Code owns that file: it rewrites the whole thing whenever a runtime
option changes (/model, the theme picker, sandbox toggles), so a stowed,
tracked copy is dirty again the moment you switch models. This strips the keys
Claude Code writes back as machine state and sorts what's left, leaving git to
see only the durable config — hooks, permissions, statusLine, plugins.

Reads the working-tree file on stdin, writes the committed form on stdout.
Wired up by `git config filter.claude-settings.clean` in bootstrap.sh and
pointed at this file by .gitattributes.
"""

import json
import sys

# Written back by Claude Code itself; per-machine, never worth a commit.
VOLATILE = ("model", "theme", "sandbox", "modelSettings")


def main() -> None:
    raw = sys.stdin.read()
    try:
        settings = json.loads(raw)
    except ValueError:
        # A half-written or hand-broken file still has to round-trip: a filter
        # that errors here wedges every git command touching the file.
        sys.stdout.write(raw)
        return

    for key in VOLATILE:
        settings.pop(key, None)

    # sort_keys because Claude Code's own key order isn't stable across
    # versions — without it a rewrite alone shows up as a diff.
    json.dump(settings, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
