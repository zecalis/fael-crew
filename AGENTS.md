# fael-crew — agent instructions

## What crew is

crew is the lead: one agent per project that picks a set of 1–5 ready chunks across its
plans, starts each approved one as a headless `claude -p` worker under its own session id in
its own worktree, answers what workers ask, lands the lanes, has a fresh session review and fix each set, merges
sets into a local stack and pushes it as one PR on the owner's push pr. The owner approves
every set and merges every PR on GitHub; local merges are the lead's.

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

- `skills/fael-lead/SKILL.md`: `/fael-lead [project]`
- `skills/fael-content/SKILL.md`: `/fael-content`
- `skills/fael-lead/crew-git`: the lead's branch moves (cut, land, stack, sync, ship), gated and
  atomic; `crew-git.test.sh` beside it is its check
- `skills/fael-lead/crew-wt`: throwaway worktrees (new, adopt, rm, gc, ls), each repo's setup and
  teardown from its `.fael/worktree.json`, a slot N leased in `<git-common-dir>/fael/slots.json`;
  `crew-wt.test.sh` beside it is its check
- `skills/fael-lead/crew-run`: the lead's processes (a worker per lane on claude or opencode, the set's reviewer):
  start, beat, run end, a one-line verdict, the brief paths a scope lacks, push pr in one call
  (ship: gates, push, the PR, then fael chunk done from the stack's trailers); `crew-run.test.sh` beside it is its check
- `skills/fael-lead/crew-pr`: push pr for the current branch of any repo, no lead and no plan stack
  (clean-tree, not-merged and gate checks by exit code, title/body from git, push, PR, `fael chunk done`
  from trailers); `crew-pr.test.sh` beside it is its check
- `scripts/wave-sandbox.sh`: rehearse a lead (sets, review, stack, push pr) on a toy project;
  `wave-sandbox.test.sh` beside it builds one and runs crew-run and crew-git through it, no claude

Skills are markdown, and there is no binary. Stateless git helpers next to a skill are fine:
their only state is git refs, so they pass the cache test above. A binary comes only when skill-held wave state
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
ids in its own repo only. `lead:<project>` is the lead's hand back; a row from outside a set
takes another key, or it replaces that hand back. `lead:miss:<class>` rows are the misses a
skill change must cite (two sets of one class).

## Before changing a skill

Run `scripts/wave-sandbox.sh` and lead the toy project through it with the changed skill
before you use it on a real plan.

## Git

- Create branches with `git switch -c`, never `git checkout`.
- Use English in commits and PRs. PR titles follow Conventional Commits:
  `type(scope): summary`.
- Never merge a PR. The owner reviews and merges.
- Each agent works in its own worktree, `wt-crew-agent-N` beside this checkout (fael's
  `wt-<repo>-agent-N`; wt-sync never removes a `wt-*`). Never switch branches in another agent's.
