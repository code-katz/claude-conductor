# Code-Katz + Paperclip: Session Orchestration Investigation

**Prepared:** March 28, 2026
**Author:** Will Curran | Code Katz
**Format:** This is the markdown source for the investigation. The formatted .docx version was generated in the Claude Chat session that produced this analysis.

---

## 1. Executive Summary

This document investigates how to solve a specific workflow pain point: coordinating 6+ parallel Claude Code sessions across multiple code-katz personas without losing track of who is doing what, in what order, and when to intervene. The investigation evaluates Paperclip (an open-source agent orchestration platform with 36k+ GitHub stars) against building a bespoke orchestration dashboard within the code-katz ecosystem.

**Core finding:** Paperclip solves the coordination and visibility problem well, but it operates at a fundamentally different abstraction level than code-katz. Paperclip manages agents as employees in a company. Code-katz manages personas as expert consultants in a session. These are complementary, not competitive. The best path is a phased approach: start by building a lightweight coordination dashboard as a new code-katz tool (claude-conductor), then evaluate Paperclip integration once its Claude Code adapter matures.

---

## 2. What You Have: The Code-Katz Ecosystem

Code-katz is a suite of six tools that together form a complete solo-developer productivity system for Claude Code:

| Tool | Purpose | Key Capability |
|------|---------|----------------|
| claude-team-cli | Persona management | 11 specialist personas with domain expertise, coordinator layer, parallel session planning |
| claude-devlog-skill | Decision memory | Structured changelog that persists architectural decisions, milestones, and bug fixes across sessions |
| claude-roadmap-skill | Priority tracking | Living roadmap with revision history; captures why priorities changed |
| claude-plans-skill | Plan archival | Archives Claude Code plan-mode outputs with meaningful names and global index |
| claude-todo-skill | Idea capture | Zero-friction task scratchpad invocable mid-session |
| claude-publish-agent | Content publishing | Markdown-to-Medium pipeline with per-project branding |

### 2.1 What Code-Katz Does Well

- Deep persona specialization: Each persona thinks and pushes back like a real domain expert. Robin asks about failure modes before features. Sage flags the professional-advice boundary. River runs a Problem Statement Drill.
- Cross-session context: The devlog, roadmap, plans, and todo skills together solve the "starting from zero" problem.
- Parallel session planning: The /parallel command and coordinator generate scoped session prompts with persona, task, and file boundaries.
- Lightweight and bash-native: No server, no database, no dependencies beyond bash 3.2+ and Claude Code.

### 2.2 The Gap

The /parallel command generates session plans, but once those sessions are running, visibility disappears:

- No live dashboard showing which sessions are active, which persona is in each, and what task each is working on
- No way to see session status (planning, coding, blocked, done) at a glance
- No dependency tracking between sessions
- No merge-order enforcement or conflict detection
- No cost tracking across sessions

---

## 3. What Paperclip Offers

### 3.1 Overview

Paperclip is a Node.js server with a React UI that orchestrates AI agents as employees in a virtual company. Launched early March 2026, 36k+ GitHub stars. MIT-licensed, self-hosted, requires Node.js 20+ with pnpm.

### 3.2 Key Features Relevant to This Use Case

| Feature | What It Does |
|---------|-------------|
| Dashboard UI | Central view of all agents/sessions with status, task, and cost |
| Ticket system | Every task is a ticket with owner, status, and threaded conversation |
| Org chart | Hierarchical roles and reporting lines |
| Cost control | Monthly budgets per agent with auto-throttling |
| Heartbeats | Agents wake on schedule, check work, act |
| Goal alignment | Every task traces back to a project goal and company mission |
| Session persistence | Sessions survive reboots |
| Claude Code adapter | Native integration via the adapters package |
| Multi-company | Run Chronicle, BoardBot, and Flat Six as separate companies |

### 3.3 Community Sentiment

