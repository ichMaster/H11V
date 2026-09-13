---
name: execute-issues
description: Execute GitHub issues for a phase sequentially - implement, validate, commit, push, and generate a report.
---

# Skill: Execute GitHub Issues

Execute GitHub issues for a phase sequentially: implement, validate, commit, push, and
generate a report.

## Usage

```
/execute-issues <label> [--issue H11V-###] [--dry-run]
```

The `<label>` is the GitHub phase label exactly as it appears (e.g., `v1.2::phase`).

- `/execute-issues v1.2::phase` -- execute all issues labeled `v1.2::phase`
- `/execute-issues v1.2::phase --issue H11V-003` -- execute a single issue from that phase
- `/execute-issues v1.2::phase --dry-run` -- show execution plan without making changes

> [!IMPORTANT]
> **Generate every line fresh.** Every line of code, test, script, and config must be written by the
> executing agent in-session. A complete earlier build of this same spec exists in this repo's git
> history (on `main`, tagged `v5.3.00`). Never `git checkout`, `git cherry-pick`, or otherwise
> recover code from history or any other ref to satisfy an issue — the generated run is the point.

## Instructions

### Step 0: Verify prerequisites

1. Confirm we are on the expected branch (the current working dev branch)
2. Confirm working tree is clean (`git status`)
3. Confirm `gh` is authenticated
4. Parse the label to determine the phase: label `v1.2::phase` -> phase `v1.2`
5. Fetch issues from GitHub:
   ```bash
   gh issue list --label "{label}" --state open --limit 100
   ```
6. Read the phase issues file for detailed descriptions: `specification/implementation/v{A.B}-issues.md`
7. If a GitHub report exists (`specification/implementation/v{A.B}-github-report.md`), read the H11-to-GitHub# mapping
8. Read [specification/ROADMAP.md](../../../specification/ROADMAP.md) for the version goal and the phase (`vA.B`) DoD/Tests, [specification/ARCHITECTURE.md](../../../specification/ARCHITECTURE.md) for the contracts the issue must honor, and [specification/VISION.md](../../../specification/VISION.md) for the product scope (MVP vs later).

### Step 1: Build execution queue

From the GitHub issue list, build an ordered queue based on dependencies:
- Parse H11V-### IDs from issue titles (format: `H11V-###: {title}`)
- Determine dependency order from the phase issues file dependency tree
- Issues with no unmet dependencies go first
- Closed issues are already excluded (Step 0 fetches `--state open`), so a re-run resumes where the
  last one stopped
- If `--issue H11V-###` is specified, execute only that issue (but verify its dependencies are closed)

Show the user the execution plan and ask for confirmation.

### Step 2: Execute each issue (loop)

For each issue in the queue:

#### 2a. Assign and announce

Print: `--- Starting H11V-###: {title} ---`

#### 2b. Read issue details

