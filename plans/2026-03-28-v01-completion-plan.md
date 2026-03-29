# claude-conductor — v0.1 Completion Plan

**Archived:** 2026-03-28
**Project:** claude-conductor
**Status:** `active`
**Original slug:** *(created in Claude Chat, no plan-mode slug)*

---

## Context

This plan was produced during a Claude Chat product investigation session. The session compared the code-katz ecosystem against Paperclip (open-source agent orchestration) and concluded that a bespoke session-tracking tool should be built within code-katz. The full investigation is in `docs/Code-Katz-Paperclip-Investigation.md`.

## What Was Done (Chat Session, March 28 2026)

The following files were created and are ready in the repo:

| File | Status | Description |
|------|--------|-------------|
| `SKILL.md` | ✅ Complete | Full skill definition: 7 sub-commands (`/conductor`, `/conductor start`, `update`, `done`, `merge`, `abandon`, `plan`, `clear`), 7 session statuses, dependency tracking, merge order, integrations with devlog/roadmap/todo/parallel |
| `bin/claude-conductor` | ✅ Complete | Bash CLI with `status` (parses SESSIONS.md table, emoji icons), `init` (creates SESSIONS.md), and `help`. Matches claude-team-cli patterns. |
| `commands/conductor.md` | ✅ Complete | `/conductor` slash command for Claude Code |
| `commands/sessions.md` | ✅ Complete | `/sessions` alias slash command |
| `install.sh` | ✅ Complete | One-command installer: skill → `~/.claude/skills/conductor/`, commands → `~/.claude/commands/`, CLI → `~/.local/bin/` (symlinked) |
| `README.md` | ✅ Complete | Full readme matching code-katz style: problem statement, "See the Difference", installation, usage, workflow walkthrough, "Works Well With" table, roadmap |
| `DEVLOG.md` | ✅ Complete | Initial entry documenting project inception and the Paperclip decision |
| `tests/run.sh` | ✅ Complete | 16-test suite: CLI basics, init, status parsing, edge cases |
| `LICENSE` | ✅ Complete | MIT |
| `.gitignore` | ✅ Complete | Matching code-katz pattern |
| `.markdownlint.json` | ✅ Complete | Matching code-katz pattern |
| `docs/Code-Katz-Paperclip-Investigation.md` | ✅ Complete | Full investigation document (markdown version) |
| `RUNBOOK.md` | ✅ Complete | Operational guide for installing, running, and using claude-conductor |

## What Needs to Be Done Next

### Priority 1: Repo Setup (Quinn)

- [ ] `git init` the repo at `~/d20m-development/code-katz/claude-conductor/`
- [ ] Create the GitHub repo under the `code-katz` organization
- [ ] `git add . && git commit -m "Initial commit: claude-conductor v0.1"` and push
- [ ] Run `bash install.sh` to install locally
- [ ] Run `bash tests/run.sh` to verify all 16 tests pass on your machine

### Priority 2: Banner Image (Sasha)

- [ ] Create `publish/images/Conductor_dark_banner.png` matching the Code Katz visual style
  - Reference existing banners: `claude-team-cli/publish/images/Team_dark_Banner.png`, `claude-devlog-skill/publish/images/Devlog_Dark_banner.png`
  - Same dimensions, color palette, and typography as the other Code Katz banners
  - The conductor concept: think "control room", "dashboard", or "orchestra conductor"

### Priority 3: CLI Enhancement (Akira)

The CLI currently has `status`, `init`, and `help`. The SKILL.md defines richer sub-commands that are handled by Claude Code via the skill. For CLI parity, Akira should implement:

- [ ] `claude-conductor start` — interactive session registration (prompt for persona, task, files, dependencies; write to SESSIONS.md)
- [ ] `claude-conductor update <#> <status>` — update a session's status in SESSIONS.md
- [ ] `claude-conductor done <#>` — move session from Active to Completed table
- [ ] `claude-conductor merge <#>` — mark session as merged with timestamp
- [ ] `claude-conductor abandon <#> <reason>` — mark session as abandoned
- [ ] `claude-conductor clear` — archive completed sessions, reset numbering

**File scope:** `bin/claude-conductor` only. All logic is SESSIONS.md table manipulation via bash/awk.

### Priority 4: Tests for New CLI Commands (Robin)

- [ ] Extend `tests/run.sh` with tests for each new CLI sub-command
- [ ] Test dependency tracking: when session #1 is marked `done`, verify the output mentions that #2 is unblocked
- [ ] Test merge order: verify `status` displays merge order correctly
- [ ] Test `clear`: verify completed sessions move to archive and numbering resets
- [ ] Test edge cases: updating a non-existent session number, abandoning a session with dependents

**File scope:** `tests/run.sh` only. Do not modify `bin/claude-conductor` (that's Akira's session).

### Priority 5: Update claude-team-cli (Akira or Quinn)

- [ ] Add claude-conductor to the "Works Well With" table in claude-team-cli's README.md
- [ ] Add `/conductor` and `/sessions` to the companion skill commands section
- [ ] Add conductor to the companion install script block (the curl one-liner section)

**File scope:** `~/d20m-development/code-katz/claude-team-cli/README.md` only.

### Priority 6: Web Dashboard — Future Sprint (Akira + Sasha)

This is the v0.2 roadmap item. Not needed now, but scoped here for future planning:

- [ ] Python FastAPI app that reads SESSIONS.md and serves a live dashboard at `localhost:8080`
- [ ] Auto-refresh every 5 seconds via SSE or polling
- [ ] Status icons, dependency arrows, merge order visualization
- [ ] Mobile-friendly layout (you mentioned wanting to coordinate from your phone)

**This is a separate sprint.** Do not combine with Priorities 1-5.

---

## Parallel Session Plan (for Priorities 3 + 4)

These can run in parallel once Priority 1 (repo setup) is complete:

```
Session 1: CLI sub-commands
Persona: /akira
Task: Implement start, update, done, merge, abandon, and clear sub-commands in bin/claude-conductor
Files: bin/claude-conductor

Session 2: Test coverage
Persona: /robin
Task: Write tests for all new CLI sub-commands including dependency tracking and edge cases
Files: tests/run.sh

Merge order: Either order is fine; both modify different files. However, Robin's tests will validate Akira's implementation, so ideally merge Session 1 first, then run Session 2's tests to verify.

Coordination session: Keep open for questions and to run tests after both sessions complete.
```

---

## Key Decisions Already Made

These are settled and should not be re-litigated:

1. **Build bespoke (claude-conductor) rather than adopt Paperclip.** Rationale: Paperclip requires Node.js/TS/Postgres infrastructure; persona depth would be lost; Paperclip is Phase 2 evaluation.
2. **SESSIONS.md as the state store.** Matches code-katz pattern (markdown files). Zero-dependency, human-readable.
3. **No auto-commit for SESSIONS.md.** Changes too frequently during a sprint. User commits manually if desired.
4. **Skill + CLI hybrid.** Slash commands for Claude Code, bash CLI for terminal. Matches claude-team-cli pattern.
5. **7 session statuses.** planning → coding → reviewing → done → merged. Plus blocked and abandoned.

## Open Questions

1. Should `claude-conductor status` also show a count of completed sessions from the current sprint, or only active ones?
2. Should the conductor auto-detect when you open a new Claude Code session in the same project and ask if you want to register it?
3. For the web dashboard (v0.2): Python FastAPI or a simpler approach like a static HTML page that reads SESSIONS.md via a bash script?
