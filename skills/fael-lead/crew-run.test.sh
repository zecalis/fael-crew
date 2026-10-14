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
onset) git switch -q plan/p/s1; mkdir -p e; echo fix >e/x; git add e; git commit -qm "review fix on s1" ;;
dirty) echo junk >junk ;;
esac; } >/dev/null # claude -p --output-format json prints the result only
echo '{"total_cost_usd":0.25,"is_error":false,"result":"verdict: stub"}'
EOF
chmod +x "$T/bin/claude"
cat >"$T/bin/opencode" <<'EOF'
#!/bin/sh
# stub: run prints opencode's json events (the message is argv's last), session export a cost
[ "$1" = session ] && { echo '{"info":{"cost":0.5}}'; exit 0; }
printf '%s\n' "$@" >"$STUB_DIR/oc-argv"; printf '%s' "$OPENCODE_CONFIG_CONTENT" >"$STUB_DIR/oc-config"
{ case $STUB in
finish) echo "$STUB_UID" >"$STUB_UID"; git add -A; git commit -qm wip
  fael chunk note "$STUB_UID" "finished: $STUB_UID on opencode" ;;
esac; } >/dev/null
echo '{"type":"step_start","sessionID":"ses_x"}'
[ "$STUB" != error ] || { echo '{"type":"error","sessionID":"ses_x","error":{"message":"no route"}}'; exit 1; }
echo '{"type":"text","sessionID":"ses_x","part":{"text":"done"}}'
EOF
chmod +x "$T/bin/opencode"
export PATH="$T/bin:$PATH"

git init -q --bare "$T/origin.git"
git init -q -b main "$T/repo"
cd "$T/repo"
echo a >a; git add a; git commit -qm init
git remote add origin "$T/origin.git"; git push -q origin main; git fetch -q origin
git remote set-head origin main
for w in wt-t-agent-1 wt-t-agent-2 wt-t-agent-3; do git worktree add -q --detach "$T/$w" origin/main; done
fael plan new sim "test" --area dev >/dev/null
add() { fael chunk add "$1" --plan sim --label "$1" --scope "$1" --size "$2" --model haiku --brief "write $1" 2>/dev/null | tail -1; }
A=$(add fa S) B=$(add fb S) C=$(add fc M) D=$(add fd S)
fael chunk add fe --plan sim --label fe --scope e/ --size S --brief "write e/" >/dev/null 2>&1
for u in $A $B $C $D; do fael chunk approve "$u" >/dev/null; done

# refusals: no set yet, the main worktree (the owner's checkout, left as it was), a dirty one
expect 4 "$CR" work p 1 "$A" --in "$T/wt-t-agent-1"
has "no plan/p/s1" "$T/out"
git branch --no-track plan/p/s1 origin/main
h=$(git symbolic-ref HEAD)
expect 4 "$CR" work p 1 "$A" --in "$T/repo"
has "the main worktree" "$T/out"
[ "$(git symbolic-ref HEAD)" = "$h" ] && [ -z "$(git branch --list "plan/p/lane/$A")" ] ||
  fail "work moved the main worktree"
touch "$T/wt-t-agent-1/junk"
expect 4 "$CR" work p 1 "$A" --in "$T/wt-t-agent-1"
rm "$T/wt-t-agent-1/junk"

# finished: a commit, a finished: note, the run ended with its cost, the worktree detached
STUB=finish STUB_UID=$A expect 0 "$CR" work p 1 "$A" --in "$T/wt-t-agent-1" --model haiku
has "· finished · \$0.25 · 1 commits" "$T/out"
has "outside, unowned: $A" "$T/out"
has "last note: finished: $A works" "$T/out"
! grep -q Terminated "$T/out" || fail "the beat loop's kill leaked a job message"
has "Bash(git push *)" "$T/argv"
has "Read(./.env*)" "$T/argv"
has "haiku" "$T/argv"
has "Lead's rules:" "$T/stdin"
has "fael chunk note $A" "$T/stdin"
[ "$(show "$A" .run.ended)" != null ] || fail "run not ended"
[ "$(show "$A" .run.cost)" = 0.25 ] || fail "cost not kept"
[ "$(show "$A" .run.client)/$(show "$A" .run.model)" = claude/haiku ] || fail "run row lacks client or model"
! git -C "$T/wt-t-agent-1" symbolic-ref -q HEAD >/dev/null || fail "w1 still on the lane"

