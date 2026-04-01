> Source: `~/.claude/plans/zazzy-weaving-gray.md`
> Archived: 2026-03-31 · Project: claude-conductor
> Status: `executed`
> Maintained by [claude-plans-skill](https://github.com/code-katz/claude-plans-skill).

---

# Plan: Branch-per-Session Isolation + Devlog Tag Suggestions

## Context

Parallel Claude Code sessions currently rely on file-scope discipline to avoid conflicts. This works when scoping is perfect, but one session touching an unexpected shared file creates a conflict with no clean way to untangle it. This plan adds git branch isolation so each parallel session works on its own branch, with the coordination session handling merges. Additionally, the devlog skill will suggest git tags for significant commits (milestones, breaking changes).

## Key Design Decision: Branch Column at End of Table

Rather than inserting a Branch column between Files and Status (which would shift ALL awk field indices across ~20 references and risk silent data corruption), **Branch is added as the LAST column**. This means zero existing column indices change. Only new code references the new field. This eliminates the single highest-risk part of the change.

---

## File 1: `claude-conductor` CLI

**Path:** `/Users/willcurran/.local/bin/claude-conductor`

### 1a. Add `generate_branch_name` function (after line 38)

```bash
generate_branch_name() {
  local num="$1" persona="$2" task="$3"
  local persona_lower task_slug
  persona_lower=$(echo "$persona" | tr '[:upper:]' '[:lower:]')
  task_slug=$(echo "$task" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | cut -c1-40)
  echo "session/${num}-${persona_lower}-${task_slug}"
}
```

### 1b. Update `cmd_init` table headers (lines 400-401, 409)

Active Sessions header becomes:
```
| # | Persona | Task | Files | Status | Started | Depends On | Notes | Activity | Branch |
|---|---------|------|-------|--------|---------|------------|-------|----------|--------|
```

Completed Sessions header becomes:
```
| # | Persona | Task | Files | Duration | Completed | Outcome | Branch |
|---|---------|------|-------|----------|-----------|---------|--------|
```

### 1c. Update `get_session_field` comment (line 85)

Add `11=Branch` to the field index comment.

### 1d. Update `cmd_add` (lines 531-579)

- Add `--branch` flag parsing: `--branch) branch="$2"; shift 2 ;;`
- Auto-generate if omitted: `branch="${branch:-$(generate_branch_name "$num" "$persona" "$task")}"`
- Update row construction (line 565): append `${branch}` as last data field
  - Old: `"| ${num} | ${persona} | ${task} | ${files} | planning | ${ts} | ${depends} | | |"`
  - New: `"| ${num} | ${persona} | ${task} | ${files} | planning | ${ts} | ${depends} | | | ${branch} |"`
- Add branch to output: `echo "  Branch: ${branch}"`
- Update help text (line 1235) to show `--branch` flag

### 1e. Update `cmd_start` (lines 424-473)

- Add branch prompt: `printf "  Branch (auto): "; read -r branch`
- Auto-generate if blank: `branch="${branch:-$(generate_branch_name "$num" "$persona" "$task")}"`
- Update row (line 464) to append branch as last field

### 1f. Update `cmd_merge` (lines 672-696)

After marking merged, read and display the branch name:
```bash
local branch
branch=$(get_session_field "$sf" "$num" 11)
echo "  Branch: ${branch}"
echo "  To merge: git checkout main && git merge ${branch}"
```

### 1g. Update `cmd_done` (lines 644-669)

After marking done, show the branch:
```bash
local branch
branch=$(get_session_field "$sf" "$num" 11)
if [[ -n "$branch" ]]; then
  echo "  Branch: ${branch}"
fi
```

### 1h. Update `cmd_status` (lines 283-365)

Read branch from field 11 and display it dimmed after the status line:
```bash
local branch
branch=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $11); print $11}')
# Add to the printf output
if [[ -n "$branch" ]]; then
  printf "  %s" "$(dim "$branch")"
fi
```

### 1i. Update `cmd_clear` (lines 731-869)

When building completed rows, extract branch and include it:
```bash
c_branch=$(echo "$row" | awk -F'|' '{gsub(/^ +| +$/, "", $11); print $11}')
# Updated completed row:
local completed_row="| ${c_num} | ${c_persona} | ${c_task} | ${c_files} | ${duration} | ${now_ts} | ${c_status} | ${c_branch} |"
```

### 1j. No changes needed to:
- `cmd_update` (status is still $6, activity is still $10)
- `cmd_abandon` (status is still $6)
- `check_dependents` (depends is still $8)
- `detect_conflicts` (status is still $6, files is still $5)
- `update_session_field` (generic, works with any field index)

---

## File 2: `generate-dashboard`

**Path:** `/Users/willcurran/d20m-development/code-katz/claude-conductor/bin/generate-dashboard`

### 2a. Active Sessions parsing (line 47-62)

Add to array declarations: `a_branch=()`
Add extraction after a_activity line:
```bash
a_branch+=("$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $11); print $11}')")
```

### 2b. Completed Sessions parsing (lines 69-85)

Add to array declarations: `c_branch=()`
Add extraction:
```bash
c_branch+=("$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/, "", $9); print $9}')")
```
(Completed table: Branch is field $9 since completed has fewer columns)

### 2c. HTML rendering

Add Branch column to both Active and Completed HTML tables in the template section.

---

## File 3: `watcher.js`

**Path:** `/Users/willcurran/d20m-development/code-katz/claude-conductor/dashboard/watcher.js`

### 3a. Update `parseSessionsTable` (lines 59-71)

Add branch to the parsed object. Since `cols` is 0-based after filtering empties:
- cols[0]=#, [1]=Persona, [2]=Task, [3]=Files, [4]=Status, [5]=Started, [6]=Depends, [7]=Notes, [8]=Activity, **[9]=Branch** (new)

```javascript
sessions.push({
  number: parseInt(cols[0], 10),
  persona: cols[1] || '',
  task: cols[2] || '',
  files: cols[3] || '',
  status: cols[4] || '',
  started: cols[5] || '',
  dependsOn: cols[6] || '',
  notes: cols[7] || '',
  branch: cols[9] || '',  // NEW — cols[8] is Activity
});
```

### 3b. Update HTML rendering

Add branch display to the session cards/table in the dashboard template.

---

## File 4: `parallel.md`

**Path:** `/Users/willcurran/.claude/commands/parallel.md`

### 4a. Update `add` command docs (line 21)

Show `--branch` flag as optional:
```
claude-conductor add --persona [Name] --task "[task]" --files "[file list]" [--depends "#N"] [--branch "custom-name"]
```

Note: branch is auto-generated if omitted.

### 4b. Update session prompt template (lines 30-80)

Each session prompt changes from:
```
First, run this command: claude-conductor u 1 coding --activity "starting work"
```
to:
```
First, run these commands:
git checkout -b session/1-[persona]-[task-slug]
claude-conductor u 1 coding --activity "starting work"
```

Completion instruction changes from:
```
When you are completely done, run: claude-conductor d 1
```
to:
```
When you are completely done:
1. Commit all changes: git add [files] && git commit -m "[persona]: [brief summary]"
2. Mark session done: claude-conductor d 1
```

### 4c. Update merge order section (line 78)

Add merge commands for the coordination session:
```
**Merge commands for coordination session:**
```bash
git checkout main
git merge session/1-[persona]-[slug]
git merge session/2-[persona]-[slug]
git branch -d session/1-[persona]-[slug] session/2-[persona]-[slug]
```

### 4d. Add rules (after line 93)

- Every session prompt must include a `git checkout -b` command matching the branch registered with conductor
- Completion instructions must include committing all work before marking done
- Use `git checkout -b <branch> || git checkout <branch>` to handle re-entry

---

## File 5: `devlog SKILL.md`

**Path:** `/Users/willcurran/.claude/skills/devlog/SKILL.md`

### 5a. Add new Step 6 (Tag Suggestion), renumber existing Step 6 to Step 7

Insert between current Step 5 (Archive) and Step 6 (Commit and Push):

```markdown
### Step 6: Tag Suggestion (Conditional)

After preparing the commit, evaluate whether this entry warrants a git tag:

**Criteria** (any one triggers a suggestion):
- Category is `milestone`
- Category is `strategy` with `Breaking Change: yes`
- The entry title or summary describes a version release, launch, or completed phase

**Tag format options:**
- **Semantic version:** `v<major>.<minor>.<patch>` -- use when the project follows semver. Check existing tags (`git tag --sort=-v:refname | head -5`) and increment: major for breaking changes, minor for features/milestones, patch for fixes.
- **Descriptive tag:** `<project-slug>-<brief-descriptor>` -- use when the project does not follow semver or the milestone is a named phase (e.g., `d20mob-phase1a-deployed`, `chronicle-v1-api-launch`). Lowercase, hyphenated, under 50 characters.

**Workflow:**
1. Check existing tags: `git tag --sort=-v:refname | head -10`
2. Propose the tag to the user: "This milestone looks tag-worthy. Suggested tag: `v0.3.0` (next minor after v0.2.1). Want me to create it?"
3. If approved: `git tag -a <tag> -m "<entry title>"`
4. If declined or no criteria met, skip silently.

**Important:** Never create a tag without explicit user approval. If unsure whether an entry qualifies, do not suggest.
```

### 5b. Update Step 7 (formerly Step 6: Commit and Push)

Change `git push origin main` to `git push origin main --tags` so approved tags are pushed alongside the commit.

---

## Migration Strategy

No migration command needed. The approach is backwards-compatible:

- **Existing SESSIONS.md files** without a Branch column will simply have an empty `$11` field, which the code handles gracefully (branch will be empty string)
- `cmd_merge` and `cmd_status` already check for non-empty branch before displaying
- New SESSIONS.md files created via `cmd_init` will have the Branch column header
- Users can manually add `| Branch |` and `|--------|` to existing table headers if they want the column visible

---

## Implementation Order

1. **`claude-conductor`**: `generate_branch_name` function + `cmd_init` headers (no breaking changes)
2. **`claude-conductor`**: `cmd_add` with `--branch` flag + `cmd_start` branch prompt
3. **`claude-conductor`**: `cmd_merge`, `cmd_done`, `cmd_status`, `cmd_clear` branch display
4. **`generate-dashboard`**: Branch parsing and HTML rendering
5. **`watcher.js`**: Branch parsing and display
6. **`parallel.md`**: Branch checkout in prompts, commit instructions, merge commands
7. **`devlog SKILL.md`**: Tag suggestion step

Steps 1-3 are one commit. Steps 4-5 are a second commit. Step 6 is a third. Step 7 is independent.

---

## Verification

1. **Conductor**: Run `claude-conductor init` in a test dir, verify Branch column in headers. Run `claude-conductor add --persona Akira --task "Test task" --files "src/"`, verify branch auto-generated and visible in row. Run `claude-conductor add --persona Sasha --task "UI work" --files "lib/" --branch "session/custom"`, verify custom branch stored. Run status, done, merge, clear and verify branch displays correctly.
2. **Dashboard**: Generate dashboard after above operations, verify Branch column renders in HTML.
3. **Parallel**: Run `/parallel` in a test context, verify session prompts include `git checkout -b` commands and merge section includes `git merge` commands.
4. **Devlog**: Create a devlog entry with category `milestone`, verify tag suggestion appears. Create one with category `feature`, verify no suggestion.
5. **Backwards compat**: Run updated conductor against an existing SESSIONS.md (without Branch column), verify no errors and empty branch handled gracefully.
