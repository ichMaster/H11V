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
| **`/ship-phase`** | the full pipeline over one or more roadmap selectors — `v0`, `v1.2`, `v0,v1-v2`. Adds missing prerequisites, sorts into dependency order, skips what is released, and runs the loop above. Gated: stops on failure and surfaces real decisions. |
| **`/ship-solution`** | the same work driven from a single issues file rather than the roadmap. For a bounded piece of work that is not a roadmap phase — a review sweep, a migration, a spike. |

The eight sub-skills are usable on their own; the orchestrators exist so a phase does not depend on
remembering the order.

## The acceptance gates

There is no unit-test framework for the game. A change is validated by five commands, and
`execute-issues`, `review-and-fix-issues` and `harden-findings` all run them:

```bash
tools/check_lua.sh                        # parse: luac -p over every .lua, no syntax errors
tools/test_worldgen.sh                    # world: luantiserver emerges the area, asserts, exits 0
tools/check_assets.py                     # art: names, sizes, alpha regimes, tiling, no metadata
tools/run_local.sh                        # Mac: a 640x480 window, walk, dig, place
tools/deploy_to_term35.sh --profile=mid   # device: it runs, on the GPU, at a measured frame rate
```

The first two run for every issue. The third is required whenever textures, menu art or the asset
pack changed, the fourth whenever anything visible changed, and the fifth whenever the phase's DoD
names a frame-rate budget or the change adds per-tick or per-frame work. A phase's DoD names the
assertions it adds; they go into `test_worldgen.sh` or `check_assets.py` — never into a new
framework.

**Two gates are unusual enough to state plainly.** `test_worldgen.sh` runs a headless
`luantiserver` with a test-only world mod that lives under `tools/` and never ships inside the game;
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
  `.term35-connect.txt`, which is gitignored; scripts read it at run time and never echo it.
