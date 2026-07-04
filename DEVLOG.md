# claude-conductor — Development Log

A living record of architectural decisions, milestones, key insights, and strategic direction.
Auto-maintained via [claude-devlog-skill](https://github.com/code-katz/claude-devlog-skill). Entries are reverse-chronological.

---

## [2026-07-04] v1.1: Harness modernization for Fable 5, plugin packaging, hooks that work

**Category:** `milestone`
**Tags:** `plugin`, `hooks`, `worktrees`, `pricing`, `fable-5`, `v1.1`
**Risk Level:** `medium`
**Breaking Change:** `no`

### Summary

Three-phase modernization against the July 2026 Claude Code harness, driven by a full audit (docs/2026-07-03-fable-harness-modernization-analysis.md) and a market survey (docs/2026-07-04-landscape-survey-parallel-session-tools.md). The conductor is now worktree-aware end to end, prices the Claude 5 lineup from config instead of stale constants, ships as an installable plugin whose hooks register automatically, and carries an end-to-end drill that exercises the full 3-session workflow.

### Detail

- Worktree-aware root discovery in CLI, hooks, static generator, and watcher: inside a git worktree, everything resolves to the main checkout so parallel sessions share one SESSIONS.md. Merge guidance no longer switches branches.
- conductor-hook rewritten: reads hook stdin JSON, resolves its own session via .conductor-links.json or a Branch-column match, one-shot keyed on session_id. The old version never parsed stdin, used a $$ marker that never matched, promoted whichever session was first in planning, and was never registered anywhere.
- New conductor-session-start (SessionStart): auto-links sessions by branch, writes .conductor-links.json, injects number, persona, task, scope, and the status-update contract as context.
- Pricing moved to dashboard/pricing.json (Claude 5 lineup, per-model cache multipliers and context windows, as_of date). Unknown models show no cost instead of Sonnet 4.6 rates; cache-write cost corrected from 0.25x to 1.25x of input. Optional ccusage engine via CONDUCTOR_CCUSAGE=1.
- Plugin packaging: .claude-plugin/plugin.json, hooks/hooks.json, SKILL.md relocated to skills/conductor/ with a root symlink; persona roster discovered from installed claude-team profiles.
- Hardening: transcript fixtures pin the JSONL contract in CI with a format-drift banner in the dashboard; React vendored for offline use; Node floor documented at 20; SKILL.md synced to the canonical 10-column schema.
- tests/e2e-drill.sh: register, isolate in worktrees, hook-driven linking and promotion, done and unblock, dependency-order merges, archive. 15 checks, run with both plain git and claude-team worktrees. The drill caught two real bugs before ship: the hook resolved its CLI only via PATH, and claude-team session markers were committable and produced add/add merge conflicts (fixed in claude-team v0.7).

### Decisions Made

- **Unknown model means no number:** a cost dashboard that silently prices Fable 5 at Sonnet rates is worse than one that says "rate unknown". Fallback pricing removed deliberately.
- **Keep the JSONL parser, fence it with fixtures:** the transcript format is officially internal; fixtures in CI plus a drift banner beat both abandoning passive discovery and trusting it blindly.
- **Keep and harden over adopt or rebuild:** the market survey found no tool covering merge ordering for human sessions, committed coordination state, personas, or passive session discovery; the commoditized layer (generic session lists) gets no further investment.

### Related

- code-katz/claude-team-cli v0.7 (companion changes)

---

## [2026-03-30] v2: Live dashboard via Stargx fork, SESSIONS.md integration, auto-linking

**Category:** `milestone`
**Tags:** `v2`, `live-dashboard`, `fork`, `stargx`, `auto-linking`, `status-detection`, `node-js`

### Summary
Forked [Stargx/claude-code-dashboard](https://github.com/Stargx/claude-code-dashboard) (MIT, 996 lines) and rebuilt conductor around it. The live dashboard provides real-time session monitoring, token/cost tracking, and auto-detection of Claude Code sessions. Built 5 layers on top: Code Katz branding, SESSIONS.md parsing, auto-linking, enhanced status detection, and CLI integration.

### Detail

**Decision:** Fork and extend rather than build from scratch. The Stargx dashboard already solved two of three planned features (real-time monitoring, token tracking). Building three things separately and stitching them later would have been more work than starting from something that already works. This consolidated three separate feature specs into one effort.

**What the fork provides:** `watcher.js` (JSONL parser, chokidar file watcher, Express API, status detection, token/cost aggregation) and a React (CDN) dashboard with session tiles, context window bars, and subagent tracking. 2 dependencies: express, chokidar.

**What we built on top:**
- Sprint 0 (Quinn): fork verified and committed, no existing files modified
- Sprint 1 (Sasha): Code Katz branding (colors, fonts, persona slots, conductor emoji set, pulsing amber for waiting state)
- Sprint 2A (Akira): SESSIONS.md parser with git-root walk, auto-linking via JSONL first-message scan, enhanced status detection (coding/planning/reviewing/needs_input/disconnected), new API endpoints (`/api/conductor`, `/api/links`), enriched `/api/sessions` with conductor data
- Sprint 2B (Akira): CLI commands (`dashboard --live`, `link`, `unlink`), frontend persona/task enrichment, merge order visualization
- Sprint 3A (Robin): 26 integration tests in `tests/dashboard-live.sh`
- Sprint 3B (Quinn): `install.sh --with-dashboard`, docs, attribution

**Key product decisions:**
1. Static dashboard preserved as fallback (zero-dep CLI stays functional without Node.js)
2. `--with-dashboard` opt-in install flag
3. Auto-linking over manual linking (scans JSONL first user messages for session patterns)
4. CLI default unchanged (`status`, not dashboard)
5. Shell-based tests only (no Jest)

**Test coverage:** 157 tests total (104 CLI + 27 static dashboard + 26 live dashboard).

### Related
- Plan: `plans/2026-03-30-v2-fork-and-build-execution.md`
- Design doc: `docs/2026-03-30-v2-fork-and-build-plan.md`
- Fork source: [Stargx/claude-code-dashboard](https://github.com/Stargx/claude-code-dashboard) (MIT)

---

## [2026-03-29] v0.2: Static HTML dashboard, conflict detection, persona icons

**Category:** `milestone`
**Tags:** `conductor`, `dashboard`, `conflict-detection`, `visual-identity`, `code-katz`
**Risk Level:** `low`
**Breaking Change:** `no`

### Summary
Shipped claude-conductor v0.2 with three features: a static HTML dashboard for persistent browser-based session monitoring, string-based file scope conflict detection between parallel sessions, and persona avatar icons on dashboard session cards. Test suite grew from 73 to 107 tests across two test files.

### Detail
The dashboard is a self-contained HTML file (`.conductor-dashboard.html`) generated by `bin/generate-dashboard`, a standalone bash script (~280 lines). It renders session cards with CSS grid, status badges with per-status colors, merge order visualization, completed sessions table, and conflict warnings. Dark theme matches the Code Katz visual system (`#141413`/`#faf9f5`/`#d4a843`). Auto-refreshes every 5 seconds via meta tag. Dashboard generation is opt-in: runs explicitly via `claude-conductor dashboard`, then auto-regenerates silently on all six status-changing commands.

Conflict detection uses `paths_overlap()` for prefix-based path comparison and `detect_conflicts()` to compare every unique pair of active sessions. Warnings surface in three places: the `conflicts` command, the `status` command output, and the dashboard. Only active sessions (planning/coding/reviewing/blocked) are checked.

Persona icons display as 36px circular avatars on each session card, loaded via GitHub raw URLs from the code-katz/.github repo. Icon filenames were standardized to lowercase-dash convention (`akira-icon.png`) across the entire `.github` media directory.

Built using two parallel sessions (Akira for conflicts, Kai for dashboard) with a coordination session for merging, integration hooks, and help updates.

### Decisions Made
- **Static HTML over FastAPI server:** Chose a zero-dependency approach (no Python, no server process). The CLI regenerates HTML on each command; browser reads the same file on refresh. Eliminates infrastructure and matches the bash-only constraint.
- **Opt-in dashboard:** Auto-regeneration only activates after the first explicit `dashboard` command. Users who never run it pay zero overhead.
- **String-based conflict detection over git-based:** Compares file path strings from SESSIONS.md rather than actual git state. Simple, fast, covers the 80% case without requiring filesystem access to each session's working tree.
- **Separate test file for dashboard:** `tests/dashboard.sh` (18 tests) tests the standalone generator script independently from the main CLI test suite (89 tests in `tests/run.sh`).
- **Lowercase-dash icon naming:** Standardized all `.github` media assets from mixed case (`Akira_Icon.png`) to `akira-icon.png`. Enables a simple case-insensitive lookup in the dashboard generator.

### Related
- Implementation plan: `plans/2026-03-29-p3-cli-subcommands.md` (reused plan file slug)
- Prior entry: [2026-03-29] P3: CLI sub-commands implemented
- Icon rename commit: code-katz/.github `f23f5ab`

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
