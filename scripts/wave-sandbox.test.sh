#!/bin/sh
# Check scripts/wave-sandbox.sh builds a sandbox the lead's helpers run on, with no claude: the
# build and its gate, pr.sh, crew-run scope on the leaked-cut trap, and crew-git from cut to the
# sync after the owner squash-merges the stack and main moves on (vela PR 502's shape).
# The rehearsal itself, a /fael-lead session with you as owner, is still the script's Run line.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
CR=$here/skills/fael-lead/crew-run CG=$here/skills/fael-lead/crew-git
# ponytail: under a temp dir fael's board skips the sandbox, which suits a build check
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
D=$T/sandbox
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -qF -- "$1" "$T/out" || { cat "$T/out" >&2; fail "no '$1'"; }; }

sh "$here/scripts/wave-sandbox.sh" "$D" >"$T/out" 2>&1 || { cat "$T/out" >&2; fail "build"; }
has "Sandbox ready"
export FAEL_STATE_DIR=$D/.state
cd "$D/calc"
./test.sh >/dev/null || fail "the skeleton fails its own gate"
uid() { fael plan export sim --json | jq -r --arg l "$1" '.chunks[] | select(.label == $l) | .uid'; }
[ "$(fael plan export sim --json | jq '.chunks | length')" = 5 ] || fail "plan sim lacks its 5 chunks"

# pr.sh pushes nothing: a branch origin lacks is refused
git branch unpushed
! ./pr.sh unpushed "t" </dev/null >/dev/null 2>&1 || fail "pr.sh took a branch origin lacks"

# the leaked-cut trap: sub's brief names calc/add.sh outside its scope; README.md is shared
"$CR" scope calc "$(uid sub)" >"$T/out" 2>&1 || { cat "$T/out" >&2; fail "crew-run scope"; }
has "unscoped sub: calc/add.sh"
! grep -q README.md "$T/out" || fail "scope listed the shared README.md"

# set 1 by hand (add), stacked, shipped and filed with pr.sh
git worktree add -q --detach "$D/wt-calc-agent-1" origin/main
git worktree add -q --detach "$D/wt-calc-agent-2" origin/main
A=$(uid add)
"$CG" cut calc 1 >/dev/null
git -C "$D/wt-calc-agent-2" switch -q -c "plan/calc/lane/$A" plan/calc/s1
(cd "$D/wt-calc-agent-2" && mkdir -p calc && printf 'echo $(($1 + $2))\n' > calc/add.sh && git add -A && git commit -qm "wip add")
git -C "$D/wt-calc-agent-2" switch -q --detach
"$CG" land calc 1 "$A" -m "feat(calc): add" --gate ./test.sh --in "$D/wt-calc-agent-1" >/dev/null
git -C "$D/wt-calc-agent-1" switch -q --detach plan/calc/s1
"$CG" stack calc 1 --gate ./test.sh --in "$D/wt-calc-agent-1" >/dev/null
"$CG" ship calc --gate ./test.sh --in "$D/wt-calc-agent-1" >/dev/null
[ "$(./pr.sh plan/calc/stack "feat(calc): add" </dev/null)" = 1 ] || fail "pr.sh did not file PR 1"

# the owner squash-merges it, main changes add.sh after, the head is deleted and pruned
git clone -q "$D/origin.git" "$T/owner"
(cd "$T/owner" && git merge -q --squash origin/plan/calc/stack >/dev/null && git commit -qm "squash PR 1" &&
  printf '# add A B\necho $(($1 + $2))\n' > calc/add.sh && git commit -qam "main moves on add" &&
  git push -q origin main :plan/calc/stack)
git fetch -q --prune origin
"$CG" sync calc --gate ./test.sh --in "$D/wt-calc-agent-1" >"$T/out" 2>&1 || { cat "$T/out" >&2; fail "sync after the merge"; }
has "stack merged into origin/main"
! git rev-parse -q --verify plan/calc/stack >/dev/null || fail "the merged stack is still here"
echo "wave-sandbox: all pass"
