---
name: fael-lead
description: Lead one project's dev work — read every plan's ready chunks in the repo, pick a set of 1-5 that can run together, pin the contracts they share, start each approved chunk as a headless claude -p worker under its own session id, answer what workers ask, land the lanes into a set branch, have a fresh session review and fix it (opus when a lane ran on opus, else sonnet), merge sets into a local stack and push the stack as one PR when the owner says push pr. Merges locally, never on GitHub, never forces a start. Run by /fael-lead [project] only.
disable-model-invocation: true
model: sonnet
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
yours to spawn. **Models:** you run on sonnet (frontmatter; a long lead turns over a big
context, so its price is the overhead): a call you cannot make from the facts is a Q, not opus. G3 proposes sonnet; opus only for a chunk that touches a migration,
money, auth or a contract another lane reads (an opus lane costs 6-8x a sonnet one, vela
2026-10-15); haiku for a mechanical S. Workers take the approved model on the approval's client
(opencode, else claude: crew-run picks). The reviewer takes the set's strongest lane: opus when
a lane ran on opus, else sonnet; never haiku. **Effort:** high. Max only aimed at one named critical point (a
contract, a migration, auth, money) — never a whole set.

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

Branch moves: `crew-git` next to this file; `…` = `--in <gate wt>`, the gates read from `gate` in
the repo's `.fael/worktree.json` (none there: add `--gate "<AGENTS.md gates, &&>"`, and ask the
owner for the key in G3), the gate worktree for every `…` and G6: `crew-wt new <repo> plan/<project>/gate` (`crew-wt` next to this
file; a throwaway worktree with the repo's own setup), or its `crew-plan-<project>-gate` row in
`crew-wt ls <repo>` when one is there; removed at G8.
First `crew-git sync <project> …` (G7.2), whatever the count below: it deletes a stack the owner merged.

```bash
fael board --json --open | jq --arg r <repo root> '.projects[] | select(.root == $r)
  | [.plans[] | select(.area == "dev") | .name] as $dev
  | [.chunks[] | select(.ready and (.plan | IN($dev[])))] | length'
```

- **0** → nothing to lead (a chunk `blocked_by` only stacked ones waits for push pr: ask for it, G7.3). Say so and stop.
- **1+** → G1. One is a set of 1: G2 still checks it against live runs, open PRs and the
  stack, and G3 still asks the owner (decision fael:01M4Z88Y).

## G1 — Facts, read once

`crew-run facts <project>` (`crew-run` next to this file): the last `lead:<project>` hand back,
the `lead:miss:*` rows, the ready dev chunks by `unblocks`, the running count. One call; never
re-read them by hand.

Per G2 pick (4-5), not every ready chunk: `crew-run facts <project> <uids>`: each one's `scope`,
`blocked_by`, `pair`, `overlaps` (live runs and open PRs included), the rows on its files, then
`crew-run scope`: each path a brief names that its scope lacks. Per past set: the `touched`
of its chunks — two that share a path collided, whatever their scopes said. `--open` drops
stacked chunks: they are the stack's `Fael-Chunk` trailers (`git log origin/main..plan/<project>/stack`),
their `touched` in `fael chunk show <uid> --json`. From run end to G7.4's done a chunk reads
`running`: stacked, waiting for that done, not stuck.

`running` (every project) ≥ 6 → stop; the machine is full.

## G2 — Cut the set

Size: **2** (1 when only one is ready), until 3 sets in a row closed with no `lead:miss`; then
up to **5**. A miss drops it back to 2.

Take ready chunks by `unblocks`, most first, ties in plan order: the next link of a chain
goes before work nothing waits on. A chunk is **out** when a check fails and no fix holds:

| Check | Fails when | Fix |
|---|---|---|
| Scoped | `scope` empty (board: `— no scope`), or `crew-run scope` (G1) lists a path the brief edits, or the change reaches a layer no brief word names: walk it one layer down in the repo's own order (its slice skill or ARCHITECTURE) — the type or schema under it, the seed or fixture that makes its data, an error code it adds, the list its rows link to, the existing checks that read what it touches (verify, unlock, relock on a moved or re-signed record): each is in the scope or a Q in G3. `crew-run scope` reads only path-shaped words, so these leaked 3 sets running | empty: out this set, named in G3 as `skipped, no scope: <uid>…` for the owner or `/fael-plan`, never dropped silently. A missing path: the scope lists it before the set (widen it in the row, the owner's `ok` sets it with `fael chunk edit --scope`) or back to `/fael-plan`; never left to the brief's prose |
| Disjoint | its scope meets another pick, a live run or an open PR; a changed pub item counts every caller (grep, tests included) | widen scope + `after` in the row, or out. A stacked chunk's paths are on the set branch already: widen scope, no `after` on it — that `after` holds the new chunk until the stacked one is done, at push pr (G7.4) |
| Order | an `after` between two picks | small → `pair` in the row (one worker, one run); big → the later waits |
| Interface | two picks meet at a type, schema, table, CLI or JSON | a contract (below) before either starts; no contract, no parallel |
| Room | a file in scope near the repo's line cap that the brief grows | widen scope to its folder in the row |
| Question | a brief leaves a choice to the owner | a Q in this table, its answer a `chunk note` — never a worker's wait |

