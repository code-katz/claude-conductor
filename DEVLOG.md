# claude-conductor — Development Log

A living record of architectural decisions, milestones, key insights, and strategic direction.
Auto-maintained via [claude-devlog-skill](https://github.com/code-katz/claude-devlog-skill). Entries are reverse-chronological.

---

## [2026-03-29] P3: CLI sub-commands implemented (start, update, done, merge, abandon, clear)

**Category:** `feature`
**Tags:** `conductor`, `cli`, `session-lifecycle`, `code-katz`
**Risk Level:** `low`
**Breaking Change:** `no`

### Summary
Implemented all 6 missing CLI sub-commands for claude-conductor, closing the gap between the SKILL.md spec (7 sub-commands) and the CLI (previously only status, init, help). Test suite expanded from 20 to 44 tests.

### Detail
The CLI now supports the full session lifecycle from the terminal: `start` for interactive registration, `update` for status changes, `done`/`merge`/`abandon` for completion states, and `clear` for archiving finished sessions to the Completed table with duration calculation and renumbering.

9 shared helper functions were extracted for table parsing, row insertion/update, dependency checking, session log appending, and cross-platform (macOS/Linux) duration calculation. The `clear` command is the most complex, handling row migration between Active and Completed tables, duration computation, sequential renumbering, and Depends On reference updates.

Also fixed a pre-existing test ordering bug where `init` was called twice without cleanup, causing a false failure.

### Decisions Made
- **`done` stays in Active table:** Only `clear` moves rows to Completed. This keeps `done` reversible (you can `update` back to `coding` if needed) and separates "task complete" from "archived."
- **No status transition enforcement:** The CLI allows any status change (e.g., `planning` directly to `merged`). It is a bookkeeping tool, not a workflow enforcer. Users know their own workflow.
- **Renumbering on `clear`:** When completed sessions are archived, remaining Active sessions get sequential numbers and all Depends On references are updated to match. This prevents gaps in session numbering.
- **macOS/Linux date compat:** Duration calculation uses `date -j -f` on macOS and `date -d` on Linux with a detection wrapper, since both are deployment targets.
- **No `/conductor plan` in CLI:** This sub-command is skill-only because it invokes `/parallel`, which is a Claude Code concept with no terminal equivalent.

### Related
- Implementation plan: `plans/2026-03-29-p3-cli-subcommands.md`
- v0.1 completion plan: `plans/2026-03-28-v01-completion-plan.md`
- Prior entry: [2026-03-28] Project inception and initial repo scaffolding

---

## [2026-03-28] Project inception and initial repo scaffolding

**Category:** `milestone`
**Tags:** `conductor`, `orchestration`, `parallel-sessions`, `code-katz`
**Risk Level:** `low`
**Breaking Change:** `no`

### Summary
Created the claude-conductor project as a new code-katz tool for tracking and coordinating parallel Claude Code sessions.

### Detail
The conductor addresses a specific gap in the code-katz workflow: after `/parallel` generates session plans, there is no visibility into which sessions are active, which persona is in each, what status each is in, or when blocked sessions become unblocked. With 6+ sessions running simultaneously, coordination breaks down.

The project was created after a product investigation comparing the code-katz ecosystem against Paperclip (an open-source agent orchestration platform with 36k+ GitHub stars). The investigation concluded that Paperclip and code-katz operate at different abstraction levels (company simulation vs. expert consultant sessions) and are complementary rather than competitive. The recommended approach is to build a lightweight conductor within code-katz first, then evaluate Paperclip integration as a later phase.

### Decisions Made
- **Build bespoke vs. adopt Paperclip:** Chose to build within code-katz rather than migrate to Paperclip. Paperclip requires a Node.js/TypeScript server and PostgreSQL, which is more infrastructure than needed for the coordination problem. The persona depth in claude-team-cli (required interactive behaviors, security focus, handoff protocols) would be lost or significantly simplified in a Paperclip migration. Paperclip remains a Phase 2 evaluation target once its Claude Code adapter matures.
- **SESSIONS.md as the state store:** Chose a markdown file over a database or JSON to match the code-katz pattern (devlog, roadmap, plans, todos all use markdown). This keeps the tool zero-dependency and human-readable.
- **Skill + CLI hybrid:** Following the claude-team-cli pattern with both a bash CLI for terminal use and a SKILL.md for Claude Code integration via slash commands.
- **No auto-commit:** SESSIONS.md changes too frequently during a sprint to auto-commit on every update. Unlike DEVLOG.md (which captures durable decisions), SESSIONS.md is ephemeral coordination state.

### Related
- Product investigation document: Code-Katz-Paperclip-Investigation.docx
- Paperclip repo: https://github.com/paperclipai/paperclip
- claude-team-cli /parallel command: the upstream planning tool that conductor tracks
