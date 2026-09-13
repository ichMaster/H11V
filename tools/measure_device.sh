#!/usr/bin/env bash
# The v0.7 measurement protocol, as far as a script can honestly take it.
#
#   tools/measure_device.sh                 all three profiles
#   tools/measure_device.sh --profile=high  one of them
#   tools/measure_device.sh --walk=30       seconds of walking (default 30)
#
# For each profile: deploy fresh on a fixed seed, let the world settle, turn on
# the debug overlay, walk forward, and capture the screen. Screenshots land in
# docs/device/ where v0.7's record lives.
#
# What this DOES NOT do, on purpose: read a number off the overlay and write it
# into the decisions log. A frame rate is read by a person looking at the capture,
# because a script that OCR'd its own screenshot and reported the result would be
# a very confident way to be wrong about the one measurement this whole milestone
# exists to take. The script gets the conditions identical and the evidence
# captured; the reading is a judgement.
#
# Every run re-checks the GPU preflight first. A measurement taken on llvmpipe is
# not a weak measurement, it is a false one.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONN_FILE="${TERM35_CONN_FILE:-$ROOT/.term35-connect.txt}"
OUT_DIR="$ROOT/docs/device"
PROFILES="low mid high"
WALK=30
SETTLE=18
REMOTE_DIR_REMOTE=h11v

for arg in "$@"; do
	case "$arg" in
		--profile=*) PROFILES="${arg#*=}" ;;
		--walk=*) WALK="${arg#*=}" ;;
		-h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
	esac
done

die() { echo "error: $*" >&2; exit 1; }
[ -f "$CONN_FILE" ] || die "no credentials file at $CONN_FILE"
cfg_get() { sed -n "s/^[[:space:]]*$1[[:space:]]*:[[:space:]]*//p" "$CONN_FILE" | head -1 | tr -d '\r'; }
IP="$(cfg_get ip)"; DEV_USER="$(cfg_get user)"; TARGET="$DEV_USER@$IP"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new)

# The environment a Wayland tool needs when it is invoked over ssh rather than
# from inside the session.
ENV_PREFIX='export XDG_RUNTIME_DIR=/run/user/$(id -u); export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR | grep -m1 "^wayland-[0-9]*$");'

echo "== GPU preflight =="
"$ROOT/tools/gpu_preflight.sh" || die "preflight failed — any measurement now would be fiction"
RENDERER="$("$ROOT/tools/gpu_preflight.sh" 2>/dev/null | tail -1 | sed 's/^ *//')"

mkdir -p "$OUT_DIR"

for profile in $PROFILES; do
	echo
	echo "== profile: $profile =="
	# --fresh so every profile sees the same world from the same seed. Without it
	# the second profile measures chunks the first already generated, which is a
	# different and much cheaper thing to draw.
	# Deliberately NOT --uncapped. Luanti steers its view range toward fps_max, so
	# raising the cap makes the engine SHRINK the range to chase it — measured:
	# with fps_max=250 both the low and mid profiles reported "view range: 40" and
	# ~74 fps, because the engine had quietly cut mid's 60 down to reach a target
	# it could never hit. Uncapping destroys the thing being measured.
	#
	# So each profile is measured at its own shipping cap, and the number that
	# carries the information is `drawtime`: the real per-frame render cost, which
	# no cap or range-steering touches.
	"$ROOT/tools/deploy_to_term35.sh" --profile="$profile" --fresh >/dev/null 2>&1 \
		|| die "deploy failed for profile $profile"

	echo "   settling ${SETTLE}s (world generation, first chunks)"
	sleep "$SETTLE"

	# A throwaway keystroke first. The first profile of a run consistently came
	# back with the player still at the spawn while later profiles had walked the
	# full distance — the window is not ready to take injected input the instant
	# the world finishes loading, and the first key of a session is swallowed.
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX wtype -k shift" 2>/dev/null
	sleep 2

	# F5 cycles the debug overlay: off -> fps/pos -> profiler -> off. One press.
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX wtype -k F5" 2>/dev/null \
		|| echo "   (wtype unavailable — capture will have no overlay)"
	sleep 2

	echo "   walking ${WALK}s"
	# Hold W by pressing it down, waiting, and releasing. A frame rate measured
	# standing still is the easy case and not the one that matters: moving forces
	# mesh generation, which is where a voxel engine actually spends its time.
	# ONE invocation, holding the key across a -s sleep. Two separate calls do not
	# work and do not complain: each wtype process creates a virtual keyboard and
	# destroys it on exit, so the release happens the instant the press returns.
	# The first two attempts both reported pos: (0.0, y, 0.0) after a full-length
	# "walk", which is what gave it away — the overlay had already proved that key
	# injection itself reaches the game, since F5 toggled it.
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX wtype -P w -s $((WALK * 1000)) -p w" 2>/dev/null &
	WALK_PID=$!
	sleep $((WALK - 3))

	SHOT="$OUT_DIR/$profile.png"
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX grim /tmp/h11v-$profile.png" 2>/dev/null \
		|| die "screenshot failed for profile $profile"
	scp -q -o BatchMode=yes "$TARGET:/tmp/h11v-$profile.png" "$SHOT" \
		|| die "could not fetch the screenshot for $profile"
	wait "$WALK_PID" 2>/dev/null

	ERRORS="$("${SSH[@]}" "$TARGET" 'grep -c "ERROR" ~/h11v/h11v-debug.txt' 2>/dev/null || echo "?")"
	echo "   captured $SHOT   (engine errors this run: $ERRORS)"
done

"$ROOT/tools/deploy_to_term35.sh" --stop >/dev/null 2>&1

cat <<EOF

== captured ==
$(ls -1 "$OUT_DIR"/*.png 2>/dev/null | sed 's/^/   /')

Renderer: $RENDERER

Next, and deliberately not automated: open each capture, read the fps line and the
drawtime off the debug overlay, and record it in docs/decisions.md together with the renderer
above. Also judge and write down in words what only a person can — the legibility
of 32x32 textures at 3.5 inches, shimmer at distance, how the palette holds at
night, and whether the H11 glyph reads on the crust block.
EOF
