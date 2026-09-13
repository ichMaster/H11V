#!/usr/bin/env bash
# Start H11V on the PocketTerm35 from inside (or over ssh into) the Sway session.
# Deployed next to the game by tools/deploy_to_term35.sh; also runnable by hand.
cd "$(dirname "$0")"
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

if [ -n "$OUTPUT" ] && [ "$OLD_SCALE" != "1.000000" ] && [ "$OLD_SCALE" != "1" ]; then
  # Persist BEFORE changing anything: the trap covers a clean exit, the file covers
  # everything else - SIGKILL, a power cut, a second launch stepping on the first.
  printf '%s %s\n' "$OUTPUT" "$OLD_SCALE" > "$STATE"
  trap restore_scale EXIT INT TERM
  swaymsg output "$OUTPUT" scale 1 >/dev/null 2>&1
fi


# Luanti 5.10 renamed the binary; a Debian package may install either name.
# Use whichever is present rather than assuming.
LUANTI="$(command -v luanti || command -v minetest)" || {
  echo "error: neither luanti nor minetest is installed on this device" >&2
  exit 1
}

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
  echo "error: the engine cannot see the h11v game." >&2
  echo "       linked $PWD/game -> $USER_DIR/games/h11v, but --gameid list does not list it." >&2
  echo "       Check the link target exists and game.conf is readable." >&2
  exit 1
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
