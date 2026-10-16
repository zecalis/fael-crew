#!/bin/sh
# Self-check for crew-pr: a throwaway repo over a local bare remote, a stub gh on PATH whose $STUB
# says what it does, its own fael state. Usage: skills/fael-lead/crew-pr.test.sh (exit 0 = all pass)
set -eu
CP=$(cd "$(dirname "$0")" && pwd)/crew-pr
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
expect() {
  want=$1; shift; got=0
  "$@" >"$T/out" 2>&1 || got=$?
  [ "$got" = "$want" ] || { cat "$T/out" >&2; fail "$* exited $got, want $want"; }
}
has() { grep -qF -- "$1" "$2" || { cat "$2" >&2; fail "no '$1' in $2"; }; }
hasnt() { ! grep -qF -- "$1" "$2" || { cat "$2" >&2; fail "'$1' in $2"; }; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export FAEL_STATE_DIR=$T/.state STUB_DIR=$T STUB=

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
git remote set-head origin main
fael plan new sim "test" --area dev >/dev/null
U=$(fael chunk add fa --plan sim --label fa --scope fa --size S --model haiku --brief "write fa" 2>/dev/null | tail -1)
fael chunk approve "$U" >/dev/null

# refused: on main, no commits, a detached HEAD, a dirty tree
expect 4 "$CP"; has "on main" "$T/out"
git switch -q -c feat/one
expect 4 "$CP"; has "no commits" "$T/out"
echo one >one; git add one; git commit -qm "feat(one): add one"
echo dirt >>one
expect 4 "$CP"; has "uncommitted" "$T/out"
git restore one
expect 4 "$CP" --bogus
expect 4 "$CP" --body "$T/nope"

# no gate in .fael/worktree.json: refused, nothing pushed
expect 4 "$CP"; has "no gate in" "$T/out"
mkdir -p .fael
printf '{"gate": "echo g >>%s/gates", "e2e": "echo e >>%s/gates; echo boom; exit $E2E"}' "$T" "$T" >.fael/worktree.json
git add .fael; git commit -qm "chore: gates"
# two commits and no -m: the subjects and the shortstat, exit 4
expect 4 "$CP"
has "feat(one): add one" "$T/out"; has "2 files changed" "$T/out"; has "-m" "$T/out"

# --dry: title, body, gates; no gate run, nothing pushed
expect 0 "$CP" --dry -m "feat(one): one"
has "title: feat(one): one" "$T/out"; has "- feat(one): add one" "$T/out"
has "## Removed (from the diff)" "$T/out"; has "Generated with [Claude Code]" "$T/out"
has "gate: echo g" "$T/out"; has "e2e: echo e" "$T/out"
[ ! -e "$T/gates" ] || fail "--dry ran a gate"
[ -z "$(git ls-remote origin refs/heads/feat/one)" ] || fail "--dry pushed"

# a failed e2e: one line, the log tail, exit 2, nothing pushed, no PR
E2E=3 expect 2 "$CP" -m "feat(one): one"
has "gate ok" "$T/out"; has "e2e FAIL (log: " "$T/out"; has boom "$T/out"
[ -z "$(git ls-remote origin refs/heads/feat/one)" ] || fail "a failed gate pushed"
[ ! -s "$T/prs" ] || fail "a failed gate filed a PR"

# gh failing before the push of a PR: refused; gh create failing after the push: 5, rerun is safe
E2E=0 STUB=ghfail expect 4 "$CP" -m "feat(one): one"
E2E=0 STUB=createfail expect 5 "$CP" -m "feat(one): one"
has "rerun" "$T/out"
[ -n "$(git ls-remote origin refs/heads/feat/one)" ] || fail "branch not pushed before gh"
STUB=; echo "my body" >"$T/body.md"
E2E=0 expect 0 "$CP" -m "feat(one): one" --body "$T/body.md"
has "PR 1 https://github.com/o/r/pull/1" "$T/out"
[ "$(wc -l <"$T/out" | tr -d ' ')" = 3 ] || { cat "$T/out" >&2; fail "success output is not gate, e2e, PR"; }
has "feat(one): one" "$T/prs.1.title"
has "Generated with [Claude Code]" "$T/prs.1.md"; has "my body" "$T/prs.1.md"

# a rerun edits the open PR instead of opening a second
echo two >two; git add two; git commit -qm "feat(one): two"
E2E=0 expect 0 "$CP" -m "feat(one): one, two"
has "PR 1 " "$T/out"
[ "$(wc -l <"$T/prs" | tr -d ' ')" = 1 ] || fail "a rerun opened a second PR"
has "feat(one): one, two" "$T/prs.1.title"
has "- feat(one): two" "$T/prs.1.md"
hasnt "Fael-Chunk" "$T/prs.1.md"

# merged: refused with its own exit, even with the work pushed
sed 's/OPEN/MERGED/' "$T/prs" >"$T/prs.x"; mv "$T/prs.x" "$T/prs"
E2E=0 expect 3 "$CP" -m "feat(one): one, two"
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
E2E=0 expect 0 "$CP"
has "PR 2 " "$T/out"
has "feat(three): drop big" "$T/prs.2.title"
has "- deleted: big" "$T/prs.2.md"
has "Why: it was unused." "$T/prs.2.md"
hasnt "Fael-Chunk" "$T/prs.2.md"
[ "$(fael chunk show "$U" --json | jq -r .state)" = done ] || fail "the trailer's chunk is not done"
E2E=0 expect 0 "$CP"
has "PR 2 " "$T/out"

# --in works from any cwd
(cd "$T" && E2E=0 expect 0 "$CP" --in "$T/repo")
echo "crew-pr.test.sh: all pass"
