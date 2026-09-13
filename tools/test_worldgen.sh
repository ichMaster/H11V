#!/usr/bin/env bash
# Acceptance gate: generate a world headlessly and assert what it contains.
#
#   tools/test_worldgen.sh              run the gate
#   tools/test_worldgen.sh --keep       keep the temporary world for inspection
#   tools/test_worldgen.sh --area=64    scan a smaller area (default 128)
#
# --area is for quick iteration. The DoD's elevation threshold describes the
# 128x128 map, so below that area it is reported but not asserted; composition
# assertions apply at every size.
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
		-h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
	esac
done

# `|| true`: sourcing bare under `set -e` would abort here, before the message.
. "$ROOT/tools/luanti_path.sh" || true
if [ "${LUANTI_MISSING:-1}" != "0" ]; then
	echo "test_worldgen: Luanti is not installed — see specification/ROADMAP.md v0.1" >&2
	exit 2
fi

[ -f "$ROOT/games/h11v/game.conf" ] || {
	echo "test_worldgen: no game at $ROOT/games/h11v" >&2; exit 2; }

# --- an isolated world, and a free port --------------------------------------

WORK="$(mktemp -d -t h11v-worldgen)"
SERVER_PID=""

cleanup() {
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
trap cleanup EXIT INT TERM

# Ask the kernel for an unused port rather than guessing one. Guessing is how a
# leftover server from an earlier run turns into a bind error nobody can place.
PORT="$(python3 -c '
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0))
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
WANT_SURFACE="h11_world:turf"
MIN_SURFACE_PCT=80

fail=0
assert_min() { # name value minimum
	# The non-numeric case must FAIL, not pass. `[ nil -lt 8 ]` exits 2, and a bare
	# `if` would take that as "not less than" and print ok — so a probe reporting
	# surface_min=nil would sail through the gate it exists to be caught by.
	case "$2" in
		''|*[!0-9-]*|-) echo "  FAIL $1=$2 (not a number)" >&2; fail=1; return ;;
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
if [ "$AREA" = "$CONTRACT_AREA" ]; then
	assert_min "elevation_range" "$(field elevation_range)" "$MIN_ELEVATION_RANGE"
else
	echo "  --   elevation_range=$(field elevation_range) (informational: the DoD's >= $MIN_ELEVATION_RANGE applies at area $CONTRACT_AREA)"
fi
assert_eq  "surface_top" "$(field surface_top)" "$WANT_SURFACE"
assert_min "surface_top_pct" "$(field surface_top_pct)" "$MIN_SURFACE_PCT"

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
