#!/usr/bin/env bash
# tests/run.sh — Test suite for claude-conductor
# Usage: bash tests/run.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLI="$REPO_DIR/bin/claude-conductor"

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

assert_output_contains() {
  local desc="$1"
  local expected="$2"
  shift 2
  total=$((total + 1))
  local output
  output=$("$@" 2>&1) || true
  if echo "$output" | grep -qF "$expected"; then
    echo "  $(green "✓") $desc"
    pass=$((pass + 1))
  else
    echo "  $(red "✗") $desc"
    echo "       Expected output to contain: $expected"
    echo "       Got: $(echo "$output" | head -3)"
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
echo "$(bold "claude-conductor test suite")"
echo "────────────────────────────────────"
echo ""

# --- CLI basics ---
echo "$(bold "CLI basics")"

assert_exit "help exits 0" 0 "$CLI" help
assert_output_contains "help shows usage" "claude-conductor" "$CLI" help
assert_exit "unknown command exits 1" 1 "$CLI" notacommand

echo ""

# --- Init ---
echo "$(bold "Init")"

assert_exit "init exits 0" 0 "$CLI" init <<< ""
assert_output_contains "init creates SESSIONS.md" "Created SESSIONS.md" "$CLI" init <<< "TestProject"

# Reset for next test
rm -f SESSIONS.md

"$CLI" init <<< "TestProject" >/dev/null 2>&1

total=$((total + 1))
if [[ -f "SESSIONS.md" ]]; then
  echo "  $(green "✓") SESSIONS.md file exists after init"
  pass=$((pass + 1))
else
  echo "  $(red "✗") SESSIONS.md file should exist after init"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "TestProject" SESSIONS.md; then
  echo "  $(green "✓") SESSIONS.md contains project name"
  pass=$((pass + 1))
else
  echo "  $(red "✗") SESSIONS.md should contain project name"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "Active Sessions" SESSIONS.md; then
  echo "  $(green "✓") SESSIONS.md has Active Sessions section"
  pass=$((pass + 1))
else
  echo "  $(red "✗") SESSIONS.md should have Active Sessions section"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "Merge Order" SESSIONS.md; then
  echo "  $(green "✓") SESSIONS.md has Merge Order section"
  pass=$((pass + 1))
else
  echo "  $(red "✗") SESSIONS.md should have Merge Order section"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "Session Log" SESSIONS.md; then
  echo "  $(green "✓") SESSIONS.md has Session Log section"
  pass=$((pass + 1))
else
  echo "  $(red "✗") SESSIONS.md should have Session Log section"
  fail=$((fail + 1))
fi

echo ""

# --- Status ---
echo "$(bold "Status")"

assert_exit "status exits 0 with SESSIONS.md" 0 "$CLI" status
assert_output_contains "status shows Session Conductor header" "Session Conductor" "$CLI" status
assert_output_contains "status shows no active sessions" "No active sessions" "$CLI" status

# Add a session row to test parsing
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API endpoints | app/routers/ | coding | 2026-03-28 14:00 | — | — |
| 2 | Sasha | Build UI wizard | frontend/src/ | blocked | 2026-03-28 14:05 | #1 | Waiting on API |

## Merge Order

1. Session #1 first
2. Session #2 after #1

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

assert_output_contains "status shows Akira session" "Akira" "$CLI" status
assert_output_contains "status shows Sasha session" "Sasha" "$CLI" status
assert_output_contains "status shows coding status" "coding" "$CLI" status
assert_output_contains "status shows blocked status" "blocked" "$CLI" status
assert_output_contains "status shows merge order" "Merge Order" "$CLI" status

echo ""

# --- Double init ---
echo "$(bold "Edge cases")"

assert_output_contains "double init warns" "already exists" "$CLI" init <<< ""

# Test with no SESSIONS.md
rm -f SESSIONS.md
assert_exit "status without SESSIONS.md exits 1" 1 "$CLI" status

echo ""

# --- Results ---
echo "────────────────────────────────────"
if [[ $fail -eq 0 ]]; then
  echo "$(green "All $total tests passed.")"
else
  echo "$(red "$fail of $total tests failed.")"
fi
echo ""

exit $fail
