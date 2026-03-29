---
name: claude-conductor
description: Track and coordinate parallel Claude Code sessions from a central dashboard. Use this skill whenever the user says "/conductor", "/sessions", "session status", "who is doing what", "show sessions", or references checking on parallel work streams. Also trigger when the user starts a new parallel session, completes a session, or asks about merge order or dependencies between sessions. Works alongside claude-team-cli to provide visibility into multi-session workflows.
---

# Session Conductor Skill

This skill maintains a `SESSIONS.md` file in the root of a project's Git repository and provides CLI commands for tracking parallel Claude Code sessions. It answers the question: "Who is doing what, in which session, and what's the status?"

This skill is **project-agnostic** and works with any repository. On first use in a session, it identifies the active project and adapts accordingly.

## Why This Matters

The `/parallel` command in claude-team-cli generates session plans with personas, tasks, and file scopes. But once those sessions are running, visibility disappears. You can't see which sessions are active, which persona is in each, what task each is working on, or which sessions are blocked waiting on others. With 6+ sessions running, you lose coordination quickly.

The conductor fills that gap. It tracks session lifecycle from plan through completion, shows status at a glance, enforces merge order, and integrates with devlog to capture what each session accomplished.

## Project Context (First Use Per Session)

The first time this skill triggers in a session, establish the project context:

1. **Memory/conversation context** — Does Claude already know what project the user is working on? If so, confirm.
2. **CWD / git remote** — Check the working directory name or `git remote -v`.
3. **Ask the user** — If neither source provides clarity, ask.

SESSIONS.md lives in the **project root**, alongside DEVLOG.md, ROADMAP.md, and TODOS.md.

### Lint Check

When establishing project context for the first time in a session, verify that the project has a linter configured. Check for stack-appropriate lint configuration files:

- **Python**: `ruff.toml`, `pyproject.toml` with `[tool.ruff]`, `.flake8`
- **JavaScript/TypeScript**: `.eslintrc*`, `eslint.config.*`, `biome.json`, or a `lint` script in `package.json`
- **Swift/iOS**: `.swiftlint.yml`
- **Go**: `.golangci.yml`
- **Rust**: `clippy` configuration in `Cargo.toml`
- **General**: `.pre-commit-config.yaml`

If no linter is configured, flag it to the user before proceeding.

---

## SESSIONS.md Format

```markdown
# [Project Name] — Session Conductor

Active coordination view for parallel Claude Code sessions.
Auto-maintained via [claude-conductor](https://github.com/code-katz/claude-conductor).

---

## Active Sessions

| # | Persona | Task | Files | Status | Started | Depends On | Notes |
|---|---------|------|-------|--------|---------|------------|-------|
| 1 | Akira | Implement /battles CRUD endpoints | app/routers/, app/models/ | coding | 2026-03-28 14:00 | — | API contracts defined |
| 2 | Sasha | Build BattleLog wizard component | frontend/src/pages/, frontend/src/components/ | blocked | 2026-03-28 14:05 | #1 | Waiting on API types |
| 3 | Robin | Integration tests for battles API | tests/ | planning | 2026-03-28 14:10 | #1 | — |

## Merge Order

1. Session #1 first (defines API contracts)
2. Sessions #2 and #3 in any order after #1

## Completed Sessions

| # | Persona | Task | Files | Duration | Completed | Outcome |
|---|---------|------|-------|----------|-----------|---------|
| — | — | — | — | — | — | — |

## Session Log

### [2026-03-28 14:00] Sessions created from /parallel plan
- Created 3 sessions for battles feature sprint
- Coordination session: this terminal
```

---

## Session Statuses

| Status | Meaning | Visual |
|--------|---------|--------|
| `planning` | Session is in plan mode, no edits yet | 📋 |
| `coding` | Actively writing code | ⚡ |
| `reviewing` | Code complete, reviewing/testing | 🔍 |
| `blocked` | Waiting on another session or external input | 🚫 |
| `done` | Task complete, ready to merge | ✅ |
| `merged` | Code merged into main branch | 🏁 |
| `abandoned` | Session stopped without completing task | ❌ |

---

## Trigger Conditions

This skill activates when the user says:

- `/conductor` or `/sessions` — show current session status
- `/conductor start` — register a new session (or batch from /parallel output)
- `/conductor update <#> <status>` — update a session's status
- `/conductor done <#>` — mark a session complete
- `/conductor merge <#>` — mark a session as merged
- `/conductor abandon <#>` — mark a session as abandoned with reason
- `/conductor plan` — generate a new /parallel plan and auto-register sessions
- `/conductor clear` — archive all completed/merged sessions and reset for next sprint

---

## Sub-Commands

### `/conductor` or `/sessions` — Show Status

1. Read SESSIONS.md
2. Display the Active Sessions table with status icons
3. Show any blocked sessions and what they're waiting on
4. Show merge order if dependencies exist
5. If no sessions are active: "No active sessions. Use `/conductor start` or `/conductor plan` to begin."

**Compact format for quick checks:**

```
Session Status for [Project Name]:

  #1  ⚡ Akira    — Implement /battles CRUD     [coding]
  #2  🚫 Sasha    — BattleLog wizard            [blocked → waiting on #1]
  #3  📋 Robin    — Integration tests            [planning]

Merge order: #1 → (#2, #3)
```