A mechanical fix rides in its row (`scope → x/ (near cap)`), so one `ok` takes it. A Q is only
for an answer that changes the set or a brief: a breaking contract, an owner's choice. Each pick
gets one line of why; a pick you cannot justify in one line is out. Before G3, read each pick's `rows:`
(facts): a row that contradicts the brief sends it back to `/fael-plan`, out of this set.

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

## G3 — The owner approves

One table, two lines a row, no uid, no header, no `—` column:

```
1  schema-x   M opus     contract:x
   fael-core/src/x.rs · unblocks 2, its scope meets no other pick
2  cli-x      S sonnet   pair #3
   fael/src/x/ (near cap) · reads x only through contract:x
```

Line two: scope · G2's why. Then each Q: `Q1 #2:` the problem in one
line, one line per option, your pick as `(a)`. End with:

```
Reply: ok · ok 2 sonnet · ok Q1 b · no 3
```

The reply is the approval, to the table you last showed: apply each Q first (`fael chunk edit`
clears an approval), then `fael chunk approve <uid>` per approved row (`--model`, `--client`
only if the owner changed them); echo what fael printed. A reply you cannot read: ask again. **No reply, no set.**

## G4 — Start

`crew-run set` runs every lane's `claude -p` at once (fael ≥ 0.58.0); all else runs in
the foreground. It outlives Bash's 10-minute limit: start it with `run_in_background`; it exits
once every lane has, so it wakes you (a subagent lead too) once per set. Never poll.

1. `crew-git cut <project> <n>`: the set branch at the stack G0 synced (no stack: `origin/main`).
2. `crew-run set <project> <n> <uids> [--contract <id>]…` from the repo: per lane a throwaway
   worktree `crew-plan-<project>-lane-<uid>` beside the main checkout (`crew-wt new`, `crew-wt`
   next to this file: its own slot, ports and database; never share `CARGO_TARGET_DIR`), then
   `crew-run work` in each; a `--contract` per contract a lane builds against that its brief's
   `contracts:` block lacks. A pair: either uid, the brief carries both. Re-modelled since the
   approval: `fael chunk approve --model` first. Once a lane lands or goes out (G5), `crew-wt rm
   <path>`; a resume (exit 1 or 2) keeps it: `crew-run set` again with the lanes to resume.

## G5 — Land

`crew-run set` prints `== <uid> · exit <x>` per lane, then its `crew-run work` lines, ending
`lane · R · state · cost · commits`. Each exit:

- **4 refused** → `fael chunk start` said `blocked` or `held`: back to G2 (principle 2).
- **1 waited** → answer with `fael chunk answer <uid> "…"` only when the code, the ledger or a
  contract answers it; else the owner. Then `crew-run set` again with it: it resumes the lane.
- **2 crashed** → its commits, `last note` and `uncommitted:` say where; `crew-run set` again, or out.
- **0 finished** → its `outside, in <plan>/<label>: <path>` and `outside, unowned: <path>` lines
  are the scope check (`project.shared` excluded) — never diff it yourself. Unowned: kept only
  if the lane's gate fails without it, as `fael chunk note <uid> "kept <path>: <why>"` (done
  hands it on); else on the lane in its worktree `git restore -s plan/<project>/s<n> <path>`
  and commit. In another open chunk: a Q before it lands. Then land it in plan order: `crew-git
  land <project> <n> <uid> -m "<chunk title>" --run <R> …` squashes it (WIP commits are resume
  checkpoints) with its chunk and run as trailers (G7.4 reads them) and moves the set only once
  the gates pass; a failure moves nothing.
  - conflict in a `project.shared` file → on the lane in its worktree `git rebase plan/<project>/s<n>`,
    resolve (lists keep both sides; goldens re-bless; `git diff --check` clean), land again;
  - conflict in a file a lane owns, or gates fail on top of another lane → out, its note says
    why, and a `lead:miss` issue (G8).

