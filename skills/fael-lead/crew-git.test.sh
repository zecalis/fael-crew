#!/bin/sh
# Self-check for crew-git: a throwaway repo and bare origin; each case asserts the exit code and
# where the refs end up. Usage: skills/fael-lead/crew-git.test.sh (exit 0 = all pass)
set -eu
CG=$(cd "$(dirname "$0")" && pwd)/crew-git
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
expect() {
  want=$1; shift; got=0
  "$@" >"$T/out" 2>&1 || got=$?
  [ "$got" = "$want" ] || { cat "$T/out" >&2; fail "$* exited $got, want $want"; }
}
r() { git rev-parse -q --verify "$1" || echo none; }
G='test -f README'
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

git init -q --bare "$T/origin.git"
git init -q -b main "$T/repo"
cd "$T/repo"
echo 1 > f; git add f; git commit -qm init
printf 'list\n' > README; printf 'README merge=union\n' > .gitattributes
git add -A; git commit -qm "readme, union"
git remote add origin "$T/origin.git"; git push -q origin main; git fetch -q origin
git switch -q --detach HEAD~1 # the worktree crew-git runs in has no .gitattributes: attr.tree must
for w in wt-t-agent-1 wt-t-agent-2 wt-t-agent-3; do git worktree add -q --detach "$T/$w" origin/main; done
expect 0 "$CG" cut p 1
[ "$(r plan/p/s1)" = "$(r origin/main)" ] || fail "cut s1 not at origin/main"
expect 4 "$CG" cut p 1

# mklane <uid> <base> <shell edit>: a lane with one WIP commit, made in wt-t-agent-3
mklane() {
  git -C "$T/wt-t-agent-3" switch -q -c "plan/p/lane/$1" "$2"
  (cd "$T/wt-t-agent-3" && sh -c "$3" && git add -A && git commit -qm "wip $1")
  git -C "$T/wt-t-agent-3" switch -q --detach
}
mklane A plan/p/s1 'echo a >> README'
mklane B plan/p/s1 'echo b >> README'
mklane E plan/p/s1 'echo e > f'
mklane C plan/p/s1 'echo c > f'
mklane D plan/p/s1 'echo d > d'
git -C "$T/wt-t-agent-2" switch -q plan/p/lane/D # D stays checked out: stack must not delete it

# land: squash, union on a shared list, conflict, gate failures, CAS, dirty worktree
expect 0 "$CG" land p 1 A -m "add a" --gate "$G" --in "$T/wt-t-agent-1"
[ "$(r plan/p/lane/A)" = none ] || fail "landed lane/A not deleted"
[ "$(git log -1 --format='%(trailers:key=Fael-Chunk,valueonly)%(trailers:key=Fael-Run)' plan/p/s1)" = A ] ||
  fail "land A: want trailer Fael-Chunk: A and no Fael-Run"
grep -q 'restore: git branch plan/p/lane/A ' "$T/out" || fail "no restore line"
expect 0 "$CG" land p 1 B -m "add b" --gate "$G" --in "$T/wt-t-agent-1"
git show plan/p/s1:README | grep -qx a && git show plan/p/s1:README | grep -qx b || fail "union lost a line"
[ "$(git rev-list --count origin/main..plan/p/s1)" = 2 ] || fail "a lane is not one commit"
expect 0 "$CG" land p 1 E -m "e" --gate "$G" --in "$T/wt-t-agent-1"
s=$(r plan/p/s1)
expect 1 "$CG" land p 1 C -m "c" --gate "$G" --in "$T/wt-t-agent-1"
grep -qx f "$T/out" || fail "conflict did not name f"
[ "$(r plan/p/s1)" = "$s" ] || fail "conflict moved s1"
expect 2 "$CG" land p 1 D -m "d" --gate no-such-tool-xyz --in "$T/wt-t-agent-1"
grep -q '127 (no tool)' "$T/out" || fail "127 not reported"
expect 2 "$CG" land p 1 D -m "d" --gate 'exit 5' --in "$T/wt-t-agent-1"
grep -q 'gate exit 5' "$T/out" || fail "gate exit not reported"
[ "$(r plan/p/s1)" = "$s" ] || fail "failed gate moved s1"
expect 3 "$CG" land p 1 D -m "d" --gate "git update-ref refs/heads/plan/p/s1 $(r origin/main)" --in "$T/wt-t-agent-1"
[ "$(r plan/p/s1)" = "$(r origin/main)" ] || fail "lost CAS overwrote s1"
git update-ref refs/heads/plan/p/s1 "$s"
touch "$T/wt-t-agent-1/junk"
expect 4 "$CG" land p 1 D -m "d" --gate "$G" --in "$T/wt-t-agent-1"
rm "$T/wt-t-agent-1/junk"
expect 4 "$CG" land p 1 D -m "d" --run 'R 1' --gate "$G" --in "$T/wt-t-agent-1"
expect 4 "$CG" land p 1 D -m "d" --gate "$G" --in "$T/repo"
grep -q 'the main worktree' "$T/out" || fail "main worktree not refused"
# any cwd: from --in itself, then from outside the repo
(cd "$T/wt-t-agent-1" && expect 0 "$CG" land p 1 D -m "d" --run R1 --gate "$G" --in "$T/wt-t-agent-1")
[ "$(git log -1 --format='%(trailers:key=Fael-Chunk,valueonly,separator=)|%(trailers:key=Fael-Run,valueonly,separator=)' plan/p/s1)" = 'D|R1' ] ||
  fail "land D: trailers missing"
