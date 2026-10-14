---
name: fael-lead
description: Lead one project's dev work — read every plan's ready chunks in the repo, pick a set of 2-5 that can run together, pin the contracts they share, start each approved chunk as a headless claude -p worker under its own session id, answer what workers ask, land the lanes into a set branch, have a fresh session review and fix it (opus, sonnet for an all-S set), merge sets into a local stack and push the stack as one PR when the owner says push pr. Merges locally, never on GitHub, never forces a start. Run by /fael-lead [project] only.
disable-model-invocation: true
---

# fael-lead — one project, one lead, one PR per stack

**A set is a bet that these chunks do not touch each other.** You place it from facts, the owner
approves it, the diff settles it, fael keeps the result for the next bet. Chunks are `/fael-plan`'s
cut (merge or split goes back there); yours are the files, each worker's own, so landing and review stay easy.

Nine gates, in order. Each may end the set; a failed gate goes back to the gate it names,
never forward. Local merges are yours; a GitHub PR merge is the owner's (decision
01M4V0FY). You never approve without the owner's reply and never `--force`.

**Inside the gates you decide.** A commit that changes no behaviour (format, a typo, a test
name) goes in without asking; a fix not worth it or barely possible is your call; subagents are
yours to spawn. **Models:** workers take the chunk's hint, haiku included. A reviewer is opus;
sonnet only for a set of S chunks; never haiku. **Effort:** high. Max only aimed at one named
critical point (a contract, a migration, auth, money) — never a whole set.

## The four principles

1. **Sequential is the default; parallel must pay.** A chunk joins a set only when its files
   are its own. Unsure → it waits for the next set. Waiting costs a round; a collision costs
   the owner.
2. **A refused start is a wrong cut.** `blocked` = the order is wrong, `held` = a run is live.
   Back to G2, never `--force`: forcing hides a plan that was not good enough.
3. **Decide from facts.** Every pick cites a board field, a ledger row or a past set. No history
   yet = 2 chunks whose scopes share nothing.
4. **A rule needs a repeat.** A miss is a `lead:miss:<class>` issue, never a skill edit. The
   skill changes only when one class hit 2 sets and no check can catch it; it never grows.

---

## G0 — Is there a set?

Branch moves: `crew-git` next to this file; `…` = `--gate "<AGENTS.md gates, &&>" --in <free worktree>`.
First `crew-git sync <project> …` (G7.2), whatever the count below: it deletes a stack the owner merged.

```bash
fael board --json --open | jq --arg r <repo root> '.projects[] | select(.root == $r)
  | [.plans[] | select(.area == "dev") | .name] as $dev
  | [.chunks[] | select(.ready and (.plan | IN($dev[])))] | length'
```

- **0** → nothing to lead (a chunk `blocked_by` only stacked ones waits for push pr: ask for it, G7.3). Say so and stop.
- **1**, nothing of yours running → not yours: the owner starts it, or approves it to the queue
  and the board starts it (decision 01M4TYKJ). Stop.
- **2+** → G1.

## G1 — Facts, read once

```bash
fael find --key lead:<project>        # the last hand back: next set, open Qs
fael find --key 'lead:miss:*'         # past misses, by class (--key takes a glob)
fael board --json --open | jq --arg r <repo root> '.projects[] | select(.root == $r) | del(.ledger)'
fael board --json | jq '.running | length'
```

Per ready chunk: `scope`, `blocked_by`, `pair`, `overlaps` (live runs and open PRs included),
and `fael chunk show <uid>` for the paths its brief really edits. Per past set: the `touched`
of its chunks — two that share a path collided, whatever their scopes said. `--open` drops
stacked chunks: they are the stack's `Fael-Chunk` trailers (`git log origin/main..plan/<project>/stack`),
their `touched` in `fael chunk show <uid> --json`.

`running` (every project) ≥ 6 → stop; the machine is full.

## G2 — Cut the set

Size: **2**, until 3 sets in a row closed with no `lead:miss`; then up to **5**. A miss drops
it back to 2.

Take ready chunks in plan order. A chunk is **out** when a check fails and no fix holds:

