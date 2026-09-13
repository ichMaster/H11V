---
name: upload-issues
description: Upload issues from a phase issues file to GitHub one by one with proper labels and dependencies.
---

# Skill: Upload Version Issues to GitHub

Upload issues from a phase issues file to GitHub one by one, with proper labels
(prefixed by version) and dependencies.

## Usage

```
/upload-issues <phase-issues-file>
```

Example: `/upload-issues @specification/implementation/v1.2-issues.md`

A phase issues file is the fine-grained breakdown of a ROADMAP phase (`vA.B`): each
phase in [specification/ROADMAP.md](../../../specification/ROADMAP.md) is split into one or more
`H11V-###` issues by `/generate-issues`. If the file does not exist yet, run
`/generate-issues <phase>` first, then this skill.

## Instructions

### Step 1: Read the phase issues file

Read the provided file (e.g., `specification/implementation/v{A.B}-issues.md`).

Determine from the file:
- **Version number** (XX): the roadmap version the phase sits under (e.g. `v1.2` → `01`).
- **Phase** (XX.YY): from the filename or heading (e.g., `v1.2-issues.md` → `v1.2`).
- **Label prefix**: `v{A.B}::` (e.g., `v1.2::`).

Parse the **Issues Summary Table** to extract for each issue:
- `ID` (e.g., H11V-001)
- `Title`
- `Size` (S, M, L)
- `Area` (the component: `games`, `server`, `agent`, `web`, `profiles`, `scripts`, `tests`)
- `Phase` (the ROADMAP phase it implements, e.g. `v1.2`)
- `Dependencies` (list of H11V-### IDs)

Then parse each **detailed issue section** (heading with H11V-###) to extract:
`Description`, `What needs to be done`, `Dependencies`, `Expected result`,
`Acceptance criteria` (should align with the phase DoD in roadmap.md).

### Step 2: Confirm with user

Show the user a summary of what will be created: number of issues, label prefix (e.g.,
`v1.2::`), the full list of labels, and ask for confirmation before proceeding.

### Step 3: Create labels (if they don't exist)

All labels MUST be prefixed with `v{A.B}::`. Label format: `v{A.B}::{category}:{value}`.

Version titles: **v1 — Game Core & Server Foundation**; **v2 — Agent Client (Haiku)**;
**v3 — Web UI (Player & Observer)**; **v4 — Agent-vs-Agent Orchestration**;
**v5 — Hardening & Polish**.

```bash
# Phase label
gh label create "v1.2::phase" --color "0E8A16" --description "Phase v1.2" 2>/dev/null || true

# Size labels
gh label create "v1.2::size:S" --color "28A745" --description "Small (1-2 days)" 2>/dev/null || true
gh label create "v1.2::size:M" --color "FFC107" --description "Medium (3-5 days)" 2>/dev/null || true
gh label create "v1.2::size:L" --color "DC3545" --description "Large (5-8 days)" 2>/dev/null || true

# Area labels (one per component touched in this phase)
gh label create "v1.2::area:games"  --color "6F42C1" 2>/dev/null || true
gh label create "v1.2::area:server" --color "1D76DB" 2>/dev/null || true
gh label create "v1.2::area:agent"  --color "0E8A16" 2>/dev/null || true
# ... web / profiles / scripts / tests as needed
```

### Step 4: Create issues ONE BY ONE

**IMPORTANT:** Issues must be created one at a time, sequentially. After creating each
issue, show the user the result (issue number, URL) and proceed to the next immediately
(do not wait for confirmation between issues).

For each issue (in order from the summary table):

1. Build the issue body in markdown:

```markdown
## Description
{description}

## What needs to be done
{full content}

## Dependencies
{dependency list, with references to already-created issue numbers}

## Expected result
{expected result}

## Acceptance criteria
{checklist}

---
**ID:** {H11V-###}
**Size:** {S/M/L}
**Version:** v{A}
**Area:** {scripts/shaders/scenes/levels/assets/tools/data/specification}
**Phase:** {vA.B from roadmap}
```

2. Create the issue with a single `gh issue create` command (one issue per command, never batch):

```bash
gh issue create \
  --title "H11V-###: {title}" \
  --label "v1.2::phase,v1.2::size:{S/M/L},v1.2::area:{area}" \
  --body "$(cat <<'BODY'
{issue body}
BODY
)"
```

3. Record the mapping: H11V-### -> GitHub issue #number
4. Report to user: `Created H11V-### -> #{number}: {title}`
5. If the issue depends on already-created issues, add a comment:
   ```bash
   gh issue comment {issue-number} --body "Blocked by #{dep-issue-number} (H11V-###)"
   ```
6. Move to the next issue.

### Step 5: Generate report

After all issues are created, generate `specification/implementation/v{A.B}-github-report.md`:

```markdown
# Phase v{A.B} -- GitHub Issues Report

**Uploaded:** {date}
**Repository:** {github repo URL}
**Total issues:** {count}

## Issue Mapping

| ARENA ID | GitHub # | Title | Phase | Labels | URL |
|----------|----------|-------|-------|--------|-----|
| H11V-001 | #5 | ... | v1.2 | v1.2::phase, v1.2::size:S, v1.2::area:games | {url} |

## Labels Created

- v{A.B}::phase
- v{A.B}::size:S, v{A.B}::size:M, v{A.B}::size:L
- v{A.B}::area:{list}
```

### Step 5.5: Emit tracking events

After each `gh issue create`, emit `issue.uploaded` with the ARENA id, `gh_number` and `url`
(`--emitter skill:upload-issues --scope phase=..,version=..,step=upload-issues,issue=H11V-###`).
This is what makes GitHub issues created/closed/open countable at all.

### Step 6: Report to user

Show the user: total issues created, link to the GitHub issues page, path to the
generated report file.

## Error Handling

- If `gh` is not authenticated, tell the user to run `gh auth login`
- If the repo has no GitHub remote yet, tell the user to create one (`gh repo create`) before uploading
- If an issue already exists with the same title, skip it and note in the report
- If label creation fails, continue (labels may already exist)
- On any failure, report what was created so far and what remains
