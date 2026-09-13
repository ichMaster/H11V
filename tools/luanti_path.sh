#!/usr/bin/env bash
# Resolve how to invoke Luanti on this machine. Source it; do not execute it.
#
#   . tools/luanti_path.sh
#   "$LUANTI" --version                 # the client
#   $LUANTI_SERVER --gameid h11v ...    # the headless server (unquoted: may be two words)
#
# Sets LUANTI, LUANTI_SERVER and LUANTI_VERSION; returns non-zero if the engine
# is not installed, so a caller can fail with its own message.
#
# Why this file exists: the two target platforms package the server differently,
# and hardcoding either name gives a red gate that reads like a bug in the game.
#
#   Debian / Raspberry Pi OS   a separate `luantiserver` binary, both on PATH.
#   macOS (Homebrew cask)      one binary inside an .app bundle, not on PATH at
#                              all, with no separate server — dedicated-server
#                              mode is the `--server` flag on the same binary.
#
# So LUANTI_SERVER is "<path> --server" on the Mac and "luantiserver" on the Pi,
# and callers must leave it unquoted at the point of use.

# Client -------------------------------------------------------------------
LUANTI=""
for candidate in \
	"$(command -v luanti 2>/dev/null)" \
	"$(command -v minetest 2>/dev/null)" \
	"/Applications/luanti.app/Contents/MacOS/luanti" \
	"/Applications/minetest.app/Contents/MacOS/minetest" \
	"$HOME/Applications/luanti.app/Contents/MacOS/luanti"; do
	if [ -n "$candidate" ] && [ -x "$candidate" ]; then LUANTI="$candidate"; break; fi
done

# Server -------------------------------------------------------------------
# Prefer a real dedicated-server binary when the platform ships one; otherwise
# fall back to the client's --server flag, which is equivalent.
LUANTI_SERVER=""
for candidate in \
	"$(command -v luantiserver 2>/dev/null)" \
	"$(command -v minetestserver 2>/dev/null)"; do
	if [ -n "$candidate" ] && [ -x "$candidate" ]; then LUANTI_SERVER="$candidate"; break; fi
done
if [ -z "$LUANTI_SERVER" ] && [ -n "$LUANTI" ]; then
	LUANTI_SERVER="$LUANTI --server"
fi

LUANTI_VERSION=""
if [ -n "$LUANTI" ]; then
	LUANTI_VERSION="$("$LUANTI" --version 2>/dev/null | head -1)"
fi

export LUANTI LUANTI_SERVER LUANTI_VERSION

# Sourced, so `return`; guard it in case someone executes the file anyway.
if [ -z "$LUANTI" ]; then
	return 1 2>/dev/null || exit 1
fi
return 0 2>/dev/null || exit 0
