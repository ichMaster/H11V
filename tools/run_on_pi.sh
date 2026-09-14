#!/usr/bin/env bash
# Start H11V on the PocketTerm35 from inside (or over ssh into) the Sway session.
# Deployed next to the game by tools/deploy_to_term35.sh; also runnable by hand.
cd "$(dirname "$0")"

# Launched from the Sway menu there is no terminal to print to, so anything that
# goes wrong before the window opens would vanish. Everything this script says is
# therefore also appended to a log next to the game, and a failure raises a
# swaynag banner rather than simply not starting — "I tapped it and nothing
# happened" is the least debuggable bug report there is.
exec > >(tee -a "$(dirname "$0")/run_on_pi.log") 2>&1
fail() {
	echo "run_on_pi: $*" >&2
	command -v swaynag >/dev/null 2>&1 && \
		swaynag -t error -m "H11V failed to start: $*" >/dev/null 2>&1 &
	exit 1
}
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  export WAYLAND_DISPLAY="$(ls "$XDG_RUNTIME_DIR" | grep -m1 '^wayland-[0-9]*$')"
fi

# This device's Luanti is the legacy Irrlicht X11 build — libX11, no SDL, no EGL,
# no GLESv2 — so it renders through GLX on XWayland rather than natively on
# Wayland. That still reaches the hardware (DISPLAY=:0 glxinfo reports V3D 7.1.7.0,
# direct rendering yes); it is simply not the path the specification originally
# assumed. See docs/decisions.md.
#
# DISPLAY must be set explicitly: over ssh there is none, and without it the
# engine dies with "Need running XServer" — which reads like a broken desktop and
# is a missing environment variable.
export DISPLAY="${DISPLAY:-:0}"
# Harmless if a future build is the SDL one; ignored by this one.
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"

# A second tap on the Sway launcher must not reach the scale dance below. The
# launcher gives no feedback and world generation takes seconds, so tapping again
# is the reasonable thing to do — and the second instance would find the note the
# first one left, read it as the leftovers of a crash, and put the panel back to
# 1.25 *under* the running game. That game then renders 640x480 into a scaled
# output, resampling every pixel of the 32x32 art: the one thing the dance exists
# to prevent, with nothing on screen to say why it now looks soft. The v0.7
# legibility judgement — do 32x32 textures read at 3.5 inches, answered yes by eye
# on this panel (docs/decisions.md, 2026-09-13) — is the kind of call that would
# then be made on a resampled frame. And whichever instance exited first would fire
# restore_scale, leaving the survivor scaled for the rest of the session.
#
# So a live engine makes this launch a no-op, and one that says so rather than
# looking like a dead button. It stops here: before the note is read, before
# h11v-debug.txt is truncated under the running game, before the game symlink is
# rebuilt, and before any trap is installed — nothing this process does can be felt
# by the one already playing. Skipping only the dance and letting the second engine
# start was the alternative and is worse: two servers on one sqlite world on a 4 GB
# Pi, and the deploy's renderer check reading a log the newcomer had just emptied.
#
# The note below is therefore treated as stale only when no engine is running,
# which is the case it was written for. Both process names are probed, as in
# deploy_to_term35.sh's --stop — a Debian package install is "luanti", older builds
# are "minetest", and which one is here is detected everywhere else in this file
# rather than assumed. Where pgrep is missing the test is simply false and the
# launch proceeds exactly as it did before this guard existed.
engine_running() {
  pgrep -x luanti >/dev/null 2>&1 || pgrep -x minetest >/dev/null 2>&1
}
if engine_running; then
  echo "run_on_pi: the game is already running; this launch changes nothing" >&2
  command -v swaynag >/dev/null 2>&1 && \
    swaynag -t warning -m "H11V is already running" >/dev/null 2>&1 &
  exit 0
fi

# The desktop runs the panel at scale 1.25 (an effective 512x384) so terminal
# text stays readable at arm's length. That is right for the desktop and wrong
# for this game: it renders 640x480, exactly the panel's mode, and any non-unit
# scale resamples every pixel of 32x32 pixel art. So drop to scale 1 for the
# duration of the game and put the desktop back exactly as it was.
SWAYSOCK="${SWAYSOCK:-$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1)}"
export SWAYSOCK
STATE="$XDG_RUNTIME_DIR/h11v-desktop-scale"
OUTPUT="" OLD_SCALE=""

sway_output() {
  swaymsg -t get_outputs 2>/dev/null | python3 -c '
import json, sys
for o in json.load(sys.stdin):
    if o.get("active"):
        print(o["name"], o.get("scale", 1)); break
' 2>/dev/null
}

# The scale sway_output prints is a JSON number that has been through Python, so a
# panel already at unit scale arrives here as "1.0". Neither spelling the guard
# below used to test for can reach it: "1.000000" is a form nothing in that chain
# produces, and "1" only survives an integer. So the guard passed on every launch,
# and a desktop already at scale 1 was reconfigured for nothing — a visible
# flicker, a note written for a value that had not changed, and a "restore"
# afterwards to what it already was (v0.8 review L14). One scale can be spelled
# "1", "1.0" or "1.000000", so trim the trailing zeros before asking.
is_unit_scale() {
  case "$1" in
    *.*) set -- "${1%"${1##*[!0]}"}"; [ "${1%.}" = "1" ];;
    *)   [ "$1" = "1" ];;
  esac
}

