# Companion Skills Audit: Five Repos, Marketplace Readiness

> Scope: claude-devlog-skill (cd960b7), claude-roadmap-skill (0f621b3), claude-plans-skill (ee33b94), claude-todo-skill (24fb28e), claude-publish-agent (9775f94), audited 2026-07-04 against Claude Code v2.1.201 and the harness facts verified earlier in this engagement.
> Personas: Akira (code and harness analysis), River (product opportunities).
> Status: analysis only. No changes were made to any of the five repos.

## Executive Summary

All five skills work today and none has the critical-severity problems the team-cli/conductor audit found. The dominant issues are: (1) a genuine workflow conflict where devlog and roadmap push directly to main, which the newly shipped branch-hygiene tooling actively blocks; (2) five copies of identical boilerplate that should exist once; (3) minimal frontmatter that leaves modern harness capabilities unused; and (4) zero plugin packaging, which is the point of this exercise. Marketplace conversion is mechanical for the four markdown skills and slightly more involved for publish-agent. The publish-agent Python code is the best-engineered artifact in the family: typed, tested, linted, with correct token hygiene.

Top five actions if changes are later approved:

| # | Action | Repos | Why first |
|---|--------|-------|-----------|
| 1 | Fix the push-to-main workflow to respect branch hygiene and detected default branches | devlog, roadmap | The skills' own git steps are rejected by team-cli's branch guard and violate coordinator-prod rules; direct conflict inside the family |
| 2 | Plugin manifests + skills/ layout for all five | all | Marketplace requirement; ~30 minutes each using the conductor pattern |
| 3 | Extract the quintuplicated Lint Check block; drop it from low-stakes skills | all | 60 lines of identical boilerplate across five repos, and it is off-mission in a todo scratchpad |
| 4 | Modernize devlog's Git Setup section (tokens-in-URLs, global git config, /home/claude paths) | devlog | The only security-relevant finding in the audit |
| 5 | Add native-feature positioning notes (todo vs task tools, plans vs plan mode) | todo, plans | Prevents Claude from conflating overlapping native features with the skills' distinct niches |

---

## Family-Level Findings (Akira)

### F1. HIGH: devlog and roadmap push directly to main, which the family now forbids

Both skills instruct: `git add <file> && git commit && git push origin main` (devlog SKILL.md Step 6; roadmap SKILL.md Step 5). Three problems, one of them new since these skills were written:

1. **team-cli's branch guard blocks it.** `claude-team branch guard install` puts a pre-commit hook that rejects commits on main/master. A user running the shipped v0.7 workflow will watch the devlog skill fail its own commit step.
2. **coordinator-prod forbids it.** "Never run git checkout... the user merges, Claude pushes" and all work goes through branches and PRs. The skills predate the prod mode and were never reconciled.
3. **`main` is hardcoded**, the same class of bug just fixed in team-cli and conductor (default branch detection).

Direction when changes are approved: commit on the CURRENT branch (never switch), push the current branch, and only push directly when the current branch IS the default branch and no coordinator-prod marker is present in `~/.claude/CLAUDE.md`. In worktree sessions this makes devlog entries ride the session branch and merge with the work, which is arguably more correct anyway: the devlog entry lands with the change it documents.

### F2. MEDIUM: one Lint Check block, five copies

The identical ~12-line stack-detection lint block appears in all five SKILL.md files (and two more copies live in team-cli's coordinators and conductor's SKILL.md: seven total across the family). Beyond the maintenance cost, placement is wrong in at least two cases: a `/todo` scratchpad add and a plan archive are not moments to gate on linter configuration (River agrees below).

Direction: keep the check where it earns its place (devlog and roadmap touch code-adjacent judgment; the coordinator already owns it at session start), delete it from todo, plans, and publish, and consider making the coordinator's session-start check the single home for it family-wide. In the plugin world, one shared rules file or the existing team SessionStart hook can own this outright.

### F3. MEDIUM: minimal frontmatter leaves harness capabilities unused

All five skills carry only `name` and `description`. Missing per current SKILL.md frontmatter support:

- `allowed-tools`: devlog and roadmap run git commands; pre-approving `Bash(git add:*)`, `Bash(git commit:*)`, `Bash(git push:*)` removes permission prompts from their happy path. todo and plans need only Read/Write/Edit. publish needs `Bash(claude-publish:*)` and `Bash(gh gist:*)`.
- `argument-hint`: `/todo <text>`, `/plans [archive|list]`, `/publish <file>` all take arguments invisibly today.
- Deliberate omission worth documenting: `disable-model-invocation` should stay OFF for these five. Proactive triggering (suggesting a devlog entry after a milestone, suggesting plan archiving) is their core value; do not suppress it.

### F4. LOW: no plugin packaging (the marketplace gap)

None of the five has `.claude-plugin/plugin.json` or the `skills/<name>/SKILL.md` layout. The conversion recipe is now established from conductor: manifest, move SKILL.md into `skills/<name>/`, root symlink for compatibility, fix the README curl URL to point at the real path (GitHub raw serves symlinks as path text; this bit conductor and it will bite all five identically since every README uses the same curl pattern).

