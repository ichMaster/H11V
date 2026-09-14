# SDLC — how a roadmap phase becomes shipped code

The pipeline that turns a phase of [ROADMAP.md](ROADMAP.md) into committed, released, working code.
Ten skills in `.claude/skills/`, two of them orchestrators, plus an instrumentation layer in
`codegen/` that records the run as it happens.

Adapted from the SDLC kit used by the sibling project H11, whose subject was a Godot/GDScript game.
Everything here is retargeted at this project: Luanti and Lua, the `specification/` documents,
`H11V-###` issue ids, and the five acceptance gates below instead of Godot's headless import and
smoke runs. The kit is shared machinery; nothing about the *game* is carried in from anywhere.

## The loop

```
for each PHASE vA in the plan (roadmap order):
    for each VERSION vA.B of that phase:
        0. reconcile-issues      ground the phase in the real implementation
        1. generate-issues       decompose vA.B → specification/implementation/vA.B-issues.md
        2. upload-issues         push them to GitHub with vA.B:: labels
        3. execute-issues        implement, validate, commit, push — one issue, one commit
        4. review-and-fix-issues review what landed; fix what must not ship
        5. release-version       bump to A.B.0, RELEASE.txt, tag, push
    at the phase boundary:
        6. harden-findings       clear the deferred HIGH/MEDIUM findings
```

Two orchestrators drive it; do not mix them within one version.

| | |
|---|---|
| **`/ship-phase`** | the full pipeline over one or more roadmap selectors — `v0`, `v1.2`, `v0,v1-v2`. Adds missing prerequisites, sorts into dependency order, skips what is released, and runs the loop above, reporting each phase to chat. Gated: stops on failure and surfaces real decisions. |
| **`/ship-solution`** | the same arc, offline. Also **roadmap-driven** — with no selector it ships *every* version that has an issues file — but it skips generation and GitHub and executes each version straight from its `vA.B-issues.md` with `execute-issues-file`. Otherwise identical: prerequisites filled in, roadmap order, reconcile → execute → review-and-fix → **release a real tag and push**, harden at each phase boundary, and one detailed timed report at the end instead of one per phase. It cannot generate a missing issues file, so a prerequisite with neither a tag nor a file is a hard stop rather than a skip. |

Both release. Neither is the route for **bounded work that is not a roadmap phase**, and that route has
no orchestrator on purpose: a review sweep is `/review-and-fix-issues` (with no argument it reviews the
working tree) or `/harden-findings`, which sweeps the existing reports and can be told to cut the patch
release itself; a one-off that already has an issues file is `/execute-issues-file`. Work big enough to
want the whole loop earns a **roadmap phase** instead — which is exactly how `v0.9` came to exist,
added to [ROADMAP.md](ROADMAP.md) after v0 was already written and released. The failure this
paragraph prevents is small and expensive: reaching for `/ship-solution` to run a migration starts a
releasing pipeline over the entire roadmap.

The eight sub-skills are usable on their own; the orchestrators exist so a phase does not depend on
remembering the order.

## The acceptance gates

There is no unit-test framework for the game. A change is validated by five commands, and
`execute-issues`, `review-and-fix-issues` and `harden-findings` all run them:

```bash
tools/check_lua.sh                        # parse: luac -p over every .lua, no syntax errors
tools/test_worldgen.sh                    # world: a headless server emerges the area, asserts, exits 0
tools/check_assets.py                     # art: names, sizes, alpha regimes, tiling, no metadata
tools/run_local.sh                        # Mac: a 640x480 window, walk, dig, place
tools/deploy_to_term35.sh --profile=mid   # device: it runs, on the GPU, at a measured frame rate
```

The first three run for every issue: the first two always did, and `check_assets.py` joined them when
it took on the node-catalogue contract between `nodes.lua` and `ARCHITECTURE.md` §Components — a
check no art change is involved in, in a gate that used to fire only when art changed. It costs about
a second. The fourth runs whenever anything visible changed, and the fifth whenever the phase's DoD
names a frame-rate budget or the change adds per-tick or per-frame work. A phase's DoD names the
assertions it adds; they go into `test_worldgen.sh` or `check_assets.py` — never into a new
framework.

