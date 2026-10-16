#!/bin/sh
# Self-check for git-ship: a throwaway repo over a local bare remote, a stub gh on PATH whose $STUB
# says what it does, its own fael state. Usage: skills/fael-lead/git-ship.test.sh (exit 0 = all pass)
set -eu
GS=$(cd "$(dirname "$0")" && pwd)/git-ship
T=$(mktemp -d); trap '[ -n "${KEEP:-}" ] || rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
expect() {
  want=$1; shift; got=0
  "$@" >"$T/out" 2>&1 || got=$?
  [ "$got" = "$want" ] || { cat "$T/out" >&2; fail "$* exited $got, want $want"; }
}
has() { grep -qF -- "$1" "$2" || { cat "$2" >&2; fail "no '$1' in $2"; }; }
hasnt() { ! grep -qF -- "$1" "$2" || { cat "$2" >&2; fail "'$1' in $2"; }; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export FAEL_STATE_DIR=$T/.state STUB_DIR=$T STUB= GATE=0

mkdir "$T/bin"
cat >"$T/bin/gh" <<'EOF'
#!/bin/sh
# stub: gh pr list|view|create|edit over $STUB_DIR/prs ("<n> <head> <STATE>" per line), prs.<n>.title and .md
[ "$STUB" != ghfail ] || exit 1
f=$STUB_DIR/prs; touch "$f"; v=$2; shift 2
h= t= b= n=
while [ $# -gt 0 ]; do
  case $1 in --head) h=$2; shift ;; --title) t=$2; shift ;; --body-file) b=$2; shift ;;
    --base | --state | --json | -q) shift ;; *) n=$1 ;; esac
  shift
done
case $v in
list) awk -v h="$h" '$2 == h {print $3 " " $1}' "$f" ;;
view) echo "https://github.com/o/r/pull/$n" ;;
create) # like gh, pushes nothing: origin must hold the head at its local tip
  [ "$STUB" != createfail ] || exit 1
  [ "$(git ls-remote origin "refs/heads/$h" | cut -f1)" = "$(git rev-parse "$h")" ] || exit 1
  n=$(($(wc -l <"$f") + 1)); echo "$n $h OPEN" >>"$f"; echo "$t" >"$f.$n.title"; cp "$b" "$f.$n.md"
  echo "https://github.com/o/r/pull/$n" ;;
edit) echo "$t" >"$f.$n.title"; cp "$b" "$f.$n.md" ;;
esac
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"

git init -q --bare "$T/origin.git"
git init -q -b main "$T/repo"
cd "$T/repo"
echo a >a; git add a; git commit -qm init
git remote add origin "$T/origin.git"; git push -q origin main; git fetch -q origin
git config rerere.enabled true
git remote set-head origin main
fael plan new sim "test" --area dev >/dev/null
U=$(fael chunk add fa --plan sim --label fa --scope fa --size S --model haiku --brief "write fa" 2>/dev/null | tail -1)
fael chunk approve "$U" >/dev/null

# refused: on main, no commits, a dirty tree, bad usage
expect 4 "$GS"; has "on main" "$T/out"
git switch -q -c feat/one
expect 4 "$GS"; has "no commits" "$T/out"
echo one >one; git add one; git commit -qm "feat(one): add one"
echo dirt >>one
expect 4 "$GS"; has "uncommitted" "$T/out"
git restore one
expect 4 "$GS" --bogus
expect 4 "$GS" --body "$T/nope"

# no gate in .fael/worktree.json: refused, nothing pushed
expect 4 "$GS"; has "no gate in" "$T/out"
mkdir -p .fael
cat >.fael/worktree.json <<EOC
{"gate": "echo g >>$T/gates; echo boom; exit \$GATE",
 "ship": {"regen": {"lock": "echo regenerated >lock; echo r >>$T/regen"}, "fresh": ["db/**"]}}
EOC
git add .fael; git commit -qm "chore: gates"
# two commits and no -m: the subjects and the shortstat, exit 4
expect 4 "$GS"
has "feat(one): add one" "$T/out"; has "2 files changed" "$T/out"; has "-m" "$T/out"