(cd / && expect 4 "$CG" land p 1 D -m "d" --gate "$G" --in "$T/wt-t-agent-1")
grep -q 'already in s1' "$T/out" || fail "land from outside the repo did not reach the repo"

# stack: ff, s1 and landed lanes gone, lane out (C) and held lane (D) kept
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s1
expect 0 "$CG" stack p 1 --gate "$G" --in "$T/wt-t-agent-1"
[ "$(r plan/p/stack)" = "$(git -C "$T/wt-t-agent-1" rev-parse HEAD)" ] || fail "stack not at w1 HEAD"
for b in s1 lane/A lane/B lane/E; do [ "$(r "plan/p/$b")" = none ] || fail "$b not deleted"; done
for b in lane/C lane/D; do [ "$(r "plan/p/$b")" != none ] || fail "$b deleted"; done

# ship gates even a stack sync did not replay, then the owner squash-merges it while set 2 stacks on top
expect 2 "$CG" ship p --gate 'exit 5' --in "$T/wt-t-agent-1"
git --git-dir="$T/origin.git" rev-parse -q --verify plan/p/stack >/dev/null && fail "a failed gate pushed"
expect 0 "$CG" ship p --gate "$G" --in "$T/wt-t-agent-1"
[ "$(git --git-dir="$T/origin.git" rev-parse plan/p/stack)" = "$(r plan/p/stack)" ] || fail "not pushed"
expect 0 "$CG" cut p 2 --in "$T/wt-t-agent-1"
[ "$(r plan/p/s2)" = "$(r plan/p/stack)" ] || fail "cut s2 not at the stack"
mklane F plan/p/s2 'echo f >> README'
expect 0 "$CG" land p 2 F -m "f" --gate "$G" --in "$T/wt-t-agent-1"
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s2
expect 0 "$CG" stack p 2 --gate "$G" --in "$T/wt-t-agent-1"
git branch --no-track plan/p/s9 plan/p/stack # a set in flight blocks the rewrite
git clone -q "$T/origin.git" "$T/c0"
(cd "$T/c0" && echo z > z && git add z &&
  git commit -qm "other PR" && git push -q origin main)
expect 4 "$CG" sync p --gate "$G" --in "$T/wt-t-agent-1"
grep -q 's9 branched from it' "$T/out" || fail "in-flight set not named"
git branch -D -q plan/p/s9
git clone -q "$T/origin.git" "$T/c"
(cd "$T/c" && git merge -q --squash origin/plan/p/stack >/dev/null 2>&1 && git commit -qm "squash PR 1" &&
  echo g > f && git commit -qam "main moves on f" && git push -q origin main)
expect 0 "$CG" sync p --gate "$G" --in "$T/wt-t-agent-1"
[ "$(git rev-list --count origin/main..plan/p/stack)" = 1 ] || fail "sync kept merged commits"
git show plan/p/stack:README | grep -qx f || fail "sync lost set 2"

# GitHub deleted the branch: no pushed ref, the tree alone proves the stack merged
git push -q origin plan/p/stack:refs/heads/tmp
(cd "$T/c" && git pull -q && git fetch -q origin tmp && git merge -q --squash FETCH_HEAD >/dev/null 2>&1 &&
  git commit -qm "squash PR 2" && git push -q origin main :tmp :plan/p/stack)
git update-ref -d refs/remotes/origin/plan/p/stack; git update-ref -d refs/remotes/origin/tmp
expect 0 "$CG" sync p --gate "$G" --in "$T/wt-t-agent-1"
[ "$(r plan/p/stack)" = none ] || fail "merged stack not deleted"
[ "$(r plan/p/lane/C)" != none ] || fail "lane out deleted"
expect 4 "$CG" ship p --gate "$G" --in "$T/wt-t-agent-1"

# a fast-forward merge (origin/main = the stack) deletes it too
git branch --no-track plan/p/s3 origin/main
mklane H plan/p/s3 'echo h >> README'
expect 0 "$CG" land p 3 H -m "h" --gate "$G" --in "$T/wt-t-agent-1"
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s3
expect 0 "$CG" stack p 3 --gate "$G" --in "$T/wt-t-agent-1"
expect 0 "$CG" ship p --gate "$G" --in "$T/wt-t-agent-1"
git --git-dir="$T/origin.git" update-ref refs/heads/main refs/heads/plan/p/stack
expect 0 "$CG" sync p --gate "$G" --in "$T/wt-t-agent-1"
[ "$(r plan/p/stack)" = none ] || fail "ff-merged stack not deleted"

