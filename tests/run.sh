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

"$CLI" merge 1 >/dev/null 2>&1

total=$((total + 1))
if grep -q "marked merged" SESSIONS.md; then
  echo "  $(green "✓") merge appends to Session Log"
  pass=$((pass + 1))
else
  echo "  $(red "✗") merge should append to Session Log"
  fail=$((fail + 1))
fi

# Reset for abandon log test
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

"$CLI" abandon 1 "no longer needed" >/dev/null 2>&1

total=$((total + 1))
if grep -q "abandoned.*no longer needed" SESSIONS.md; then
  echo "  $(green "✓") abandon appends to Session Log with reason"
  pass=$((pass + 1))
else
  echo "  $(red "✗") abandon should append to Session Log with reason"
  fail=$((fail + 1))
fi

# Reset for clear log test
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | done | 2026-03-28 14:00 | | |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$CLI" clear >/dev/null 2>&1

total=$((total + 1))
if grep -q "Archived.*session" SESSIONS.md; then
  echo "  $(green "✓") clear appends to Session Log"
  pass=$((pass + 1))
else
  echo "  $(red "✗") clear should append to Session Log"
  fail=$((fail + 1))
fi

echo ""

# --- Dependency tracking ---
echo "$(bold "Dependency tracking")"

# Session with multiple dependencies
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | coding | 2026-03-28 14:00 | | |
| 2 | Robin | Write tests | tests/ | coding | 2026-03-28 14:00 | | |
| 3 | Sasha | Build UI | src/ui/ | blocked | 2026-03-28 14:00 | #1, #2 | |

## Merge Order

#1, #2 → #3

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

# Completing #1 should unblock #3
assert_output_contains "done on #1 unblocks session with multiple deps" "unblocked" "$CLI" done 1

# Session with no dependents should show no unblock message
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | coding | 2026-03-28 14:00 | | |
| 2 | Sasha | Build UI | src/ui/ | coding | 2026-03-28 14:00 | | |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

# Done on #1 with no dependents should not mention "unblocked"
total=$((total + 1))
output=$("$CLI" done 1 2>&1) || true
if echo "$output" | grep -qF "unblocked"; then
  echo "  $(red "✗") done with no dependents should not show unblock message"
  fail=$((fail + 1))
else
  echo "  $(green "✓") done with no dependents shows no unblock message"
  pass=$((pass + 1))
fi

echo ""

# --- Clear: renumbering ---
echo "$(bold "Clear renumbering")"

# Setup: 3 sessions, clear #1 and #3, verify #2 becomes #1
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | merged | 2026-03-28 14:00 | | |
| 2 | Sasha | Build UI | src/ui/ | coding | 2026-03-28 14:00 | | |
| 3 | Robin | Write tests | tests/ | done | 2026-03-28 14:00 | | |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$CLI" clear >/dev/null 2>&1

# Sasha (was #2) should now be #1
total=$((total + 1))
if sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | grep -q "| 1 | Sasha"; then
  echo "  $(green "✓") clear renumbers remaining sessions (Sasha #2 → #1)"
  pass=$((pass + 1))
else
  echo "  $(red "✗") clear should renumber remaining sessions"
  fail=$((fail + 1))
fi

# Test renumbering updates Depends On references
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | done | 2026-03-28 14:00 | | |
| 2 | Sasha | Build UI | src/ui/ | coding | 2026-03-28 14:00 | | |
| 3 | Robin | Write tests | tests/ | blocked | 2026-03-28 14:00 | #2 | |

## Merge Order

#2 → #3

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$CLI" clear >/dev/null 2>&1

# Robin's dependency should update from #2 to #1
total=$((total + 1))
if sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | grep "Robin" | grep -q "#1"; then
  echo "  $(green "✓") clear updates Depends On references after renumber"
  pass=$((pass + 1))
else
  echo "  $(red "✗") clear should update Depends On references after renumber"
  fail=$((fail + 1))
fi

echo ""

# --- Clear: Completed table ---
echo "$(bold "Clear: Completed table")"

cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API | src/api/ | done | 2026-03-28 14:00 | | |
| 2 | Robin | Write tests | tests/ | abandoned | 2026-03-28 15:00 | | |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$CLI" clear >/dev/null 2>&1

# Verify rows landed in Completed Sessions
total=$((total + 1))
if sed -n '/^## Completed Sessions/,/^## [^C]/p' SESSIONS.md | grep -q "Akira"; then
  echo "  $(green "✓") clear moves Akira to Completed Sessions"
  pass=$((pass + 1))
else
  echo "  $(red "✗") clear should move Akira to Completed Sessions"
  fail=$((fail + 1))
fi

total=$((total + 1))
if sed -n '/^## Completed Sessions/,/^## [^C]/p' SESSIONS.md | grep -q "Robin"; then
  echo "  $(green "✓") clear moves Robin to Completed Sessions"
  pass=$((pass + 1))
else
  echo "  $(red "✗") clear should move Robin to Completed Sessions"
  fail=$((fail + 1))
fi

# Verify outcome column contains the status
total=$((total + 1))
if sed -n '/^## Completed Sessions/,/^## [^C]/p' SESSIONS.md | grep "Akira" | grep -q "done"; then
  echo "  $(green "✓") Completed row has correct outcome (done)"
  pass=$((pass + 1))
else
  echo "  $(red "✗") Completed row should have outcome (done)"
  fail=$((fail + 1))
fi

total=$((total + 1))
if sed -n '/^## Completed Sessions/,/^## [^C]/p' SESSIONS.md | grep "Robin" | grep -q "abandoned"; then
  echo "  $(green "✓") Completed row has correct outcome (abandoned)"
  pass=$((pass + 1))
else
  echo "  $(red "✗") Completed row should have outcome (abandoned)"
  fail=$((fail + 1))
fi

# Verify duration column is populated (not empty or just dashes)
total=$((total + 1))
duration_val=$(sed -n '/^## Completed Sessions/,/^## [^C]/p' SESSIONS.md | grep "Akira" | awk -F'|' '{gsub(/^ +| +$/, "", $6); print $6}')
if [[ -n "$duration_val" && "$duration_val" != "—" && "$duration_val" != "-" ]]; then
  echo "  $(green "✓") Completed row has calculated duration ($duration_val)"
  pass=$((pass + 1))
else
  echo "  $(red "✗") Completed row should have calculated duration (got: '$duration_val')"
  fail=$((fail + 1))
fi

# Verify Active Sessions table is now empty
total=$((total + 1))
active_data=$(sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | { grep '^|[^-]' || true; } | { grep -v 'Persona' || true; } | wc -l | tr -d ' ')
if [[ "$active_data" -eq 0 ]]; then
  echo "  $(green "✓") Active Sessions table is empty after full clear"
  pass=$((pass + 1))
else
  echo "  $(red "✗") Active Sessions table should be empty after full clear ($active_data rows remain)"
  fail=$((fail + 1))
fi

echo ""

# --- Start command ---
echo "$(bold "Start")"

# Reset with empty SESSIONS.md
cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

# Pipe stdin for interactive prompts: persona, task, files, depends
printf 'Akira\nBuild API\nsrc/api/\n\n' | "$CLI" start >/dev/null 2>&1

total=$((total + 1))
if sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | grep -q "Akira"; then
  echo "  $(green "✓") start registers session from stdin"
  pass=$((pass + 1))
else
  echo "  $(red "✗") start should register session from stdin"
  fail=$((fail + 1))
fi

total=$((total + 1))
if sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | grep "Akira" | grep -q "planning"; then
  echo "  $(green "✓") start sets initial status to planning"
  pass=$((pass + 1))
else
  echo "  $(red "✗") start should set initial status to planning"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "registered.*Akira" SESSIONS.md; then
  echo "  $(green "✓") start appends to Session Log"
  pass=$((pass + 1))
else
  echo "  $(red "✗") start should append to Session Log"
  fail=$((fail + 1))
fi

