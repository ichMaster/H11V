#!/usr/bin/env bash
# Acceptance gate: generate a world headlessly and assert what it contains.
#
#   tools/test_worldgen.sh              run the gate
#   tools/test_worldgen.sh --keep       keep the temporary world for inspection
#   tools/test_worldgen.sh --area=64    scan a smaller area (default 128)
#   tools/test_worldgen.sh --timeout=60 give up after N seconds (default 180)
#
# --area is for quick iteration. The DoD's numbers describe the 128x128 map, so
# at any other area they are measured and printed but not asserted — a smaller
# sample honestly measures less and a larger one measures a different map. The
# composition assertions have no such problem and apply at every size.
#
# Starts a dedicated server with games/h11v, force-emerges the area, scans it with
# a VoxelManip, prints one result line and shuts down. Exits 0 when every
# assertion holds, 1 otherwise — and prints the measured values either way,
# because a gate that says only FAIL costs a debugging session that a gate saying
# elevation_range=3 does not.
#
# The scanning mod lives in tools/worldgen_probe and is enabled as a world mod.
# It is never shipped inside the game.
#
# Three things learned the hard way in v0.1, all load-bearing here:
#   * macOS has no luantiserver binary, so the invocation is resolved, never
#     hardcoded — see tools/luanti_path.sh.
#   * A killed server keeps its port, and the next run then fails with a bind
#     error that reads like a different bug. So: a free port, and cleanup on
#     every exit path including the interrupt.
#   * Emerging is asynchronous; the probe waits for it rather than sampling a
#     half-generated map.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AREA=128
KEEP=0
TIMEOUT=180

for arg in "$@"; do
	case "$arg" in
		--keep) KEEP=1 ;;
		--area=*) AREA="${arg#*=}" ;;
		--timeout=*) TIMEOUT="${arg#*=}" ;;
		-h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
	esac
done

# Both values are compared with `[` further down, and a non-numeric one does not
# make this gate fail — it makes the gate stop checking. `--timeout=3m` made
# `[ "$elapsed" -ge 3m ]` exit 2 on every pass of the wait loop, and since `set -e`
# is deliberately off the `if` was simply false: the hang guard was gone and the
# run would have waited forever. `--area=banana` reached the engine, which fell
# back to 128 inside the probe, while the shell saw an AREA that was not 128 and
# skipped every DoD assertion — a gate printing PASS while asserting almost
# nothing. Both are rejected here, where the message can name the option.
case "$AREA" in ''|*[!0-9]*)
	echo "test_worldgen: --area must be a whole number of nodes, not '$AREA'" >&2; exit 2 ;;
esac
case "$TIMEOUT" in ''|*[!0-9]*)
	echo "test_worldgen: --timeout must be a whole number of seconds, not '$TIMEOUT'" >&2; exit 2 ;;
esac
# The scan samples one column in sixteen, so below 16 nodes it samples almost
# nothing and every measurement it prints is noise.
[ "$AREA" -ge 16 ] || { echo "test_worldgen: --area must be at least 16 nodes" >&2; exit 2; }
[ "$TIMEOUT" -ge 1 ] || { echo "test_worldgen: --timeout must be at least 1 second" >&2; exit 2; }

# `|| true`: sourcing bare under `set -e` would abort here, before the message.
. "$ROOT/tools/luanti_path.sh" || true
if [ "${LUANTI_MISSING:-1}" != "0" ]; then
	echo "test_worldgen: Luanti is not installed — see specification/ROADMAP.md v0.1" >&2
	exit 2
fi

[ -f "$ROOT/games/h11v/game.conf" ] || {
	echo "test_worldgen: no game at $ROOT/games/h11v" >&2; exit 2; }

# --- an isolated world, and a free port --------------------------------------

# `mktemp -d -t PREFIX` is a BSD-ism. GNU mktemp reads -t as the deprecated
# "template in $TMPDIR" flag and refuses a template with no XXXXXX, so on the Pi —
# a platform this gate is explicitly meant to run on — the command failed, WORK
# became empty under `set -u` (which does not trip on command substitution), WORLD
# became /world, and the run collapsed into permission errors that read like a
# broken checkout. The explicit template works on both.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/h11v-worldgen.XXXXXX")"
[ -n "$WORK" ] && [ -d "$WORK" ] || {
	echo "test_worldgen: could not create a temporary directory in ${TMPDIR:-/tmp}" >&2; exit 2; }
SERVER_PID=""

