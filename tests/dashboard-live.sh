#!/usr/bin/env bash
# tests/dashboard-live.sh — Integration tests for the live Node.js dashboard
# Usage: bash tests/dashboard-live.sh
# Requires: Node.js 20+
# Skips gracefully if Node.js is not installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLI="$REPO_DIR/bin/claude-conductor"
WATCHER="$REPO_DIR/dashboard/watcher.js"

# Test counters
pass=0
fail=0
total=0
skipped=0

# Test helpers
bold()  { printf '\033[1m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
red()   { printf '\033[31m%s\033[0m' "$*"; }
dim()   { printf '\033[2m%s\033[0m' "$*"; }
yellow(){ printf '\033[33m%s\033[0m' "$*"; }

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

assert_json_field() {
  local desc="$1"
  local json="$2"
  local field="$3"
  total=$((total + 1))
  if echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); assert $field" 2>/dev/null; then
    echo "  $(green "✓") $desc"
    pass=$((pass + 1))
  else
    echo "  $(red "✗") $desc"
    fail=$((fail + 1))
  fi
}

# --- Pre-flight: check Node.js ---
if ! command -v node >/dev/null 2>&1; then
  echo ""
  echo "$(yellow "⚠") Node.js not found. Skipping live dashboard tests."
  echo "  Install Node.js 20+ to run these tests."
  echo ""
  exit 0
fi

if [[ ! -f "$WATCHER" ]]; then
  echo ""
  echo "$(red "✗") watcher.js not found at $WATCHER"
  echo "  Run Sprint 0 first (copy dashboard files into repo)."
  echo ""
  exit 1
fi

# Check npm dependencies installed
if [[ ! -d "$REPO_DIR/dashboard/node_modules" ]]; then
  echo ""
  echo "$(dim "Installing dashboard dependencies...")"
  cd "$REPO_DIR/dashboard" && npm install --silent 2>/dev/null
fi

# --- Setup: temp directory with git repo + SESSIONS.md ---
TMPDIR=$(mktemp -d)
trap 'kill $SERVER_PID 2>/dev/null || true; rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Create a test SESSIONS.md
cat > SESSIONS.md << 'SESSIONS_EOF'
# test-project — Session Conductor

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Build API endpoints | api/routers/ | coding | 2026-03-30 10:00 |  | |
| 2 | Sasha | Style dashboard | dashboard/public/ | planning | 2026-03-30 10:00 | #1 | |

## Merge Order

Session 1 first, then Session 2 (depends on API types).

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|

## Session Log
SESSIONS_EOF

git add -A && git commit -q -m "init"

echo ""
echo "$(bold "live dashboard test suite")"
echo "────────────────────────────────────"
echo ""

# --- Start server ---
echo "$(bold "Server lifecycle")"

PORT=3099
PORT=$PORT node "$WATCHER" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

# Verify server started
total=$((total + 1))
if kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "  $(green "✓") server starts without error"
  pass=$((pass + 1))
else
  echo "  $(red "✗") server failed to start"
  fail=$((fail + 1))
  # Can't continue
  echo ""
  echo "────────────────────────────────────"
  echo "$(red "$fail of $total tests failed.")"
  exit 1
fi

# Verify port is listening
total=$((total + 1))
if curl -sf "http://localhost:$PORT/" >/dev/null 2>&1; then
  echo "  $(green "✓") server responds on port $PORT"
  pass=$((pass + 1))
else
  echo "  $(red "✗") server not responding on port $PORT"
  fail=$((fail + 1))
fi

echo ""

# --- API: /api/sessions ---
echo "$(bold "/api/sessions")"

SESSIONS_JSON=$(curl -sf "http://localhost:$PORT/api/sessions" 2>/dev/null || echo "[]")

total=$((total + 1))
if echo "$SESSIONS_JSON" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  echo "  $(green "✓") returns valid JSON"
  pass=$((pass + 1))
