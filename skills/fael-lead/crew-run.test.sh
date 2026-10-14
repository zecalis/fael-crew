#!/bin/sh
# Self-check for crew-run: a throwaway repo with its own fael state and a stub claude on PATH
# whose $STUB says what the worker does. Usage: skills/fael-lead/crew-run.test.sh (exit 0 = all pass)
set -eu
CR=$(cd "$(dirname "$0")" && pwd)/crew-run
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
expect() {
  want=$1; shift; got=0
  "$@" >"$T/out" 2>&1 || got=$?
  [ "$got" = "$want" ] || { cat "$T/out" >&2; fail "$* exited $got, want $want"; }
}
has() { grep -qF -- "$1" "$2" || { cat "$2" >&2; fail "no '$1' in $2"; }; }
show() { fael chunk show "$1" --json | jq -r "$2"; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export FAEL_STATE_DIR=$T/.state STUB_DIR=$T CREW_RUN_BEAT=1 STUB= STUB_UID=

# the board's stalled threshold is 30 min: the default beat must land inside it
b=$(sed -n 's/^beat=\${CREW_RUN_BEAT:-\([0-9]*\)}$/\1/p' "$CR")
[ -n "$b" ] && [ "$b" -lt 1800 ] || fail "default beat '$b' not under the board's 1800 s"

mkdir "$T/bin"
cat >"$T/bin/claude" <<'EOF'
#!/bin/sh
# stub: argv and stdin kept; $STUB is what the worker does, $STUB_UID its chunk
printf '%s\n' "$@" >"$STUB_DIR/argv"; cat >"$STUB_DIR/stdin"
{ case $STUB in
finish) echo "$STUB_UID" >"$STUB_UID"; git add -A; git commit -qm wip
  fael chunk note "$STUB_UID" "finished: $STUB_UID works" ;;
wait) fael chunk wait "$STUB_UID" "B=0 prints what?" --on owner >/dev/null ;;
step) fael chunk note "$STUB_UID" "step 1; next step 2" ;;
fail) echo boom >&2; exit 3 ;;
error) echo '{"is_error":true}'; exit 0 ;;
slow) sleep 3; fael chunk show "$STUB_UID" --json | jq -r '.run.last_seen' >"$STUB_DIR/seen"
  fael chunk note "$STUB_UID" "finished: slow" ;;
fix) echo fix >>a; git commit -qam "review fix" ;;
dirty) echo junk >junk ;;
esac; } >/dev/null # claude -p --output-format json prints the result only
echo '{"total_cost_usd":0.25,"is_error":false}'
EOF
chmod +x "$T/bin/claude"
export PATH="$T/bin:$PATH"

git init -q --bare "$T/origin.git"
git init -q -b main "$T/repo"
cd "$T/repo"
echo a >a; git add a; git commit -qm init
git remote add origin "$T/origin.git"; git push -q origin main; git fetch -q origin
git remote set-head origin main
for w in w1 w2 w3; do git worktree add -q --detach "$T/$w" origin/main; done
fael plan new sim "test" --area dev >/dev/null
add() { fael chunk add "$1" --plan sim --label "$1" --scope "$1" --size "$2" --model haiku --brief "write $1" 2>/dev/null | tail -1; }
A=$(add fa S) B=$(add fb S) C=$(add fc M) D=$(add fd S)
for u in $A $B $C $D; do fael chunk approve "$u" >/dev/null; done

# refusals: no set yet, the caller's own worktree, a dirty one
expect 4 "$CR" work p 1 "$A" --in "$T/w1"
has "no plan/p/s1" "$T/out"
git branch --no-track plan/p/s1 origin/main
expect 4 "$CR" work p 1 "$A" --in "$T/repo"
touch "$T/w1/junk"
expect 4 "$CR" work p 1 "$A" --in "$T/w1"
rm "$T/w1/junk"

# finished: a commit, a finished: note, the run ended with its cost, the worktree detached
STUB=finish STUB_UID=$A expect 0 "$CR" work p 1 "$A" --in "$T/w1" --model haiku
has "· finished · \$0.25 · 1 commits" "$T/out"
has "last note: finished: $A works" "$T/out"
! grep -q Terminated "$T/out" || fail "the beat loop's kill leaked a job message"
has "Bash(git push *)" "$T/argv"
has "Read(./.env*)" "$T/argv"
has "haiku" "$T/argv"
has "Lead's rules:" "$T/stdin"
has "fael chunk note $A" "$T/stdin"
[ "$(show "$A" .run.ended)" != null ] || fail "run not ended"
[ "$(show "$A" .run.cost)" = 0.25 ] || fail "cost not kept"
! git -C "$T/w1" symbolic-ref -q HEAD >/dev/null || fail "w1 still on the lane"

# waited, then a resume on the same lane: a note without finished: is a crash, so is a failed
# or erroring claude even after a finished: note
STUB=wait STUB_UID=$B expect 1 "$CR" work p 1 "$B" --in "$T/w2"
has "wait: B=0 prints what?" "$T/out"
fael chunk answer "$B" "prints error" >/dev/null
STUB=step STUB_UID=$B expect 2 "$CR" work p 1 "$B" --in "$T/w2"
has "· crashed ·" "$T/out"
STUB=fail STUB_UID=$B expect 2 "$CR" work p 1 "$B" --in "$T/w2"
has "claude exit 3" "$T/out"
STUB=error STUB_UID=$B expect 2 "$CR" work p 1 "$B" --in "$T/w2"
STUB=finish STUB_UID=$B expect 0 "$CR" work p 1 "$B" --in "$T/w2"
[ "$(git rev-list --count plan/p/s1..plan/p/lane/$B)" = 1 ] || fail "resume left the lane"

# beat: a slow worker is seen while it runs
STUB=slow STUB_UID=$D expect 0 "$CR" work p 1 "$D" --in "$T/w3"
[ "$(cat "$T/seen")" != null ] || fail "no beat while the worker ran"

# fael refuses a chunk another run holds: back to G2, the worktree left detached
git -C "$T/w3" switch -q --detach
(cd "$T/w3" && CLAUDE_CODE_SESSION_ID=x fael chunk start "$C" >/dev/null)
expect 4 "$CR" work p 1 "$C" --in "$T/w1"
has "fael refused the start" "$T/out"
! git -C "$T/w1" symbolic-ref -q HEAD >/dev/null || fail "w1 left on the refused lane"

# review: S lanes take sonnet, set 1 reviews against origin/main, a fix commit stays on HEAD
expect 4 "$CR" review p 1 --in "$T/w1"
STUB=fix expect 0 "$CR" review p 1 --in "$T/w1" --lanes "$A,$B"
has sonnet "$T/argv"
has "origin/main...plan/p/s1" "$T/stdin"
has "1 fix commits" "$T/out"
git -C "$T/w1" switch -q --detach plan/p/s1
STUB=fix expect 0 "$CR" review p 1 --in "$T/w1" --lanes "$A,$C"
has opus "$T/argv"
git branch --no-track plan/p/stack origin/main
git -C "$T/w1" switch -q --detach plan/p/s1
STUB=dirty expect 2 "$CR" review p 1 --in "$T/w1" --lanes "$A"
has "plan/p/stack...plan/p/s1" "$T/stdin"
has "uncommitted: 1 files the reviewer left" "$T/out"
expect 4 "$CR" nope p 1
echo "crew-run: all pass"
