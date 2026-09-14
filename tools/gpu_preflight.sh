#!/usr/bin/env bash
# Prove the PocketTerm35 will render on its GPU, not on a software rasterizer.
#
#   tools/gpu_preflight.sh            probe the device over ssh
#   tools/gpu_preflight.sh --local    probe this machine instead
#
# Exit 0 when the renderer is the Pi 5's V3D hardware driver; non-zero otherwise.
#
# This exists because the failure it catches is silent. With a broken GL setup
# Mesa falls back to llvmpipe: the world still draws, the game still plays, and
# every frame-rate number taken from that session is fiction. A measurement that
# is merely wrong is worse than one that is missing, so this runs before v0.7's
# protocol and again on every deploy.
#
# The reading that gates is glxinfo's. The device's Luanti is the legacy Irrlicht
# X11 build, so the game renders through GLX on XWayland: that is the path it
# takes, and the only path worth verifying. eglinfo is kept as a secondary,
# non-gating reading - it is what this script asked at first, and it answered V3D
# correctly about a path the game never takes. See docs/decisions.md, 2026-09-13,
# "The device renders through GLX on XWayland, not EGL on Wayland".
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONN_FILE="${TERM35_CONN_FILE:-$ROOT/.term35-connect.txt}"

local_mode=0
case "${1:-}" in
	--local) local_mode=1 ;;
	-h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
	"") ;;
	*) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

die() { echo "error: $*" >&2; exit 1; }

# The probe itself, run either here or there.
# Probe the path the GAME takes, not a path that happens to work. The device's
# engine is the legacy Irrlicht X11 build and renders through GLX on XWayland, so
# GLX is what must be verified — an earlier version of this script asked EGL,
# which answered V3D correctly while telling us nothing about the renderer the
# game would actually get. EGL is kept as a secondary reading.
#
# glxinfo's stderr is kept, not discarded. When the GLX reading is missing, the
# reason is always in it — "Error: unable to open display :0", an xauth refusal —
# and throwing it away left the caller with an absent line and no cause (v0.8 review
# M5). It is printed only when there is no reading to print, so a healthy probe stays
# three lines long.
PROBE='
echo "LIBGL_ALWAYS_SOFTWARE=[${LIBGL_ALWAYS_SOFTWARE:-unset}]"
if command -v glxinfo >/dev/null 2>&1; then
	glx="$(DISPLAY="${DISPLAY:-:0}" glxinfo -B 2>&1)"
	glx_lines="$(printf "%s\n" "$glx" | grep -iE "OpenGL renderer|direct rendering" | head -2)"
	if [ -n "$glx_lines" ]; then
		printf "%s\n" "$glx_lines"
	elif [ -n "$glx" ]; then
		printf "%s\n" "$glx" | head -6 | sed "s/^/(glxinfo said) /"
	else
		echo "(glxinfo said) nothing at all, on either stream"
	fi
else
	echo "NO-GLXINFO: glxinfo is not installed here"
fi
if command -v eglinfo >/dev/null 2>&1; then
	eglinfo 2>/dev/null | grep -iE "OpenGL ES profile renderer" | head -1 | sed "s/^/(egl) /"
fi
if ! command -v glxinfo >/dev/null 2>&1 && ! command -v eglinfo >/dev/null 2>&1; then
	echo "NO-PROBE: install mesa-utils"
fi
'

if [ "$local_mode" = 1 ]; then
	OUT="$(bash -c "$PROBE" 2>&1)"
	WHERE="this machine"
else
	[ -f "$CONN_FILE" ] || die "no credentials file at $CONN_FILE"
	cfg_get() {
		sed -n "s/^[[:space:]]*$1[[:space:]]*:[[:space:]]*//p" "$CONN_FILE" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//'
	}
	IP="$(cfg_get ip)"; DEV_USER="$(cfg_get user)"
	[ -n "$IP" ] && [ -n "$DEV_USER" ] || die "need 'ip:' and 'user:' in $CONN_FILE"
	WHERE="$DEV_USER@$IP"
	OUT="$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
		"$DEV_USER@$IP" "$PROBE" 2>&1)" \
		|| die "cannot reach $WHERE over ssh (powered off, asleep, or key auth not set up:
    tools/deploy_to_term35.sh --setup-key)"
fi