# --dry: title, body, gate; no gate run, nothing pushed
expect 0 "$GS" --dry -m "feat(one): one"
has "title: feat(one): one" "$T/out"; has "- feat(one): add one" "$T/out"
has "## Removed (from the diff)" "$T/out"; has "Generated with [Claude Code]" "$T/out"
has "gate: echo g" "$T/out"
[ ! -e "$T/gates" ] || fail "--dry ran a gate"
[ -z "$(git ls-remote origin refs/heads/feat/one)" ] || fail "--dry pushed"

# a failed gate: the step line, the log tail, exit 2, nothing pushed, no PR
GATE=3 expect 2 "$GS" -m "feat(one): one"
has "✓ rebase" "$T/out"; has "✗ gate (log: " "$T/out"; has boom "$T/out"
GATE=0 # sh keeps an assignment made before a function call
[ -z "$(git ls-remote origin refs/heads/feat/one)" ] || fail "a failed gate pushed"
[ ! -s "$T/prs" ] || fail "a failed gate filed a PR"

# gh failing before the push: refused; gh create failing after the push: 5, rerun is safe
STUB=ghfail expect 4 "$GS" -m "feat(one): one"; STUB=
STUB=createfail expect 5 "$GS" -m "feat(one): one"; STUB=
has "rerun" "$T/out"
[ -n "$(git ls-remote origin refs/heads/feat/one)" ] || fail "branch not pushed before gh"
echo "my body" >"$T/body.md"
expect 0 "$GS" -m "feat(one): one" --body "$T/body.md"
cat >"$T/want" <<EOC
✓ clean
✓ pr-state
✓ rebase
✓ gate
✓ push
✓ pr
PR 1 https://github.com/o/r/pull/1
EOC
cmp -s "$T/out" "$T/want" || { cat "$T/out" >&2; fail "success output is not the seven step lines"; }
has "feat(one): one" "$T/prs.1.title"
has "Generated with [Claude Code]" "$T/prs.1.md"; has "my body" "$T/prs.1.md"

# a rerun edits the open PR instead of opening a second
echo two >two; git add two; git commit -qm "feat(one): two"
expect 0 "$GS" -m "feat(one): one, two"
has "PR 1 " "$T/out"
[ "$(wc -l <"$T/prs" | tr -d ' ')" = 1 ] || fail "a rerun opened a second PR"
has "feat(one): one, two" "$T/prs.1.title"
has "- feat(one): two" "$T/prs.1.md"
hasnt "Fael-Chunk" "$T/prs.1.md"

# merged: refused with its own exit, even with the work pushed
sed 's/OPEN/MERGED/' "$T/prs" >"$T/prs.x"; mv "$T/prs.x" "$T/prs"
expect 3 "$GS" -m "feat(one): one, two"
has "new branch from origin/main" "$T/out"

# one commit: its subject is the title; the Fael-Chunk trailer closes the chunk, trailer out of the
# body, a rerun skips the done chunk; removed and big-loss files in the Removed section
git switch -q -c feat/two origin/main
git restore --source=feat/one --worktree --staged .fael
seq 60 >big; git add big .fael; git commit -qm "chore: big and gates"; git push -q origin HEAD:main; git fetch -q origin
git switch -q -c feat/three origin/main
git rm -q big; git commit -qm "feat(three): drop big

Why: it was unused.

Fael-Chunk: $U"
fael chunk start "$U" >/dev/null 2>&1 || :
expect 0 "$GS"
has "PR 2 " "$T/out"
has "feat(three): drop big" "$T/prs.2.title"
has "- deleted: big" "$T/prs.2.md"
has "Why: it was unused." "$T/prs.2.md"
hasnt "Fael-Chunk" "$T/prs.2.md"
[ "$(fael chunk show "$U" --json | jq -r .state)" = done ] || fail "the trailer's chunk is not done"
expect 0 "$GS"
has "PR 2 " "$T/out"
# no fael on PATH: the trailer is skipped silently
(cd "$T" && PATH=$(echo "$PATH" | tr : '\n' | grep -v "$(dirname "$(command -v fael)")" | paste -sd: -) \
  expect 0 "$GS" --in "$T/repo") || fail "a ship without fael"

