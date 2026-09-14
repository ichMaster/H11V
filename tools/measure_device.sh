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
# Verbatim from tools/deploy_to_term35.sh, including the trailing-whitespace strip
# this copy was missing (v0.8 review L16). One trailing space on the "ip:" line made
# TARGET "user@1.2.3.4 ", which ssh splits into a host plus a remote command — the
# run then died more than twenty seconds later with a message about grim, and the
# file that was actually wrong was never mentioned.
cfg_get() {
	sed -n "s/^[[:space:]]*$1[[:space:]]*:[[:space:]]*//p" "$CONN_FILE" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}
IP="$(cfg_get ip)"; DEV_USER="$(cfg_get user)"
# Checked here, where the message can name the file, instead of surfacing as the
# first ssh call failing for a reason of its own.
[ -n "$IP" ] || die "no usable 'ip:' line in $CONN_FILE (expected: ip: 192.168.1.105)"
[ -n "$DEV_USER" ] || die "no usable 'user:' line in $CONN_FILE (expected: user: ich)"
TARGET="$DEV_USER@$IP"
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
	#
	# The deploy's output is captured, not discarded. This is the one run whose
	# numbers reach docs/decisions.md, and the deploy's post-launch check is the only
	# reading in the chain that comes from the ENGINE's own log — sending both streams
	# to /dev/null silenced precisely the warning that would void the measurement
	# (v0.8 review M6). On any failure the log is printed and its path named.
	DEPLOY_LOG="$(mktemp "${TMPDIR:-/tmp}/h11v-deploy-$profile.XXXXXX")"
	"$ROOT/tools/deploy_to_term35.sh" --profile="$profile" --fresh >"$DEPLOY_LOG" 2>&1 \
		|| { sed 's/^/   | /' "$DEPLOY_LOG" >&2
		     die "deploy failed for profile $profile (output above, kept in $DEPLOY_LOG)"; }
	# And the warning aborts this profile, the way a failed preflight aborts the run:
	# a measurement on a software rasterizer is not a weaker measurement, it is a
	# false one, and a false one recorded is worse than a profile left unmeasured.
	# The pattern matches both halves of the evidence: the GPU name the engine logged
	# and the deploy's own warning wording, so the abort does not depend on Mesa
	# spelling its software driver one of three ways.
	if grep -qiE 'llvmpipe|softpipe|swrast|software rasterizer' "$DEPLOY_LOG"; then
		sed 's/^/   | /' "$DEPLOY_LOG" >&2
		die "the deploy reported a software rasterizer for profile $profile - nothing