Read the full issue description from the phase issues file (the detailed section for this H11V-###).

#### 2c. Implement

Execute the tasks described in the issue. Follow the conventions in `CLAUDE.md` and the
architecture in `specification/ARCHITECTURE.md`. Route by component ([architecture.md](../../../specification/ARCHITECTURE.md) §2):

- **The world mod** (`games/h11v/mods/h11_world/`): `nodes.lua` owns the `NODES` data table and is the only place a block type is defined; `mapgen.lua` owns mapgen parameters, the three structural aliases and the surface biome; `player.lua` owns the hand, inventory, spawn and HUD. Nothing outside `nodes.lua` registers a node.
- **Mechanics live as data.** A new block is a row in `NODES`; a mutation is a row in the rules table (`rule → block transformation → condition`) over those same ids; a bot's character is a needs weighting. Reach for a table before reaching for a branch.
- **The bots** (`games/h11v/mods/h11_bots/`, from v2): `body`, `needs`, `intent`, `perception` and the Lua StubBrain. The body runs on fast ticks and **never blocks on the network**; the brain is asked at exactly four wake conditions and its answer is collected on a later step.
- **The engine is not ours** (Luanti): no forks, no patches. Where a need looks like it wants a new engine feature, find the stock primitive — the table in `specification/ARCHITECTURE.md` §Engine primitives lists the ones this project stands on.
- **Three engine strictnesses** that fail silently rather than loudly, all in `specification/ARCHITECTURE.md`: tile order needs a *triple* for turf; water needs a source/flowing *pair*; surface layers come from `core.register_biome`, never from the v6 `mapgen_dirt*` aliases.
- **Assets are content** (`games/h11v/**/textures/`, `menu/`): committed **output**. The source of record is the delivered pack in `specification/art/h11v/`, installed by one rsync and never hand-edited in place — a re-delivery would erase the edit.
- **Contract changes:** any change to a stable seam — the `NODES` table shape, the mutation rule table, the `Perception → Intent` contract, a mod boundary — updates `specification/ARCHITECTURE.md` **AND** the acceptance check that pins it, in the same commit. `Perception → Intent` additionally needs a line in `docs/decisions.md`.
- Follow existing style and patterns; keep each phase self-contained (don't pull later phases in early). Lua is `local` by default: no globals outside the one table a mod exports.

#### 2d. Validate

Run the acceptance gates ([ARCHITECTURE.md](../../../specification/ARCHITECTURE.md) §Acceptance
and testing). There is no unit-test framework — these four commands **are** the suite:

1. **Parse:** `tools/check_lua.sh` — `luac -p` over every `.lua`, no syntax errors
   lines. Lua parse errors and broken resource paths surface here and nowhere else.
2. **World:** `tools/test_worldgen.sh` — must exit **0**. This is the primary gate;
   run it for every issue, whatever the issue touched.
3. **Art:** `tools/check_assets.py` — must report every file conforming. Required whenever
   `assets/` or `specification/art/h11v/` changed.
4. **Visual:** `tools/run_local.sh` — a 640x480 window on the Mac: walk, dig, place, no missing textures.
   Required whenever rendering, shaders, the HUD or the map changed; **read at least one frame back**
   and confirm it shows what the issue claims.
5. **Budget:** on the device, `tools/deploy_to_term35.sh --profile=mid` — frame rate read from the F5 overlay, GPU preflight green —
   mean and worst frame inside **16.67 ms**. Required when the phase's DoD names a budget, and for
   anything that adds geometry, materials, sprites or per-frame work.
6. **Acceptance criteria:** go through each criterion from the issue and verify it against the phase
   DoD/Tests in `specification/ROADMAP.md`.

Record pass/fail for each check. **Tests are part of the work** — a phase's DoD names the checks it
adds, and they go into `test_worldgen.sh`, `check_assets.py` or `test_worldgen.sh`, never into a new
framework. Never commit on a red `test_worldgen.sh`.
validation: every gate runs headless or on the device; **nothing in the acceptance path calls a paid API.**

#### 2e. Commit

```bash
git add {specific files created/modified}
git commit -m "$(cat <<'EOF'
H11V-###: {title}

{1-2 sentence summary of what was implemented}

Closes #{github-issue-number}

Co-Authored-By: <the running model's trailer> <noreply@anthropic.com>
EOF
)"
```

#### 2f. Push

```bash
git push
```

#### 2g. Close issue with summary

```bash
gh issue close {issue-number} --comment "$(cat <<'EOF'
## Implementation Summary

**Commit:** {commit-hash}
**Files changed:** {count}

### What was done
{bullet list of key changes}

### Validation
{pass/fail status for each check}

### Acceptance criteria
{checklist with pass/fail}
EOF
)"
```

#### 2g-bis. Emit tracking events

One line per site, via `python3 -m tracker.emit <type> --emitter skill:execute-issues --scope
phase=..,version=..,step=execute-issues,issue=H11V-### [...]`. 2a → `issue.start` (`size`, `area`);
after upload → `issue.uploaded` (`gh_number`, `url`); 2c → `issue.implement.end`; 2d →
`issue.validate.end` (`attempt`, parsed `test_worldgen.sh` PASS/FAIL counts — on a parse failure emit with
`null` counts and `data.parse_error` rather than skipping the event); 2e → `issue.commit`; 2g →
`issue.closed`; end of loop → `issue.end` (`attempts`).

**Step 3's failure path is the one that matters.** Emit `issue.failed` (with a classified `reason`:
`test-failure` / `type-error` / `import-error` / `timeout` / `other`) and then `issue.reverted`
**before** `git checkout -- .` runs. After the revert there is no commit, no file and no trace — this
event is the *only* record that the attempt happened, which is the whole reason this system exists.

#### 2h. Log progress

Append to the in-memory execution log: issue ID + title, commit hash, files changed,
validation results, status (success/partial/failed).

### Step 3: Handle failures

If implementation or validation fails for an issue:

1. Do NOT commit broken code
2. Revert changes: `git checkout -- .`
3. Add a comment to the GitHub issue explaining what failed
4. Log the failure
5. Ask the user: continue to next issue (if no dependency), or stop?

### Step 3b: No automatic version bump

**Do NOT bump the version automatically.** Never change the version (VERSION file,
RELEASE.txt, or git tag) without explicit user confirmation. When a phase's issues are
all done, report completion and let the user decide whether/when to release via
`/release-version`.

Version notation `vA.B.C`: `XX` = roadmap version (v1…v5), `YY` = phase, `ZZ` =
post-release fix. Roadmap phase `vA.B` → release `vA.B.00`. If some issues failed or
were skipped, do NOT release — note in the report that the phase is incomplete.

### Step 4: Generate execution report

After all issues are processed (or on stop), generate `specification/implementation/v{A.B}-execution-report.md`:

```markdown
# Phase v{A.B} -- Execution Report

**Date:** {date}
**Branch:** {branch name}
**Label:** {label}
**Target release:** v{A.B}.00
**Executed by:** Claude Code

## Summary

| Status | Count |
|--------|-------|
| Completed | {n} |
| Failed | {n} |
| Skipped | {n} |
| Remaining | {n} |

## Issues

| # | ARENA ID | Title | Phase | Status | Commit | Files | Tests |
|---|----------|-------|-------|--------|--------|-------|-------|
| 1 | H11V-001 | ... | v1.2 | completed | a1b2c3d | 4 | pass |

## Detailed Results

### H11V-001: ...
**Status:** completed · **Commit:** a1b2c3d
**Validation:** [x] import · [x] smoke · [x] art · [x] frames

## Next Steps
{remaining issues + dependencies}
```

Commit and push the report (`ARENA`-style message, with the Co-Authored-By trailer).

## Important Rules

- **Generate every line fresh.** Never `git checkout`/`cherry-pick`/merge code out of git history or any other ref to satisfy an issue — every line is written in-session.
- **One issue at a time.** Never work on multiple issues simultaneously.
- **Dependency order.** Never start an issue whose dependencies are not closed.
- **Clean commits.** Each issue = one commit. No mixing work across issues.
- **No broken code.** Only commit code that passes validation (the acceptance gates).
- **Checks ship with the feature.** A phase's DoD names the assertions it adds to `test_worldgen.sh`, `check_assets.py` or `test_worldgen.sh`;
  live calls are permitted and opt-in.
- **Server is the ultimate authority.** LLM/client output is untrusted; re-validate every move server-side. Seats keyed by per-connection token, never by name; observers never hold a seat.
- **`nodes.lua` owns the block catalogue.** Nothing outside it registers a node, and every later mechanic addresses blocks by the ids it defines.
- **Contracts stay stable.** A seam change updates `specification/ARCHITECTURE.md` and its contract test in the same commit.
- **Secrets stay out of the repo.** The device password lives only in the gitignored `.term35-connect.txt`; never hardcode it, echo it, or put it in a command's argv.
- **Ask on ambiguity.** If an issue description is unclear, ask the user rather than guessing.
- **Progress updates.** Print a short status line after each issue completes.