### `/conductor start` — Register Sessions

**From /parallel output:**
When the user runs `/parallel` first and then `/conductor start`, parse the parallel plan output and auto-register all sessions:

1. Extract persona, task, and file scope from each session in the plan
2. Set all initial statuses to `planning`
3. Extract merge order from the plan
4. Write to SESSIONS.md
5. Log the creation in the Session Log section
6. Confirm: "Registered 3 sessions from /parallel plan. All set to `planning`."

**Manual registration:**
If no /parallel output is available, prompt:

1. "Which persona?" (suggest based on context)
2. "What's the task?" (short, specific description)
3. "Which files/directories?" (explicit scope)
4. "Any dependencies?" (other session numbers)

Assign the next available session number.

### `/conductor update <#> <status>` — Update Status

1. Read SESSIONS.md
2. Find session by number
3. Update the status field
4. If changing to `done`, prompt: "Want to log this to the devlog? I can draft an entry from the session's task."
5. If a blocked session's dependency just became `done`, notify: "Session #2 is unblocked — Sasha can proceed with the BattleLog wizard."
6. Add a timestamped note to the Session Log
7. Write SESSIONS.md

### `/conductor done <#>` — Complete a Session

1. Update status to `done`
2. Prompt for outcome summary: "Brief summary of what was accomplished?"
3. Move the session from Active to Completed table
4. Check if this unblocks any other sessions and notify
5. Offer to create a devlog entry
6. Add to Session Log
7. Write SESSIONS.md

### `/conductor merge <#>` — Mark as Merged

1. Update status to `merged` in the Completed table
2. Record the merge timestamp
3. If all sessions in a dependency chain are merged, note: "All sessions in the battles sprint are merged. Sprint complete."
4. Add to Session Log

### `/conductor abandon <#>` — Abandon a Session

1. Prompt for reason: "Why is this being abandoned?"
2. Update status to `abandoned`
3. Move to Completed table with the reason
4. Check if any sessions depended on this one and flag them: "Warning: Session #2 depends on #1 which was abandoned. #2 may need rescoping."
5. Add to Session Log

### `/conductor plan` — Generate and Register

1. Invoke the `/parallel` planning logic (analyze context, identify streams)
2. Present the parallel plan to the user for approval
3. On approval, auto-register all sessions via `/conductor start`
4. This is a convenience command that combines `/parallel` + `/conductor start`

### `/conductor clear` — Archive and Reset

1. Move all `done` and `merged` sessions to an archive section at the bottom of SESSIONS.md
2. Remove them from the Active and Completed tables
3. Reset session numbering for the next sprint
4. Confirm: "Archived 3 completed sessions. Ready for next sprint."

---

## Dependency Tracking

When sessions have dependencies:

1. The `Depends On` column in the Active Sessions table shows which session(s) must complete first
2. When a dependency completes (`done` or `merged`), the conductor automatically:
   - Notifies the user that downstream sessions are unblocked
   - Suggests the merge order for the next step
3. Circular dependencies are flagged as errors during registration

**Merge order is always explicit.** The conductor does not auto-merge. It tells you what can be merged and in what order. You do the actual merge.

---

## Integration with Other Code-Katz Tools

### Devlog Integration
When a session completes, the conductor offers to generate a devlog entry:
- Category is inferred from the session's task (API work → `feature`, tests → `infrastructure`, etc.)
- The entry includes the persona who led the work, the task description, and the outcome summary
- Tags are derived from the file scope

### Roadmap Integration
When all sessions in a sprint complete, the conductor checks ROADMAP.md for the related tier item and suggests marking it complete or updating its status.

### Todo Integration
When a session is abandoned or a new task surfaces during a session, the conductor offers to add it to TODOS.md with the appropriate persona tag.

### Parallel Integration
The `/conductor plan` command wraps `/parallel` to provide a seamless plan-to-track workflow. The conductor reads the /parallel output format natively.

---

## Workflow: Writing to SESSIONS.md

### Always read before writing
Read SESSIONS.md before any write operation.

### No approval gate for status updates
Status changes are low-stakes and time-sensitive. Write immediately and confirm.

### Show changes for destructive operations
`/conductor clear` and `/conductor abandon` show what will change and ask for confirmation.

### No automatic git commit
SESSIONS.md is a coordination artifact, not a changelog. The user can commit it if they want it in source control, but it changes too frequently to auto-commit on every update.

---

## Session Log

The Session Log at the bottom of SESSIONS.md is an append-only record of all session lifecycle events. Each entry is timestamped:

```markdown
### [YYYY-MM-DD HH:MM] Event description
- Details about what changed
```

This provides a timeline of the sprint's coordination history. It is never edited or deleted, only appended to.

---

## Writing Style

- **No emdashes in prose:** Restructure to use commas, colons, semicolons, parentheses, or separate sentences. Emdashes are acceptable as separators in structured lists.
- Status updates are terse and factual
- Session descriptions are short and imperative
- The Session Log captures coordination decisions, not implementation details (that's the devlog's job)

---

## Creating SESSIONS.md for the First Time

```markdown
# [Project Name] — Session Conductor

Active coordination view for parallel Claude Code sessions.
Auto-maintained via [claude-conductor](https://github.com/code-katz/claude-conductor).

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
```

Replace `[Project Name]` with the project name established during session setup.
