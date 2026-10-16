# fael-crew

A lead agent that runs a small team of 1–4 agents on one plan, on top of
[fael](https://github.com/zecalis/fael).

> **Experimental. macOS only.**

fael is the secretary: it keeps the plan, every chunk and the ledger (decisions, open
issues, hand-offs), and hands them to an agent at the file or chunk it works on.
fael-crew is the lead: one per project, it picks a set of 1–5 ready chunks across the
project's plans, starts each approved one as a headless `claude -p` worker under its own
session id, answers what workers ask, lands the lanes, has a fresh session review and fix each set, merges
sets into a local stack and pushes it as one PR on the owner's push pr. The owner approves
every set and merges every PR on GitHub; local merges are the lead's.

## What's here

| Path | What |
|---|---|
| `skills/fael-lead` | `/fael-lead [project]` — lead one project's sets with `claude -p` workers |
| `skills/fael-lead/crew-git` | the lead's branch moves: land, stack, sync, ship — gated, atomic, needs git ≥ 2.54 |
| `skills/fael-lead/crew-run` | the lead's processes: workers, the set's reviewer, and `ship` — push pr in one call (gates, push, the PR, chunks done) |
| `skills/fael-lead/crew-wt` | throwaway worktrees: `new`, `adopt`, `rm`, `gc`, `ls`, each with the repo's own setup and teardown (below) |
| `skills/fael-content` | `/fael-content` — plan a month of posts as chunks |
| `scripts/wave-sandbox.sh` | rehearse a lead on a throwaway toy project before a real one; `wave-sandbox.test.sh` checks it builds and the helpers run on it |

## Requirements

- macOS, git ≥ 2.54
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

## Throwaway worktrees

Every lane gets a fresh worktree from `crew-wt new` and loses it to `crew-wt rm` once it lands;
no worktree is permanent. A repo that needs more than git per worktree (a database, ports,
`bun install`) registers it in `.fael/worktree.json`:

```json
{ "setup": "bun scripts/worktree.ts setup", "teardown": "bun scripts/worktree.ts teardown" }
```

Both keys are optional. Each worktree holds a slot N, the lowest free one, leased in
`<git-common-dir>/fael/slots.json`. The hooks get `FAEL_WT_SLOT=N`, `FAEL_WT_PATH` and
`FAEL_WT_MAIN` (the main checkout). setup runs in the worktree. teardown runs in the main
checkout, because the worktree may already be gone. The files setup writes must be
gitignored, or the worktree reads as dirty. `crew-wt adopt` takes in a worktree made
elsewhere (the desktop app's `.claude/worktrees/<name>`). `crew-wt gc <repo>` tears down
each slot whose worktree was deleted by anything else. The contract is in the head of
`skills/fael-lead/crew-wt`.

## Gates and push pr

push pr is the same steps in every repo: rebase the stack onto `origin/main`, gate, e2e, push,
open or update the PR, done its chunks in fael. `crew-run ship` runs them all; each set was
reviewed before it joined the stack. The repo names only its commands, in the same
`.fael/worktree.json`:

```json
{ "gate": "bun run typecheck && bun run lint && bun test", "e2e": "bun run e2e" }
```

crew-git gates every land, stack and sync with `gate`; ship adds `e2e` after it.

## The line between crew and fael

crew may keep its own cache, but only state that dies with the wave: worker PIDs, free
worktrees, worker logs, the wave queue, cached briefs. Anything a later session or person
needs (chunk state, a hand-off, a decision the lead made mid-wave, an issue a worker
found, an answer worth reusing) goes into fael.

The test: delete crew's cache. If the next session lost something, it was in the wrong
place.

## License

MIT
