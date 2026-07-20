---
description: Search persistent memory and answer with citations
---
Search persistent memory to answer: $ARGUMENTS

Work through the tiers, stopping at the first one that fully answers. Use claude-mem's progressive disclosure — never fetch full details before filtering:

1. **Tier 0 — injected context**: If the `<core-memory>` block or claude-mem's injected session context already answers it, use that.
2. **Tier 1 — core file**: Read `memory/MEMORY.md`.
3. **Tier 2 — search index**: Call claude-mem's `search` MCP tool with the question (it does hybrid semantic + keyword matching, so phrasing doesn't need to be exact). Review the compact index of results.
4. **Tier 3 — targeted fetch**: For only the promising result IDs, call `timeline` for chronological context and `get_observations` for full details.

Then produce the answer:
- Rerank what you retrieved by actual relevance; ignore weak matches.
- Cite every fact with its source — the memory/session it came from and its date, e.g. `(claude-mem observation, 2026-07-19)` or `(memory/MEMORY.md)`.
- If memory does not contain the answer, say exactly that. Never guess or fabricate a memory — an uncited confident answer is worse than "not in memory".
