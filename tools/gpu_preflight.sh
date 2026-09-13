#!/usr/bin/env bash
# Prove the PocketTerm35 will render on its GPU, not on a software rasterizer.
#
#   tools/gpu_preflight.sh            probe the device over ssh
#   tools/gpu_preflight.sh --local    probe this machine instead
#
# Exit 0 when the renderer is the Pi 5's V3D hardware driver; non-zero otherwise.
#
# This exists because the failure it catches is silent. With a broken EGL setup
# Mesa falls back to llvmpipe: the world still draws, the game still plays, and
# every frame-rate number taken from that session is fiction. A measurement that
# is merely wrong is worse than one that is missing, so this runs before v0.7's
# protocol and again on every deploy.
#
# The probe is eglinfo rather than glxinfo: Luanti renders through EGL on
# Wayland, and glxinfo reports nothing useful over a session with no X display.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONN_FILE="${TERM35_CONN_FILE:-$ROOT/.term35-connect.txt}"

local_mode=0
case "${1:-}" in
	--local) local_mode=1 ;;
	-h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
	"") ;;
	*) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

die() { echo "error: $*" >&2; exit 1; }

# The probe itself, run either here or there.
PROBE='
echo "LIBGL_ALWAYS_SOFTWARE=[${LIBGL_ALWAYS_SOFTWARE:-unset}]"
if command -v eglinfo >/dev/null 2>&1; then
	eglinfo 2>/dev/null | grep -iE "OpenGL ES profile renderer" | head -1
elif command -v glxinfo >/dev/null 2>&1; then
	glxinfo -B 2>/dev/null | grep -i "OpenGL renderer" | head -1
else
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

RENDERER="$(echo "$OUT" | grep -i "renderer" | head -1)"

if echo "$OUT" | grep -q "NO-PROBE"; then
	die "no eglinfo or glxinfo on the target — install mesa-utils and run this again"
fi
if echo "$OUT" | grep -qE "LIBGL_ALWAYS_SOFTWARE=\[(1|true)\]"; then
	die "LIBGL_ALWAYS_SOFTWARE is set: the target is forced onto a software rasterizer"
fi
if echo "$RENDERER" | grep -qiE "llvmpipe|softpipe|swrast|software"; then
	echo
	echo "FAIL: software rasterizer in use." >&2
	echo "Every frame-rate number from this target would be fiction. Fix EGL/V3D before" >&2
	echo "measuring — see specification/ARCHITECTURE.md, 'The GPU path'." >&2
	exit 1
fi
if [ -z "$RENDERER" ]; then
	die "could not read a renderer string; treat this as a failed preflight, not a pass"
fi
# On the device the answer must be V3D specifically; --local is informational, since
# the Mac is never where a measurement counts.
if [ "$local_mode" = 0 ] && ! echo "$RENDERER" | grep -qi "V3D"; then
	die "renderer is not V3D: ${RENDERER#*: }"
fi

echo
echo "PASS: hardware renderer on $WHERE."
echo "Record this line in docs/decisions.md beside any measurement it justifies:"
echo "   ${RENDERER#*: }"
