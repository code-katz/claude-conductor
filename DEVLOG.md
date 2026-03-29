# claude-conductor — Development Log

A living record of architectural decisions, milestones, key insights, and strategic direction.
Auto-maintained via [claude-devlog-skill](https://github.com/code-katz/claude-devlog-skill). Entries are reverse-chronological.

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
