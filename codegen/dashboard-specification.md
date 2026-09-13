# Dashboard specification

The page at `:8420` that shows a pipeline run as it happens. This document is the palette's source of
truth; `codegen/tests/test_dashboard.py` reads the table below and fails if the shipped
`dashboard/static/styles.css` has drifted from it.

## Purpose

One page, read at a glance while a `/ship-phase` run is going: which issue is executing, how long
each one took, which gates passed, and where the skills' semantic events and the hook's mechanical
record disagree. It reads `codegen/runs/` and writes only under `codegen/var/` — a viewer, never a
participant.

## Palette

Both themes are checked for colour-vision-deficiency safety by the validator in
`tests/render_panels.js`; `test_the_shipped_palette_still_passes_the_validator` runs it on every
suite. Changing a colour here means changing it in `styles.css` in the same commit, and vice versa.

| Token | Light | Dark |
| --- | --- | --- |
| `--plane` | `#f9f9f7` | `#0d0d0d` |
| `--text-primary` | `#0b0b0b` | `#ffffff` |
| `--text-secondary` | `#52514e` | `#c3c2b7` |
| `--text-muted` | `#898781` | `#898781` |
| `--grid` | `#e1e0d9` | `#2c2c2a` |
| `--axis` | `#c3c2b7` | `#383835` |
| `--deemph` | `#d6d5cf` | `#3a3a37` |
| `--series-1…5` | `#2a78d6` `#eb6834` `#1baf7a` `#eda100` `#e87ba4` | `#3987e5` `#d95926` `#199e70` `#c98500` `#d55181` |

Status colours (`--good`, `--warning`, `--serious`, `--critical`) are semantic, not series: they
encode gate outcomes and finding severity, and are never used to distinguish one series from another.

## Layout

- **Run header** — run id, elapsed time, the phase selector it was launched with, and a live state
  dot (`.s-run` pulses while a run is open).
- **Issue timeline** — one row per `H11V-###`, its gate results, and its duration; the series colours
  distinguish gates, not issues.
- **Reconciliation** — where `tracker/reconcile.py` found the skills' events and the hook's record
  disagreeing. This is the panel the whole instrumentation exists for: a skill can forget to emit,
  and the hook cannot.

## Constraints

- The dashboard is a separate process, started deliberately, and never on the pipeline's critical
  path — it is the only part of `codegen/` allowed third-party dependencies.
- It reads `runs/` and writes `var/`; `test_dashboard_writes_only_under_codegen` asserts it never
  touches `/tmp` or an expanded home path.
- The snapshot it serves is a cache with an invalidation rule, because a cache that never invalidates
  is a frozen page.
