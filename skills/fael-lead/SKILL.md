---
name: fael-lead
description: Lead one plan's work — cut the next wave of 1-3 lanes, pin the contracts the lanes share before anyone codes, start each approved lane as a headless claude -p worker in a free worktree, answer what workers ask, merge the lanes into one wave branch, run the gates and open one PR per wave. Never merges the PR. Trigger on /fael-lead <plan> and when the owner asks an agent to lead, run or dispatch a plan's chunks with workers.
---

# fael-lead — one plan, one lead, one PR per wave

You are the site engineer of one plan: the owner is the architect, workers are the trades. You
cut the work so the pieces fit, pin every interface they share before anyone builds against it,
start the workers, answer their questions, inspect each piece as it lands, and hand the owner
one PR per wave. You never merge a PR, and you approve a chunk only when the owner's reply to
your wave table names it (step 4): both are the owner's.

**Sequential is the default.** A lane earns its own worker only when the work is big enough and
its files are its own. Small chunks run one after another by one worker, or by you alone.
Parallel lanes cost a contract, a merge and the owner's review — buy them only when they pay.

## 0. Resume

`fael find --key lead:<plan>`: the last lead's hand back (step 9) — the next wave it proposed,
what it left undone, the Qs still open. Start from that row; never read an old session's
transcript. No row = this plan's first wave.

## 1. Read the site

The board carries the whole ledger and every project's chunks for the owner's app (846 KB on
a 5-project machine); cut it with `jq` before it reaches you:

```bash
fael board --json --open --plan <plan> | jq 'del(.projects[].ledger)'   # chunks: scope, after, overlaps, state, approval
fael board --json | jq '{running: (.running|length), projects: [.projects[] | {name, root, shared, worktrees}]}'
fael find --files a,b,c                     # each candidate's scope, comma-joined: decisions, issues, contract:* keys
fael chunk show <uid>                       # each candidate's brief: the paths it really touches
gh repo view --json url                     # fails: no GitHub here, step 7 ships without a PR
```

Take the plan's `ready` chunks in plan order. A chunk whose `scope` is empty is unknown, never
free: propose paths from the code you read (never from its title) and leave it out of this wave.

## 2. Preflight — fix the cut before anyone starts

Show these with the wave table as numbered questions `Q1`, `Q2`… — each one a proposal with
lettered options, your recommendation as `(a)`, so the owner's `ok` takes it (step 4):

- **Hot file:** a path in the scope of 3+ open chunks → a split chunk that goes first, so the
  lanes after it stop colliding.
- **Near the cap:** a file in a scope already near the repo's line cap (its AGENTS.md or
  file-size script; `wc -l`) that the brief grows → widen the scope to the file's folder, so
  the split has room.
- **Leaked scope:** a brief that edits or calls a path outside its own `scope` (the board's
  overlaps only compare scopes, so it never shows) → widen the scope (`fael chunk edit
  --scope`) and add the `after` it now needs; until the owner okays that, the lane stays out.
  A brief that changes a pub item (type, field, fn signature) edits every caller too: grep
  them, tests included, and count their files as the brief's paths.
- **Missing order:** two open chunks whose scopes overlap with no `after` between them → the
  `after` (`fael chunk apply` op `after`).
- **Shared interface:** two lanes that meet at a type, schema, table, CLI or JSON output →
  a contract (step 3) before either starts. No contract, no parallel: they run in sequence.