else
  echo "  $(red "✗") returns valid JSON"
  fail=$((fail + 1))
fi

total=$((total + 1))
if echo "$SESSIONS_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d, list)" 2>/dev/null; then
  echo "  $(green "✓") returns an array"
  pass=$((pass + 1))
else
  echo "  $(red "✗") returns an array"
  fail=$((fail + 1))
fi

echo ""

# --- API: /api/conductor ---
echo "$(bold "/api/conductor")"

CONDUCTOR_JSON=$(curl -sf "http://localhost:$PORT/api/conductor" 2>/dev/null || echo "{}")

assert_json_field "returns valid JSON with activeSessions" "$CONDUCTOR_JSON" "'activeSessions' in d"
assert_json_field "has 2 active sessions" "$CONDUCTOR_JSON" "len(d['activeSessions']) == 2"
assert_json_field "session 1 persona is Akira" "$CONDUCTOR_JSON" "d['activeSessions'][0]['persona'] == 'Akira'"
assert_json_field "session 1 task is Build API endpoints" "$CONDUCTOR_JSON" "d['activeSessions'][0]['task'] == 'Build API endpoints'"
assert_json_field "session 2 persona is Sasha" "$CONDUCTOR_JSON" "d['activeSessions'][1]['persona'] == 'Sasha'"
assert_json_field "session 2 depends on #1" "$CONDUCTOR_JSON" "d['activeSessions'][1]['dependsOn'] == '#1'"
assert_json_field "merge order is populated" "$CONDUCTOR_JSON" "len(d['mergeOrder']) > 0"
assert_json_field "has projectRoot field" "$CONDUCTOR_JSON" "'projectRoot' in d"

echo ""

# --- API: /api/links ---
echo "$(bold "/api/links")"

LINKS_JSON=$(curl -sf "http://localhost:$PORT/api/links" 2>/dev/null || echo "[]")

total=$((total + 1))
if echo "$LINKS_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d, list)" 2>/dev/null; then
  echo "  $(green "✓") returns an array"
  pass=$((pass + 1))
else
  echo "  $(red "✗") returns an array"
  fail=$((fail + 1))
fi

echo ""

# --- CLI: link/unlink ---
echo "$(bold "CLI link/unlink")"

assert_exit "link with no args exits 1" 1 "$CLI" link
assert_exit "unlink with no args exits 1" 1 "$CLI" unlink
assert_exit "link exits 0" 0 "$CLI" link 1 test-uuid-abc
assert_output_contains "link confirms success" "Linked session #1" "$CLI" link 1 test-uuid-abc

# Verify file was created
total=$((total + 1))
if [[ -f ".conductor-links.json" ]]; then
  echo "  $(green "✓") .conductor-links.json created"
  pass=$((pass + 1))
else
  echo "  $(red "✗") .conductor-links.json created"
  fail=$((fail + 1))
fi

# Verify content
total=$((total + 1))
if python3 -c "
import json
data = json.load(open('.conductor-links.json'))
assert any(e['conductorNumber'] == 1 and e['sessionId'] == 'test-uuid-abc' for e in data)
" 2>/dev/null; then
  echo "  $(green "✓") link file contains correct entry"
  pass=$((pass + 1))
else
  echo "  $(red "✗") link file contains correct entry"
  fail=$((fail + 1))
fi

assert_exit "unlink exits 0" 0 "$CLI" unlink 1
assert_output_contains "unlink confirms success" "Unlinked session #1" "$CLI" unlink 1

# Verify entry removed
total=$((total + 1))
"$CLI" link 1 test-uuid-abc >/dev/null 2>&1
"$CLI" unlink 1 >/dev/null 2>&1
if python3 -c "
import json
data = json.load(open('.conductor-links.json'))
assert not any(e['conductorNumber'] == 1 for e in data)
" 2>/dev/null; then
  echo "  $(green "✓") unlink removes entry from file"
  pass=$((pass + 1))
