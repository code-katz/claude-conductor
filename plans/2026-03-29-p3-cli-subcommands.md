> Source: `~/.claude/plans/harmonic-leaping-mist.md`
> Archived: 2026-03-29 · Project: claude-conductor
> Status: `executed`
> Maintained by [claude-plans-skill](https://github.com/code-katz/claude-plans-skill).

---

# Plan: claude-conductor P3 — CLI Sub-commands

## Context

claude-conductor v0.1 shipped with a SKILL.md that defines 7 sub-commands and 7 session statuses, but the CLI (`bin/claude-conductor`, 244 lines of bash) only implements `status`, `init`, and `help`. The SKILL.md drives behavior inside Claude Code sessions, but the CLI is the terminal-side tool for checking and updating sessions without entering a Claude session.

P3 adds the 6 missing sub-commands: `start`, `update`, `done`, `merge`, `abandon`, `clear`. This closes the gap between what the skill promises and what the CLI delivers, making conductor a daily-driver tool.

## Critical Files

- **Modify:** `code-katz/claude-conductor/bin/claude-conductor` (all sub-commands and helpers)
- **Modify:** `code-katz/claude-conductor/tests/run.sh` (extend test suite)
- **Read-only reference:** `code-katz/claude-conductor/SKILL.md` (behavior spec)

## Implementation

### Phase 1: Shared Helpers

Add between `check_sessions()` (line 68) and `cmd_status()` (line 71):

| Helper | Purpose |
|--------|---------|
| `validate_status()` | Validates status string against the 7 allowed values |
| `session_exists()` | Checks if session # exists in Active Sessions table |
| `get_session_field()` | Extracts a column value from a session row by field index |
| `next_session_number()` | Scans Active table for highest # and returns max+1 |
| `update_session_field()` | In-place update of a field in a session row (awk read-modify-write to tmp, then mv) |
| `insert_active_row()` | Appends a new row to the Active Sessions table (awk, insert before first non-pipe line after separator) |
| `append_log()` | Appends timestamped entry to Session Log section at end of file |
| `check_dependents()` | Scans Depends On columns for references to a session #; prints unblock/warning messages |
| `now_timestamp()` | Returns `YYYY-MM-DD HH:MM` |

### Phase 2: `update <#> <status>` (foundation command)

Exercises all core helpers. Implementation:
1. Validate args (session # and status required)
2. `session_exists` check
3. `validate_status` check
4. `update_session_field` on column 6 (Status)
5. `check_dependents` for unblock notifications
6. `append_log` with status change message
7. Print confirmation with status icon

### Phase 3: `done <#>`, `merge <#>`, `abandon <#> [reason]`

Thin wrappers around the same helpers:

- **done**: Sets status to `done`, runs `check_dependents`, logs
- **merge**: Sets status to `merged`, logs
- **abandon**: Sets status to `abandoned`, updates Notes column (field 9) if reason provided, runs `check_dependents` (prints warning about blocked dependents), logs

**Design decision:** `done` keeps the session in the Active table. Only `clear` moves rows to Completed. This keeps `done` reversible and matches the SESSIONS.md lifecycle.

### Phase 4: `start [count]`

Interactive registration:
1. Parse optional count arg (default 1)
2. Loop count times, prompting for: persona, task, files, depends_on
3. Compute next session # via `next_session_number`
4. `insert_active_row` with status `planning` and current timestamp
5. `append_log` for each registration
6. Print confirmation

### Phase 5: `clear`

Most complex command. Single awk pass over the file:
1. Identify Active rows with status `done`, `merged`, or `abandoned`
2. For each, compute duration from Started timestamp to now
3. Build Completed table rows (# | Persona | Task | Files | Duration | Completed | Outcome)
4. Remove those rows from Active table
5. Renumber remaining Active rows sequentially (1, 2, 3...)
6. Update Depends On references to match new numbering
7. Insert completed rows into Completed Sessions table
8. `append_log` with summary
9. Print what was archived

**Duration calculation:** Parse `YYYY-MM-DD HH:MM` with bash parameter expansion, use `date` for epoch conversion with macOS/Linux compat wrapper.

**Edge case:** If no clearable sessions exist, print "No sessions to archive." and exit 0.

### Phase 6: Dispatch and Help Updates

- Add cases to the dispatch switch: `start`, `update|u`, `done|d`, `merge|m`, `abandon`, `clear`
- Update `cmd_help()` to list CLI sub-commands (not just slash commands)

## Design Decisions

1. **No status transition enforcement** — CLI allows any status change (e.g., `planning` to `merged`). It is a bookkeeping tool, not a workflow enforcer.
2. **`done` stays in Active table** — Only `clear` moves to Completed. This keeps done reversible.
3. **Renumbering on `clear`** — Remaining Active sessions get sequential numbers; Depends On refs updated to match.
4. **macOS compat** — Use `date -j -f` on macOS, `date -d` on Linux, with detection wrapper.
5. **No plan command in CLI** — `/conductor plan` is skill-only (it invokes `/parallel` which is a Claude Code concept). CLI skips this.

## Verification

1. Run existing tests: `bash tests/run.sh` (all 16 should still pass)
2. Manual test workflow:
   - `claude-conductor init` in a test project
   - `claude-conductor start` to register 2 sessions (one depending on the other)
   - `claude-conductor status` to verify display
   - `claude-conductor update 1 coding` then `update 1 done`
   - `claude-conductor done 1` and verify unblock notification for session #2
   - `claude-conductor merge 1`
   - `claude-conductor abandon 2 "scope changed"`
   - `claude-conductor clear` and verify Completed table populated, Active table empty
   - Inspect Session Log section for all entries
3. Run extended tests: new test sections in `tests/run.sh` covering each sub-command, invalid args, edge cases