CLEANED=0
cleanup() {
	[ "$CLEANED" = 0 ] || return 0
	CLEANED=1
	if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
		kill "$SERVER_PID" 2>/dev/null
		# Give it a moment to release the port, then insist.
		for _ in 1 2 3 4 5; do
			kill -0 "$SERVER_PID" 2>/dev/null || break
			sleep 0.4
		done
		kill -9 "$SERVER_PID" 2>/dev/null
	fi
	if [ "$KEEP" = 1 ]; then
		echo "kept: $WORK"
	else
		rm -rf "$WORK"
	fi
}
# A signal handler that only cleans up is not enough: bash runs the handler and
# then RESUMES the script, so Ctrl-C used to kill the server, fall out of the wait
# loop, find no probe line and print "FAIL — the server exited without reporting",
# which describes nothing that happened. So the signal traps exit, and cleanup is
# idempotent because exiting from a handler runs the EXIT trap as well.
trap cleanup EXIT
trap 'echo >&2; echo "test_worldgen: interrupted" >&2; exit 130' INT
trap 'echo "test_worldgen: terminated" >&2; exit 143' TERM

# Ask the kernel for an unused port rather than guessing one. Guessing is how a
# leftover server from an earlier run turns into a bind error nobody can place.
#
# UDP, not TCP: the engine's port is the UDP one ("Network port to listen (UDP)",
# minetest.conf.example), so a free TCP port is no evidence at all about whether
# the port the server is about to bind is free.
PORT="$(python3 -c '
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.bind(("127.0.0.1", 0))
print(s.getsockname()[1]); s.close()
')"

WORLD="$WORK/world"
mkdir -p "$WORLD/worldmods"
cp -R "$ROOT/tools/worldgen_probe" "$WORLD/worldmods/worldgen_probe"

cat > "$WORLD/world.mt" <<EOF
gameid = h11v
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
world_name = h11v_worldgen
load_mod_worldgen_probe = true
EOF

# A fixed seed so the gate is reproducible: a flaky gate is worse than no gate.
cat > "$WORK/minetest.conf" <<EOF
fixed_map_seed = 20260913
h11v_probe_area = $AREA
mg_name = v7
max_block_generate_distance = 16
EOF

# --- run ----------------------------------------------------------------------

LOG="$WORK/server.log"
OUT="$WORK/stdout.txt"

echo "test_worldgen: area ${AREA}x${AREA}, port $PORT, seed 20260913"
luanti_server \
	--world "$WORLD" \
	--gameid h11v \
	--config "$WORK/minetest.conf" \
	--logfile "$LOG" \
	--port "$PORT" \
	>"$OUT" 2>&1 &
SERVER_PID=$!

# Wait for the probe's line, the server's exit, or the timeout — whichever first.
elapsed=0
while kill -0 "$SERVER_PID" 2>/dev/null; do
	grep -q 'H11V-WORLDGEN' "$OUT" 2>/dev/null && break
	sleep 1
	elapsed=$((elapsed + 1))
	if [ "$elapsed" -ge "$TIMEOUT" ]; then
		echo "test_worldgen: FAIL — no result after ${TIMEOUT}s" >&2
		tail -20 "$LOG" >&2 2>/dev/null
		exit 1
	fi
done

RESULT="$(grep -m1 'H11V-WORLDGEN' "$OUT" 2>/dev/null || true)"
if [ -z "$RESULT" ]; then
	echo "test_worldgen: FAIL — the server exited without reporting" >&2
	tail -20 "$LOG" >&2 2>/dev/null
	exit 1
fi

echo "$RESULT"

field() { echo "$RESULT" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -1; }

STATUS="$(field status)"
[ "$STATUS" = "ok" ] || { echo "test_worldgen: FAIL — probe status=$STATUS" >&2; exit 1; }

# --- assertions ---------------------------------------------------------------
# Each prints what it measured, pass or fail. v0.3 adds water and trees; the
# thresholds live here rather than in the probe so that changing what the project
# demands never means changing what it measures.

CONTRACT_AREA=128          # the map the DoD's numbers describe
MIN_ELEVATION_RANGE=8
WANT_SURFACE="h11_world:regolith"
MIN_SURFACE_PCT=80
MIN_WATER=1                # the DoD asks only that water is present
# The DoD's words, against the number that means them. `growths` is the probe's
# estimate of how many spires stand in the 128x128 area; `trees` is the raw count
# of SAMPLED columns holding one, which is sixteen times smaller because the scan
# looks at one column in sixteen.
#
# Until the colony retheme this gate asserted `trees >= 20` and was believed to be
# checking the DoD. It was silently demanding sixteen times that, and it only came
# to light when the magenta crowns forced the density down and a world that
# comfortably satisfies "at least 20 trees" turned the gate red.
#
# Neither figure is bit-stable: both wobble by about one sampled column between
# runs on a fixed seed, because decoration placement draws from a PRNG the map
# seed does not fully pin. Keep the margins wide; a threshold set near the
# measured value makes this gate flaky.
MIN_GROWTHS=20             # the DoD: "at least 20 trees in a 128x128 area"
# A floor, not the DoD: the point is to catch a schematic that places nothing,
# and a schematic that places nothing measures exactly 0. This was 4, which is a
# different claim entirely — 4 sampled columns is 4 * STEP^2 = 64 growths, 3.2x
# what the DoD asks — and it could never be the binding assertion anyway, because
# MIN_GROWTHS=20 already requires trees >= 2.
#
# That 16x granularity is worth stating plainly: growths only ever takes multiples
# of 16, so the DoD's "at least 20" is in practice "at least 32".
MIN_TREES=1

