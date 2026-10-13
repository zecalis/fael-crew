# fael-crew

A lead agent that runs a small team of 1–4 agents on one plan, on top of
[fael](https://github.com/zecalis/fael).

> **Experimental. macOS only.**

fael is the secretary: it keeps the plan, every chunk and the ledger (decisions, open
issues, hand-offs), and hands them to an agent at the file or chunk it works on.
fael-crew is the lead: one per project, it picks a set of 2–5 ready chunks across the
project's plans, starts each approved one as a headless `claude -p` worker under its own
session id, answers what workers ask, lands the lanes, has a fresh opus review and fix each set, merges
sets into a local stack and pushes it as one PR on the owner's push pr. The owner approves
every set and merges every PR on GitHub; local merges are the lead's.

## What's here

| Path | What |
|---|---|
| `skills/fael-lead` | `/fael-lead [project]` — lead one project's sets with `claude -p` workers |
| `skills/fael-content` | `/fael-content` — plan a month of posts as chunks |
| `scripts/wave-sandbox.sh` | rehearse a lead on a throwaway toy project before a real one |

## Requirements

- macOS
- [fael](https://github.com/zecalis/fael) (`brew install zecalis/tap/fael`, then `fael install`)
- [Claude Code](https://claude.com/claude-code) (`claude` on `PATH`)

## Install

```sh
git clone https://github.com/zecalis/fael-crew ~/fael-crew
ln -s ~/fael-crew/skills/fael-lead ~/.claude/skills/fael-lead
ln -s ~/fael-crew/skills/fael-content ~/.claude/skills/fael-content
```

Rehearse once, then lead a real project:

```sh
~/fael-crew/scripts/wave-sandbox.sh
```

## The line between crew and fael

crew may keep its own cache, but only state that dies with the wave: worker PIDs, free
worktrees, worker logs, the wave queue, cached briefs. Anything a later session or person
needs (chunk state, a hand-off, a decision the lead made mid-wave, an issue a worker
found, an answer worth reusing) goes into fael.

The test: delete crew's cache. If the next session lost something, it was in the wrong
place.

## License

MIT
