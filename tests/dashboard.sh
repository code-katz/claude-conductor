#!/usr/bin/env bash
# tests/dashboard.sh — Test suite for generate-dashboard
# Usage: bash tests/dashboard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DASH="$REPO_DIR/bin/generate-dashboard"

# Test counters
pass=0
fail=0
total=0

# Test helpers
bold()  { printf '\033[1m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
red()   { printf '\033[31m%s\033[0m' "$*"; }
dim()   { printf '\033[2m%s\033[0m' "$*"; }

assert_exit() {
  local desc="$1"
  local expected="$2"
  shift 2
  total=$((total + 1))
  if "$@" >/dev/null 2>&1; then
    actual=0
  else
    actual=$?
  fi
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  $(green "✓") $desc"
    pass=$((pass + 1))
  else
    echo "  $(red "✗") $desc (expected exit $expected, got $actual)"
    fail=$((fail + 1))
  fi
}

assert_file_exists() {
  local desc="$1"
  local path="$2"
  total=$((total + 1))
  if [[ -f "$path" ]]; then
    echo "  $(green "✓") $desc"
    pass=$((pass + 1))
  else
    echo "  $(red "✗") $desc (file not found: $path)"
    fail=$((fail + 1))
  fi
}

assert_file_contains() {
  local desc="$1"
  local path="$2"
  local expected="$3"
  total=$((total + 1))
  if grep -qF "$expected" "$path" 2>/dev/null; then
    echo "  $(green "✓") $desc"
    pass=$((pass + 1))
  else
    echo "  $(red "✗") $desc"
    echo "       Expected file to contain: $expected"
    fail=$((fail + 1))
  fi
}

assert_file_not_contains() {
  local desc="$1"
  local path="$2"
  local unexpected="$3"
  total=$((total + 1))
  if ! grep -qF "$unexpected" "$path" 2>/dev/null; then
    echo "  $(green "✓") $desc"
    pass=$((pass + 1))
  else
    echo "  $(red "✗") $desc"
    echo "       Expected file NOT to contain: $unexpected"
    fail=$((fail + 1))
  fi
}

# Setup: create a temp directory with a git repo
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

echo ""
echo "$(bold "generate-dashboard test suite")"
echo "────────────────────────────────────"
echo ""

# --- Helper: create a standard SESSIONS.md ---
create_sessions() {
  cat > SESSIONS.md << 'EOF'
# MyProject — Session Conductor

Active coordination view for parallel Claude Code sessions.

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes | Activity |
|---|---------|------|-------|--------|---------|------------|-------|----------|
| 1 | Akira | Build API endpoints | app/routers/ | coding | 2026-03-28 14:00 | — | API contracts defined | |
| 2 | Sasha | Build UI wizard | frontend/src/ | blocked | 2026-03-28 14:05 | #1 | Waiting on API | |
| 3 | Robin | Write test suite | tests/ | planning | 2026-03-28 14:10 | — | | |

## Merge Order

1. Session #1 first (defines API types)
2. Session #2 after #1 (consumes API in UI)
3. Session #3 independent

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|
| 0 | Toni | Draft GTM plan | docs/gtm/ | 1h 30m | 2026-03-28 12:00 | done |

## Session Log

### [2026-03-28 14:00] Session #1 registered
EOF
}

# -----------------------------------------------
# Test 1: exits 0 with valid SESSIONS.md
# -----------------------------------------------
echo "$(bold "Basic generation")"

create_sessions
assert_exit "exits 0 with valid SESSIONS.md" 0 "$DASH"

echo ""

# -----------------------------------------------
# Test 2: HTML file is created
# -----------------------------------------------
echo "$(bold "File creation")"

rm -f .conductor-dashboard.html
create_sessions
"$DASH" > /dev/null 2>&1
assert_file_exists "creates .conductor-dashboard.html" ".conductor-dashboard.html"

echo ""

# -----------------------------------------------
# Test 3-9: HTML content checks
# -----------------------------------------------
echo "$(bold "HTML content")"

assert_file_contains "contains project name" ".conductor-dashboard.html" "MyProject"
assert_file_contains "contains session persona (Akira)" ".conductor-dashboard.html" "Akira"
assert_file_contains "contains session task text" ".conductor-dashboard.html" "Build API endpoints"
assert_file_contains "contains status text (coding)" ".conductor-dashboard.html" "coding"
assert_file_contains "contains conductor-version meta tag" ".conductor-dashboard.html" 'conductor-version'
assert_file_contains "contains dark theme background" ".conductor-dashboard.html" "#141413"
assert_file_contains "contains Google Fonts link" ".conductor-dashboard.html" "fonts.googleapis.com"

echo ""

# -----------------------------------------------
# Test 10: Merge order content
# -----------------------------------------------
echo "$(bold "Merge order")"

assert_file_contains "contains merge order content" ".conductor-dashboard.html" "Session #1 first"

echo ""

# -----------------------------------------------
# Test 11: Completed session data
# -----------------------------------------------
echo "$(bold "Completed sessions")"

assert_file_contains "contains completed session persona" ".conductor-dashboard.html" "Toni"
assert_file_contains "contains completed session task" ".conductor-dashboard.html" "Draft GTM plan"

echo ""

# -----------------------------------------------
# Test 12: Exits 1 when no SESSIONS.md
# -----------------------------------------------
echo "$(bold "Error handling")"

rm -f SESSIONS.md
assert_exit "exits 1 when no SESSIONS.md exists" 1 "$DASH"

echo ""

# -----------------------------------------------
# Test 13: Empty active sessions
# -----------------------------------------------
echo "$(bold "Edge cases")"

cat > SESSIONS.md << 'EOF'
# EmptyProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes | Activity |
|---|---------|------|-------|--------|---------|------------|-------|----------|

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$DASH" > /dev/null 2>&1
assert_file_contains "shows no-sessions message when empty" ".conductor-dashboard.html" "No active sessions"

# Restore and regenerate for next tests
create_sessions
"$DASH" > /dev/null 2>&1

echo ""

# -----------------------------------------------
# Test 14: Dependency display
# -----------------------------------------------
echo "$(bold "Dependencies")"

assert_file_contains "shows dependency info" ".conductor-dashboard.html" "Depends on:"
assert_file_contains "shows dependency value (#1)" ".conductor-dashboard.html" "#1"

echo ""

# -----------------------------------------------
# Test 15: Accepts explicit path argument
# -----------------------------------------------
echo "$(bold "Path argument")"

mkdir -p subdir
cp SESSIONS.md subdir/SESSIONS.md
assert_exit "accepts explicit SESSIONS.md path" 0 "$DASH" subdir/SESSIONS.md
assert_file_exists "creates dashboard next to provided SESSIONS.md" "subdir/.conductor-dashboard.html"

echo ""

# -----------------------------------------------
# UX improvements
# -----------------------------------------------
echo "$(bold "Icon size")"

assert_file_contains "persona icons are 54px" ".conductor-dashboard.html" "width: 54px"

echo ""

echo "$(bold "Elapsed time")"

assert_file_contains "session cards have data-started attribute" ".conductor-dashboard.html" "data-started="
assert_file_contains "HTML contains formatElapsed function" ".conductor-dashboard.html" "formatElapsed"
assert_file_contains "HTML contains card-elapsed class" ".conductor-dashboard.html" "card-elapsed"

echo ""

echo "$(bold "Fade-in refresh")"

assert_file_contains "HTML contains opacity transition" ".conductor-dashboard.html" "transition: opacity"
assert_file_contains "fetch polling present for live updates" ".conductor-dashboard.html" "pollForChanges"

echo ""

echo "$(bold "Activity status")"

# Create fixture with activity in Activity column
cat > SESSIONS.md << 'EOF'
# MyProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes | Activity |
|---|---------|------|-------|--------|---------|------------|-------|----------|
| 1 | Akira | Build API | app/ | coding | 2026-03-28 14:00 | | | writing tests |
| 2 | Sasha | Build UI | src/ | blocked | 2026-03-28 14:05 | #1 | | needs response |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$DASH" > /dev/null 2>&1

assert_file_contains "activity text rendered on card" ".conductor-dashboard.html" "card-activity"
assert_file_contains "activity shows text content" ".conductor-dashboard.html" "writing tests"
assert_file_contains "needs response gets urgent class" ".conductor-dashboard.html" "card-activity--urgent"

echo ""

# --- Summary ---
echo "────────────────────────────────────"
if [[ $fail -eq 0 ]]; then
  echo "$(green "All $total tests passed.")"
else
  echo "$(red "$fail of $total tests failed.")"
fi
echo ""

exit $fail