# waited, then a resume on the same lane: a note without finished: is a crash, so is a failed
# or erroring claude even after a finished: note
STUB=wait STUB_UID=$B expect 1 "$CR" work p 1 "$B" --in "$T/wt-t-agent-2"
has "wait: B=0 prints what?" "$T/out"
fael chunk answer "$B" "prints error" >/dev/null
STUB=step STUB_UID=$B expect 2 "$CR" work p 1 "$B" --in "$T/wt-t-agent-2"
has "· crashed ·" "$T/out"
STUB=fail STUB_UID=$B expect 2 "$CR" work p 1 "$B" --in "$T/wt-t-agent-2"
has "claude exit 3" "$T/out"
STUB=error STUB_UID=$B expect 2 "$CR" work p 1 "$B" --in "$T/wt-t-agent-2"
STUB=finish STUB_UID=$B expect 0 "$CR" work p 1 "$B" --in "$T/wt-t-agent-2"
[ "$(git rev-list --count plan/p/s1..plan/p/lane/$B)" = 1 ] || fail "resume left the lane"
# no --model: the approval's model, else the chunk's hint, reaches claude and the run row
[ "$(show "$B" .run.model)" = haiku ] || fail "run row lacks the hint's model"
has haiku "$T/argv"

# beat: a slow worker is seen while it runs; started from outside the repo
(cd / && STUB=slow STUB_UID=$D expect 0 "$CR" work p 1 "$D" --in "$T/wt-t-agent-3")
[ "$(cat "$T/seen")" != null ] || fail "no beat while the worker ran"
has "outside: none" "$T/out"

# opencode: an opencode approval runs opencode in place of claude, under the same deny list,
# and the run row keeps its client, model and the session export's cost
O=$(add fo S)
fael chunk approve "$O" --client opencode --model oc/m >/dev/null
rm -f "$T/argv"
STUB=finish STUB_UID=$O expect 0 "$CR" work p 1 "$O" --in "$T/wt-t-agent-3"
has "· finished · \$0.50 · 1 commits" "$T/out"
[ ! -e "$T/argv" ] || fail "an opencode lane ran claude"
has "--standalone" "$T/oc-argv"
has "oc/m" "$T/oc-argv"
has "Lead's rules:" "$T/oc-argv"
has '"git push *":"deny"' "$T/oc-config"
has '".env*":"deny"' "$T/oc-config"
[ "$(show "$O" .run.client)/$(show "$O" .run.model)/$(show "$O" .run.cost)" = opencode/oc/m/0.5 ] ||
  fail "opencode run row: $(show "$O" .run)"
STUB=error STUB_UID=$O expect 2 "$CR" work p 1 "$O" --in "$T/wt-t-agent-3"
has "opencode exit 1" "$T/out"

# fael refuses a chunk another run holds: back to G2, the worktree left detached
git -C "$T/wt-t-agent-3" switch -q --detach
(cd "$T/wt-t-agent-3" && CLAUDE_CODE_SESSION_ID=x fael chunk start "$C" >/dev/null)
expect 4 "$CR" work p 1 "$C" --in "$T/wt-t-agent-1"
has "fael refused the start" "$T/out"
! git -C "$T/wt-t-agent-1" symbolic-ref -q HEAD >/dev/null || fail "w1 left on the refused lane"

# review: S lanes take sonnet, set 1 reviews against origin/main, a fix commit stays on HEAD
expect 4 "$CR" review p 1 --in "$T/wt-t-agent-1"
STUB=fix expect 0 "$CR" review p 1 --in "$T/wt-t-agent-1" --lanes "$A,$B"
has sonnet "$T/argv"
has "origin/main...plan/p/s1" "$T/stdin"
has "1 fix commits" "$T/out"
has "outside, unowned: a" "$T/out"
has "verdict: stub" "$T/out"
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s1
s=$(git rev-parse plan/p/s1)
STUB=onset expect 0 "$CR" review p 1 --in "$T/wt-t-agent-1" --lanes "$A,$C"
has opus "$T/argv"
has "1 fix commits" "$T/out"
has "outside, in sim/fe: e/x" "$T/out"
! git -C "$T/wt-t-agent-1" symbolic-ref -q HEAD >/dev/null || fail "review left w1 on a branch"
git branch -f plan/p/s1 "$s" # the reviewer moved s1; put it back for the cases below
git branch --no-track plan/p/stack origin/main
git -C "$T/wt-t-agent-1" switch -q --detach plan/p/s1
STUB=dirty expect 2 "$CR" review p 1 --in "$T/wt-t-agent-1" --lanes "$A"
has "plan/p/stack...plan/p/s1" "$T/stdin"
has "uncommitted: 1 files the reviewer left" "$T/out"
has "outside: none" "$T/out"
expect 4 "$CR" nope p 1

