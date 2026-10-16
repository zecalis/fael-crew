#!/bin/sh
# gate.sh — the repo's one gate (.fael/worktree.json "gate"): sh -n on every shell script, then every
# *.test.sh, then shellcheck when installed. One ✓/✗ line per step by its own exit code; a failing
# step adds its last 40 lines. Exit 1 if any step failed.
cd "$(dirname "$0")/.." || exit 1
out=$(mktemp) && trap 'rm -f "$out"' EXIT
bad=0
step() { # name cmd...
  n=$1; shift
  if "$@" >"$out" 2>&1; then echo "✓ $n"; else echo "✗ $n"; tail -n 40 "$out"; bad=1; fi
}
scripts=
for f in bin/* skills/fael-lead/* scripts/*; do
  [ -f "$f" ] && head -n 1 "$f" | grep -q '^#!.*sh' && scripts="$scripts $f"
done
for f in $scripts; do step "sh -n $f" sh -n "$f"; done
for f in $scripts; do
  case $f in *.test.sh) step "$f" sh "$f" ;; esac
done
if command -v shellcheck >/dev/null; then
  for f in $scripts; do step "shellcheck $f" shellcheck "$f"; done
else
  echo "- shellcheck skipped: not installed"
fi
exit $bad