**Two gates are unusual enough to state plainly.** `test_worldgen.sh` runs a headless
server (`tools/luanti_path.sh` resolves the platform's invocation) with a test-only world mod that
lives under `tools/` and never ships inside the game;
it prints one parseable line and shuts the server down. And the device gate's numbers are void
unless the GPU preflight is green — a software rasterizer draws the world correctly and makes every
frame-rate claim fiction. See [ARCHITECTURE.md](ARCHITECTURE.md) §The GPU path.

## Issue identity and versions

- Issue ids are `H11V-###`, **globally sequential** across phase files and across regeneration runs.
  They never reset.
- GitHub labels are prefixed `vA.B::`, e.g. `v0.2::phase`.
- Releases are `A.B.C`: `A` = roadmap version, `B` = phase within it, `C` = a post-release fix on
  that phase. Roadmap phase `vA.B` → release `A.B.0`. **Never bump a version without explicit
  confirmation.**
- `gh` must be authenticated for `upload-issues`; the remote is `ichMaster/H11V`.

## What the skills write

```
specification/implementation/
  vA.B-issues.md             the decomposed phase, ready to upload
  vA.B-github-report.md      H11V-### → GitHub issue number
  vA.B-execution-report.md   what was implemented, validated and committed
  vA.B-code-review.md        findings from review-and-fix-issues
```

The directory is committed: the reports are the record of how a version was built.

### What the record actually is, and what the harden sweep reads

A set is written **by the run**. A version shipped outside the pipeline has no set, and none is
written for it afterwards — so this directory is not an index of the releases, and reading it as one
is how review finding M26 was raised. What is there, as of v0.9:

| versions | what exists | how they were shipped |
| --- | --- | --- |
| v0.1 | the full set | the pipeline |
| v0.2 | issues, execution report, code review | the pipeline |
| v0.3 | issues, execution report | the pipeline; no review was run |
| v0.4–v0.6 | nothing | GitHub issues `H11V-014`…`H11V-018` driven by hand, without an issues file or reports |
| v0.7–v0.8 | nothing | direct commits, no issue ids |
| at tag `0.8.0` | `v0.8-code-review.md` | a full-**repository** adversarial review, not a review of v0.8's diff |
| v0.9 | issues, github report, execution report | the pipeline, from the v0.8 review's findings |

**The gap was not backfilled, and will not be.** An execution report is worth something because the
run wrote it: it says which gates were green against work that was happening while it said so.
Reconstructing five of them out of `git log` produces a document with the shape of evidence and none
of the substance, indistinguishable on the page from one that was earned — and the next contributor
would have no way to tell which they were reading. A report is written by its run or it is not
written.

**The findings, which is what M26 was actually about, are not missing.** `v0.8-code-review.md` read
the repository at tag `0.8.0` — every line v0.4–v0.8 landed, plus every specification document —
rather than one version's diff, and `harden-findings` globs
`specification/implementation/*code-review*.md`. Those findings have been in the sweep's input since
the day they were raised. What was missing was any document saying so, which is this section.

Two rules follow, and they are what keeps the sweep honest:

- **A full-tree review at a tag is the code review of record for every earlier version that has none
  of its own.** It is named for the tag it read and its header states its scope, so what it covers
  is checkable rather than assumed. `v0.8-code-review.md` covers v0.4–v0.8 on exactly that basis.
- **`specification/implementation/*code-review*.md` is the only input the phase-boundary sweep has.**
  A finding that must survive a phase boundary lives in one of those files, carrying a Status that
  says fixed-with-a-commit or deferred-with-a-home. A finding recorded anywhere else — a commit
  message, `docs/decisions.md`, an issue comment — is a note, not a work item, and no sweep will
  ever come back for it.

## Instrumentation (`codegen/`)

The subject-independent half. It watches the pipeline run and records it; it imports nothing from the
game and is not deleted when the game changes.

```
codegen/
  tracker/    the event log: emit → reduce → state     (stdlib only)
  hooks/      the PostToolUse hook — the deterministic floor  (stdlib only)
  dashboard/  a FastAPI page on :8420
  tests/      293 tests over the above
  runs/       one directory per run — gitignored
```

Two independent sources of truth, and reconciling them is how skill compliance gets measured. The
**skills** emit semantic events (`issue.start`, `issue.validate.end`, `harden.finding.fixed`) — they
know what the work meant, and they can forget to emit. The **hook** is harness-executed on every
Bash/Write/Edit call, so it cannot be forgotten — it sees real timestamps and knows nothing about
meaning. `tracker/reconcile.py` compares them.

The hook is wired in [.claude/settings.json](../.claude/settings.json). Three rules it must never
break, because it runs inside the session it observes: always exit 0, never write to stdout, and
never record a raw command string — a command line can carry a credential. That last rule is not
hypothetical here: `tools/deploy_to_term35.sh` reads a device password out of a gitignored file.

The tracker and the hook are **stdlib-only on purpose**, and a test asserts it: they sit on the
pipeline's critical path, and an emitter that cannot import is an emitter that can break a build.
Only the dashboard and the test suite have dependencies.

```bash
python3 -m venv .venv && .venv/bin/pip install -r codegen/requirements.txt
.venv/bin/python -m pytest -c codegen/pyproject.toml codegen/tests   # 293 passed, 2 skipped
.venv/bin/python -m uvicorn codegen.dashboard.server:app --port 8420
```

## What was deliberately not imported

- **`reset-generated`** — a skill that deletes everything a run created, by reading the run's own
  log. That is right where the application is a regenerable test fixture; here the application **is**
  the product and a skill that can delete it is a footgun.
- **`codegen/bridge/` and `codegen/device/`** — a Bluetooth bridge and an M5 device frontend for
  displaying run status on external hardware. Unrelated to this project.
- **Anything from the game half of H11.** GDScript, the PLAYPAL palette tooling, the deck language,
  the shooter's acceptance runners. The kit is shared; the game is not.

## Working agreement

- **One issue, one commit.** A commit that does not correspond to an issue is either a fix to the
  previous one or does not belong in the run.
- **Never commit on a red gate.** A red `test_worldgen.sh` halts the pipeline; report what landed and
  what did not.
- **Generate the work, do not recover it.** Never `git checkout` or `cherry-pick` code from another
  ref to satisfy an issue.
- **Contract changes update the document in the same commit.** The `NODES` table shape, the mutation
  rule table, the `Perception → Intent` contract and the mod boundaries are seams; changing one
  without changing [ARCHITECTURE.md](ARCHITECTURE.md) is how the documents start lying. The
  `Perception → Intent` contract additionally needs a line in `docs/decisions.md`.
- **The device is the truth.** A budget claim measured on the Mac is not a measurement, and one
  measured on llvmpipe is not a measurement either.
- **Credentials never enter the repository.** The device's ip, user and password live in
  `.term35-connect.txt` and the brain host's in `.brain-connect.txt`; both are gitignored, read at
  run time, and never echoed.