## G6 — Review and fix

Every set, no exception: the lead wrote the cut, so a fresh session judges the diff, and each
lane's brief is its spec. `crew-run review <project> <n> --in <gate wt> --lanes <landed uids>`
runs `/fael-review high --fix` on the set against the stack (opus when a lane ran on opus,
else sonnet), its fixes committed on that worktree's HEAD, the rest recorded to fael. Its `outside`
lines read as G5's (a kept note on a lane, a restore on that HEAD); its last lines are the
verdict G8 hands back. Exit 2: it failed or left uncommitted work — read it there.

Then you: a nit or PLAUSIBLE worth a commit, commit it there; G7.1 gates it. A fix you hand to a
subagent runs only the tests of files it touches: the stack gates the set (G7). A blocker it
could not fix → that lane out (G5), a `lead:miss:review` issue either way.

## G7 — Stack, and ship on the owner's word

1. Stack the set — yours, not a PR: `crew-git stack <project> <n> …` fast-forwards the stack to
   the gate worktree's HEAD and deletes `s<n>` and each landed lane. The next set branches from
   the stack's tip at G4.1: it does not wait on the owner.
2. At G0: `crew-git sync <project> …` replays the stack onto `origin/main`, minus what merged.
3. **Ship** when the owner says `push pr` — or ask once when the stack holds ~10 chunks, a
   breaking change, or the next set waits on a stacked chunk's `after`. Write the body to a file,
   per set: lanes (uid, hand-off), lanes out and why, the review's verdict, **Breaking** (any CLI,
   schema or URL key renamed or removed, with its lane), **Merge danger**: one- or two-way door ·
   blast radius in a word. Then `crew-run ship <project> -m "<type(scope): summary>" --body <file>
   --in <gate wt>`: crew-git ship (sync, `gate` and `e2e` from `.fael/worktree.json`, a
   lease-guarded push), one PR for the stack with a **Removed** section from the diff appended,
   then G7.4. A rerun gates again and updates the same PR. Exit: crew-git's table, nothing pushed ·
   5, gh failed after the push: rerun ship. What the repo's AGENTS.md adds to `push pr` (Windows
   CI) is yours after it.
4. Ship ends in `crew-run done <project> --pr <N>`: it dones every chunk the stack's trailers
   name, its hand-off the lane's `finished:` note; a rerun skips what is done. Then re-file the G8
   note with `stack: PR <N>`. The PR's merge on GitHub is the owner's, always.

## G8 — Learn, then hand back

Each miss of this set is one issue, its class in the key:

```bash
fael add issue "<what happened, the set, the repro>" --title "<one line>" \
  --key lead:miss:<leak|collision|contract|refused|gate-on-top|review|brief> --files <a,b>
```

Then compare what each lane really changed (G5's `outside` lines, `touched` once done): a shared
path no scope predicted is a `collision` miss too. A class at 2 sets → a Q naming the gate that
should have caught it: a check (script, gate, CI) if mechanical, else a skill change, no net lines.

Hand back in the owner's language, these lines only:

```
set <n> stacked · in: <labels> · out: <label — why> · review: <verdict>
stack: <k> sets, <m> chunks, not pushed      (or: PR <N>)
check before merge: ≤3 things the owner tries by hand
breaking: <what, who calls it>        (only when there is one)
next set: <labels> — a proposal, not started      (or: none — <why>)
```

Last, the row the next lead resumes from (G1). Then end this session: the next set starts in a
new one (`/fael-lead <project>`), since every turn rereads the whole context and a long one costs
each turn more — this row carries all it needs. Mid-set, a live lane lives only in this context. Re-file it at a G0 stop too. `--files` warns on a path only
the stack holds yet: expected. Commas and full stops only: fael refuses two `·`, or three `;`/`·`.

```bash
fael add note "Set <n> stacked, in <labels>, out <labels>. Next: <labels>, because <why>.
Misses: <classes, or none>. Open Qs: <each, or none>." \
  --title "lead <project>: set <n> stacked, next <labels>" --key lead:<project> \
  --files <paths the set touched, a,b> [--supersedes <last lead:<project> id>]
```

Then free the gate worktree: `crew-wt rm <gate wt>` and `git branch -D plan/<project>/gate` (crew-git
only ever detaches it, so the branch holds nothing). The next set's G0 makes a fresh one.
