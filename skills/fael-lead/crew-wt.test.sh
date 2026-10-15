#!/bin/sh
# Self-check for crew-wt: a throwaway repo and bare origin whose .fael/worktree.json logs each hook;
# each case asserts the exit code, the slots and what is left on disk.
# Usage: skills/fael-lead/crew-wt.test.sh (exit 0 = all pass)
set -eu
CW=$(cd "$(dirname "$0")" && pwd)/crew-wt
T=$(cd "$(mktemp -d)" && pwd -P); trap 'kill $pid 2>/dev/null || :; rm -rf "$T"' EXIT
pid=
fail() { echo "FAIL: $*" >&2; exit 1; }
expect() {
  want=$1; shift; got=0
  "$@" >"$T/out" 2>&1 || got=$?
  [ "$got" = "$want" ] || { cat "$T/out" >&2; fail "$* exited $got, want $want"; }
}
slots() { jq -cS . "$T/repo/.git/fael/slots.json"; }
# sl <b>: the slot crew-feat-<b> holds (parallel new hands them out in any order)
sl() { slots | jq -r --arg p "$T/crew-feat-$1" 'to_entries[] | select(.value == $p) | .key'; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export LOG=$T/hooks.log

git init -q --bare "$T/origin.git"
git init -q -b main "$T/repo"
cd "$T/repo"
mkdir .fael
# setup fails when FAIL_SETUP is set, after it made something teardown has to clean
cat > .fael/worktree.json <<'EOF'
{ "setup": "echo \"setup $FAEL_WT_SLOT $FAEL_WT_PATH $PWD\" >> \"$LOG\"; [ -z \"${FAIL_SETUP:-}\" ]",
  "teardown": "echo \"teardown $FAEL_WT_SLOT $FAEL_WT_PATH $([ \"$PWD\" = \"$FAEL_WT_MAIN\" ] && echo main)\" >> \"$LOG\"" }
EOF
git add -A; git commit -qm init
git remote add origin "$T/origin.git"; git push -q origin main; git fetch -q origin

# parallel new: four calls at once, four distinct slots, each setup in its own worktree
for b in a b c d; do "$CW" new "$T/repo" "feat/$b" >"$T/new-$b" 2>&1 & done
wait
[ "$(slots | jq -r 'keys | join(" ")')" = "1 2 3 4" ] &&
  [ "$(slots | jq -r '[.[]] | sort | join(" ")')" = "$T/crew-feat-a $T/crew-feat-b $T/crew-feat-c $T/crew-feat-d" ] ||
  { cat "$T"/new-*; fail "parallel new: $(slots)"; }
for b in a b c d; do
  n=$(sl $b)
  grep -qx "setup $n $T/crew-feat-$b $T/crew-feat-$b" "$LOG" || fail "setup for $b: no slot $n line in its worktree"
  [ "$(git -C "$T/crew-feat-$b" symbolic-ref --short HEAD)" = "feat/$b" ] || fail "crew-feat-$b not on feat/$b"
done
[ ! -e "$T/repo/.git/fael/slots.json.lock" ] || fail "lock left behind"

# a failed setup leaves nothing behind: no worktree, no branch, no slot; teardown cleaned up
before=$(slots)
(export FAIL_SETUP=1; expect 2 "$CW" new "$T/repo" feat/x) # a subshell: sh keeps VAR=x before a function
[ ! -e "$T/crew-feat-x" ] || fail "failed setup left its worktree"
git rev-parse -q --verify feat/x >/dev/null && fail "failed setup left its branch"
[ "$(slots)" = "$before" ] || fail "failed setup left its slot: $(slots)"
grep -qx "teardown 5 $T/crew-feat-x main" "$LOG" || fail "failed setup ran no teardown"
[ "$(git worktree list | wc -l)" -eq 5 ] || fail "worktree list changed"

# rm refuses a dirty worktree, then a live one (a claude process with its cwd inside)
touch "$T/crew-feat-a/junk"
expect 4 "$CW" rm "$T/crew-feat-a"
grep -q 'uncommitted work' "$T/out" || fail "dirty not named"
rm "$T/crew-feat-a/junk"
mkdir "$T/bin"; cp /bin/sleep "$T/bin/claude"; codesign -s - -f "$T/bin/claude" 2>/dev/null # a copy unsigned is killed
(cd "$T/crew-feat-a" && exec "$T/bin/claude" 60) & pid=$!
sleep 1
expect 4 "$CW" rm "$T/crew-feat-a"
grep -q 'claude process runs' "$T/out" || fail "live not named"
[ -d "$T/crew-feat-a" ] && grep -q crew-feat-a "$T/repo/.git/fael/slots.json" || fail "refused rm removed something"
grep -q "teardown $(sl a) " "$LOG" && fail "refused rm ran teardown"
kill $pid; wait $pid 2>/dev/null || :; pid=
# by slot number from inside the repo, then by path from anywhere
a=$(sl a)
expect 0 "$CW" rm "$a"
[ ! -e "$T/crew-feat-a" ] || fail "rm left the worktree"
grep -qx "teardown $a $T/crew-feat-a main" "$LOG" || fail "rm: no teardown in the main checkout"
[ "$(slots | jq -r --arg a "$a" 'has($a)')" = false ] || fail "rm kept slot $a"
(cd / && expect 0 "$CW" rm "$T/crew-feat-b")
expect 4 "$CW" rm "$T/repo"

# gc tears down a slot whose worktree was deleted by hand, then new reuses the lowest free slot
c=$(sl c) d=$(sl d)
rm -rf "$T/crew-feat-c"
expect 0 "$CW" gc "$T/repo"
grep -qx "freed slot $c · $T/crew-feat-c" "$T/out" || fail "gc did not print slot $c"
grep -qx "teardown $c $T/crew-feat-c main" "$LOG" || fail "gc ran no teardown for slot $c"
[ "$(slots | jq -r 'keys | join(" ")')" = "$d" ] || fail "gc: $(slots)"
git worktree list | grep -q crew-feat-c && fail "gc did not prune"
expect 0 "$CW" gc "$T/repo"
[ ! -s "$T/out" ] || fail "second gc freed something: $(cat "$T/out")"

# adopt: a worktree the desktop app made, --at and --from on new, ls
git worktree add -q -b app "$T/repo/.claude/worktrees/app" origin/main
e=$(slots | jq -r '[range(1; 9)] - (keys | map(tonumber)) | first') # the lowest free slot
(cd "$T/repo/.claude/worktrees/app" && expect 0 "$CW" adopt)
grep -qx "slot $e · $T/repo/.claude/worktrees/app" "$T/out" || fail "adopt did not take slot $e"
expect 0 "$CW" adopt "$T/repo/.claude/worktrees/app"
grep -q already "$T/out" || fail "a second adopt leased again"
git -C "$T/crew-feat-d" commit -q --allow-empty -m d
f=$(slots | jq -r '[range(1; 9)] - (keys | map(tonumber)) | first')
expect 0 "$CW" new "$T/repo" lane --at "$T/elsewhere" --from feat/d
[ "$(git -C "$T/elsewhere" log -1 --format=%s)" = d ] || fail "--from ignored"
expect 0 "$CW" ls "$T/repo"
[ "$(cat "$T/out")" = "$(printf '%s\n' "$e · $T/repo/.claude/worktrees/app · app" "$f · $T/elsewhere · lane" \
  "$d · $T/crew-feat-d · feat/d" | sort -n)" ] || { cat "$T/out" >&2; fail "ls"; }

# no .fael/worktree.json: the git part alone, still a slot
rm -rf .fael; git commit -qam "no hooks"; git push -q origin main; git fetch -q origin
: > "$LOG"
expect 0 "$CW" new "$T/repo" plain
expect 0 "$CW" rm "$T/crew-plain"
[ ! -s "$LOG" ] || fail "a hook ran with no worktree.json"
expect 4 "$CW" nope
echo "crew-wt: all pass"