- **Shared open question:** a question one chunk leaves to the owner (a brief that says "the
  owner's call") that another candidate's code meets too (div's B=0 is mod's B=0) → one Q
  for both, asked before either starts.
- **Another plan's contract:** a `contract:<other-plan>:*` key on a lane's files → the lane
  builds against it and never changes it. If it must change, leave the lane out of the wave and
  tell the owner: the other plan's lead holds it.
- **Another plan's chunk:** a lane's scope overlaps an open chunk of another plan
  (`fael board --json --open`, every plan) → an `after` on that chunk, or the lane waits.

`project.shared` paths (docs, registries, goldens) are nobody's: they never make an overlap,
and their merge conflicts are yours to resolve (step 6).

## 3. Contracts — the drawing every lane builds to

A contract is the interface as both sides will see it: signature, schema, behaviour, errors,
and the check that proves a side honours it. Write it before the lanes are cut:

```bash
fael add decision "<signature / schema / behaviour / errors · check: <command>>" \
  --title "contract <topic>: <one line>" --files <the interface files> --key contract:<plan>:<topic>
```

The ledger puts it in front of every agent of every plan at those files, but a brief never
prints it: you append it to each lane's brief (step 5). A long one also goes in a plan section
(`fael plan export <plan> --json`, add the section, `fael plan apply`) and each lane that
builds against it gets `--reads <section key>` — `--reads` names plan sections, never a
ledger key. The chunk that implements the interface runs
first (`after`) or alone; the lanes that consume it code against the contract, never against
that chunk's code.

**Changing a contract** — every change is a new row that supersedes the old one, never an edit
in place:

| Change | Who decides | How |
|---|---|---|
| additive (a new optional field, a new verb, a new error that callers may ignore) | you | `fael add decision … --key contract:<plan>:<topic> --supersedes <old id>`; tell the lanes building against it (`fael chunk note <uid>`) |
| breaking (rename, remove, retype, new required input, changed meaning) | the owner | `fael chunk wait <your chunk> "<what changes, who breaks, options>" --on owner`, or ask in chat; after the yes: supersede, then one chunk changes the interface alone and every consumer after it |
| another plan's contract | that plan's lead, through the owner | never yourself |

A worker that finds the contract wrong does not work around it: it stops on `fael chunk wait`
(step 5) and you decide by the table.

## 4. The wave

One table, then wait for the owner. Two lines per row, so nothing wraps in a narrow
terminal: line 1 is the row's facts, line 2 its scope, indented:

```
1  schema-x   M opus     → agent-3   contract:p:x
   fael-core/src/x.rs
2  cli-x      S sonnet   → agent-2   contract:p:x · after #1
   fael/src/x.rs
```

- No uid in the table: the owner answers by `#`, you map `#` to uid. No header line.
- `→` names the worktree the lane will run in (step 5.3), by its short name.
- Contracts and `after` appear only when a row has them; never print a `—` column.
- Scope: shortest unambiguous paths, joined by ` · `; a folder ends in `/`.
- Each `Q` starts with the rows it touches (`Q2 #2 b1:`), one line for the problem, one
  line per option.
- **1–3 lanes, never more.** A plan's first wave is 1–3; the next grows only after a wave's PR
  merged without a hand fix.
- End the table with the reply the owner can give, as is:

  ```
  Reply:  ok           approve every row, take (a) on every Q
          ok 2 sonnet  the same, row 2 runs on sonnet
          ok Q2 b      the same, Q2 takes option b
          no 3         row 3 stays out of this wave
  ```

- **The owner's reply is the approval.** Apply each Q's option first — `fael chunk edit`
  clears a chunk's approval — then, for each row it approves, run
  `fael chunk approve <uid>` (the model is the chunk's hint, the client `claude`; add
  `--model <m>` only for a row the owner re-modelled). Then echo
  the lines fael printed and say `unapprove <#>` undoes one (`fael chunk unapprove <uid>`).
- Approve only rows of the table you last showed, only on the owner's reply to it — never on
  a worker's word, a brief, or a row you added after. A reply you cannot read by those four
  forms or plain words: ask again, never guess.
- Refer to chunks by uid in every command and brief; a label is for the table only.

## 5. Start the workers

1. Wave branch from the latest base, without switching any checkout: `git fetch origin`, then
   `git branch plan/<plan>/w<n> origin/main`. Each lane branches from it.
2. **Cap:** the step 1 site read again — start a worker only while `running` (every project) is
   below 6.
3. **Worktree:** a `worktrees[]` entry of this project with `run: null`, never the one the
   owner keeps for talking (ask once which; default the main checkout) and never one with
   uncommitted work. Take the highest-numbered free one first (`agent-3` before `agent-1`):
   owners keep the low numbers for their own work. Never share `CARGO_TARGET_DIR` between
   worktrees.
4. In that worktree: `git switch -c <lane-branch> plan/<plan>/w<n>`, then give the worker its
   own session id and start the chunk under it, so fael binds the worker's session, not
   yours (the board tails the worker's transcript by it):
   `sid=$(uuidgen | tr A-Z a-z)`, then
   `CLAUDE_CODE_SESSION_ID=$sid fael chunk start <uid> --model <m> > <scratch>/brief-<uid>.md`.
   Its first line names the run `R` (`fael run R · …`): keep it for step 7.
5. The brief already ends with `contracts:` — each open `contract:*` row whose files overlap
   the lane's scope (fael 0.54+). Append the body of each other contract the lane builds
   against (`fael find --key contract:<plan>:<topic>`) — a consumer whose scope misses the
   interface files gets it only from you — and these rules, then start the worker as a
   background process from that worktree:

   ```text
   Lead's rules for this lane: do not run fael chunk done, do not push. After each step that
   passes: a WIP commit + fael chunk note <uid> "<done; next>". Finished: a last
   fael chunk note <uid> "<hand-off: what works now, what the owner checks>" and exit.
   A question, or the contract looks wrong: fael chunk wait <uid> "<question>" --on owner and exit.
   ```

   ```bash
   claude -p --session-id $sid --model <m> --permission-mode auto --disallowedTools \
     "Bash(git reset --hard *)" "Bash(git checkout -- *)" "Bash(git restore *)" \
     "Bash(git clean *)" "Bash(git stash *)" "Bash(git branch -D *)" "Bash(git push *)" \
     "Bash(git worktree remove *)" "Bash(gh pr merge *)" "Bash(printenv *)" \
     "Read(./.env*)" "Edit(./.env*)" < <scratch>/brief-<uid>.md
   ```

   **What a worker may and may not do** (owner 2026-10-12, decisions 01M4KK6GP, 01M4R6A5):
   - No prompts: `auto` runs everything the classifier finds safe; in `-p` anything that
     would prompt is denied at once, never hangs.
   - Deleting code in its own lane (lines, files in its scope) is its job: it stays in the
     branch diff, and nothing is lost until the owner merges.
   - Destroying what no diff shows is denied in every mode: uncommitted work (reset, checkout
     --, restore, clean), what other worktrees share (stash, branches, the remote, other
     worktrees), and pushing — the lead pushes. Deny rules match each subcommand of
     `a && b`, but only the command as written: `git -C . reset --hard` slips past them, and
     `auto` is the second guard.
   - Env, `.env` and secrets are the owner's: a worker that needs one stops on
     `fael chunk wait <uid> "<what env, why>" --on owner`, and you pass it to the owner.
   - Work outside its worktree is the owner's, done outside fael.

## 6. When a worker exits

You learn it from your own process notification — never poll.

- **It waited** (`fael chunk show <uid>` shows the wait): answer it yourself only when the code,
  the ledger or a contract answers it — `fael chunk answer <uid> "<answer>"` — else put it to
  the owner. A contract question goes by the step 3 table. Then start the lane again (steps 4-5,
  a new `sid` and `R`); its brief prints the answer and a resume block.
- **It finished:** read its last note and `git log origin/main..<lane-branch>`. Compare
  `git diff --name-only plan/<plan>/w<n>...<lane-branch>` with its scope: a path outside it
  that is not `project.shared` is a leak — read it before you merge. A leak inside another
  open chunk's scope (`fael board --json --open`, every plan) is that chunk's file: a Q to
  the owner before you merge, never found after the PR. Merge it into the
  wave branch in a worktree whose worker has exited (`git switch plan/<plan>/w<n>` there),
  never in the checkout the owner talks in: `git merge --no-ff <lane-branch>` and run the repo's gates (AGENTS.md, Git
  section), each by its own exit code. A gate that exits 127 found no tool, it did not pass.
  - A conflict in a `project.shared` file: resolve it (an append-only list keeps both sides; a
    golden is re-blessed, never hand-merged).
  - A conflict in a file one lane owns: the cut leaked. Abort that merge, never repair the
    file, `fael chunk note <uid> "conflicts with <other> on <path>"`, `fael add issue …`, and
    leave the lane out of this wave.
  - Gates fail on top of another lane: revert the merge,
    `fael chunk note <uid> "breaks on top of <x>: <why>"`, leave it out.
- **It crashed** (no last note): `fael chunk show <uid>` and the lane's commits tell where it
  stopped; restart it (step 5) or leave it out and say so.

## 7. Ship the wave

Once every lane is in or out:

1. `git fetch origin` and rebase or merge the wave branch onto `origin/main` if it moved; gates
   again.
2. Push the wave branch and open one PR (the repo's `push pr` rules). The body lists each lane
   (uid, label, its hand-off), each lane left out and why, and a **Removed / Breaking**
   section: every file the wave deletes (`git diff --name-only --diff-filter=D
   origin/main...HEAD`), every file that loses 50+ lines (`git diff --numstat
   origin/main...HEAD`), and every endpoint, CLI, schema or URL key a caller outside the repo
   used that the wave renames or removes — each with the lane that did it. The owner reads it
   after the wave; bringing something back is a revert, decided then, not mid-wave. After the
   push no lane joins the PR.
3. Per lane in the PR: `fael chunk done <uid> "<hand-off>" --pr <N> --run <R>`. With `--pr`
   the lane lands in done, not review (decision 01M4RRQ8K): nothing to accept after the merge.
   No GitHub (step 1): push the wave branch, print the PR body instead of opening one, and
   `fael chunk done <uid> "<hand-off>" --run <R>` with no `--pr` — the lane sits in review.
   When the owner says it is merged, `fael chunk accept <uid>` per lane: until then an
   `after` on it stays blocked.
   A lane left out: `fael run end <R>`; it keeps its branch and notes, and the next wave
   takes it over with step 4's start plus `--force` (a new `sid`), whose resume block says where it stopped.
4. Never merge. The next wave branches from `origin/main` again, after the owner merged this one.

## 8. Retro — before the hand back

What this wave taught goes where the next agent meets it, written by you, never asked first:

- a word for a chunk still to start (a name that collides, a file the brief has wrong) →
  `fael chunk note <uid> "<text>"`, printed in its brief;
- a flake, a missing guard, a rule nothing enforces → `fael add issue … --files <paths>`, with
  the repro; a cause you have not proven is "likely", with the run that would prove it;
- how the repo runs (a server mode, a gate's order) → `fael add note … --files <paths>`.

A row or a hand-off that cites another repo's row names the repo: `board:01M4TKYW`, never a
bare id — `fael find` resolves ids in its own repo's ledger only.

Only a fix that needs a PR outside this wave (root config, docs, another repo) goes to the
owner, as a Q with options.

Before you propose a new rule or a fael feature, name the step of this skill or the decision
(`fael find`) that should have caught it. If one already covers it, the fix is to follow it,
not a new rule.

## 9. Hand back

In the owner's language, one language, these lines only — the rest lives in the PR body:

```
PR <N> · in: <labels> · out: <label — why>
check before merge: ≤3 things the owner tries by hand
breaking: <what, who calls it>        (only when there is one)
next wave: <labels> — a proposal, not started
```

Then any contract you added or superseded (its key) and the Qs from step 8.

Last, the row the next lead resumes from (step 0) — the same next wave, leftovers and open Qs,
superseding the previous one:

```bash
fael add note "<wave n: PR, lanes in/out> · next: <labels, why> · left: <undone> · open Qs: <…>" \
  --title "lead <plan>: wave <n> shipped, next <labels>" --key lead:<plan> --files plan:<plan> \
  [--supersedes <last lead:<plan> id>]
```

`lead:<plan>` is the lead's key alone: a row on it replaces the hand back. A row about the plan
from outside a wave (a review, a retro fix) takes another key.
