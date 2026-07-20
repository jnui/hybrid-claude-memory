#!/bin/bash
# SessionStart hook: inject the project's curated core memory, capped.
# (Conversation history capture + injection is handled globally by claude-mem;
# this covers what claude-mem doesn't: the curated identity/decisions layer.)
CORE="${CLAUDE_PROJECT_DIR:-.}/memory/MEMORY.md"
[ -f "$CORE" ] || exit 0
python3 - "$CORE" <<'EOF'
import sys
out = open(sys.argv[1], errors="replace").read().strip()[:5200]  # ~1300 token cap
if out:
    print("<core-memory>")
    print("Curated project memory (run /recall <question> to search full conversation history):")
    print()
    print(out)
    print("</core-memory>")
EOF
exit 0
