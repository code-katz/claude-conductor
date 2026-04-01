<p align="center">
  <img src="publish/images/claude-conductor-header.svg" alt="claude-conductor" width="100%">
</p>

# claude-conductor

> See all your parallel Claude Code sessions. Know who is doing what.

![License: MIT](https://img.shields.io/badge/license-MIT-blue) ![Bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-green) ![Works with Claude Code](https://img.shields.io/badge/works%20with-Claude%20Code-8A2BE2) ![Skill + CLI](https://img.shields.io/badge/type-skill%20%2B%20CLI-orange)

---

## The Problem

You run `/parallel` and get a clean plan: three sessions, three personas, three file scopes, a merge order. You open the terminals. Work begins.

Thirty minutes later, you have six tabs open and no idea which one is which. Akira finished the API endpoints, but did Sasha see that? Robin is writing tests against an API contract that might have changed. You think Session 2 is blocked on Session 1, but you're not sure Session 1 is actually done. You alt-tab between terminals trying to reconstruct the state of your sprint from terminal scrollback.

The `/parallel` command plans the work. The conductor tracks it.

---

## Who This Is For

Developers running 2+ parallel Claude Code sessions who use [claude-team-cli](https://github.com/code-katz/claude-team-cli) to assign personas to each session.

If you've ever lost track of which terminal has which persona, forgotten the merge order from a `/parallel` plan, or missed that a blocked session became unblocked twenty minutes ago, the conductor is for you.

---

## See the Difference

You have three parallel sessions running. You want to know the state of the sprint.

**Without the conductor:**

> **You:** *(alt-tabs to Terminal 1)* What was Akira working on again? *(scrolls up)* Oh right, the API endpoints. Are they done? *(reads scrollback)* Looks done maybe? *(alt-tabs to Terminal 2)* Is Sasha still blocked? *(alt-tabs to Terminal 3)* Wait, which one was Robin in?

**With the conductor:**

> **You:** `/conductor`
>
> ```
> Session Status for The Chronicle:
>
>   #1  ✅ Akira    — Implement /battles CRUD         [done]
>   #2  🚫 Sasha    — BattleLog wizard                [blocked → waiting on #1]
>   #3  📋 Robin    — Integration tests                [planning]
>
> Merge order: #1 → (#2, #3)
> ```
>
> **Claude:** Session #1 is done. Session #2 is blocked on #1, but #1 just completed, so Sasha is unblocked. Want me to update #2 to `coding`?

One command. Full visibility. No tab-switching.

<!-- TODO: capture fresh screenshot of v1 live dashboard and embed here -->

---

## What It Does

- **Tracks active sessions** in a `SESSIONS.md` file with persona, task, file scope, status, and dependencies
- **Shows status at a glance** with a compact formatted view and status icons
- **Live web dashboard** with real-time session monitoring, persona icons, and permission mode badges
- **Per-session token counts and cost tracking** so you know where context is going
- **Auto-links Claude Code sessions** to conductor personas via JSONL detection
- **Monitors dependencies** and notifies when blocked sessions become unblocked
- **Enforces merge order** so you know what to merge first
- **Auto-registers sessions** from `/parallel` output, so you go from plan to tracking in one step
- **Integrates with devlog** to capture what each session accomplished when it completes
- **Tracks session lifecycle** from planning through merge with a timestamped session log
- **Checks for linter config** on first use per session

---

## Session Statuses

| Status | Icon | Meaning |
|--------|------|---------|
| `planning` | 📋 | Session is in plan mode, no edits yet |
| `coding` | ⚡ | Actively writing code |
| `reviewing` | 🔍 | Code complete, reviewing or testing |
| `blocked` | 🚫 | Waiting on another session or external input |
| `done` | ✅ | Task complete, ready to merge |
| `merged` | 🏁 | Code merged into main branch |
| `abandoned` | ❌ | Session stopped without completing task |

---

## Installation

### Quick install

```bash
git clone https://github.com/code-katz/claude-conductor.git
cd claude-conductor
bash install.sh
```

This installs:
- The conductor skill to `~/.claude/skills/conductor/`
- Slash commands (`/conductor`, `/sessions`) to `~/.claude/commands/`
- The `claude-conductor` CLI to `~/.local/bin/` (symlinked)

Make sure `~/.local/bin` is on your `PATH`:

```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"
```

### Skill-only install (no CLI)

If you only want the Claude Code skill and slash commands:

```bash
mkdir -p ~/.claude/skills/conductor
curl -o ~/.claude/skills/conductor/SKILL.md \
  https://raw.githubusercontent.com/code-katz/claude-conductor/main/SKILL.md

mkdir -p ~/.claude/commands
curl -o ~/.claude/commands/conductor.md \
  https://raw.githubusercontent.com/code-katz/claude-conductor/main/commands/conductor.md
curl -o ~/.claude/commands/sessions.md \
  https://raw.githubusercontent.com/code-katz/claude-conductor/main/commands/sessions.md
```

---

## Usage

### In Claude Code (primary workflow)

```bash
# Show all active sessions
/conductor
/sessions                    # alias

# Plan and register sessions in one step
/conductor plan

# Register sessions from a /parallel plan you already generated
/conductor start

# Update a session's status
/conductor update 1 coding
/conductor update 2 blocked

# Mark a session complete
/conductor done 1

# Mark a session as merged
/conductor merge 1

# Mark a session as abandoned
/conductor abandon 3

# Archive completed sessions and reset
/conductor clear
```

### CLI (from your terminal, outside Claude Code)

```bash
# Show all active sessions
claude-conductor status
claude-conductor              # status is the default

# Create SESSIONS.md in your project
claude-conductor init

# Full command reference
claude-conductor help
```

---

## Typical Workflow

### 1. Plan the sprint

In your coordination session (the one you keep open for questions and commits):

```
/parallel
```

This generates a session plan with personas, tasks, and file scopes.

### 2. Register the sessions

```
/conductor start
```

The conductor parses the `/parallel` output and registers all sessions automatically.

Or combine both steps:

```
/conductor plan
```

### 3. Open terminals and work

Open a new Claude Code terminal for each session. Activate the persona (`/akira`, `/sasha`, `/robin`) and paste the task from the plan.

### 4. Track progress

From your coordination session, check on everyone:

```
/conductor
```

Update statuses as work progresses:

```
/conductor update 1 coding
/conductor update 1 done
```

### 5. Merge and close

When sessions complete, the conductor tells you the merge order:

```
/conductor merge 1
```

It notifies you when blocked sessions become unblocked:

> "Session #2 is unblocked. Sasha can proceed with the BattleLog wizard."

### 6. Log and archive

When a session completes, the conductor offers to create a devlog entry. After the sprint, archive everything:

```
/conductor clear
```

---

## SESSIONS.md

Lives in your project root alongside `DEVLOG.md`, `ROADMAP.md`, and `TODOS.md`. Contains:

- **Active Sessions table** with persona, task, files, status, dependencies
- **Merge Order** showing the dependency graph
- **Completed Sessions table** with duration and outcome
- **Session Log** with timestamped lifecycle events

The file is a coordination artifact. It changes frequently during a sprint and is not auto-committed. Commit it manually if you want it in source control.

---

## Works Well With

| Project | What it does | How it connects |
|---|---|---|
| [claude-team-cli](https://github.com/code-katz/claude-team-cli) | Personas and `/parallel` planning | Conductor tracks sessions that `/parallel` creates |
| [claude-devlog-skill](https://github.com/code-katz/claude-devlog-skill) | Structured development changelog | Session completions auto-generate devlog entries |
| [claude-roadmap-skill](https://github.com/code-katz/claude-roadmap-skill) | Living product roadmap | Sprint completions update roadmap tier items |
| [claude-plans-skill](https://github.com/code-katz/claude-plans-skill) | Archived implementation plans | Conductor references the active plan for context |
| [claude-todo-skill](https://github.com/code-katz/claude-todo-skill) | Lightweight task scratchpad | Abandoned sessions create todo items for follow-up |
| [claude-publish-agent](https://github.com/code-katz/claude-publish-agent) | Publish markdown to platforms | Write about your multi-session workflow |

---

## Project Structure

```
claude-conductor/
├── README.md
├── SKILL.md                # The skill source file
├── DEVLOG.md               # Development log for this project
├── RUNBOOK.md              # Operational guide
├── install.sh              # One-command installer
├── bin/
│   ├── claude-conductor    # CLI script
│   ├── conductor-hook      # PostToolUse hook for proactive status
│   ├── generate-dashboard  # Static HTML dashboard generator
│   └── serve-dashboard     # Dashboard server wrapper
├── commands/
│   ├── conductor.md        # /conductor slash command
│   └── sessions.md         # /sessions alias
├── dashboard/
│   ├── watcher.js          # Live dashboard server (Node.js)
│   ├── public/index.html   # React dashboard UI
│   └── package.json        # Dashboard dependencies
├── tests/
│   ├── run.sh              # CLI test suite (104 tests)
│   ├── dashboard.sh        # Static dashboard tests (27 tests)
│   └── dashboard-live.sh   # Live dashboard tests (26 tests)
├── docs/                   # Architecture and design docs
└── publish/
    └── images/             # Banner images, screenshots
```

---

## Requirements

- macOS or Linux
- Bash 3.2+
- [Claude Code](https://claude.ai/code)
- [claude-team-cli](https://github.com/code-katz/claude-team-cli) (recommended, for personas and `/parallel`)
- Node.js 18+ (optional, for live dashboard)

---

## Live Dashboard

The conductor includes a real-time web dashboard that auto-detects your Claude Code sessions, tracks token usage and costs, and overlays persona/task data from SESSIONS.md.

```bash
# Install with dashboard support
bash install.sh --with-dashboard

# Start the live dashboard
claude-conductor dashboard --live

# Stop it
claude-conductor dashboard --live --stop
```

The live dashboard provides:
- Real-time session monitoring (2-second polling)
- Per-session token counts and cost tracking
- Context window usage bars
- Auto-linking of Claude Code sessions to conductor personas
- Conductor-aware status (coding, planning, reviewing, needs_input)
- Merge order visualization from SESSIONS.md

The static HTML dashboard (`claude-conductor dashboard --open`) remains available as a zero-dependency fallback.

---

## Roadmap

### v1.0 (current)

- SESSIONS.md format with active/completed tables and session log
- Slash commands: `/conductor`, `/sessions`, `/conductor start`, `/conductor update`, `/conductor done`, `/conductor merge`, `/conductor abandon`, `/conductor clear`, `/conductor plan`
- CLI: `claude-conductor status`, `init`, `start`, `update`, `done`, `merge`, `abandon`, `clear`, `conflicts`, `dashboard`, `link`, `unlink`, `help`
- Static HTML dashboard with file conflict detection
- Live Node.js dashboard with real-time session monitoring, token tracking, and cost display
- Persona icons, smart project labels, and permission mode badges
- Auto-linking of JSONL sessions to conductor personas
- Enhanced status detection (coding/planning/reviewing/needs_input/disconnected)
- Dependency tracking with unblock notifications
- Merge order enforcement
- Integration hooks for devlog, roadmap, and todo skills
- 157 tests across CLI, static dashboard, and live dashboard

### Next

- **Claude Code hooks:** `SessionStart` hook to auto-assign personas on new session creation
- **Git integration:** detect file conflicts between sessions before they happen
- **Paperclip bridge:** adapter to sync session state into a Paperclip instance for users who want the full orchestration platform

---

## Acknowledgments

The live dashboard is built on [claude-code-dashboard](https://github.com/Stargx/claude-code-dashboard) by [Stargx](https://github.com/Stargx) (MIT), which provides real-time JSONL session monitoring, token tracking, and the React dashboard UI. Code Katz extended it with SESSIONS.md integration, persona enrichment, auto-linking, conductor-aware status detection, and CLI orchestration.

---

## License

See [LICENSE](LICENSE) for details.