### F5. LOW: legacy artifacts

`devlog.skill` and `publish.skill` are ZIP archives in the old claude.ai skill-upload format, stale since the repos standardized on SKILL.md. Remove or move under `publish/` as historical artifacts.

---

## Per-Repo Findings

### claude-devlog-skill

The most mature skill and the strongest concept in the family. Findings beyond F1-F5:

**Akira:**
- D1 MEDIUM (security): the Git Setup section instructs embedding tokens in remote URLs (`https://[token]@github.com/...`), which persists credentials in plaintext in `.git/config` and shell history, and runs `git config --global user.name "[Project] Devlog"`, which hijacks the user's global git identity for all repos. Direction: repo-local `git config`, and `gh auth` / credential helpers instead of URL-embedded tokens. The `/home/claude/[repo-name]` path convention is the old claude.ai sandbox; current remote sessions use different roots. This whole section should shrink to "commit on the current branch; authentication is the environment's problem."
- D2 LOW: the session-start "read DEVLOG.md before any work" behavior is prompt-hope, the same pattern replaced with SessionStart hooks in team-cli and conductor. As a plugin, a SessionStart hook could inject the last N entry titles plus any SUPERSEDED pointers as context deterministically, costing far less than the full-file read on large devlogs.
- D3 LOW: the supersession/archiving mechanism (markers, DEVLOG-ARCHIVE.md, no tombstones) is genuinely well-designed: explicit, user-approved, context-budget-aware. No changes suggested; noted as the pattern the other skills should imitate for lifecycle problems.

**River:**
- The strategic frame: Claude Code now has automatic memory (`MEMORY.md`), which is opaque and machine-managed. The devlog is the *explainable, reviewable, committed* memory. That is the positioning: "memory you can read, diff, and trust," feeding humans, future sessions, and subagents alike. Lean into it in the README.
- Highest-leverage feature: a `/devlog from-diff` mode drafting an entry from the current branch's diff or a just-merged PR, since the harness now has PR context readily available. Cuts entry friction to near zero.
- Cross-family: conductor session completion already offers devlog entries by prose convention; once both are plugins, the conductor completion path can invoke the devlog skill directly, which turns convention into contract.

### claude-roadmap-skill

**Akira:**
- R1 LOW: same F1 push flow; same fix.
- R2 LOW: the proactive trigger ("after River planning sessions") predates River-as-subagent. With team v0.7, a delegated River agent can now own roadmap updates end to end; the skill text should acknowledge delegation as an invocation path ("have River update the roadmap").

**River:**
- The Revision History append-only log is the differentiator (roadmaps that explain themselves); the Current Roadmap templates are heavyweight for solo projects. Opportunity: a "lite" template (tiers only, no OKR/snapshot sections) selectable at creation, defaulting by project size. The OKR section in particular reads as ceremony most solo users skip; ask once at creation instead of shipping empty tables.
- Cross-family: conductor's sprint completion should propose the `delivery`-triggered roadmap entry automatically (both plugins, one hook). The README already promises this integration in prose; it is currently aspiration, not mechanism.

### claude-plans-skill

**Akira:**
- P1 MEDIUM: the global `~/.claude/plans/INDEX.md` is machine-local state indexing project-local files. On a second machine (or a cloud session), the index is missing or stale while the plans themselves are in the repo. The in-file `> Status:` header (added in March) already makes plan files self-describing, which means the index is derivable. Direction: treat INDEX.md as a rebuildable cache, and add a "rebuild index from `<project>/plans/` directories" workflow so cloud/second-machine sessions degrade gracefully.
- P2 LOW: the `~/.claude/plans/<random-slug>.md` auto-save assumption remains correct in the current harness (verified against docs). The skill is safe on this contract, but it is an internal-format dependency of the same class as conductor's JSONL parsing; the doc should say what to do when the slug file is absent (it does: conversation extraction; keep that primary in cloud sessions where slugs may not exist).
- P3 LOW: proactive archive suggestion at plan-mode end is prompt-hope; as a plugin, a Stop or ExitPlanMode-adjacent hook can make the suggestion deterministic.

**River:**
- Plans are the family's "how before execution" artifact and the natural input to `/parallel`: an archived plan should be one command away from a conductor-registered sprint ("execute this plan as parallel sessions"). team-cli already links sessions to plan slugs (`--plan`); the reverse direction (plan → sprint scaffold) is the unbuilt half and the most differentiated feature available to this skill.
- The five-status lifecycle (`active/archived/superseded/executed/rejected`) is more valuable than users likely realize; surface it: "plans list" grouped by status, and a one-line "what changed since this plan" comparison when reading an executed plan.

### claude-todo-skill