measured now is worth recording. Fix GLX/V3D on the device (tools/gpu_preflight.sh,
specification/ARCHITECTURE.md 'The GPU path'); the deploy output is in $DEPLOY_LOG."
	fi
	# The deploy's own renderer line, carried down to the screenshot it belongs to
	# rather than re-probed: this is what the engine reported during THIS profile. The
	# deploy's NOTE matches too, which is the point — "no evidence" has to be as
	# visible beside a capture as a renderer name is. The seds strip only the deploy's
	# decoration; if its wording ever changes, the whole line is printed instead,
	# which is still the truth.
	PROFILE_RENDERER="$(grep -i -m1 'renderer' "$DEPLOY_LOG" \
		| sed -e 's/^==> *//' -e 's/^renderer (engine log): *//')"
	[ -n "$PROFILE_RENDERER" ] || PROFILE_RENDERER="unconfirmed - the deploy said nothing about the renderer"
	rm -f "$DEPLOY_LOG"

	echo "   settling ${SETTLE}s (world generation, first chunks)"
	sleep "$SETTLE"

	# A throwaway keystroke first. The first profile of a run consistently came
	# back with the player still at the spawn while later profiles had walked the
	# full distance — the window is not ready to take injected input the instant
	# the world finishes loading, and the first key of a session is swallowed.
	#
	# `Shift_L`, not `shift`. wtype takes X keysym names, and it answers `Unknown
	# key 'shift'` — on stderr, which this line discarded — for both `shift` and
	# `Shift`. So from the day it was written until v0.9's device pass, the
	# throwaway never fired and the swallowed-first-key problem it exists to
	# absorb was still live in every measurement run's first profile. Found by
	# reading the output rather than the script: a 25 s walk ended at pos (0,y,0).
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX wtype -k Shift_L" || die "wtype could not send a keystroke — is it installed on the device?"
	sleep 2

	# F5 cycles the debug overlay: off -> fps/pos -> profiler -> off. One press.
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX wtype -k F5" 2>/dev/null \
		|| echo "   (wtype unavailable — capture will have no overlay)"
	sleep 2

	echo "   walking ${WALK}s"
	# The key is Up, NOT w, and the difference is the whole measurement.
	#
	# tools/device/gamepad.conf sets `keymap_forward = KEY_UP`: on the panel the
	# D-pad moves you and W does nothing at all. That file landed in v0.7.1, one
	# release AFTER the v0.7.0 measurement session — so the recorded numbers are
	# safe, and every run since would have held a key the device does not bind,
	# captured a frame of the player standing at spawn, and reported it as a
	# 30-second walk. Confirmed on the device in v0.9's pass: `w` for 30 s left
	# pos at (0.0, 17.5, 0.0); `Up` for 25 s reached (37.2, 14.5, 24.6).
	#
	# This line is coupled to gamepad.conf and there is no way to make the shell
	# notice if that file moves forward again. The check that would catch it is
	# the human one this script already insists on: the captured frame shows the
	# position, so a reading at the spawn coordinates is not a measurement.
	#
	# Hold it by pressing down, waiting, and releasing. A frame rate measured
	# standing still is the easy case and not the one that matters: moving forces
	# mesh generation, which is where a voxel engine actually spends its time.
	# ONE invocation, holding the key across a -s sleep. Two separate calls do not
	# work and do not complain: each wtype process creates a virtual keyboard and
	# destroys it on exit, so the release happens the instant the press returns.
	# The first two attempts both reported pos: (0.0, y, 0.0) after a full-length
	# "walk", which is what gave it away — the overlay had already proved that key
	# injection itself reaches the game, since F5 toggled it.
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX wtype -P Up -s $((WALK * 1000)) -p Up" 2>/dev/null &
	WALK_PID=$!
	sleep $((WALK - 3))

	SHOT="$OUT_DIR/$profile.png"
	"${SSH[@]}" "$TARGET" "$ENV_PREFIX grim /tmp/h11v-$profile.png" 2>/dev/null \
		|| die "screenshot failed for profile $profile"
	scp -q -o BatchMode=yes "$TARGET:/tmp/h11v-$profile.png" "$SHOT" \
		|| die "could not fetch the screenshot for $profile"
	wait "$WALK_PID" 2>/dev/null

	# grep -c prints 0 and EXITS 1 when there is nothing to count, so the old
	# `|| echo "?"` fired on every clean run and appended a second word: the best
	# outcome available printed as "0 ?" and read as the could-not-read case (v0.8
	# review L15). The two states are now separated at the source — the remote side
	# says whether the log could be READ, and the count is only ever a number.
	ERRORS="$("${SSH[@]}" "$TARGET" "
		[ -r ~/$REMOTE_DIR_REMOTE/h11v-debug.txt ] || { echo unreadable; exit 0; }
		grep -c ERROR ~/$REMOTE_DIR_REMOTE/h11v-debug.txt || true" 2>/dev/null)"
	case "$ERRORS" in
		''|*[!0-9]*) ERRORS="? - could not read ~/$REMOTE_DIR_REMOTE/h11v-debug.txt" ;;
	esac
	echo "   captured $SHOT   (engine errors this run: $ERRORS)"
	echo "   renderer this profile: $PROFILE_RENDERER"
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
