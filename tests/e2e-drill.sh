#!/usr/bin/env bash
# tests/e2e-drill.sh — End-to-end drill of the parallel-session workflow.
#
# Simulates the full flagship flow with three sessions:
#   register (conductor add) -> isolate (worktree per session) ->
#   SessionStart hook links + injects context -> PostToolUse hook promotes
#   planning->coding on first edit -> commit + rebase -> done (unblock
#   notification) -> coordination session merges in dependency order ->
#   merged -> clear archives the sprint.
#
# Worktrees are created with claude-team when CLAUDE_TEAM points at the CLI
# (exercising the cross-tool contract), else with plain git worktree.
#
# Usage: bash tests/e2e-drill.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLI="$REPO_DIR/bin/claude-conductor"
HOOK="$REPO_DIR/bin/conductor-hook"
SESSION_START="$REPO_DIR/bin/conductor-session-start"

pass=0; fail=0; total=0
bold()  { printf '\033[1m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
red()   { printf '\033[31m%s\033[0m' "$*"; }

check() { # check <desc> <condition-exit-code>
  total=$((total + 1))
  if [[ "$2" -eq 0 ]]; then
    echo "  $(green "✓") $1"; pass=$((pass + 1))
  else
    echo "  $(red "✗") $1"; fail=$((fail + 1))
  fi
}

contains() { echo "$1" | grep -qF "$2"; }

DRILL=$(mktemp -d)
MARKER_DIR="${TMPDIR:-/tmp}"
rm -f "$MARKER_DIR"/.conductor-hook-drill-* 2>/dev/null
trap 'rm -rf "$DRILL"; rm -f "$MARKER_DIR"/.conductor-hook-drill-* 2>/dev/null' EXIT

echo ""
echo "$(bold "end-to-end drill: 3 sessions, worktrees, hooks, merge queue")"
echo "────────────────────────────────────"

# --- 1. Project + registration (coordination session) ---
MAIN="$DRILL/project"
git init -q "$MAIN"
git -C "$MAIN" config user.email "drill@test" >/dev/null
git -C "$MAIN" config user.name "Drill" >/dev/null
mkdir -p "$MAIN/api" "$MAIN/ui" "$MAIN/tests"
echo "base" > "$MAIN/api/base.txt"
git -C "$MAIN" add -A && git -C "$MAIN" commit -q -m "init"
DEFAULT_BRANCH=$(git -C "$MAIN" symbolic-ref --short HEAD)

(cd "$MAIN" && printf '\n' | "$CLI" init >/dev/null 2>&1)
(cd "$MAIN" && "$CLI" add --persona Akira --task "battles api" --files "api/" >/dev/null 2>&1)
(cd "$MAIN" && "$CLI" add --persona Sasha --task "battle ui" --files "ui/" >/dev/null 2>&1)
(cd "$MAIN" && "$CLI" add --persona Robin --task "battle tests" --files "tests/" --depends "#1" >/dev/null 2>&1)
git -C "$MAIN" add -A && git -C "$MAIN" commit -q -m "register sprint"

ROWS=$(sed -n '/^## Active Sessions/,/^## [^A]/p' "$MAIN/SESSIONS.md" | grep -cE '^\| *[0-9]+ *\|')
check "three sessions registered in SESSIONS.md" $([[ "$ROWS" == "3" ]]; echo $?)

BR1=$(cd "$MAIN" && "$CLI" status | grep -o 'session/1-akira[a-z0-9-]*' | head -1)
BR2=$(cd "$MAIN" && "$CLI" status | grep -o 'session/2-sasha[a-z0-9-]*' | head -1)
BR3=$(cd "$MAIN" && "$CLI" status | grep -o 'session/3-robin[a-z0-9-]*' | head -1)
check "branch names auto-generated for all three" $([[ -n "$BR1" && -n "$BR2" && -n "$BR3" ]]; echo $?)

# --- 2. Isolation: one worktree per session ---
make_worktree() { # make_worktree <branch> <path>
  if [[ -n "${CLAUDE_TEAM:-}" && -x "${CLAUDE_TEAM}" ]]; then
    (cd "$MAIN" && HOME="$DRILL/home" "$CLAUDE_TEAM" session start "$1" >/dev/null 2>&1)
    # claude-team puts worktrees under $HOME/.claude/worktrees/<project>/<branch-with-dashes>
    local wt="$DRILL/home/.claude/worktrees/$(basename "$MAIN")/$(echo "$1" | tr '/' '-')"
    [[ -d "$wt" ]] && ln -s "$wt" "$2"
  else
    git -C "$MAIN" worktree add -q "$2" -b "$1" "$DEFAULT_BRANCH"
  fi
}
mkdir -p "$DRILL/home/.claude"
make_worktree "$BR1" "$DRILL/wt1"
make_worktree "$BR2" "$DRILL/wt2"
make_worktree "$BR3" "$DRILL/wt3"
check "three isolated worktrees created" $([[ -d "$DRILL/wt1/" && -d "$DRILL/wt2/" && -d "$DRILL/wt3/" ]]; echo $?)
check "coordination checkout still on default branch" $([[ "$(git -C "$MAIN" symbolic-ref --short HEAD)" == "$DEFAULT_BRANCH" ]]; echo $?)

# --- 3. SessionStart hook: link + context per session ---
CTX1=$(printf '{"session_id":"drill-s1","cwd":"%s"}' "$(cd "$DRILL/wt1" && pwd -P)" | "$SESSION_START")
CTX2=$(printf '{"session_id":"drill-s2","cwd":"%s"}' "$(cd "$DRILL/wt2" && pwd -P)" | "$SESSION_START")
CTX3=$(printf '{"session_id":"drill-s3","cwd":"%s"}' "$(cd "$DRILL/wt3" && pwd -P)" | "$SESSION_START")
check "session 1 receives its identity and task" $(contains "$CTX1" "session #1 (Akira)"; echo $?)
check "session 3 context includes dependency" $(contains "$CTX3" "Depends on: #1"; echo $?)
LINKS=$(cat "$MAIN/.conductor-links.json" 2>/dev/null || echo "[]")
check "all three sessions auto-linked" $(python3 -c "
import json,sys
d = json.loads('''$LINKS''')
ids = {e['sessionId']: e['conductorNumber'] for e in d}
assert ids.get('drill-s1') == 1 and ids.get('drill-s2') == 2 and ids.get('drill-s3') == 3
" 2>/dev/null; echo $?)

# --- 4. Work + PostToolUse hook: planning -> coding ---
mkdir -p "$DRILL/wt1/api" "$DRILL/wt2/ui" "$DRILL/wt3/tests"
echo "endpoint" > "$DRILL/wt1/api/battles.txt"
echo "component" > "$DRILL/wt2/ui/battlelog.txt"
echo "test" > "$DRILL/wt3/tests/battles_test.txt"
for i in 1 2 3; do
  printf '{"session_id":"drill-s%s","cwd":"%s","tool_name":"Edit"}' "$i" "$(cd "$DRILL/wt$i" && pwd -P)" | "$HOOK"
done
STATUS_OUT=$(cd "$MAIN" && "$CLI" status)
CODING=$(echo "$STATUS_OUT" | grep -c '\[coding\]')
check "PostToolUse hook promoted all three to coding" $([[ "$CODING" == "3" ]]; echo $?)

# --- 5. Complete: commit, rebase, done, unblock notification ---
for i in 1 2 3; do
  git -C "$DRILL/wt$i" add -A && git -C "$DRILL/wt$i" commit -q -m "session $i work"
  git -C "$DRILL/wt$i" rebase -q "$DEFAULT_BRANCH" >/dev/null 2>&1
done
DONE1=$(cd "$MAIN" && "$CLI" d 1 2>&1)
check "session 1 marked done" $(sed -n '/^## Active Sessions/,/^## [^A]/p' "$MAIN/SESSIONS.md" | grep -E '^\| *1 *\|' | grep -q '| done |'; echo $?)
check "completing #1 unblocks Robin (#3)" $(contains "$DONE1" "unblocked"; echo $?)
(cd "$MAIN" && "$CLI" d 2 >/dev/null 2>&1; "$CLI" d 3 >/dev/null 2>&1)

# --- 6. Coordination session merges in dependency order (no checkout) ---
MERGE_OK=0
git -C "$MAIN" merge -q --no-edit "$BR1" >/dev/null 2>&1 || MERGE_OK=1
git -C "$MAIN" merge -q --no-edit "$BR2" >/dev/null 2>&1 || MERGE_OK=1
git -C "$MAIN" merge -q --no-edit "$BR3" >/dev/null 2>&1 || MERGE_OK=1
check "merges land in dependency order without conflicts" "$MERGE_OK"
check "all session work present on default branch" $([[ -f "$MAIN/api/battles.txt" && -f "$MAIN/ui/battlelog.txt" && -f "$MAIN/tests/battles_test.txt" ]]; echo $?)
check "coordination checkout never left default branch" $([[ "$(git -C "$MAIN" symbolic-ref --short HEAD)" == "$DEFAULT_BRANCH" ]]; echo $?)

for i in 1 2 3; do (cd "$MAIN" && "$CLI" m "$i" >/dev/null 2>&1); done
check "all three marked merged" $([[ "$(sed -n '/^## Active Sessions/,/^## [^A]/p' "$MAIN/SESSIONS.md" | grep -c '| merged |')" == "3" ]]; echo $?)

# --- 7. Archive ---
(cd "$MAIN" && printf 'y\n' | "$CLI" clear >/dev/null 2>&1)
LEFT=$(sed -n '/^## Active Sessions/,/^## [^A]/p' "$MAIN/SESSIONS.md" | grep -cE '^\| *[0-9]+ *\|')
check "clear archives the sprint (0 active sessions)" $([[ "$LEFT" == "0" ]]; echo $?)

echo "────────────────────────────────────"
if [[ "$fail" -eq 0 ]]; then
  echo "$(green "All $total drill checks passed.")"
  exit 0
else
  echo "$(red "$fail of $total drill checks failed.")"
  exit 1
fi