# --- the rebase: main moves under the branch, from a second clone of origin
git clone -q "$T/origin.git" "$T/other"
moved() { # moved <path> <content>: a commit on main from the other clone
  (cd "$T/other" && git pull -q origin main && mkdir -p "$(dirname "$1")" && echo "$2" >"$1" &&
    git add "$1" && git commit -qm "main: $1" && git push -q origin HEAD:main)
}
inprogress() { [ -d "$(git rev-parse --git-path rebase-merge)" ]; } # REBASE_HEAD lingers after a clean rebase
cut() { git fetch -q origin; git switch -q -c "$1" origin/main; }

# main moved, no conflict: rebased and shipped
cut feat/a; echo a >a1; git add a1; git commit -qm "feat(a): a"
moved m1 m
expect 0 "$GS"
git merge-base --is-ancestor origin/main HEAD || fail "not rebased onto main"
[ -f m1 ] || fail "main's file missing after the rebase"
has "PR 3 " "$T/out"

# a conflict in a regen file: main's side taken, the command ran, shipped
moved lock base; cut feat/b
echo branch >lock; echo b >b1; git add lock b1; git commit -qm "feat(b): lock"
moved lock main
rm -f "$T/regen"
expect 0 "$GS"
[ "$(cat lock)" = regenerated ] || fail "lock is '$(cat lock)'"
[ -f "$T/regen" ] || fail "the regen command did not run"
git merge-base --is-ancestor origin/main HEAD || fail "regen: not rebased"
! inprogress || fail "regen: rebase left in progress"
has "PR 4 " "$T/out"

# a conflict in a fresh file: exit 6, the file listed, aborted, nothing pushed
moved db/m.sql base; cut feat/c
echo branch >db/m.sql; git add db; git commit -qm "feat(c): migration"; tip=$(git rev-parse HEAD)
moved db/m.sql main
expect 6 "$GS"
has "✗ rebase: conflict in db/m.sql" "$T/out"; has "rerun after resolving: git rebase origin/main" "$T/out"
[ "$(grep -c '^✗' "$T/out")" = 1 ] || fail "not one line per conflicted file"
! inprogress || fail "fresh: rebase left in progress"
! git rev-parse -q --verify REBASE_HEAD >/dev/null || fail "fresh: REBASE_HEAD left"
[ "$(git rev-parse HEAD)" = "$tip" ] && [ -z "$(git status --porcelain)" ] || fail "fresh: branch not as it was"
[ -z "$(git ls-remote origin refs/heads/feat/c)" ] || fail "fresh: pushed"

# an unresolved conflict elsewhere: exit 6, aborted
moved x base; cut feat/d
echo branch-x >x; git add x; git commit -qm "feat(d): x"; tip=$(git rev-parse HEAD)
moved x main-x
expect 6 "$GS"
has "✗ rebase: conflict in x" "$T/out"
! inprogress || fail "other: rebase left in progress"
[ "$(git rev-parse HEAD)" = "$tip" ] || fail "other: branch not as it was"

# the same kind of conflict rerere already resolved: staged and continued
moved y base; cut feat/e
echo branch-y >y; git add y; git commit -qm "feat(e): y"; tip=$(git rev-parse HEAD)
moved y main-y
git fetch -q origin; git rebase origin/main >/dev/null 2>&1 || :
echo resolved >y; git add y; GIT_EDITOR=true git rebase --continue >/dev/null 2>&1
git reset -q --hard "$tip"
expect 0 "$GS"
[ "$(cat y)" = resolved ] || fail "rerere's resolution not used: '$(cat y)'"
! inprogress || fail "rerere: rebase left in progress"

# a remote commit the local branch lacks: the push is refused, exit 1
cut feat/f; echo f >f1; git add f1; git commit -qm "feat(f): f"
expect 0 "$GS"
(cd "$T/other" && git fetch -q origin && git switch -q -c feat/f origin/feat/f && echo r >r1 && git add r1 &&
  git commit -qm "remote: r1" && git push -q origin feat/f)
echo g >f2; git add f2; git commit -qm "feat(f): g"
expect 1 "$GS" -m "feat(f): f and g"
has "✗ push" "$T/out"; has "remote has commits you lack: fetch and look" "$T/out"

# --in works from any cwd
cut feat/g; echo g >g1; git add g1; git commit -qm "feat(g): g"
(cd "$T" && expect 0 "$GS" --in "$T/repo")
echo "git-ship.test.sh: all pass"
