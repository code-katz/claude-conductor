# claude-conductor v2 — Fork & Build Plan

**Created:** 2026-03-30
**Project:** claude-conductor
**Status:** `proposed`
**Supersedes:** `2026-03-28-v01-completion-plan.md`, `2026-03-30-token-tracking-feature-spec.md`, `2026-03-30-realtime-dashboard-feature-spec.md`

---

## The Decision

Fork [Stargx/claude-code-dashboard](https://github.com/Stargx/claude-code-dashboard) and rebuild claude-conductor around it. The dashboard becomes the heart of the tool, not an add-on.

### Why

The dashboard already solves two of our three planned features out of the box:

| Feature | Previously Planned | Dashboard Already Does It? |
|---------|-------------------|---------------------------|
| Real-time session monitoring | Separate feature spec (Option A, hooks + FastAPI) | **Yes** — auto-detects sessions, shows status every 2s |
| Token/cost tracking | Separate feature spec (Python JSONL parser) | **Yes** — per-session and combined totals with model pricing |
| Persona/task orchestration | Current v0.1 (bash CLI + SESSIONS.md) | **No** — this is the Code Katz value-add |

Building three things separately and stitching them together later is more work than starting from something that already works and adding what's missing. The fork-and-extend approach consolidates all three specs into one effort.

### What Changes

| Aspect | v0.1 (current) | v2 (this plan) |
|--------|----------------|----------------|
| Core identity | Bash CLI + Claude Code skill | Web dashboard + CLI + skill |
| Runtime | Bash only | Node.js (dashboard) + Bash (CLI/skill) |
| Token tracking | Not implemented (spec only) | Inherited from fork — already working |
| Real-time status | Not implemented (spec only) | Inherited from fork — already working |
| Data source | SESSIONS.md (manual updates) | JSONL files (automatic) + SESSIONS.md (orchestration) |
| Session detection | Manual (`/conductor start`) | Auto-detect from `~/.claude/projects/` + manual persona assignment |

### What Stays the Same

- SESSIONS.md format and its role as the orchestration layer
- `/conductor` slash commands and `claude-conductor` CLI
- SKILL.md, install.sh, and the code-katz repo conventions
- Integration with claude-team-cli personas
- All existing plans/ and docs/ remain as historical context

---

## The Fork Source

**Repo:** [github.com/Stargx/claude-code-dashboard](https://github.com/Stargx/claude-code-dashboard)
**License:** MIT
**Size:** 4 commits, ~2 files of real logic
**Stack:** Node.js, Express, chokidar, single HTML file (React via CDN)
**Dependencies:** 2 production packages (`express`, `chokidar`)

**What it provides:**

- `watcher.js` — JSONL parser, file watcher, Express API server, status detection logic, token/cost aggregation
- `public/index.html` — React dashboard with session tiles, status indicators, token counts, context window bars, git branch display, subagent tracking, recent activity logs
- Auto-detection of all Claude Code sessions via `~/.claude/projects/`
- Status states: thinking (green), waiting (yellow), idle (grey/orange), stale (dimmed)
- Refreshes every 2 seconds via polling

---

## What We Build On Top

### Layer 1: Code Katz Branding & Visual Identity (Sasha)

The dashboard ships with a "dark terminal aesthetic." We replace this with Code Katz visual identity from day one.

- [ ] Color palette matching code-katz repos (dark theme, accent colors from existing banners)
- [ ] Code Katz logo/banner at top of dashboard
- [ ] Custom fonts matching code-katz style
- [ ] Session tiles redesigned to show persona names prominently
- [ ] Status icons matching conductor's existing emoji set (📋⚡🔍🚫✅🏁❌)
- [ ] "Needs Input" state upgraded from yellow to a pulsing red alert
- [ ] Banner image for `publish/images/` in the code-katz style

**File scope:** `public/index.html`, `public/` assets

### Layer 2: Persona & Orchestration Integration (Akira)

This is the Code Katz differentiation — no other dashboard knows about personas, tasks, or merge order.

- [ ] **SESSIONS.md reader** — Parse the Active Sessions table to get persona names, tasks, file scopes, dependencies, and merge order
- [ ] **Session-to-persona mapping** — New config file (`.conductor-links.json`) that maps Claude Code `session_id` → conductor session number. Populated via:
  - CLI: `claude-conductor link <#> <session_id>`
  - Dashboard UI: dropdown on each auto-detected session tile to assign a persona
- [ ] **Enriched session tiles** — For linked sessions, overlay persona name, task description, and file scope from SESSIONS.md onto the dashboard tile
- [ ] **Merge order display** — Show dependency graph at bottom of dashboard (from SESSIONS.md)
- [ ] **Unlinked session handling** — Auto-detected sessions without a persona link show as "Unassigned" with a prompt to link them
- [ ] **Project filtering** — If SESSIONS.md exists in the detected project's root, show orchestration data. Otherwise show the plain dashboard view.

**File scope:** `watcher.js` (add SESSIONS.md parsing), `public/index.html` (UI enhancements)

### Layer 3: Enhanced Status Detection (Akira)

The fork has 4 states (thinking, waiting, idle, stale). Conductor needs richer states that map to the development workflow.

- [ ] Map existing dashboard states to conductor statuses:
  - `thinking` → `coding` (⚡) or `planning` (📋) depending on whether tool use includes Write/Edit
  - `waiting` → `needs_input` (🔴) — the critical "come look at this" state
  - `idle` → `idle` (⏸️) — waiting for you to type something
  - `stale` → `disconnected` (👻) — session may have ended
- [ ] Add new detection for `reviewing` (🔍) — session is running tests (Bash tool with test/lint commands)
- [ ] Add `done` detection — session's Stop event fired after a `/conductor done` update
- [ ] Consider adding Claude Code hooks (Phase 2) for `PermissionRequest` events, which the JSONL approach might miss or delay

**File scope:** `watcher.js` (status mapping logic)

### Layer 4: CLI & Skill Updates (Akira)

Update the existing conductor CLI and skill to work alongside the dashboard.

- [ ] `claude-conductor dashboard` — starts the Node.js dashboard server
- [ ] `claude-conductor dashboard stop` — stops the server
- [ ] `claude-conductor link <#> <session_id>` — links a session to a persona
- [ ] `claude-conductor unlink <#>` — removes a link
- [ ] Update `install.sh` to include `npm install` for the dashboard dependencies
- [ ] All existing CLI commands (`status`, `init`, `help`) remain unchanged
- [ ] All existing slash commands remain unchanged
- [ ] Update SKILL.md with dashboard-related commands

**File scope:** `bin/claude-conductor`, `install.sh`, `SKILL.md`, `commands/conductor.md`

### Layer 5: Repo Structure & Docs (Quinn)

Merge the fork into the existing conductor repo structure while maintaining code-katz conventions.

- [ ] Place dashboard files under `dashboard/` subdirectory:

```
claude-conductor/
├── README.md                          ← Updated with dashboard info
├── SKILL.md                           ← Updated with new commands
├── DEVLOG.md                          ← New entry for v2 decision
├── RUNBOOK.md                         ← Updated with dashboard startup
├── install.sh                         ← Updated to include npm install
├── bin/
│   └── claude-conductor               ← CLI (bash, extended)
├── commands/
│   ├── conductor.md                   ← Slash command (updated)
│   └── sessions.md                    ← Alias (unchanged)
├── dashboard/
│   ├── package.json                   ← From fork
│   ├── watcher.js                     ← From fork (extended)
│   └── public/
│       └── index.html                 ← From fork (restyled)
├── docs/
│   └── Code-Katz-Paperclip-Investigation.md
├── plans/
│   ├── 2026-03-28-v01-completion-plan.md
│   ├── 2026-03-30-token-tracking-feature-spec.md
│   ├── 2026-03-30-realtime-dashboard-feature-spec.md
│   └── 2026-03-30-v2-fork-and-build-plan.md    ← THIS FILE
├── publish/
│   └── images/
└── tests/
    ├── run.sh                         ← Existing CLI tests
    └── test_dashboard.sh              ← New dashboard tests
```

- [ ] Update README.md with new "See the Difference" section showing the dashboard
- [ ] Update RUNBOOK.md with dashboard startup/shutdown instructions
- [ ] Add attribution to Stargx/claude-code-dashboard in README (MIT license requires this)
- [ ] Update DEVLOG.md with v2 architecture decision entry

**File scope:** All docs, `dashboard/` directory structure

---

## Implementation Sequence

### Sprint 0: Fork & Verify (Quinn — 1 session)

Get the fork working inside the conductor repo before changing anything.

1. Clone `Stargx/claude-code-dashboard` into a temp directory
2. Copy `watcher.js`, `public/`, and `package.json` into `claude-conductor/dashboard/`
3. `cd dashboard && npm install && npm start`
4. Verify it works at `localhost:3001` with your current Claude Code sessions
5. Commit: `"chore: add dashboard from Stargx/claude-code-dashboard (MIT)"`

**Exit criteria:** Dashboard runs, auto-detects your sessions, shows token counts. No modifications yet.

### Sprint 1: Branding (Sasha — 1 session)

Restyle the dashboard to Code Katz identity.

1. Replace color palette, fonts, and layout
2. Add Code Katz banner/logo
3. Redesign session tiles with persona-ready layout (even before persona data is wired up)
4. Upgrade "waiting" state to pulsing red "Needs Input" alert
5. Create `publish/images/Conductor_dark_banner.png` (the banner from the v0.1 plan)

**Exit criteria:** Dashboard looks like a Code Katz tool, not a generic terminal monitor.

### Sprint 2: Conductor Integration (Akira — 1-2 sessions)

Wire up the Code Katz orchestration layer.

1. Add SESSIONS.md parser to `watcher.js`
2. Implement `.conductor-links.json` for session-to-persona mapping
3. Enrich session tiles with persona name, task, file scope when linked
4. Add merge order display
5. Refine status detection (planning vs coding vs reviewing)
6. Add `claude-conductor dashboard` and `claude-conductor link` to CLI

**Exit criteria:** Linked sessions show persona names, tasks, and merge order on the dashboard.

### Sprint 3: Tests & Docs (Robin + Quinn — parallel)

**Robin:**
1. Test dashboard server starts and serves API
2. Test SESSIONS.md parsing with various formats
3. Test session linking and unlinking
4. Test status mapping logic
5. Test dashboard with 0, 1, and 3+ sessions

**Quinn:**
1. Update all docs (README, RUNBOOK, SKILL.md)
2. Update install.sh
3. Add attribution
4. DEVLOG entry

**Exit criteria:** All tests pass. Docs are current. `install.sh` works end-to-end.

---

## Parallel Session Plan for Sprints 1-2

After Sprint 0 (Quinn verifies the fork works):

```
Session 1: Branding
Persona: /sasha
Task: Restyle dashboard to Code Katz visual identity, create banner image
Files: dashboard/public/

Session 2: Conductor integration
Persona: /akira
Task: Add SESSIONS.md parsing, persona mapping, merge order, enhanced status detection, CLI commands
Files: dashboard/watcher.js, bin/claude-conductor, SKILL.md

Merge order: Either order is fine — they touch different parts of the codebase.
Sasha modifies HTML/CSS, Akira modifies JS backend and bash CLI.

Coordination session: Keep open for testing both changes together.
```

---

## Key Decisions

1. **Fork, don't rewrite.** The dashboard's JSONL parsing and status detection logic is the hardest part to build. It's already done and working. Extending it is faster than rebuilding.
2. **Node.js stays.** The dashboard is ~200 lines of JavaScript. Rewriting in Python would take 3-4 sessions for zero functional gain. Claude Code handles the JS; you direct the sessions.
3. **Dashboard goes in `dashboard/` subdirectory.** Keeps it cleanly separated from the bash CLI and skill files. The CLI launches it with `claude-conductor dashboard`.
4. **SESSIONS.md remains the orchestration source of truth.** The dashboard reads it but doesn't replace it. Slash commands still manage it. The dashboard is a viewer, not an editor (for now).
5. **Token tracking comes free.** No separate Python module needed. The fork already parses tokens from JSONL files. The token tracking feature spec is effectively complete by inheriting the fork.
6. **Branding from day one.** The dashboard will look like a Code Katz tool before any features are added. This is a deliberate choice — polish is part of the product.
7. **Attribution is required.** MIT license means we must credit Stargx/claude-code-dashboard. Add a line in README and keep the original LICENSE notice in the dashboard directory.

## Open Questions

1. **Dashboard as default command?** Should `claude-conductor` (with no arguments) launch the dashboard instead of the CLI status view? Or should `claude-conductor` remain the CLI and `claude-conductor dashboard` be explicit?
2. **Auto-linking via SessionStart hook?** In a future sprint, could a global Claude Code hook prompt you to assign a persona when a new session starts, automatically populating `.conductor-links.json`?
3. **Mobile access?** The dashboard runs on localhost. For phone access, you'd need Tailscale or similar. Worth documenting but not building yet.
4. **Merge the repos or keep separate?** This plan assumes the dashboard lives inside the existing `claude-conductor` repo. Alternative: create `claude-conductor-dashboard` as a separate code-katz repo. Recommendation: keep it in one repo — it's one tool.

---

## References

- Fork source: [github.com/Stargx/claude-code-dashboard](https://github.com/Stargx/claude-code-dashboard) — MIT license, 2 dependencies, ~2 files
- Previous plans (now superseded by this consolidated plan):
  - `plans/2026-03-28-v01-completion-plan.md` — v0.1 bash CLI completion
  - `plans/2026-03-30-token-tracking-feature-spec.md` — JSONL token tracking
  - `plans/2026-03-30-realtime-dashboard-feature-spec.md` — real-time dashboard research
- Paperclip architecture research: `docs/Code-Katz-Paperclip-Investigation.md`
- Claude Code hooks reference: [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks)
