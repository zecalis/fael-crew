# fael-crew — agent instructions

## What crew is

crew is the lead: one agent that runs a small team of 1–4 agents on one fael plan. It cuts
the next wave of lanes, starts each approved lane as a headless `claude -p` worker in its own
worktree, answers what workers ask, merges the lanes into one branch and opens one PR per
wave. The owner approves every wave and merges every PR.

[fael](https://github.com/zecalis/fael) is the secretary: it keeps the plan, every chunk
and the ledger, and hands them to an agent at the file or chunk it works on. crew is an
agent that *uses* fael. It never makes fael judge. Decisions `01M4SN8Z` (secretary rule)
and `01M4SQ9B` (the split) in fael's ledger say why.

## The line between crew and fael

crew may keep its own cache, but only state that dies with the wave: worker PIDs, free
worktrees, worker logs, the wave queue, cached briefs. Anything a later session or person
needs (chunk state, a hand-off, a decision the lead made mid-wave, an issue a worker
found, an answer worth reusing) goes into fael.

The test: delete crew's cache. If the next session lost something, it was in the wrong
place.

crew talks to fael through its commands and JSON (`fael chunk start|wait|done`,
`fael board --json`, `fael plan export --json`, `fael add|find|close`). If crew needs
something fael lacks, file it in the fael repo. It ships there only if it passes the
secretary rule: it hangs on a file or a chunk key, it fires on something the agent or
owner did, and it judges nothing.

## What's here

- `skills/fael-lead/SKILL.md`: `/fael-lead <plan>`
- `skills/fael-content/SKILL.md`: `/fael-content`
- `scripts/wave-sandbox.sh`: rehearse a wave on a toy plan

Skills are markdown and there is no binary. A binary comes only when skill-held wave state
(PIDs, free worktrees) proves unreliable, for example a lead session crashing and leaving
workers orphaned. Users link the skills from this checkout, so a change here is live on
`git pull` and needs no release.

macOS only for now.

## Memory: fael

Log as you work. Do not wait to be asked.

```text
fael add decision|issue|note "..." --title "<≤15-word headline>" --files <files>
fael find [text] [--files ...] [--key ...]
fael close <id> "..."
```

Every row needs `--files`. Write each row so it stands without this chat. Before ending a
session that changed files, add a row.

A row that cites another repo's row names the repo (`board:01M4TKYW`): `fael find` resolves
ids in its own repo only. `lead:<plan>` is the lead's hand back; a row from outside a wave
takes another key, or it replaces that hand back.

## Before changing a skill

Run `scripts/wave-sandbox.sh` and lead the toy plan through it with the changed skill
before you use it on a real plan.

## Git

- Create branches with `git switch -c`, never `git checkout`.
- Use English in commits and PRs. PR titles follow Conventional Commits:
  `type(scope): summary`.
- Never merge a PR. The owner reviews and merges.
- Each agent works in its own worktree. Never switch branches in another agent's.