| Check | Fails when | Fix |
|---|---|---|
| Known | `scope` empty | out this set; paths from the code (never the title) in its next row |
| Disjoint | its scope, or a path its brief edits, meets another pick, a live run or an open PR; a changed pub item counts every caller (grep, tests included) | widen scope + `after` in the row, or out. A stacked chunk's paths are on the set branch already: scope only, no `after` (it waits for done, G7.4) |
| Order | an `after` between two picks | small → `pair` in the row (one worker, one run); big → the later waits |
| Interface | two picks meet at a type, schema, table, CLI or JSON | a contract (below) before either starts; no contract, no parallel |
| Room | a file in scope near the repo's line cap that the brief grows | widen scope to its folder in the row |
| Question | a brief leaves a choice to the owner | a Q in this table, its answer a `chunk note` — never a worker's wait |

A mechanical fix rides in its row (`scope → x/ (near cap)`), so one `ok` takes it. A Q is only
for an answer that changes the set or a brief: a breaking contract, an owner's choice.

`project.shared` paths (docs, registries, goldens) are nobody's: never an overlap, their
conflicts are yours at G5.

**Contract** — the interface as both sides see it, written before anyone codes:

```bash
fael add decision "<signature / schema / behaviour / errors — check: <command>>" \
  --title "contract <topic>: <one line>" --files <interface files> --key contract:<project>:<topic>
```

A change is a new row with `--supersedes`, never an edit. Additive (optional field, new verb):
yours, then `fael chunk note` each lane on it. Breaking (rename, remove, retype, new required
input): the owner's, by a Q.

Each pick gets one line of why. A pick you cannot justify in one line is out.

## G3 — The owner approves

One table, two lines a row, no uid, no header, no `—` column:

```
1  schema-x   M opus     → agent-3   contract:x
   fael-core/src/x.rs · first in plan order, its scope meets no other pick
2  cli-x      S sonnet   → agent-2   pair #3
   fael/src/x/ (near cap) · reads x only through contract:x
```

Line two: scope, then G2's one line of why. `→` is the worktree it will run in (G4). Then each Q: `Q1 #2:` the problem in one line, one line
per option, your pick as `(a)`. End with the one line:

```
Reply: ok · ok 2 sonnet · ok Q1 b · no 3
```

The reply is the approval: apply each Q first (`fael chunk edit` clears an approval), then
`fael chunk approve <uid>` per approved row (`--model` only if re-modelled), and echo what fael
printed. Only rows of the table you last showed, only on the owner's reply. A reply you cannot
read: ask again. **No reply, no set.**

## G4 — Start

`crew-run` next to this file runs one `claude -p` per call (fael ≥ 0.58.0). Start each `work`
and `review` in the background: its exit is your notification — never poll.

1. `crew-git cut <project> <n>`: the set branch at the stack G0 synced (no stack: `origin/main`).
2. Per lane, a worktree: a `worktrees[]` entry with `run: null` and no uncommitted work, highest
   number first; never the one the owner talks in (crew-run refuses only the main one). Never
   share `CARGO_TARGET_DIR`.
3. Per lane: `crew-run work <project> <n> <uid> --in <worktree> [--contract <id>]…`, one
   `--contract` per contract the lane builds against that its brief's `contracts:` block does
   not list; `--model` only if re-modelled. A pair: either uid, the brief carries both.

## G5 — Land

`crew-run work` ends in one line (`lane · R · state · cost · commits`) and its exit:

- **4 refused** → `fael chunk start` said `blocked` or `held`: back to G2 (principle 2).
- **1 waited** → answer with `fael chunk answer <uid> "…"` only when the code, the ledger or a
  contract answers it; else the owner. Then `crew-run work` again: it resumes the lane.
- **2 crashed** → its commits, `last note` and `uncommitted:` lines say where. `crew-run work`
  again, or out.