# done: the trailers crew-git land wrote, once origin holds the stack; a rerun skips
CG=$(dirname "$CR")/crew-git
rm "$T/wt-t-agent-1/junk"
# a pair: one lane, one run R for both halves; the worker writes outside its scope
P=$(add fp S) Q=$(add fq S)
printf '[{"op":"pair","chunks":["%s","%s"]}]' "$P" "$Q" | fael chunk apply --json - >/dev/null
for u in $P $Q; do fael chunk approve "$u" >/dev/null; done
STUB=finish STUB_UID=$P expect 0 "$CR" work p 1 "$P" --in "$T/wt-t-agent-1"
has "outside, unowned: $P" "$T/out"
[ "$(show "$Q" .run.id)" = "$(show "$P" .run.id)" ] || fail "the pair did not share one run"
for u in $A $B $P; do expect 0 "$CG" land p 1 "$u" -m "lane $u" --run "$(show "$u" .run.id)" --gate true --in "$T/wt-t-agent-2"; done
expect 0 "$CG" stack p 1 --gate true --in "$T/wt-t-agent-2"
expect 4 "$CR" done p --pr 5
has "crew-git ship first" "$T/out"
fael chunk note "$A" "kept x: the gate fails without it" >/dev/null
fael chunk note "$B" "finished: $B works, commit on plan/p/lane/$B, not pushed" >/dev/null
expect 0 "$CG" ship p --gate true --in "$T/wt-t-agent-2"
(cd / && expect 0 "$CR" done p --pr 5 --in "$T/wt-t-agent-2")
for u in $A $B $P $Q; do [ "$(show "$u" .state)" = done ] || fail "$u not done"; done
! grep -q 'outside,' "$T/out" || fail "done repeated the outside lines run end printed"
[ "$(show "$A" .handoff.text)" = "$A works · kept x: the gate fails without it" ] ||
  fail "hand-off is not A's finished: note and its kept note"
kB=$(git log --format=%h --grep "^lane $B\$" plan/p/stack)
[ "$(show "$B" .handoff.text)" = "$B works, commit on $kB (PR 5), not pushed" ] ||
  fail "hand-off still names B's deleted lane branch: $(show "$B" .handoff.text)"
[ "$(show "$Q" .handoff.text)" = "$P works" ] || fail "the pair's other half lost the lane's hand-off"
[ "$(show "$D" .state)" != done ] || fail "D done without a trailer"
expect 0 "$CR" done p --pr 5 --in "$T/wt-t-agent-2"
has "$A already done" "$T/out"
has "$Q already done" "$T/out"
# a trailer naming a run fael no longer holds: done stops non-zero, the chunk stays open
expect 0 "$CG" cut p 2
git -C "$T/wt-t-agent-2" switch -q --detach plan/p/s2
(cd "$T/wt-t-agent-2" && git commit -q --allow-empty -m "d" -m "Fael-Chunk: $D
Fael-Run: 01M4XXXXXXXXXXXXXXXXXXXXXX")
expect 0 "$CG" stack p 2 --gate true --in "$T/wt-t-agent-2"
expect 0 "$CG" ship p --gate true --in "$T/wt-t-agent-2"
expect 1 "$CR" done p --pr 5 --in "$T/wt-t-agent-2"
has "not 01M4XXXXXXXXXXXXXXXXXXXXXX" "$T/out"
[ "$(show "$D" .state)" != done ] || fail "D done under a run it no longer holds"

# scope: a path the brief names outside the scope (and project.shared) is listed; a label works
S1=$(fael chunk add fs --plan sim --label fs --scope s/ --size S --brief "Write s/a.sh and s/b/c.sh, then edit lib/x.sh and README.md." 2>/dev/null | tail -1)
mkdir -p .fael && echo README.md >.fael/shared
expect 0 "$CR" scope p "$S1"
has "unscoped fs: lib/x.sh" "$T/out"
! grep -q "s/a.sh\|README.md" "$T/out" || fail "scope listed a path inside the scope or shared"
expect 0 "$CR" scope p "$A"
has "unscoped: none" "$T/out"
rm .fael/shared

# drift: every crew-git / crew-run verb SKILL.md calls (a command starts a backtick span) is one
# the script takes
for v in $(grep -oE '`crew-(git|run) [a-z]+' "$(dirname "$CR")/SKILL.md" | tr -d '`' | sort -u | tr ' ' :); do
  ! "$(dirname "$CR")/${v%%:*}" "${v#*:}" p 1 x 2>&1 | grep -q 'unknown verb' ||
    fail "SKILL.md calls ${v%%:*} ${v#*:}, which the script does not take"
done
echo "crew-run: all pass"