fail=0
assert_min() { # name value minimum
	# The non-numeric case must FAIL, not pass. `[ nil -lt 8 ]` exits 2, and a bare
	# `if` would take that as "not less than" and print ok — so a probe reporting
	# surface_min=nil would sail through the gate it exists to be caught by.
	#
	# `${2#-}` strips one leading minus and then nothing but digits is allowed, so a
	# sign is accepted only where a sign belongs. The previous pattern listed `-` in
	# the accepted character class, which permitted it anywhere: `3-` reached the
	# comparison, `[ 3- -lt 3 ]` exited 2, and the else branch printed ok — the exact
	# failure this guard is here to prevent.
	case "${2#-}" in
		''|*[!0-9]*) echo "  FAIL $1=$2 (not a number)" >&2; fail=1; return ;;
	esac
	if [ "$2" -lt "$3" ]; then
		echo "  FAIL $1=$2 (need >= $3)" >&2; fail=1
	else
		echo "  ok   $1=$2 (>= $3)"
	fi
}
assert_eq() { # name value expected
	if [ "$2" != "$3" ]; then
		echo "  FAIL $1=$2 (need $3)" >&2; fail=1
	else
		echo "  ok   $1=$2"
	fi
}

assert_min "sampled" "$(field sampled)" 1

# The v0.2 DoD, made machine-checkable: a horizon with elevation rather than a
# slab, and our turf on top rather than the bare stone a missing biome gives.
#
# elevation_range is asserted only at the contract area. The DoD's "at least 8
# blocks" is a property of the 128x128 map, not a density — a 48x48 sample of the
# same terrain honestly measures less, and asserting the full map's number
# against a fraction of it would turn --area into a source of red gates that mean
# nothing. Composition assertions have no such problem and always apply.
#
# Numeric comparison, not string: AREA is validated as digits at parse time, and
# `-eq` also makes 0128 and +128 the same area the DoD describes rather than a
# silent trip down the informational branch.
if [ "$AREA" -eq "$CONTRACT_AREA" ]; then
	assert_min "elevation_range" "$(field elevation_range)" "$MIN_ELEVATION_RANGE"
else
	echo "  --   elevation_range=$(field elevation_range) (informational: the DoD's >= $MIN_ELEVATION_RANGE is asserted only at area $CONTRACT_AREA)"
fi
assert_eq  "surface_top" "$(field surface_top)" "$WANT_SURFACE"
assert_min "surface_top_pct" "$(field surface_top_pct)" "$MIN_SURFACE_PCT"

# The v0.3 DoD. Both are properties of the 128x128 map rather than densities, so
# like elevation_range they are asserted at the contract area only.
#
# `water` counts sampled columns whose GROUND is a water source, and `trees`
# counts columns containing a trunk — neither is a raw block count, and the probe
# says so where it computes them. Asserting a number whose definition lives
# somewhere else is how a gate starts meaning something nobody intended.
if [ "$AREA" -eq "$CONTRACT_AREA" ]; then
	assert_min "water" "$(field water)" "$MIN_WATER"
	assert_min "growths" "$(field growths)" "$MIN_GROWTHS"
	assert_min "trees" "$(field trees)" "$MIN_TREES"
else
	echo "  --   water=$(field water) growths=$(field growths) trees=$(field trees) (informational: asserted only at area $CONTRACT_AREA)"
fi

# Engine errors are a failure even when the probe reports ok: a world that
# generates despite an error is a world built on something we do not understand.
if grep -qE 'ERROR\[' "$LOG" 2>/dev/null; then
	echo "  FAIL engine logged errors:" >&2
	grep -E 'ERROR\[' "$LOG" | sed 's/^/       /' | head -6 >&2
	fail=1
else
	echo "  ok   no engine errors"
fi

if [ "$fail" = 0 ]; then
	echo "test_worldgen: PASS"
	exit 0
fi
echo "test_worldgen: FAIL" >&2
exit 1