**Akira:**
- T1 MEDIUM: overlap with native task tools needs explicit positioning inside the SKILL. Claude Code now ships TaskCreate/TaskUpdate/TaskList (session-scoped, machine-local, used for in-flight work) and agent-team task lists. TODOS.md is the opposite: cross-session, committed, persona-routed backlog. Without a "when to use which" paragraph, a session may reasonably dump `/todo` items into the native list or vice versa. One paragraph fixes it: native tasks for THIS session's execution steps; TODOS.md for ideas that must survive the session.
- T2 LOW: the persona-tag requirement hard-depends on claude-team personas but degrades poorly without them (mandatory `→ **Persona**` tag with no fallback). Direction: keep required when team profiles are installed (detectable at `~/.claude/team/`), optional otherwise.
- T3 LOW: drop the Lint Check (F2); it is most obviously misplaced here.

**River:**
- The todo file is the top of the family funnel: idea → TODOS.md → plan → sprint → devlog → roadmap. The unbuilt move: "promote this todo" (todo → conductor `add` or plan-mode seed), turning the scratchpad into the sprint intake queue. Cheap to specify, high narrative value for the suite.
- Native task tools made "session checklists" free, which REMOVES scope pressure from this skill: it no longer needs states beyond open/done. Resist adding kanban ceremony; its value is being the two-second capture.

### claude-publish-agent

**Akira:**
- PB1 (code quality, positive): the Python package is the best code in the family. Clean click CLI, platform ABC with a dataclass result, 600-permission token storage with legacy migration, timeouts on all HTTP calls, specific 401/429 handling, pytest suite with `responses`, ruff configured with a modern floor (3.10). No refactoring needed.
- PB2 LOW: `MediumPlatform._token` is assigned in `authenticate()` but never declared in `__init__` alongside `_user_id`/`_username`. Declare it for symmetry and type honesty.
- PB3 MEDIUM (environment): the gist flow shells out to `gh`, which is absent in Claude Code web/remote sessions (verified: not present in this container). The SKILL should note the fallback for remote sessions: create the gist via the GitHub MCP server when available, or defer publishing to a local session. Without this note, `/publish` in a cloud session dead-ends at Step 5.
- PB4 LOW: whether `pipx install claude-publish-agent` resolves (i.e., the package is on PyPI) could not be verified from this environment. If it is not published, the README's install instruction fails for everyone; verify before marketplace listing since the SKILL depends on the CLI existing.
- PB5 LOW: plugin note: the plugin can ship the SKILL and a `/publish` command, but the Python CLI stays a pipx prerequisite (plugins add `bin/` to PATH but should not vendor a Python package). The SKILL's existing prerequisites section already handles this; keep the plugin thin.

**River:**
- Medium's import-via-gist workaround is genuinely clever given the closed API, but Medium-only is a shrinking story. The two platforms with real, open APIs worth adapters: **dev.to** (Forem API, simple token, markdown-native, developer audience exactly matches the content) and **Ghost** (Admin API, for self-hosted blogs). LinkedIn remains API-hostile; keep "coming soon" honest or drop the promise. dev.to is the obvious next adapter: smallest effort, largest audience fit, and the existing `Platform` ABC makes it an afternoon.
- The content kit (style-guide scaffolding) is quietly the most differentiated piece: it is Kai and Toni's output made durable. Opportunity: `/publish` draft review invoking Toni (positioning pass) and Kai (image specs) as subagents now that delegation exists.

---

## Marketplace Readiness Checklist

Per repo, the conversion when approved (order matches the recommended sequence):

| Step | devlog | roadmap | plans | todo | publish |
|---|---|---|---|---|---|
| `.claude-plugin/plugin.json` | needed | needed | needed | needed | needed |
| `skills/<name>/SKILL.md` + root symlink | needed | needed | needed | needed | needed |
| README curl URL fix (symlink gotcha) | needed | needed | needed | needed | needed |
| Frontmatter (`allowed-tools`, `argument-hint`) | needed | needed | needed | needed | needed |
| F1 git-flow fix | needed | needed | n/a (no git) | n/a (no git) | n/a |
| Lint Check removal | keep | keep | remove | remove | remove |
| marketplace.json entry in claude-plugins | 1 line | 1 line | 1 line | 1 line | 1 line |
| Extra | D1 git-setup rewrite, D2 hook (optional) | R2 delegation note | P1 index rebuild | T1 positioning note | PB3 remote note, PB4 PyPI check |

Estimated effort: the four markdown skills are roughly 30-45 minutes each including the F1 fix where applicable; publish is about an hour with the PyPI verification. All seven marketplace entries (five here plus the two live ones) then resolve from one `/plugin marketplace add`.

## Sequencing Recommendation

1. **Wave 1 (mechanical, no behavior change):** plugin manifests, skills/ layout, README fixes, frontmatter, marketplace entries for todo and plans (the two with no git workflow to fix). Ships the marketplace story fastest.
2. **Wave 2 (behavior fixes):** F1 git-flow fix + D1 security rewrite for devlog and roadmap, then their marketplace entries.
3. **Wave 3 (publish):** PB4 PyPI verification, PB3 remote-session note, manifest, entry.
4. **Backlog (River's list, each its own decision):** devlog from-diff, plan-to-sprint promotion, todo promotion, dev.to adapter, SessionStart devlog digest, roadmap lite template.

*Analysis prepared 2026-07-04 by Akira (code) and River (product). No files in the five audited repos were modified.*
