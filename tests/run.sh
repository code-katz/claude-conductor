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
rm -f SESSIONS.md
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

# --- Update ---
echo "$(bold "Update")"

# Set up a fresh SESSIONS.md with a session
"$CLI" init <<< "TestProject" >/dev/null 2>&1
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

Active coordination view for parallel Claude Code sessions.

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | planning | 2026-03-28 14:00 | | |
| 2 | Sasha | Build UI | src/ui/ | blocked | 2026-03-28 14:00 | #1 | |

## Merge Order

#1 → #2

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

assert_exit "update exits 0" 0 "$CLI" update 1 coding
assert_output_contains "update confirms status change" "reviewing" "$CLI" update 1 reviewing
assert_exit "update with invalid status exits 1" 1 "$CLI" update 1 invalid
assert_exit "update with nonexistent session exits 1" 1 "$CLI" update 99 coding
assert_exit "update with missing args exits 1" 1 "$CLI" update

echo ""

# --- Done ---
echo "$(bold "Done")"

# Reset SESSIONS.md for done tests
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | coding | 2026-03-28 14:00 | | |
| 2 | Sasha | Build UI | src/ui/ | blocked | 2026-03-28 14:00 | #1 | |

## Merge Order

#1 → #2

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

assert_exit "done exits 0" 0 "$CLI" done 1
assert_output_contains "done shows unblock notification" "unblocked" "$CLI" done 1

# Verify status was updated in file
total=$((total + 1))
if grep -q "| 1 |.*| done |" SESSIONS.md; then
  echo "  $(green "✓") done updates status in SESSIONS.md"
  pass=$((pass + 1))
else
  echo "  $(red "✗") done should update status in SESSIONS.md"
  fail=$((fail + 1))
fi

assert_exit "done with missing arg exits 1" 1 "$CLI" done
assert_exit "done with nonexistent session exits 1" 1 "$CLI" done 99

echo ""

# --- Merge ---
echo "$(bold "Merge")"

assert_exit "merge exits 0" 0 "$CLI" merge 1
assert_output_contains "merge confirms merged" "merged" "$CLI" merge 2

total=$((total + 1))
if grep -q "| 2 |.*| merged |" SESSIONS.md; then
  echo "  $(green "✓") merge updates status in SESSIONS.md"
  pass=$((pass + 1))
else
  echo "  $(red "✗") merge should update status in SESSIONS.md"
  fail=$((fail + 1))
fi

assert_exit "merge with missing arg exits 1" 1 "$CLI" merge

echo ""

# --- Abandon ---
echo "$(bold "Abandon")"

# Reset for abandon tests
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | coding | 2026-03-28 14:00 | | |
| 2 | Sasha | Build UI | src/ui/ | blocked | 2026-03-28 14:00 | #1 | |

## Merge Order

#1 → #2

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

assert_exit "abandon exits 0" 0 "$CLI" abandon 1 "scope changed"
assert_output_contains "abandon shows warning about dependents" "depends on" "$CLI" abandon 1

total=$((total + 1))
if grep -q "| 1 |.*| abandoned |" SESSIONS.md; then
  echo "  $(green "✓") abandon updates status in SESSIONS.md"
  pass=$((pass + 1))
else
  echo "  $(red "✗") abandon should update status in SESSIONS.md"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "scope changed" SESSIONS.md; then
  echo "  $(green "✓") abandon writes reason to Notes column"
  pass=$((pass + 1))
else
  echo "  $(red "✗") abandon should write reason to Notes column"
  fail=$((fail + 1))
fi

assert_exit "abandon with missing arg exits 1" 1 "$CLI" abandon

echo ""

# --- Clear ---
echo "$(bold "Clear")"

# Set up with mixed statuses
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | done | 2026-03-28 14:00 | | |
| 2 | Sasha | Build UI | src/ui/ | coding | 2026-03-28 14:00 | | |
| 3 | Robin | Write tests | tests/ | merged | 2026-03-28 14:00 | | |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

assert_output_contains "clear reports archived count" "Archived 2" "$CLI" clear

# Verify Sasha (coding) remains in Active
total=$((total + 1))
if sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | grep -q "Sasha"; then
  echo "  $(green "✓") clear keeps active sessions"
  pass=$((pass + 1))
else
  echo "  $(red "✗") clear should keep active sessions"
  fail=$((fail + 1))
fi

# Test clear with nothing to archive
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | coding | 2026-03-28 14:00 | | |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

assert_output_contains "clear with nothing to archive" "No sessions to archive" "$CLI" clear

echo ""

# --- Session Log ---
echo "$(bold "Session Log")"

# Reset and test that operations append to log
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | planning | 2026-03-28 14:00 | | |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$CLI" update 1 coding >/dev/null 2>&1

total=$((total + 1))
if grep -q "status changed to coding" SESSIONS.md; then
  echo "  $(green "✓") update appends to Session Log"
  pass=$((pass + 1))
else
  echo "  $(red "✗") update should append to Session Log"
  fail=$((fail + 1))
fi

"$CLI" done 1 >/dev/null 2>&1

total=$((total + 1))
if grep -q "marked done" SESSIONS.md; then
  echo "  $(green "✓") done appends to Session Log"
  pass=$((pass + 1))
else
  echo "  $(red "✗") done should append to Session Log"
  fail=$((fail + 1))
fi

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