restore_scale() {
  [ -n "$OUTPUT" ] && [ -n "$OLD_SCALE" ] && swaymsg output "$OUTPUT" scale "$OLD_SCALE" >/dev/null 2>&1
  rm -f "$STATE"
}

if [ -n "$SWAYSOCK" ] && command -v swaymsg >/dev/null 2>&1; then
  # A previous run that was SIGKILLed, or lost power, never restored the desktop
  # scale and left its note behind. Honour that note before reading the current
  # value, or we would save 1 as "the desktop scale" and lose 1.25 permanently.
  if [ -f "$STATE" ]; then
    read -r SAVED_OUTPUT SAVED_SCALE < "$STATE" || true
    if [ -n "${SAVED_OUTPUT:-}" ] && [ -n "${SAVED_SCALE:-}" ]; then
      echo "note: a previous run left the panel at game scale; restoring $SAVED_SCALE" >&2
      swaymsg output "$SAVED_OUTPUT" scale "$SAVED_SCALE" >/dev/null 2>&1 || true
    fi
    rm -f "$STATE"
  fi
  read -r OUTPUT OLD_SCALE <<<"$(sway_output)"
fi

if [ -n "$OUTPUT" ] && ! is_unit_scale "$OLD_SCALE"; then
  # Persist BEFORE changing anything: the trap covers a clean exit, and the file
  # covers what no trap can — SIGKILL and a power cut. A second launch is not on
  # that list and never was: the file is what misleads it, and the liveness check
  # above is what holds it back.
  printf '%s %s\n' "$OUTPUT" "$OLD_SCALE" > "$STATE"
  trap restore_scale EXIT INT TERM
  swaymsg output "$OUTPUT" scale 1 >/dev/null 2>&1
fi


# Luanti 5.10 renamed the binary; a Debian package may install either name.
# Use whichever is present rather than assuming.
#
# /usr/games is on PATH in a login shell and NOT in the environment a desktop
# launcher or a systemd user unit hands you — and Debian puts the luanti wrapper
# exactly there. Searching PATH alone means the game starts from a terminal and
# does nothing at all from the Sway menu, which is the least debuggable failure
# a user can be given. So PATH is widened first, then searched.
PATH="$PATH:/usr/games:/usr/local/games:/usr/local/bin"
export PATH
LUANTI="$(command -v luanti || command -v minetest || true)"
[ -n "$LUANTI" ] || fail "neither luanti nor minetest is installed (looked on PATH and /usr/games)"

# The deployed tree is self-contained: ./game is the H11V game, ./minetest.conf
# is base + profile assembled on the Mac.
#
# The game has to be findable by id, and the engine has NO --userdata flag: it
# looks in its share path and in its own user directory, and nowhere else. So the
# game is linked into that user directory. Which one it is depends on the build --
# 5.10 on this device still uses the pre-rename ~/.minetest -- so detect rather
# than assume, and create the legacy name only as the fallback.
USER_DIR="$HOME/.luanti"
[ -d "$USER_DIR" ] || USER_DIR="$HOME/.minetest"
mkdir -p "$USER_DIR/games"
rm -rf "$USER_DIR/games/h11v"
ln -s "$PWD/game" "$USER_DIR/games/h11v"

# Prove the engine can see it before launching. Both streams are captured on
# purpose: 5.10 prints the game list to stderr and 5.17 to stdout, and a check
# that reads only one of them is a guard that blocks working deploys — which is
# its own defect, and worse than no guard, because it is believed. Without this the failure surfaces
# later and elsewhere -- the deploy script reports "the game did not stay up" for
# a game that copied perfectly and simply could not be resolved.
if ! "$LUANTI" --gameid list 2>&1 | grep -qx 'h11v'; then
  fail "the engine cannot see the h11v game (linked $PWD/game -> $USER_DIR/games/h11v)"
fi

# The world has to exist before --go will use it: the engine creates a world from
# the main menu, not from the command line, and with --go it simply refuses. So
# the deploy owns world creation — one world.mt naming our gameid is all it takes,
# and the engine generates the map into it on first run.
# Start each run's engine log fresh. Luanti appends, and the deploy's renderer
# check greps the FIRST match — so a stale line from a failed launch three
# deploys ago would be reported as this run's renderer, forever. A log that
# describes a run other than the current one is worse than no log.
: > "$PWD/h11v-debug.txt"

WORLD_DIR="$USER_DIR/worlds/h11v_dev"
if [ ! -f "$WORLD_DIR/world.mt" ]; then
  mkdir -p "$WORLD_DIR"
  cat > "$WORLD_DIR/world.mt" <<'WORLDMT'
gameid = h11v
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
world_name = h11v_dev
creative_mode = true
enable_damage = false
WORLDMT
  echo "==> created world h11v_dev"
fi

# Not exec: the trap above has to run when the game exits.
"$LUANTI" \
  --config "$PWD/minetest.conf" \
  --logfile "$PWD/h11v-debug.txt" \
  --gameid h11v \
  --worldname h11v_dev \
  --go \
  "$@"
