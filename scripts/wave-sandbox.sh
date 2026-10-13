#!/bin/sh
# Rehearse /fael-lead (G0-G8: sets, review, local stack, push pr) in a throwaway repo first.
# Usage: scripts/wave-sandbox.sh [dir]   (default: ~/fael-wave-sandbox; never under a temp
# dir — fael board skips those). Again from scratch: fael board --drop <dir>/calc; rm -rf <dir>.
# Builds a toy project "calc" — repo, bare origin, 3 worktrees — and a plan "sim" of five
# chunks, each made to hit one gate. No GitHub: ./pr.sh stands in for gh pr create, and the
# repo's AGENTS.md says so. Its fael.db is the sandbox's own; run through <dir>/sandbox.sh and
# fael's state (board registry, stats, the machine-wide running count) is too.
set -eu
DIR=${1:-$HOME/fael-wave-sandbox}
[ -e "$DIR" ] && { echo "$DIR exists — fael board --drop $DIR/calc; rm -rf $DIR" >&2; exit 1; }
mkdir -p "$DIR"
cat > "$DIR/sandbox.sh" <<'EOF'
#!/bin/sh
# Runs a command with the sandbox's own fael state; agents it starts inherit it.
#   ./sandbox.sh claude      ./sandbox.sh fael board
#   open -n <FaelBoard.app> --env FAEL_STATE_DIR=<this dir>/.state
export FAEL_STATE_DIR="$(cd "$(dirname "$0")" && pwd)/.state"
mkdir -p "$FAEL_STATE_DIR"
exec "$@"
EOF
chmod +x "$DIR/sandbox.sh"
export FAEL_STATE_DIR="$DIR/.state"
mkdir -p "$FAEL_STATE_DIR"
git init -q --bare "$DIR/origin.git"
git init -q -b main "$DIR/calc"
cd "$DIR/calc"

mkdir -p calc .fael
cat > README.md <<'EOF'
# calc

Tiny shell calculator. Each operation is `calc/<op>.sh A B` and prints the result.

## Operations
EOF
printf 'README.md\n' > .fael/shared
cat > AGENTS.md <<'EOF'
# calc — agent rules

Gates: `./test.sh` (exit 0). Commits and PRs in English.

No GitHub here. `push pr` = run the gates, then `./pr.sh <branch> "<title>" < body.md`: it
pushes the branch to origin, files the PR in origin.git/prs and prints its number N — use N
wherever a PR number goes (`fael chunk done --pr N`). Never merge: the owner does.
EOF
cat > pr.sh <<'EOF'
#!/bin/sh
# Stand-in for gh pr create: pushes <branch>, files the PR (body from stdin), prints its number.
set -eu
git push -q -f origin "$1"
p=$(git remote get-url origin)/prs
printf '%s\t%s\n' "$1" "$2" >> "$p"
n=$(wc -l < "$p" | tr -d ' ')
cat > "$p.$n.md"
echo "$n"
EOF
cat > test.sh <<'EOF'
#!/bin/sh
# Gate: every calc/*.sh that exists must give the right answer.
set -eu
t() { got=$(sh "calc/$1.sh" "$2" "$3"); [ "$got" = "$4" ] || { echo "FAIL $1 $2 $3: got '$got' want '$4'"; exit 1; }; }
[ -f calc/add.sh ] && t add 2 3 5 && t add -2 3 1
[ -f calc/mul.sh ] && t mul 4 5 20
[ -f calc/sub.sh ] && t sub 7 2 5
[ -f calc/div.sh ] && t div 8 2 4
[ -f calc/mod.sh ] && t mod 7 3 1
echo ok
EOF
chmod +x test.sh pr.sh
printf '.fael/log/\n' > .gitignore
git add -A
git commit -qm "calc skeleton"
git remote add origin "$DIR/origin.git"
git push -q origin main
# another PR the owner merges mid-run (G7.2): it touches only README's intro line
git switch -q -c owner-change
sed -i '' 's/^Tiny shell calculator\./Tiny POSIX shell calculator./' README.md
git commit -qam "docs: say POSIX"
git push -q origin owner-change
git switch -q main
git branch -q -D owner-change
for n in 1 2 3; do git worktree add -q "$DIR/w$n" -b "idle-$n"; done

fael plan new sim "Lead rehearsal: calc ops" --area dev >/dev/null
add() { fael chunk add "$1" --plan sim --label "$2" --scope "$3" --size S --model haiku --brief "$4" | tail -1; }
add "calc add" add calc/add.sh \
  "Write calc/add.sh: prints A+B (integers, negatives too). Gate: the repo's gates (AGENTS.md)."
add "calc mul" mul calc/mul.sh \
  "Write calc/mul.sh: prints A*B. Also add a line '- mul: A*B' under Operations in README.md. Gate: the repo's gates (AGENTS.md)."
add "calc sub" sub calc/sub.sh \
  "Write calc/sub.sh: prints A-B, implemented by calling calc/add.sh with -B. Add a usage comment at the top of calc/add.sh saying sub depends on it. Add '- sub: A-B' to README.md. Gate: the repo's gates (AGENTS.md)."
add "calc div" div calc/div.sh \
  "Write calc/div.sh: prints A/B as an integer. What it prints when B is 0 is the owner's call — not decided here. Add '- div: A/B' to README.md. Gate: the repo's gates (AGENTS.md)."
add "calc mod" mod calc/mod.sh \
  "Write calc/mod.sh: prints A mod B. Gate: the repo's gates (AGENTS.md)."

cat <<EOF

Sandbox ready: $DIR/calc (origin: $DIR/origin.git, worktrees: w1 w2 w3)

Traps — what a correct lead does (no lead:miss history, so sets are 2):
  set 1  add + mul        plan order, scopes disjoint; mul edits README.md (shared, nobody's)
  G6     every set        a fresh opus /fael-review high --fix on the set, never haiku
  G7.1   set 1 stacked    plan/calc/stack fast-forwards to s1, nothing pushed
  G7.2   before set 2     you merged owner-change: the lead rebases the stack onto origin/main
  set 2  sub + div        sub's brief edits calc/add.sh outside its scope: the row widens the
                          scope, and no --after add (add is in the stack, not done: an after
                          would block until push pr) — or sub waits; never --force
         div              B=0 is yours: the worker runs chunk wait, the lead asks you
         README.md        sub and div both append to it: the second to land conflicts there,
                          the lead resolves it, keeping both lines
  G0     mod alone        one ready chunk: the lead stops — you start it from the board
  push pr               ./pr.sh, one PR for the stack; then chunk done --pr N per stacked chunk
  G8     a miss           a lead:miss:<class> issue, never a skill edit; the lead:calc note

Run:  cd $DIR/calc && ../sandbox.sh claude   then   /fael-lead calc
You play the owner: answer each set table ( ok · ok 2 sonnet · ok Q1 b · no 3 ), answer div's
B=0, and say "push pr" when you want the stack shipped.
  merge another PR (after set 1):  git -C $DIR/origin.git update-ref refs/heads/main refs/heads/owner-change
  merge the stack's PR:            git -C $DIR/origin.git update-ref refs/heads/main refs/heads/plan/calc/stack
EOF