echo "== GPU preflight: $WHERE =="
echo "$OUT" | sed 's/^/   /'

# The two readings, kept apart on purpose. GLX_RENDERER is glxinfo's "OpenGL
# renderer string:"; the EGL line is eglinfo's "OpenGL ES profile renderer:", which
# the old fallback grep for a bare "renderer" also matched — so when glxinfo produced
# nothing the EGL answer quietly became "the renderer" and the script printed PASS
# about a path the game never takes (v0.8 review M5).
GLX_RENDERER="$(echo "$OUT" | grep -i "OpenGL renderer" | head -1)"
GLX_DIRECT="$(echo "$OUT" | grep -i "direct rendering" | head -1)"
EGL_RENDERER="$(echo "$OUT" | grep -i "(egl)" | head -1)"

if echo "$OUT" | grep -q "NO-PROBE"; then
	die "no eglinfo or glxinfo on the target — install mesa-utils and run this again"
fi
if echo "$OUT" | grep -qE "LIBGL_ALWAYS_SOFTWARE=\[(1|true)\]"; then
	die "LIBGL_ALWAYS_SOFTWARE is set: the target is forced onto a software rasterizer"
fi

# On the device the GLX reading is not one of two acceptable answers, it is the
# answer. Missing it means the path the game renders through was never verified, and
# docs/decisions.md (2026-09-13) settles what that is worth: a check that verifies
# the wrong path is not a weaker check, it is a false one.
if [ "$local_mode" = 0 ] && [ -z "$GLX_RENDERER" ]; then
	echo
	echo "FAIL: the GLX probe produced no renderer line on $WHERE." >&2
	echo "The game renders through GLX on XWayland, so nothing above verifies the path it" >&2
	echo "takes, and an unverified path is a failed preflight - not a pass." >&2
	if [ -n "$EGL_RENDERER" ]; then
		echo "EGL did answer (${EGL_RENDERER#*: }) and is deliberately not accepted in its place:" >&2
		echo "that is the reading this check used to pass on while GLX went unasked." >&2
	fi
	echo "Usual causes: glxinfo not installed (mesa-utils), XWayland not running, or" >&2
	echo "DISPLAY/xauth unreachable from this ssh session. Any '(glxinfo said)' line above" >&2
	echo "carries glxinfo's own reason. See specification/ARCHITECTURE.md, 'The GPU path'." >&2
	exit 1
fi

# --local is informational - the Mac is never where a measurement counts - so there
# the EGL reading is accepted when the machine has no GLX probe at all. On the device
# that branch is unreachable: the gate above has already refused.
RENDERER="$GLX_RENDERER"
[ -n "$RENDERER" ] || RENDERER="$EGL_RENDERER"

if echo "$RENDERER" | grep -qiE "llvmpipe|softpipe|swrast|software"; then
	echo
	echo "FAIL: software rasterizer in use." >&2
	echo "Every frame-rate number from this target would be fiction. Fix GLX/V3D before" >&2
	echo "measuring — see specification/ARCHITECTURE.md, 'The GPU path'." >&2
	exit 1
fi
if [ -z "$RENDERER" ]; then
	die "could not read a renderer string; treat this as a failed preflight, not a pass"
fi
# The other half of the GLX reading, which was printed and never checked. "direct
# rendering: No" with a V3D renderer string is a real state - an indirect GLX context
# still names the hardware driver while routing every frame through the X server -
# and it would be measured as if the GPU were drawing.
if [ -n "$GLX_RENDERER" ] && ! echo "$GLX_DIRECT" | grep -qi "direct rendering: *yes"; then
	die "GLX reports \"${GLX_DIRECT:-direct rendering: (no such line)}\" on $WHERE.
The renderer names hardware but the frames do not go straight to it, so any
measurement here would be of the indirect path. Fix it before measuring."
fi
# On the device the answer must be V3D specifically.
if [ "$local_mode" = 0 ] && ! echo "$RENDERER" | grep -qi "V3D"; then
	die "renderer is not V3D: ${RENDERER#*: }"
fi

echo
echo "PASS: hardware renderer on $WHERE."
[ -n "$GLX_RENDERER" ] || echo "      (EGL reading only - informational, and never accepted on the device.)"
echo "Record this line in docs/decisions.md beside any measurement it justifies:"
echo "   ${RENDERER#*: }"
