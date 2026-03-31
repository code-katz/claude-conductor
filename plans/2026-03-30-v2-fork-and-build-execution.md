> Source: `~/.claude/plans/robust-prancing-whisper.md`
> Archived: 2026-03-30 · Project: claude-conductor
> Status: `active`
> Maintained by [claude-plans-skill](https://github.com/code-katz/claude-plans-skill).

---

# claude-conductor v2: Fork & Build Execution Plan

## Context

claude-conductor v0.2 is a bash CLI + static HTML dashboard for coordinating parallel Claude Code sessions. It works, but two planned features (real-time monitoring, token tracking) would require significant new development. The [Stargx/claude-code-dashboard](https://github.com/Stargx/claude-code-dashboard) (MIT, 996 lines, 2 deps) already provides both features out of the box via JSONL file watching. Forking and extending it is faster than building from scratch, and consolidates three separate feature specs into one effort.

The existing v2 plan at `code-katz/claude-conductor/docs/2026-03-30-v2-fork-and-build-plan.md` is sound. This execution plan refines it with product risk resolutions, clearer sequencing, and acceptance criteria.

---

## Key Product Decisions

### 1. Keep the static dashboard as fallback
The existing `bin/generate-dashboard`, `templates/dashboard.html`, and `bin/serve-dashboard` stay. The live dashboard is additive, accessed via `claude-conductor dashboard --live`. Nothing is removed in v2.

**Why:** The CLI must remain fully functional without Node.js. Zero-dependency is a core value of the tool. The live dashboard is opt-in.

### 2. `--with-dashboard` install flag
`install.sh` gains an optional `--with-dashboard` flag that runs `npm install` in `dashboard/`. Without it, installation is unchanged (bash-only).

### 3. Auto-linking over manual linking
The watcher scans the first user message of each JSONL file for patterns like `session #N` or persona names. This auto-populates `.conductor-links.json`. Manual `claude-conductor link/unlink` exists as override. No manual step required for standard workflows.

### 4. CLI default unchanged
`claude-conductor` (no args) remains `status`. `claude-conductor dashboard` remains static HTML. Only `claude-conductor dashboard --live` launches Node.js.

### 5. Shell-based tests for Node.js layer
New `tests/dashboard-live.sh` follows existing bash test harness pattern. No Jest. Start server, curl APIs, assert JSON, clean up. Keeps test stack uniform.

---

## Sprint Sequence

### Sprint 0: Fork & Verify (Quinn, 1 session)

**Goal:** Forked dashboard runs inside the conductor repo. Zero existing files modified.

**Steps:**
1. Create `dashboard/` directory
2. Copy `watcher.js`, `public/index.html`, `package.json` from Stargx repo
3. `cd dashboard && npm install && node watcher.js`
4. Verify at `localhost:3001` with active Claude Code sessions
5. Add to `.gitignore`: `node_modules/`, `.conductor-links.json`, `.conductor-live-server.pid`
6. Commit: `chore: add dashboard from Stargx/claude-code-dashboard (MIT)`

**Acceptance criteria:**
- [x] `node dashboard/watcher.js` starts without errors
- [x] `localhost:3001` shows active sessions
- [x] All existing tests pass (`tests/run.sh` + `tests/dashboard.sh`)
- [x] No existing files modified

**Files added:** `dashboard/watcher.js`, `dashboard/public/index.html`, `dashboard/package.json`
**Files modified:** `.gitignore`

---

### Sprint 1: Branding (Sasha, 1 session) -- can parallel with Sprint 2A

**Goal:** Dashboard looks like a Code Katz tool.

**Steps:**
1. Replace color palette with Code Katz dark theme (`#141413` bg, `#faf9f5` text, `#d4a843` amber)
2. Replace fonts with Poppins + JetBrains Mono
3. Add Code Katz banner/logo in header
4. Add empty "Persona" slot on session tiles (populated by Sprint 2B)
5. Replace fork's status colors with conductor emoji set
6. Make "waiting" state a pulsing amber alert
7. Create `publish/images/conductor-v2-banner.svg`

**Acceptance criteria:**
- [ ] No Stargx branding visible
- [ ] Colors/fonts match existing static dashboard (`templates/dashboard.html` lines 12-27)
- [ ] Session tiles have visible "Persona: Unassigned" placeholder

**Files modified:** `dashboard/public/index.html`
**Files added:** `publish/images/conductor-v2-banner.svg`

---

### Sprint 2A: Backend Integration (Akira, 1 session) -- can parallel with Sprint 1

**Goal:** Watcher parses SESSIONS.md, auto-links sessions, maps statuses.

**Steps:**
1. Add SESSIONS.md parser to `watcher.js` (find file via git root walk, parse Active Sessions table, watch for changes)
2. Implement auto-linking: scan first `user` message in each JSONL for `session #N` / persona patterns, write `.conductor-links.json`
3. Add API endpoints: `GET /api/conductor` (SESSIONS.md data), `GET /api/links` (link mappings)
4. Enrich `GET /api/sessions` with conductor data for linked sessions
5. Map status detection:
   - `thinking` + Write/Edit tool -> `coding`
   - `thinking` + no edit tools -> `planning`
   - `thinking` + Bash with test/lint -> `reviewing`
   - `waiting` -> `needs_input`
   - `idle` -> `idle`
   - `stale` (>5min) -> `disconnected`

**Acceptance criteria:**
- [ ] `GET /api/conductor` returns parsed SESSIONS.md
- [ ] Auto-linking populates `.conductor-links.json` within 10s for standard-workflow sessions
- [ ] `GET /api/sessions` includes persona/task for linked sessions
- [ ] Status mapping distinguishes coding/planning/reviewing

**Files modified:** `dashboard/watcher.js`

---

### Sprint 2B: CLI + Frontend Enrichment (Akira, 1 session) -- depends on 2A

**Goal:** CLI commands for live dashboard. Frontend shows persona data and merge order.

**Steps:**
1. Add to `bin/claude-conductor`:
   - `dashboard --live`: check for `node`, start `dashboard/watcher.js` in bg, write PID, open browser
   - `dashboard --live --stop`: kill from PID file, clean up
   - `link <#> <session_id>`: write to `.conductor-links.json`
   - `unlink <#>`: remove from `.conductor-links.json`
2. Update `dashboard/public/index.html`:
   - Show persona name, task, file scope on linked tiles
   - Show "Unassigned" badge on unlinked sessions
   - Add merge order visualization from SESSIONS.md Depends On column

**Acceptance criteria:**
- [ ] `claude-conductor dashboard --live` starts server, opens browser
- [ ] `claude-conductor dashboard --live --stop` stops cleanly
- [ ] `link`/`unlink` commands work and persist to JSON
- [ ] Dashboard shows persona names on linked sessions
- [ ] Merge order visible at bottom of dashboard
- [ ] All existing CLI tests pass

**Files modified:** `bin/claude-conductor`, `dashboard/public/index.html`, `dashboard/watcher.js` (minor)

---

### Sprint 3A: Tests (Robin, 1 session) -- depends on Sprints 1+2

**Goal:** Integration tests for the live dashboard.

**Steps:**
1. Create `tests/dashboard-live.sh` using existing test harness pattern
2. Test categories:
   - Server lifecycle (start, port check, stop)
   - API responses (`/api/sessions`, `/api/conductor`, `/api/links` JSON structure)
   - SESSIONS.md parsing (create temp file, verify API output)
   - Auto-linking (mock JSONL with `session #1 (Akira)`, verify `.conductor-links.json`)
   - CLI integration (`dashboard --live` starts, `--stop` kills)
   - Graceful degradation (error message when `node` not found)
   - Link/unlink commands
3. Tests skip gracefully if Node.js not installed (warning, not failure)
4. Target: 15-25 tests

**Files added:** `tests/dashboard-live.sh`

---

### Sprint 3B: Docs & Install (Quinn, 1 session) -- depends on Sprints 1+2

**Goal:** All docs current, install works end-to-end.

**Steps:**
1. Update `install.sh`: add `--with-dashboard` flag for `npm install`
2. Update `RUNBOOK.md`: live dashboard section, CLI reference, mobile access note
3. Update `README.md`: feature description, Stargx attribution
4. Update `SKILL.md`: `dashboard --live`, `link`, `unlink` docs
5. Update `commands/conductor.md`: new sub-commands
6. Add `dashboard/LICENSE` (MIT from Stargx)
7. Add DEVLOG.md entry for v2 architecture decision

**Files modified:** `install.sh`, `RUNBOOK.md`, `README.md`, `SKILL.md`, `commands/conductor.md`, `DEVLOG.md`
**Files added:** `dashboard/LICENSE`

---

## Dependency Graph

```
Sprint 0 (Quinn)
    |
    +---> Sprint 1  (Sasha, index.html) --+
    |                                      |
    +---> Sprint 2A (Akira, watcher.js) --+--> Sprint 2B (Akira, CLI + frontend)
                                                    |
                                           Sprint 3A (Robin) + Sprint 3B (Quinn) in parallel
```

**Merge order:** 0 -> (1 || 2A) -> 2B -> (3A || 3B)

## Session Estimate

| Sprint | Persona | Sessions | Est. Duration |
|--------|---------|----------|---------------|
| 0 | Quinn | 1 | 15-20 min |
| 1 | Sasha | 1 | 30-45 min |
| 2A | Akira | 1 | 45-60 min |
| 2B | Akira | 1 | 45-60 min |
| 3A | Robin | 1 | 30-45 min |
| 3B | Quinn | 1 | 20-30 min |
| **Total** | | **6 sessions** | **~3-4 hrs** |

## Verification

After all sprints merged:
1. `bash install.sh --with-dashboard` completes without errors
2. `claude-conductor status` works (unchanged behavior)
3. `claude-conductor dashboard` generates static HTML (unchanged)
4. `claude-conductor dashboard --live` starts Node.js server at `localhost:3001`
5. Dashboard shows active sessions with persona names, tasks, token costs
6. `claude-conductor dashboard --live --stop` kills server
7. All test suites pass: `tests/run.sh`, `tests/dashboard.sh`, `tests/dashboard-live.sh`

## Open Questions Resolved

| Question | Resolution |
|----------|-----------|
| Dashboard as default command? | No. `claude-conductor` stays as `status`. Live dashboard is `dashboard --live`. |
| Auto-linking via hook? | Deferred. Auto-linking via JSONL first-message scan covers the standard workflow. Hooks are a v3 consideration. |
| Mobile access? | Document in RUNBOOK.md, don't build. Suggest Tailscale. |
| Merge or separate repos? | One repo. Dashboard lives in `dashboard/` subdirectory. |
| Remove static dashboard? | No. Keep as fallback. Revisit in v3. |
