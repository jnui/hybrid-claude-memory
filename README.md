# Claude Code Memory System

Portable, per-project memory for Claude Code. It covers the three jobs any AI memory
system has to do — **storage**, **injection**, and **recall** — by combining
[claude-mem](https://github.com/thedotmack/claude-mem) as the global engine with a thin
per-project layer that claude-mem doesn't provide. Single-user by design; there is no
teams/shared-brain layer.

## The three jobs, and who does each

### 1. Storage — automatic, summarized

Handled by **claude-mem** (installed once per machine). Its lifecycle hooks fire on
every session — SessionStart, UserPromptSubmit, PostToolUse, Stop, SessionEnd — so
capture never depends on the agent deciding something is worth remembering. Everything
Claude reads, edits, and runs is captured as observations, compressed with AI, and
stored in SQLite + Chroma vectors under `~/.claude-mem/` on your machine. Nothing
leaves your computer.

On top of that, this package keeps a **curated core layer** per project:
`memory/MEMORY.md` — your identity, standing decisions, and active projects. The
auto-captured stream is the raw history; this file is the small set of facts that
should *always* be in context.

### 2. Injection — always on, capped

Two things load at session start:

- claude-mem injects relevant context from your session history (starting with your
  second session in a project).
- This package's `SessionStart` hook (`.claude/memory/hooks/inject.sh`) injects
  `memory/MEMORY.md`, capped at ~1,300 tokens so the context never bloats. You pay for
  those tokens once per session, and you never start from zero.

### 3. Recall — hybrid search, cited answers

The `/recall <question>` command walks a tiered search, stopping at the first tier
that answers, and uses claude-mem's progressive disclosure so it filters before
fetching (roughly 10x token savings):

| Tier | Source | Cost |
|------|--------|------|
| 0 | Context already injected this session | free |
| 1 | `memory/MEMORY.md` | one file read |
| 2 | claude-mem `search` — hybrid semantic + keyword (vectors + FTS5), so it finds memories by *meaning*, not just exact words | compact index, ~50–100 tokens/result |
| 3 | claude-mem `timeline` + `get_observations` on only the promising result IDs | full details, fetched selectively |

The answer comes back **reranked and cited** — every fact names the memory or file it
came from. And if the answer isn't in memory, Claude says exactly that instead of
fabricating one: a confident answer with no source is worse than "not in memory."

`/remember <fact>` explicitly promotes a durable fact into `memory/MEMORY.md`
(replacing contradicted bullets rather than duplicating, converting relative dates to
absolute).

## Install

Once per machine:

```bash
npx claude-mem install
npx claude-mem start        # if the worker isn't already running
```

Then per project:

```bash
./install.sh /path/to/your/project
```

Restart Claude Code inside that project. The installer is idempotent: it copies the
hook and commands, creates `memory/MEMORY.md` from the template (never overwriting an
existing one), and merges the SessionStart hook into the project's
`.claude/settings.json` without touching other settings.

To use this on another machine, copy this folder (or clone the repo) and run the same
two steps.

## Layout after install

```
your-project/
  .claude/
    memory/hooks/inject.sh    # SessionStart: capped core-memory snapshot
    commands/recall.md        # /recall — tiered search, cited answers
    commands/remember.md      # /remember — promote fact to core layer
    settings.json             # SessionStart hook merged in
  memory/
    MEMORY.md                 # curated core layer, always injected
```

Conversation history lives in claude-mem's global store (`~/.claude-mem/`), so it is
searchable from any project on the machine.

## Repo contents

```
install.sh            # per-project installer (idempotent)
hooks/inject.sh       # SessionStart hook: inject capped MEMORY.md
commands/recall.md    # /recall slash command
commands/remember.md  # /remember slash command
templates/MEMORY.md   # starting MEMORY.md for new projects
```
