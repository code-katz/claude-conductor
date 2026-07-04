# Phase 4 Spike: Conductor and Native Agent Teams

> Question: when Claude Code's experimental agent teams reach GA, is conductor's future "the durable artifact + merge-order layer on top of native teams," or a standalone tracker? This spike gathers the facts needed to answer, and ships a read-only prototype bridge.
> Environment: Claude Code v2.1.201. Native task format verified against real task files produced by this harness. Agent-team behavior verified against official docs (code.claude.com/docs/en/agent-teams); a live team was not run for this spike.

## 1. Verified findings

### The native task format maps almost 1:1 onto conductor's schema

Native task lists live at `~/.claude/tasks/<list-id>/<n>.json` (list-id is a session id; for agent teams, the team name, `session-` + first 8 chars of the lead's session id). Verified real format:

```json
{
  "id": "1",
  "subject": "team-cli: rewrite /parallel for worktree isolation",
  "description": "...",
  "activeForm": "Rewriting /parallel for worktrees",
  "status": "completed",
  "blocks": [],
  "blockedBy": []
}
```

Team tasks additionally carry `owner` (the teammate's name). Mapping:

| Native task field | Conductor column |
|---|---|
| `subject` | Task |
| `status` pending / in_progress / completed | planning / coding / done |
| `owner` | Persona |
| `blockedBy` | Depends On |
| `activeForm` | Activity |

What the native list does NOT carry: file scope, branch, merge order, cost, started-at. Those are exactly conductor's additions.

### Team metadata

`~/.claude/teams/{team-name}/config.json` holds a `members` array (name, agent id, agent type). Both stores are machine-local, cleaned up per retention policy, never committed, and the docs explicitly reject a project-level team-state file. Task claiming uses file locking, so third-party WRITES to these files are unsafe by design.

### Hook feeds exist for exactly what conductor needs

`TaskCreated`, `TaskCompleted`, and `TeammateIdle` fire in team contexts. A TaskCompleted hook invoking `claude-conductor u <n> done` (after resolving the task to a row) would give conductor real-time status without any transcript scanning. These events fire only for team sessions, so registering them is a no-op for today's workflows.

### Constraints that gate adoption

Experimental and off by default (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`); one team per session; no session resumption with in-process teammates; task status can lag; internal formats can change on any release (same caveat as the JSONL transcripts, and the same fixture-based defense applies).

## 2. Prototype shipped with this spike

`bin/conductor-teams-peek` — a read-only viewer that renders any native task list in conductor terms (status icons, persona, dependencies, activity). Read-only is deliberate: the native store uses file locking for claim coordination, so the bridge observes and never writes. Try it:

```bash
conductor-teams-peek                 # list native task lists
conductor-teams-peek <list-id>       # one list, conductor-style
```

Covered by 6 tests against pinned fixtures (suite total: 117).

## 3. Assessment

The two systems are complementary, not competitive, and the seam is clean:

- **Native teams own**: execution topology (lead + teammates), messaging, task claiming, in-session display.
- **Conductor owns**: the committed artifact (SESSIONS.md survives the team; native state is deleted with the session), file scopes and conflict detection, branch/merge order, cost, and the human-driven multi-terminal workflow that teams do not address.

**Recommended posture: conductor becomes team-aware, not team-based.** Concretely, when teams reach GA:

1. **Ingest, don't mirror**: a SessionStart/TaskCreated-driven importer that registers team tasks as conductor rows (owner→persona, blockedBy→depends), so a team sprint appears in SESSIONS.md and the dashboard alongside human worktree sessions.
2. **Hook-driven status**: TaskCompleted/TeammateIdle hooks update rows; no polling, no transcript parsing.
3. **Never write the native store**: conductor's merge-order and scope-conflict logic stays advisory on top; task claiming remains native.
4. **Fixture-fence the formats** exactly as done for transcripts: pin sample task/config files in CI so a format change breaks tests, not users.

**Do not build the full bridge yet.** The blocking conditions to revisit: teams GA (or the experimental flag defaulting on), session resumption support for teammates, and a documented (or at least stable-in-practice) task/config format across several releases. Until then, `conductor-teams-peek` answers "what is that team doing" on demand, and the drill-tested worktree workflow remains the primary path.

## 4. Facts for the eventual implementation

- List ids under `~/.claude/tasks/` are session ids for solo sessions and team names for teams; distinguish by the presence of `~/.claude/teams/<id>/config.json`.
- `status` also admits `deleted` (peek skips them).
- `blockedBy` holds numeric ids, not `#n` strings.
- Team names are derivable from the lead session id (`session-` + first 8 chars), which the SessionStart hook already receives on stdin — auto-detection of "this session leads a team" is one string operation away.