else
  echo "  $(red "✗") unlink removes entry from file"
  fail=$((fail + 1))
fi

echo ""

# --- CLI: help shows new commands ---
echo "$(bold "CLI help")"

assert_output_contains "help shows live flag" "live" "$CLI" help
assert_output_contains "help shows link command" "link" "$CLI" help
assert_output_contains "help shows unlink command" "unlink" "$CLI" help

echo ""

# --- Transcript fixtures: pricing, unknown models, drift counters ---
# Feeds pinned JSONL fixtures through a second watcher instance so a Claude
# Code transcript-format change breaks CI here instead of blanking the
# dashboard silently in production.
echo "$(bold "Transcript fixtures")"

FIXTURE_HOME=$(mktemp -d)
mkdir -p "$FIXTURE_HOME/.claude/projects/fixture-hash"
cp "$SCRIPT_DIR/fixtures/transcript-sample.jsonl" "$FIXTURE_HOME/.claude/projects/fixture-hash/fixture-session.jsonl"

FIXTURE_PORT=3098
HOME="$FIXTURE_HOME" PORT=$FIXTURE_PORT node "$WATCHER" >/dev/null 2>&1 &
FIXTURE_PID=$!
sleep 2

FIXTURE_JSON=$(curl -sf "http://localhost:$FIXTURE_PORT/api/sessions" 2>/dev/null || echo "[]")
HEALTH_JSON=$(curl -sf "http://localhost:$FIXTURE_PORT/api/health" 2>/dev/null || echo "{}")

assert_json_field "fixture sessions are parsed" "$FIXTURE_JSON" \
  "any(s['sessionId'] == 'fixture-session-0001' for s in d)"
assert_json_field "fable-5 session is priced (cost > 0)" "$FIXTURE_JSON" \
  "any(s['sessionId'] == 'fixture-session-0001' and s['costUSD'] and s['costUSD'] > 0 and s['costSource'] == 'pricing' for s in d)"
assert_json_field "fable-5 cost includes 1.25x cache-write rate" "$FIXTURE_JSON" \
  "abs(next(s for s in d if s['sessionId'] == 'fixture-session-0001')['costUSD'] - 0.2425) < 0.005"
assert_json_field "unknown model gets null cost, not a wrong number" "$FIXTURE_JSON" \
  "any(s['sessionId'] == 'fixture-session-0002' and s['costUSD'] is None and s['costSource'] == 'unknown' for s in d)"
assert_json_field "session carries per-model context window" "$FIXTURE_JSON" \
  "any(s['sessionId'] == 'fixture-session-0001' and s.get('contextWindow') == 200000 for s in d)"
assert_json_field "permission mode captured from transcript" "$FIXTURE_JSON" \
  "any(s['sessionId'] == 'fixture-session-0001' and s.get('permissionMode') == 'acceptEdits' for s in d)"
assert_json_field "health reports pricing provenance" "$HEALTH_JSON" \
  "d['pricingAsOf'] is not None and d['costEngine'] == 'pricing.json'"
assert_json_field "health: fixture lines parse without drift" "$HEALTH_JSON" \
  "d['parsedLines'] >= 5 and d['parseErrors'] == 0 and d['formatDrift'] == False"

kill "$FIXTURE_PID" 2>/dev/null || true
rm -rf "$FIXTURE_HOME"

echo ""

# --- Server stop ---
echo "$(bold "Server cleanup")"

total=$((total + 1))
if kill "$SERVER_PID" 2>/dev/null; then
  echo "  $(green "✓") server stops cleanly"
  pass=$((pass + 1))
else
  echo "  $(red "✗") server stops cleanly"
  fail=$((fail + 1))
fi

echo ""

# --- Summary ---
echo "────────────────────────────────────"
if [[ "$fail" -eq 0 ]]; then
  echo "$(green "All $total tests passed.")"
else
  echo "$(red "$fail of $total tests failed.")"
  exit 1
fi
