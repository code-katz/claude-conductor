# claude-conductor — Runbook

Operational guide for installing, running, and using claude-conductor to coordinate parallel Claude Code sessions.

---

## Prerequisites

- macOS or Linux
- Bash 3.2+
- [Claude Code](https://claude.ai/code) installed
- [claude-team-cli](https://github.com/code-katz/claude-team-cli) installed (recommended, for personas and `/parallel`)
- `~/.local/bin` on your PATH

---

## Installation

### From the repo (recommended)

```bash
cd ~/d20m-development/code-katz/claude-conductor
bash install.sh
```

This installs three things:

1. **Skill file** → `~/.claude/skills/conductor/SKILL.md`
   - Claude Code reads this automatically and enables the `/conductor` behavior
2. **Slash commands** → `~/.claude/commands/conductor.md` and `sessions.md`
   - Enables `/conductor` and `/sessions` in Claude Code
3. **CLI** → `~/.local/bin/claude-conductor` (symlinked to `bin/claude-conductor` in the repo)
   - Available in any terminal session

### Verify installation

```bash
# CLI should respond
claude-conductor help

# Check that the skill file is in place
ls ~/.claude/skills/conductor/SKILL.md

# Check that slash commands are in place
ls ~/.claude/commands/conductor.md
ls ~/.claude/commands/sessions.md
```

### Skill-only install (no CLI)

If you only want the Claude Code skill without the terminal CLI:

```bash
mkdir -p ~/.claude/skills/conductor
cp SKILL.md ~/.claude/skills/conductor/SKILL.md
mkdir -p ~/.claude/commands
cp commands/conductor.md ~/.claude/commands/
cp commands/sessions.md ~/.claude/commands/
```

---

## Initial Setup (Per Project)

Before using the conductor in a project, initialize SESSIONS.md:

### Option A: From the terminal

```bash
cd ~/your-project
claude-conductor init
```

This creates `SESSIONS.md` in the project root (same directory as your DEVLOG.md, ROADMAP.md, and TODOS.md). It prompts for the project name and sets up the empty session tables.

### Option B: From Claude Code

Open Claude Code in your project and type:

```
/conductor start
```

If SESSIONS.md doesn't exist, the skill creates it automatically when registering the first session.

---

## Day-to-Day Usage

### The typical workflow

**Step 1: Plan parallel sessions**

In your coordination session (the Claude Code terminal you keep open for planning and commits):

```
/parallel
```

This generates a session plan with personas, tasks, and file scopes. Review and approve it.

**Step 2: Register sessions**

```
/conductor start
```

The conductor parses the `/parallel` output and registers all sessions into SESSIONS.md. Each session gets a number, persona, task, file scope, status (`planning`), and dependency information.

Or combine planning and registration:

```
/conductor plan
```

**Step 3: Open terminals and work**

For each session in the plan, open a new Claude Code terminal:

1. Activate the persona: `/akira` (or whichever persona the plan specifies)
2. Paste the task from the plan
3. Work

**Step 4: Track progress**

From your coordination session, check on all sessions:

```
/conductor
```

This shows the compact status view:

```
Session Status for The Chronicle:

  #1  ⚡ Akira    — Implement /battles CRUD         [coding]
  #2  🚫 Sasha    — BattleLog wizard                [blocked → waiting on #1]
  #3  📋 Robin    — Integration tests                [planning]

Merge order: #1 → (#2, #3)
```

Update statuses as work progresses:

```
/conductor update 1 done
```

The conductor will notify you when blocked sessions become unblocked.

**Step 5: Merge and close**

When a session completes:

```
/conductor done 1
```

The conductor prompts for an outcome summary and offers to create a devlog entry. It also tells you the next step in the merge order.

After merging:

```
/conductor merge 1
```

**Step 6: Archive when the sprint is done**

```
/conductor clear
```

Moves all completed and merged sessions to the archive section and resets for the next sprint.

---

## CLI Reference

These commands work from any terminal (not just Claude Code):

| Command | What it does |
|---------|-------------|
| `claude-conductor` | Show all active sessions (default) |
| `claude-conductor status` | Same as above |
| `claude-conductor init` | Create SESSIONS.md in the current project |
| `claude-conductor help` | Show full command reference |

### Slash commands (Claude Code only)

| Command | What it does |
|---------|-------------|
| `/conductor` | Show current session status |
| `/sessions` | Alias for `/conductor` |
| `/conductor start` | Register sessions (from /parallel output or manual) |
| `/conductor update <#> <status>` | Update a session's status |
| `/conductor done <#>` | Mark a session complete |
| `/conductor merge <#>` | Mark a session as merged |
| `/conductor abandon <#>` | Mark a session as abandoned |
| `/conductor plan` | Generate /parallel plan and auto-register |
| `/conductor clear` | Archive completed sessions and reset |

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

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| `SESSIONS.md` | Project root (e.g., `~/my-project/SESSIONS.md`) | Session state for this project |
| `SKILL.md` | `~/.claude/skills/conductor/SKILL.md` | Claude Code skill definition |
| `conductor.md` | `~/.claude/commands/conductor.md` | Slash command |
| `sessions.md` | `~/.claude/commands/sessions.md` | Alias slash command |
| `claude-conductor` | `~/.local/bin/claude-conductor` | CLI (symlinked to repo) |

---

## Troubleshooting

### `/conductor` doesn't work in Claude Code

1. Check the skill is installed: `ls ~/.claude/skills/conductor/SKILL.md`
2. Check the command is installed: `ls ~/.claude/commands/conductor.md`
3. Start a new Claude Code session (skills are loaded at session start)

### `claude-conductor` not found in terminal

1. Check it exists: `ls -la ~/.local/bin/claude-conductor`
2. Check your PATH: `echo $PATH | tr ':' '\n' | grep local`
3. If missing, add to `~/.zshrc`: `export PATH="$HOME/.local/bin:$PATH"` and run `source ~/.zshrc`

### SESSIONS.md not found

The conductor looks for SESSIONS.md by walking up from the current directory to find the git root. Make sure you're inside a git repository:

```bash
git rev-parse --show-toplevel
```

If not in a git repo, SESSIONS.md defaults to the current directory.

### Status shows "No active sessions" but I have sessions running

The conductor only knows about sessions that were registered via `/conductor start`. If you opened terminals without registering them, use `/conductor start` to register them manually.

---

## Running Tests

```bash
cd ~/d20m-development/code-katz/claude-conductor
bash tests/run.sh
```

Expected output: 16 tests, all passing. The tests create a temporary git repo, test CLI commands, and verify SESSIONS.md parsing.

---

## Uninstalling

```bash
# Remove skill
rm -rf ~/.claude/skills/conductor

# Remove slash commands
rm ~/.claude/commands/conductor.md
rm ~/.claude/commands/sessions.md

# Remove CLI
rm ~/.local/bin/claude-conductor
```

SESSIONS.md files in your projects can be deleted or kept as historical records.
