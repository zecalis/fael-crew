#!/bin/sh
# Rehearse a /fael-lead wave in a throwaway repo before running one on a real plan.
# Usage: scripts/wave-sandbox.sh [dir]   (default: ~/fael-wave-sandbox; never under a temp
# dir — fael board skips those). Done: fael board --drop <dir>/repo, then rm -rf <dir>.
# Builds a toy repo + bare origin + 3 worktrees and a plan "sim" of five chunks, each
# made to hit one path of the skill: clean merge, shared-file conflict, a leaked cut,
# a question the worker must ask, the 3-lane cap. Its fael.db is the sandbox's own; only fael board's
# machine-wide `running` count is shared with real work.
set -eu
DIR=${1:-$HOME/fael-wave-sandbox}
[ -e "$DIR" ] && { echo "$DIR exists — remove it or pass another dir" >&2; exit 1; }
mkdir -p "$DIR"
git init -q --bare "$DIR/origin.git"
git init -q -b main "$DIR/repo"
cd "$DIR/repo"

mkdir -p calc .fael
cat > README.md <<'EOF'
# calc

Tiny shell calculator. Each operation is `calc/<op>.sh A B` and prints the result.

## Operations
EOF
printf 'README.md\n' > .fael/shared
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
chmod +x test.sh
printf '.fael/log/\n' > .gitignore
git add -A
git commit -qm "calc skeleton"
git remote add origin "$DIR/origin.git"
git push -q origin main
for n in 1 2 3; do git worktree add -q "$DIR/w$n" -b "idle-$n"; done

fael plan new sim "Wave rehearsal: calc ops" --area dev >/dev/null
add() { fael chunk add "$1" --plan sim --label "$2" --scope "$3" --size S --model haiku --brief "$4" | tail -1; }
add "calc add" add calc/add.sh \
  "Write calc/add.sh: prints A+B (integers, negatives too). Gate: ./test.sh passes. Clean lane: expect a plain merge."
add "calc mul" mul calc/mul.sh \
  "Write calc/mul.sh: prints A*B. Also add a line '- mul: A*B' under Operations in README.md. Gate: ./test.sh."
add "calc sub" sub calc/sub.sh \
  "Write calc/sub.sh: prints A-B, implemented by calling calc/add.sh with -B. Add a usage comment at the top of calc/add.sh saying sub depends on it. Add '- sub: A-B' to README.md. Gate: ./test.sh."
add "calc div" div calc/div.sh \
  "Write calc/div.sh: prints A/B as an integer. What it prints when B is 0 is the owner's call — not decided here. Add '- div: A/B' to README.md. Gate: ./test.sh."
add "calc mod" mod calc/mod.sh \
  "Write calc/mod.sh: prints A mod B. Gate: ./test.sh."

cat <<EOF

Sandbox ready: $DIR/repo (origin: $DIR/origin.git, free worktrees: w1 w2 w3)

Traps — what a correct lead does:
  add   clean lane                     merges, gates pass
  mul   README.md is in .fael/shared;  the second of mul/div to merge conflicts there:
        div edits it too                 lead resolves it itself, keeps both lines
  sub   scope says sub.sh, brief edits add.sh
                                       preflight flags it (or the merge conflicts):
                                       lane out + chunk note + issue, file never repaired
  div   B=0 undecided                  worker runs chunk wait; lead asks you, never guesses
  mod   clean, last in plan order      cap is 3 lanes (add mul div): mod waits for wave 2

Run:  cd $DIR/repo && claude   then   /fael-lead sim
Sandbox has no GitHub: the lead sees it at step 1, pushes the wave branch and runs chunk done
without --pr, so lanes sit in review. To play the merge before wave 2:
  git push origin origin/plan/sim/w1:main   then tell the lead "w1 merged" — it accepts the lanes
You play the owner: answer the wave table with  ok  (or  ok 2 sonnet,  no 3) — the lead approves
EOF
