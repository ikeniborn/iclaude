#!/usr/bin/env python3
"""UserPromptSubmit hook: nudge to consult the wiki first. Never blocks."""
import json
import sys

HINT = ("Before starting work, consider /iwiki-query to consult docs/wiki/ "
        "for relevant context.")


def main() -> int:
    try:
        json.load(sys.stdin)  # consume payload; we don't gate on it
    except Exception:
        pass
    print(HINT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
