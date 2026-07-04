# Landscape Survey: Parallel Claude Code Session Orchestration (July 2026)

> Question under evaluation: does an existing, hardened solution (native Claude feature, popular tool, or IDE) meet the goals of claude-conductor?
> Method: multi-agent web survey with direct fetches of official docs, repos, and vendor sites on 2026-07-04. Items that could not be directly fetched (some vendor sites returned 403 through the research proxy) are marked UNVERIFIED where relevant.
> Conductor's goals, as scored: (a) parallel session tracking with statuses, (b) worktree/branch isolation, (c) dependency-aware merge ordering, (d) persona identity per session, (e) per-session token/cost, (f) human-driven interactive sessions, (g) durable in-repo artifact, (h) maintenance health.

## Verdict

No existing tool meets the full goal set. Hardened solutions exist for isolation plus session visibility (roughly half of conductor's surface), and that layer is being commoditized by Anthropic itself. For the coordination semantics: exactly one tool has real merge-queue mechanics and agent identities (Gas Town), but it targets autonomous 20-30 agent swarms, not human-piloted sessions. Nobody covers dependency-aware merge ordering for human session branches, a committed in-repo coordination artifact, behavioral personas bound to sessions, or passive tracking of sessions launched in arbitrary terminals. Those four are conductor's defensible core.

## Comparison table

Key: Y = yes, P = partial, N = no, U = unverified.

| Tool | a | b | c | d | e | f | g | h |
|---|---|---|---|---|---|---|---|---|
| Agent teams (Anthropic, experimental) | Y | N | P (tasks, not merges) | P | N | P | N | N (experimental) |
| Agent view / `--bg` (Anthropic, preview) | Y | Y | N | P | P | Y | N | P (preview) |
| Claude Code Desktop (GA, Apr 2026 parallel sidebar) | Y | Y | N | P | Y | Y | N | Y |
| Claude Code on the web (GA) | P | P | N | P | U | P | N | Y |
| VS Code extension (GA, parallel tabs) | Y | P | N | P | Y | Y | N | Y |
| Conductor.build (Melty Labs, Mac app) | Y | Y | N | P | P | Y | N | Y |
| Crystal (stravu) | Y | Y | P | N | P | Y | N | N (deprecated Feb 2026) |
| Nimbalyst (Crystal successor) | Y | Y | N | P | P/U | Y | P/U | Y (young) |
| Vibe Kanban (BloopAI) | Y | Y | N | N | N | P | N | P (Bloop shut down Apr 2026) |
| claude-squad (smtg-ai, ~8k stars) | Y | Y | N | P | N | Y | N | Y |
| CCManager (kbwo) | Y | Y | N | N | N | Y | N | Y |
| Sculptor (Imbue) | Y | P | N | N | N | Y | N | P (research preview) |
| claude-flow / Ruflo (ruvnet) | P | P/U | P | P | P | N/P | P | P (autonomous swarms, not human sessions) |
| Gas Town (gastownhall, Steve Yegge, ~16k stars) | Y | Y | Y ("Refinery" Bors-style merge queue) | Y (agent roles/identities) | N/U | P (autonomous swarms) | P (JSONL beads, not markdown) | Y |
| Happy (slopus, ~22k stars, mobile/web remote) | Y | P | N | N | P | Y | N | Y |
| cmux (manaflow-ai, ~24k stars, agent-aware terminal) | Y | P | N | N | N | Y | N | Y |
| Emdash (generalaction, YC W26) | Y | Y | N | N | N/U | P | N | Y |
| coder/mux (Coder Technologies) | Y | Y | N | N | Y (cost dashboard) | Y | P | Y |
| Zed Parallel Agents (Apr 2026) | Y | Y (opt-in) | N | N | N | Y | N | Y |
| Cursor 3.x parallel agents | Y | Y | N | N | N | P | N | Y |
| JetBrains Air (preview) | Y | Y | U | N | U | P | N | P |
| ccusage (cost CLI, ~17k stars) | N | N | N | N | Y | n/a | N | Y |

## Key findings

### 1. Merge ordering between session branches: covered by exactly one tool, for a different workflow
Every session-manager GUI ends at "review diff, open PR, merge" per workspace (verified for Conductor.build: merge flow is strictly per-workspace PR plus a Checks-tab gate; no cross-workspace ordering anywhere in its docs or changelog). The exceptions and near-misses: Gas Town's "Refinery" is a genuine Bors-style merge queue with verification gates, but Gas Town orchestrates autonomous 20-30 agent swarms driven through a coordinating "Mayor," not N human-piloted terminals. Agent teams unblock dependent *tasks* (not merges; experimental). Stack-aware merge queues (Graphite, GA; GitHub stacked PRs, private preview) order PR stacks but know nothing about Claude sessions. For the human-driven parallel-session workflow, dependency-aware merge ordering remains uncovered.

### 2. Durable in-repo coordination artifact: the niche is empty
Agent teams store the shared task list in `~/.claude/tasks/` (docs explicitly reject a project-level team-state file: "a file like `.claude/teams/teams.json` in your project directory is not recognized"). All GUI orchestrators use app databases or config dirs. In-repo markdown state exists for tasks/specs (Backlog.md ~5.9k stars, spec-kit ~118k stars, cc-sessions ~1.5k stars, beads ~25k stars but JSONL) but none track sessions/agents. No SESSIONS.md-equivalent convention exists anywhere else on GitHub. Anthropic's own best-practices guidance endorses markdown scratchpads for inter-Claude coordination, but no product implements it.

### 3. Personas: only shallow naming exists elsewhere
Agent teams give teammates lead-assigned names; claude-squad has launcher profiles; Conductor.build assigns city codenames to workspaces. No surveyed tool binds a behavioral persona (name + role + expertise) to a human-driven session as a tracked entity. claude-team-cli + claude-conductor is, per the survey, the clearest implementation of that pattern in the ecosystem.

### 4. Passive discovery of arbitrary terminal sessions: unique to conductor
Every surveyed tool tracks only sessions launched inside it (or backgrounded from within Claude Code, for agent view). Conductor's JSONL-detection auto-linking of sessions the user started in any terminal was not found in any other tool.

### 5. Per-session cost: solved as data, unsolved as dashboard
ccusage (~16.8k stars, v20.x, very active) is the de-facto standard for per-session cost from local JSONL data (`ccusage session --json`, statusline integration); claude-monitor v4 covers live monitoring. No orchestration dashboard surveyed shows cost-per-session as a first-class column. Anthropic closed the consolidated cross-session usage view request (anthropics/claude-code#31564) as not planned. Native surfaces (`/usage`, Desktop usage ring) are single-session.

### 6. Market churn is high; native is moving up-stack
In roughly five months: Crystal deprecated, Bloop shut down (Vibe Kanban sunsetting to community maintenance), Terragon shut down (Feb 2026), Omnara archived (Feb 2026), Ona/Gitpod acquired by OpenAI (June 2026), Sculptor still an experimental preview, agent teams still experimental. Meanwhile Anthropic shipped the Desktop parallel-session sidebar with worktrees and PR watching (GA), agent view (preview), and VS Code parallel tabs (GA), and well-funded entrants arrived (Conductor.build raised a $22M Series A in May 2026 and launched Conductor Cloud; cmux, Happy, and Emdash all grew fast). The generic "list my parallel sessions with status" layer is being commoditized from both directions; the coordination semantics above it are not.

### 7. Naming: "Conductor" is now doubly collided
Melty Labs' conductor.build (Mac app, YC S24, $22M Series A, weekly releases through v0.72) owns the name in this exact product category, and Google separately ships a "Conductor" Gemini CLI extension for context-driven development. Notably, Google's Conductor is the tool closest in spirit to the in-repo markdown philosophy (persistent committed context/spec/plan files), though it is a single-CLI planning workflow, not a session manager. A rename or explicit positioning decision for code-katz/claude-conductor should precede any public push.

## Implications for the modernization plan

1. **Keep-and-harden is validated, with scope discipline.** Conductor's defensible core is the four gaps (merge order, in-repo artifact, personas, passive discovery). Harden the dashboard; do not expand it toward features native surfaces will commoditize (generic session lists, generic monitoring).
2. **Prefer hardened dependencies for cost math.** Rather than maintaining a bespoke pricing table forever, offer ccusage as an optional cost engine (`ccusage session --json` per session id) with the config-driven `pricing.json` as the zero-dependency fallback. This outsources price-list maintenance to a 17k-star project whose whole job is that table.
3. **Watch two native tracks as future substrates, not current dependencies:** agent teams (task list + `TeammateIdle`/`TaskCompleted` hooks) and agent view/Desktop worktrees. Phase 4 spike unchanged.
4. **Naming collision, flagged for GTM:** conductor.build (Melty Labs, YC-backed, actively developed Mac app) owns the "Conductor" name in this exact category. Worth a positioning decision (rename vs. lean into "the open, in-repo, persona-aware one") before any public push.

## Sources

Native: code.claude.com/docs/en/agent-teams, /agent-view, /desktop, /vs-code, /worktrees, /costs, /monitoring-usage, /sessions. Tools: github.com/stravu/crystal, github.com/BloopAI/vibe-kanban (+ vibekanban.com/blog/shutdown), github.com/smtg-ai/claude-squad, github.com/kbwo/ccmanager, github.com/imbue-ai/sculptor, github.com/ruvnet/claude-flow, github.com/ccusage/ccusage, github.com/Maciek-roboblog/Claude-Code-Usage-Monitor, github.com/MrLesk/Backlog.md, github.com/github/spec-kit, github.com/GWUDCAP/cc-sessions, github.com/gastownhall/beads, conductor.build, nimbalyst.com, zed.dev/blog/parallel-agents, cursor.com/docs/configuration/worktrees, graphite.com/blog/the-first-stack-aware-merge-queue, anthropics/claude-code#31564.
