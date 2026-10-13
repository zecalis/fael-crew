# fael-crew

A lead agent that runs a small team of 1–4 agents on one plan, on top of
[fael](https://github.com/zecalis/fael).

> **Experimental. macOS only.**

fael is the secretary: it keeps the plan, every chunk and the ledger (decisions, open
issues, hand-offs), and hands them to an agent at the file or chunk it works on.
fael-crew is the lead: it cuts the next wave of lanes, starts each approved lane as a
headless `claude -p` worker in its own worktree, answers what workers ask, merges the
lanes into one branch and opens one PR per wave. The owner approves every wave and
merges every PR.

## What's here

| Path | What |
|---|---|
| `skills/fael-lead` | `/fael-lead <plan>` — lead one plan's waves with `claude -p` workers |
| `skills/fael-content` | `/fael-content` — plan a month of posts as chunks |
| `scripts/wave-sandbox.sh` | rehearse a wave on a throwaway toy plan before a real one |

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

Rehearse once, then lead a real plan:

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
