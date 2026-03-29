> Source: `~/.claude/plans/harmonic-leaping-mist.md`
> Archived: 2026-03-29 · Project: claude-conductor
> Status: `executed`
> Maintained by [claude-plans-skill](https://github.com/code-katz/claude-plans-skill).

---

# Plan: claude-conductor v0.2 — Dashboard + Conflict Detection

## Context

v0.1 is fully shipped (CLI lifecycle commands, 73 tests, visual identity, team-cli integration). The user runs 2-3 parallel Claude Code sessions and loses track of relationships, status, and progress. The CLI `status` command works but requires terminal switching which breaks flow. The user also wants early warning when parallel sessions have overlapping file scopes.

v0.2 adds two features: a static HTML dashboard (persistent browser tab) and string-based file conflict detection between sessions.

## Feature 1: Static HTML Dashboard

### Approach
A `generate_dashboard()` bash function that parses SESSIONS.md and writes a self-contained HTML file with inline CSS. No server, no Python, no JavaScript. Browser auto-refreshes via `<meta http-equiv="refresh" content="5">`.

### Dashboard Layout
- **Header bar**: Project name, session count, last updated timestamp
- **Session cards**: One card per active session showing persona, task, files, status (with emoji), started time, dependencies, notes
- **Dependency visualization**: Merge order section showing which sessions block which (CSS-styled arrows/badges)
- **Conflict warnings**: If file scope overlaps detected, shown as warning banner
- **Completed sessions**: Collapsed section at bottom
- **Dark theme**: `#141413` background, `#faf9f5` text, `#d4a843` amber accent, `#b0aea5` secondary text
- **Fonts**: Google Fonts (JetBrains Mono, Poppins) via CDN link

## Feature 2: Git Conflict Detection

### Approach
String-based file scope comparison. Reads the Files column from active sessions, tokenizes paths, and checks for prefix overlaps between every pair of sessions. No git operations, no filesystem access.

## Design Decisions

1. **Opt-in dashboard**: Auto-regeneration only happens after first explicit `dashboard` command (checks if file exists). Never slows down CLI for users who don't want the dashboard.
2. **No JavaScript**: Pure HTML+CSS with meta-refresh. Keeps the file self-contained and avoids complexity.
3. **String-based conflicts**: Compares file path strings from SESSIONS.md, not actual git state. Simple, fast, good enough for the 80% case.
4. **Silent dashboard failures**: `maybe_regenerate_dashboard()` uses `|| true`. Dashboard bugs never break primary commands.
5. **Google Fonts via CDN**: Requires internet for proper font rendering, but degrades gracefully to system monospace/sans-serif.