Overwhelmingly positive. Users praise UX quality (compared to Linear), agent-agnostic approach, and solving a real coordination pain point. The creator built Paperclip because he had 20 Claude Code tabs open and couldn't remember what any were doing. Several tutorials and deployment guides appeared within weeks of launch.

### 3.4 Maturity Assessment

- Very new (launched ~March 2026). High velocity but expect rough edges.
- TypeScript/Node.js stack (not Python).
- Requires running a server (Node.js + Postgres). More infrastructure than bash-only.
- Claude Code adapter documentation is thin.

---

## 4. Head-to-Head Comparison

| Dimension | Code-Katz (Today) | Paperclip |
|-----------|-------------------|-----------|
| Persona depth | **Deep**: 11 specialists with required interactive behaviors, security focus, handoff protocols | Shallow: role title + job description |
| Session visibility | **None**: /parallel generates plans, then you're on your own | **Full**: dashboard shows all agents, tasks, status, cost |
| Cost tracking | None | **Per-agent monthly budgets** with auto-throttle |
| Cross-session context | **Excellent**: devlog, roadmap, plans, todos | Good: goal ancestry + persistent state |
| Infrastructure | **Zero**: bash scripts + markdown | Heavy: Node.js + PostgreSQL + React |
| Tech stack | **Bash** (comfort zone) | TypeScript/React |
| Governance | Manual: coordinator suggests | **Built-in**: approval gates, rollback |
| Multi-project | Per-project files | **Full multi-company** isolation |
| Maturity | **v0.4, stable, proven** | v1, new, fast-moving |

---

## 5. Strategic Options

### Option A: Adopt Paperclip, Migrate Personas

**Verdict: Not recommended.** Too much to rebuild, too much persona depth to lose. TypeScript stack. Early-stage project risk.

### Option B: Integrate Code-Katz into Paperclip

**Verdict: Promising for Phase 2 (3-6 months).** Once Paperclip's Claude Code adapter is better documented.

### Option C: Build a Bespoke Orchestration Dashboard (Recommended)

**Verdict: Recommended as Phase 1.** Add claude-conductor to code-katz. Solves the immediate pain with minimal disruption.

---

## 6. Recommended Approach: Phased Strategy

### Phase 1: claude-conductor (Weeks 1-3)

1. Session registry: SESSIONS.md tracks active sessions with persona, task, file scope, status, start time
2. Dashboard command: `claude-conductor status` or `/conductor` shows formatted table
3. Session lifecycle: start, update, done, merge, abandon, clear
4. Dependency awareness: tracks merge order, flags when upstream sessions complete
5. Integration with existing skills: session completion auto-triggers devlog entries

### Phase 2: Evaluate Paperclip Integration (Month 2-3)

1. Install Paperclip locally and run alongside your workflow as a read-only dashboard
2. Evaluate which features add value beyond claude-conductor
3. If clear value, build a custom adapter syncing conductor state into Paperclip

### Phase 3: Decide on Long-Term Architecture (Month 4+)

Continue with conductor, adopt Paperclip with adapter, or contribute a code-katz integration to Paperclip.

---

## 7. Using Claude Chat Effectively Across 6+ Sessions

- **Session Naming Convention:** Name each session explicitly in the first message
- **Coordination Session Pattern:** Keep one session as your coordination hub (no code writing)
- **Session Handoff Briefs:** Make them mandatory, not optional
- **Claude Chat as the War Room:** Chat for thinking, Code for doing
- **Session Budget Discipline:** Each session gets a specific task; close when done

---

## Appendix: Key Links

- Paperclip GitHub: https://github.com/paperclipai/paperclip
- Paperclip Docs: https://paperclip.ing/docs
- Paperclip Discord: https://discord.gg/m4HZY7xNG3
- Code-Katz claude-team-cli: https://github.com/code-katz/claude-team-cli
- 7-Day Paperclip Tutorial: https://paperclipai.info/
