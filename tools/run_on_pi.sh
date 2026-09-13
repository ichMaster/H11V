#!/usr/bin/env bash
# Start H11V on the PocketTerm35 from inside (or over ssh into) the Sway session.
# Deployed next to the game by tools/deploy_to_term35.sh; also runnable by hand.
cd "$(dirname "$0")"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  export WAYLAND_DISPLAY="$(ls "$XDG_RUNTIME_DIR" | grep -m1 '^wayland-[0-9]*$')"
fi

# Luanti renders through SDL; on this device that must be the Wayland backend
# talking to EGL/V3D. Left to its own devices SDL can pick X11-on-Xwayland and
# quietly land on llvmpipe, which draws correctly and makes every fps number a
# lie. See specification/ARCHITECTURE.md, "The GPU path".
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

# Luanti 5.10 renamed the binary and the user directory; a Debian package may
# still install either. Use whichever is present rather than assuming.
LUANTI="$(command -v luanti || command -v minetest)" || {
  echo "error: neither luanti nor minetest is installed on this device" >&2
  exit 1
}

# The deployed tree is self-contained: ./game is the H11V game, ./minetest.conf
# is base + profile assembled on the Mac. --gameid needs the game visible in a
# games/ directory, so point the engine's user path at a directory we own here.
USER_DIR="$PWD/userdata"
mkdir -p "$USER_DIR/games" "$USER_DIR/worlds"
rm -f "$USER_DIR/games/h11v"
ln -s "$PWD/game" "$USER_DIR/games/h11v"

# Not exec: the trap above has to run when the game exits.
"$LUANTI" \
  --config "$PWD/minetest.conf" \
  --logfile "$PWD/h11v-debug.txt" \
  --gameid h11v \
  --worldname h11v_dev \
  --go \
  "$@"
