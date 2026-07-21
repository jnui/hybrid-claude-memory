# Claude Code Memory System

this project is inspired by this video https://www.youtube.com/watch?v=H9BUkgDf5Y4

This project is vibe coded and has not been extensively tested, use at your own risk. I am using it on a couple of projects, and it seems to work ok.

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

## How it works day-to-day

There isn't one hook — there are several, firing at different rhythms:

- **PostToolUse (claude-mem)** — the workhorse. It fires after *every single tool call*
  Claude makes: every file read, every edit, every command run. This is why capture is
  continuous rather than end-of-session. Each firing records an observation to the
  local worker service.
- **UserPromptSubmit (claude-mem)** — fires every time you send a prompt.
- **Stop (claude-mem)** — fires each time Claude finishes responding, closing out that
  turn's observations.
- **SessionStart (claude-mem + this package's inject.sh)** — fires once when you launch
  Claude Code in a project (and again after `/clear` or a resume). claude-mem injects
  relevant history; this package injects `memory/MEMORY.md`, capped at ~1,300 tokens.
- **SessionEnd (claude-mem)** — fires when the session closes, for final wrap-up.

During active development, capture happens dozens of times per conversation — you
never have to think about it.

Over a project's life the flow looks like this: as you work, raw observations pile up
per tool call; claude-mem's AI compression turns them into structured facts rather
than storing raw transcripts. Everything is indexed both as keywords (FTS5) and as
vectors (Chroma), which is why you can later find "that database decision" even if you
originally called it "the Postgres thing." From your **second session onward** in a
project, claude-mem starts injecting the most relevant slices of that history at
startup, so you don't begin from zero.

Then there's the deliberate layer: when something is genuinely durable — "Acme
invoices weekly," "we chose Supabase" — run `/remember` and it gets promoted into
`memory/MEMORY.md`, which is *always* injected, not just when search deems it
relevant. When you need something old, `/recall` searches in tiers and answers with
citations — or tells you plainly the memory isn't there.

The practical division: claude-mem is your automatic long-tail memory of everything;
`MEMORY.md` is the small set of facts too important to leave to a search ranking.

### Useful commands

| Command | Where | When to use it |
|---------|-------|----------------|
| `/recall <question>` | inside Claude Code | You need something from past sessions — a decision, a client detail, an old outcome. Returns a cited answer or an honest "not in memory". |
| `/remember <fact>` | inside Claude Code | Something durable just got decided (preference, standing decision, project fact) and you want it in *every* future session, guaranteed. |
| `/learn-codebase` | inside Claude Code | Optional, once per project: front-loads memory by ingesting the whole repo (~5 min) instead of building memory passively. |
| `/how-it-works` | inside Claude Code | Quick refresher on claude-mem's pipeline. |
| `npx claude-mem start` | terminal | The worker isn't running (e.g. after a reboot) and observations aren't being captured. |
| `npx claude-mem install` | terminal | Once per machine, or to repair/update the global claude-mem setup. |
| `./install.sh <project-path>` | terminal, from this repo | Add the per-project layer (MEMORY.md + hooks + commands) to a new project. Safe to re-run. |

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

Restart Claude Code inside that project (note make sure you are in the project folder). The installer is idempotent: it copies the
hook and commands, creates `memory/MEMORY.md` from the template (never overwriting an
existing one), and merges the SessionStart hook into the project's
`.claude/settings.json` without touching other settings.

The first time you run claude you will get a message saying that the memory does not work until you start it a second time, so if you see that, stop claude and restart claude. Then I normally get it to add something to memory to test it.

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
