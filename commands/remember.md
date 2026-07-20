---
description: Explicitly save a durable fact to core memory
---
Save to core memory: $ARGUMENTS

The conversation itself is already auto-captured by claude-mem, so only the curated layer needs updating:

1. Add or update a terse `- ` bullet in the matching section of `memory/MEMORY.md` (Identity / Standing decisions / Active projects). Convert relative dates ("next Friday") to absolute dates. Keep the file under ~100 lines — it is injected into every session.
2. If it contradicts an existing bullet, replace the old one rather than appending a duplicate.
3. Confirm in one line what was saved.