# GitHub squash-merges the pushed stack with an owner's tweak and deletes its head, while set 5
# stacks on top: the gone head is the merge, so only set 5 replays, and the next ship's lease
# expects no branch
expect 0 "$CG" cut p 4 --in "$T/wt-t-agent-1"
mklane I plan/p/s4 'echo i > i'
expect 0 "$CG" land p 4 I -m "i" --gate "$G" --in "$T/wt-t-agent-1"
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s4
expect 0 "$CG" stack p 4 --gate "$G" --in "$T/wt-t-agent-1"
expect 0 "$CG" ship p --gate "$G" --in "$T/wt-t-agent-1"
expect 0 "$CG" cut p 5 --in "$T/wt-t-agent-1"
mklane J plan/p/s5 'echo j > j'
expect 0 "$CG" land p 5 J -m "j" --gate "$G" --in "$T/wt-t-agent-1"
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s5
expect 0 "$CG" stack p 5 --gate "$G" --in "$T/wt-t-agent-1"
(cd "$T/c" && git pull -q && git fetch -q origin plan/p/stack && git merge -q --squash FETCH_HEAD >/dev/null 2>&1 &&
  echo 'i!' > i && git add i && git commit -qm "squash PR 3, owner's tweak" && git push -q origin main :plan/p/stack)
expect 0 "$CG" sync p --gate "$G" --in "$T/wt-t-agent-1"
[ "$(git rev-list --count origin/main..plan/p/stack)" = 1 ] || fail "sync replayed the merged set 4"
[ "$(git show plan/p/stack:i)" = 'i!' ] || fail "sync lost the owner's tweak"
[ "$(r refs/remotes/origin/plan/p/stack)" = none ] || fail "stale origin/plan/p/stack kept"
expect 0 "$CG" ship p --gate "$G" --in "$T/wt-t-agent-1"

# the same, but another fetch --prune drops origin/plan/p/stack before sync runs: ship's own
# refs/crew record still names the pushed head, so only set 6 replays (vela PR 502 replayed the lot)
expect 0 "$CG" cut p 6 --in "$T/wt-t-agent-1"
mklane K plan/p/s6 'echo k > k'
expect 0 "$CG" land p 6 K -m "k" --gate "$G" --in "$T/wt-t-agent-1"
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s6
expect 0 "$CG" stack p 6 --gate "$G" --in "$T/wt-t-agent-1"
(cd "$T/c" && git pull -q && git fetch -q origin plan/p/stack && git merge -q --squash FETCH_HEAD >/dev/null 2>&1 &&
  echo 'j!' > j && git add j && git commit -qm "squash PR 4, owner's tweak" && git push -q origin main :plan/p/stack)
git fetch -q --prune origin
expect 0 "$CG" sync p --gate "$G" --in "$T/wt-t-agent-1"
[ "$(git rev-list --count origin/main..plan/p/stack)" = 1 ] || fail "sync replayed the merged set 5 after a prune"
[ "$(git show plan/p/stack:j)" = 'j!' ] || fail "sync lost the owner's tweak after a prune"
git show plan/p/stack:k >/dev/null 2>&1 || fail "sync lost set 6 after a prune"

# a stack shipped before that record existed, pruned too, and main changed set 7's line after the
# squash: the newest stack commit main holds stands in for the pushed head
expect 0 "$CG" ship p --gate "$G" --in "$T/wt-t-agent-1"
expect 0 "$CG" cut p 7 --in "$T/wt-t-agent-1"
mklane L plan/p/s7 'echo l > l'
expect 0 "$CG" land p 7 L -m "l" --gate "$G" --in "$T/wt-t-agent-1"
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s7
expect 0 "$CG" stack p 7 --gate "$G" --in "$T/wt-t-agent-1"
(cd "$T/c" && git pull -q && git fetch -q origin plan/p/stack && git merge -q --squash FETCH_HEAD >/dev/null 2>&1 &&
  git commit -qm "squash PR 5" && echo 'k!' > k && git commit -qam "main moves on k" && git push -q origin main :plan/p/stack)
git update-ref -d refs/crew/plan/p/stack
git fetch -q --prune origin
expect 0 "$CG" sync p --gate "$G" --in "$T/wt-t-agent-1"
[ "$(git rev-list --count origin/main..plan/p/stack)" = 1 ] || fail "sync replayed the merged set 6 without a record"
[ "$(git show plan/p/stack:k)" = 'k!' ] || fail "sync lost main's change without a record"
expect 4 "$CG" nope p
echo "crew-git: all pass"