- **0 finished** → its `outside, in <plan>/<label>: <path>` and `outside, unowned: <path>` lines
  are the scope check (`project.shared` excluded) — never diff it yourself. Unowned: kept only
  if the lane's gate fails without it, as `fael chunk note <uid> "kept <path>: <why>"` (done
  hands it on); else on the lane in a free worktree `git restore -s plan/<project>/s<n> <path>`
  and commit. In another open chunk: a Q before it lands. Then land it in plan order, `--in` a free worktree:
  `crew-git land <project> <n> <uid> -m "<chunk title>" --run <R> …` squashes it (WIP commits
  are resume checkpoints, not PR history) with its chunk and run as trailers (G7.4 reads them)
  and moves the set only once the gates pass; a failure moves nothing.
  - conflict in a `project.shared` file → on the lane in a free worktree `git rebase plan/<project>/s<n>`,
    resolve (lists keep both sides; goldens re-bless; `git diff --check` clean), land again;
  - conflict in a file a lane owns, or gates fail on top of another lane → out, its note says
    why, and a `lead:miss` issue (G8).

## G6 — Review and fix

Every set, no exception: the lead wrote the cut, so a fresh session judges the diff, and each
lane's brief is its spec. `crew-run review <project> <n> --in <free worktree> --lanes <landed uids>`
runs `/fael-review high --fix` on the set against the stack (sonnet for an all-S set, else
opus), its fixes committed on that worktree's HEAD, the rest recorded to fael; its last lines
are the verdict G8 hands back. Exit 2: it failed or left uncommitted work — read it there.

Then you: a nit or PLAUSIBLE worth a commit, commit it there; G7.1 gates it. A blocker it
could not fix → that lane out (G5), a `lead:miss:review` issue either way.

## G7 — Stack, and ship on the owner's word

1. Stack the set — yours, not a PR: `crew-git stack <project> <n> …` `--in` the G6 worktree
   fast-forwards the stack to its HEAD and deletes `s<n>` and each landed lane. The next set
   branches from the stack's tip at G4.1: it does not wait on the owner.
2. At G0: `crew-git sync <project> …` replays the stack onto `origin/main`, minus what merged.
3. **Ship** when the owner says `push pr` — or ask once when the stack holds ~10 chunks, a
   breaking change, or the next set waits on a stacked chunk's `after`. `crew-git ship <project> …`
   (sync, gates, a lease-guarded push), then one PR by the repo's `push pr` rules
   (Windows CI per AGENTS.md). Body per set: lanes (uid, hand-off), lanes out and why, the
   review's verdict, **Removed / Breaking** (deleted files, files that lost 50+ lines, any CLI,
   schema or URL key renamed or removed, with its lane), and **Merge danger**: one-way or two-way door · blast radius in a word.
4. Then `crew-run done <project> --pr <N>`: it dones every chunk the stack's trailers name, its
   hand-off the lane's `finished:` note; a rerun skips what is done. Then re-file the G8 note
   with `stack: PR <N>`. The PR's merge on GitHub is the owner's, always.

## G8 — Learn, then hand back

Each miss of this set is one issue, its class in the key:

```bash
fael add issue "<what happened, the set, the repro>" --title "<one line>" \
  --key lead:miss:<leak|collision|contract|refused|gate-on-top|review> --files <a,b>
```

Then compare what each lane really changed (its `outside` lines at G5; `touched` in the board
JSON once done): a shared path no scope predicted is a `collision` miss too. A
class now at 2 sets → a Q to the owner naming the gate that should have caught it: a check (script,
gate, CI) when the miss is mechanical, else a skill change that removes as many lines as it adds.

Hand back in the owner's language, these lines only:

```
set <n> stacked · in: <labels> · out: <label — why> · review: <verdict>
stack: <k> sets, <m> chunks, not pushed      (or: PR <N>)
check before merge: ≤3 things the owner tries by hand
breaking: <what, who calls it>        (only when there is one)
next set: <labels> — a proposal, not started      (or: none — <why>)
```

Last, the row the next lead resumes from (G1) — the one point to `/clear` or compact; mid-set, a
live lane lives only in this context. Re-file it at a G0 stop too. `--files` warns on a path only
the stack holds yet: expected.

```bash
fael add note "set <n>: stacked, in <labels>, out <labels>
next: <labels, why>
misses: <classes>
open Qs: <…>" \
  --title "lead <project>: set <n> stacked, next <labels>" --key lead:<project> \
  --files <paths the set touched, a,b> [--supersedes <last lead:<project> id>]
```
