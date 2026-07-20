#!/bin/bash
# Install the per-project memory layer: ./install.sh /path/to/project
# Prereq (once per machine): npx claude-mem install
set -e
TARGET="${1:?usage: ./install.sh /path/to/project}"
SRC="$(cd "$(dirname "$0")" && pwd)"

# claude-mem is the global storage/search engine — warn if it's missing
[ -d "$HOME/.claude-mem" ] || echo "WARNING: claude-mem not detected. Run once per machine: npx claude-mem install"

mkdir -p "$TARGET/.claude/memory/hooks" "$TARGET/.claude/commands" "$TARGET/memory"
cp "$SRC"/hooks/inject.sh "$TARGET/.claude/memory/hooks/"
cp "$SRC"/commands/*.md "$TARGET/.claude/commands/"
[ -f "$TARGET/memory/MEMORY.md" ] || cp "$SRC/templates/MEMORY.md" "$TARGET/memory/MEMORY.md"
chmod +x "$TARGET/.claude/memory/hooks/inject.sh"

# Merge SessionStart hook into .claude/settings.json without clobbering existing config
python3 - "$TARGET/.claude/settings.json" <<'EOF'
import json, os, sys
p = sys.argv[1]
s = json.load(open(p)) if os.path.exists(p) else {}
hooks = s.setdefault("hooks", {})
cmd = ".claude/memory/hooks/inject.sh"
entries = hooks.setdefault("SessionStart", [])
if not any(cmd in h.get("command", "") for e in entries for h in e.get("hooks", [])):
    entries.append({"hooks": [{"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR/' + cmd + '"'}]})
json.dump(s, open(p, "w"), indent=2)
print("hooks merged into", p)
EOF

echo "Installed. Restart Claude Code inside $TARGET to activate."
