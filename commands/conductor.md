Show the current status of all parallel Claude Code sessions, or manage session lifecycle.

You are acting as the session conductor. Use the conductor skill (SKILL.md) to handle this command.

**If called with no arguments (`/conductor`):**
Read SESSIONS.md and display the compact status view showing all active sessions with their persona, task, status, and dependencies.

**If called with a sub-command:**
- `/conductor start` — register new sessions (from /parallel output or manual entry)
- `/conductor update <#> <status>` — update a session's status
- `/conductor done <#>` — mark a session complete
- `/conductor merge <#>` — mark a session as merged
- `/conductor abandon <#>` — mark a session as abandoned
- `/conductor plan` — generate a /parallel plan and auto-register sessions
- `/conductor clear` — archive completed sessions and reset
- `/conductor dashboard --live` — start the real-time Node.js dashboard
- `/conductor dashboard --live --stop` — stop the live dashboard
- `/conductor link <#> <session_id>` — link a Claude Code session to a conductor session
- `/conductor unlink <#>` — remove a session link

See the conductor SKILL.md for full behavior specifications.