# Register a second session and verify numbering
printf 'Sasha\nBuild UI\nsrc/ui/\n#1\n' | "$CLI" start >/dev/null 2>&1

total=$((total + 1))
if sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | grep -q "| 2 | Sasha"; then
  echo "  $(green "✓") start auto-increments session number"
  pass=$((pass + 1))
else
  echo "  $(red "✗") start should auto-increment session number"
  fail=$((fail + 1))
fi

# Test start with count argument
printf 'Robin\nTest suite\ntests/\n\nMorgan\nSecurity audit\nsrc/auth/\n\n' | "$CLI" start 2 >/dev/null 2>&1

total=$((total + 1))
active_count=$(sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | { grep '^|[^-]' || true; } | { grep -v 'Persona' || true; } | wc -l | tr -d ' ')
if [[ "$active_count" -eq 4 ]]; then
  echo "  $(green "✓") start with count registers multiple sessions (4 total)"
  pass=$((pass + 1))
else
  echo "  $(red "✗") start with count should register multiple sessions (expected 4, got $active_count)"
  fail=$((fail + 1))
fi

# Test start with invalid count
assert_exit "start with invalid count exits 1" 1 "$CLI" start abc

echo ""

# --- Aliases ---
echo "$(bold "Aliases")"

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

assert_exit "alias 's' works for status" 0 "$CLI" s
assert_exit "alias 'u' works for update" 0 "$CLI" u 1 coding
assert_exit "alias 'd' works for done" 0 "$CLI" d 1
assert_exit "alias 'm' works for merge" 0 "$CLI" m 1

echo ""

# --- Chain operations ---
echo "$(bold "Chain operations")"

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
"$CLI" update 1 reviewing >/dev/null 2>&1
"$CLI" done 1 >/dev/null 2>&1
"$CLI" merge 1 >/dev/null 2>&1

total=$((total + 1))
if grep -q "| 1 |.*| merged |" SESSIONS.md; then
  echo "  $(green "✓") chain: planning → coding → reviewing → done → merged"
  pass=$((pass + 1))
else
  echo "  $(red "✗") chain should end with merged status"
  fail=$((fail + 1))
fi

# Verify all transitions logged
total=$((total + 1))
log_count=$(grep -c "^### \[" SESSIONS.md || true)
if [[ "$log_count" -ge 4 ]]; then
  echo "  $(green "✓") chain: all $log_count transitions logged"
  pass=$((pass + 1))
else
  echo "  $(red "✗") chain should log all transitions (expected >=4, got $log_count)"
  fail=$((fail + 1))
fi

echo ""

# --- Field preservation ---
echo "$(bold "Field preservation")"

cat > SESSIONS.md << 'EOF'
# TestProject — Session Conductor

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build the API endpoints | src/api/routers/ | planning | 2026-03-28 14:00 | #2 | Important session |

## Merge Order

No dependencies defined.

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
EOF

"$CLI" update 1 coding >/dev/null 2>&1

# Verify other fields survived the update
total=$((total + 1))
if grep -q "Build the API endpoints" SESSIONS.md; then
  echo "  $(green "✓") update preserves Task field"
  pass=$((pass + 1))
else
  echo "  $(red "✗") update should preserve Task field"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "src/api/routers/" SESSIONS.md; then
  echo "  $(green "✓") update preserves Files field"
  pass=$((pass + 1))
else
  echo "  $(red "✗") update should preserve Files field"
  fail=$((fail + 1))
fi

total=$((total + 1))
if sed -n '/^## Active Sessions/,/^## [^A]/p' SESSIONS.md | grep "Akira" | grep -q "#2"; then
  echo "  $(green "✓") update preserves Depends On field"
  pass=$((pass + 1))
else
  echo "  $(red "✗") update should preserve Depends On field"
  fail=$((fail + 1))
fi

total=$((total + 1))
if grep -q "Important session" SESSIONS.md; then
  echo "  $(green "✓") update preserves Notes field"
  pass=$((pass + 1))
else
  echo "  $(red "✗") update should preserve Notes field"
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
