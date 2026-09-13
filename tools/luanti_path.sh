#!/usr/bin/env bash
# Resolve how to invoke Luanti on this machine. Source it; do not execute it.
#
#   . tools/luanti_path.sh
#   "$LUANTI" --version                  # the client
#   luanti_server --gameid h11v ...      # the headless server
#
# Sets LUANTI and LUANTI_VERSION, and defines luanti_server() — call that rather
# than expanding a variable: on the Mac the server is "<binary> --server", two
# words, and zsh does not word-split an unquoted parameter the way bash does, so
# `$LUANTI_SERVER ...` silently becomes one very odd filename. A function is the
# one form that behaves the same in both shells. LUANTI_SERVER is still exported,
# for printing in diagnostics only.
#
# Returns non-zero and sets LUANTI_MISSING=1 if the engine is not installed. A
# caller running `set -e` must source it as
#
#   . tools/luanti_path.sh || true
#
# and then check LUANTI_MISSING -- sourcing it bare under `set -e` aborts the
# caller at the `.` line, before it can print its own message, which is precisely
# the outcome the return code exists to avoid.
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
if [ -n "$LUANTI_SERVER" ]; then
	# A real dedicated-server binary: run it directly.
	luanti_server() { command "$LUANTI_SERVER" "$@"; }
elif [ -n "$LUANTI" ]; then
	# No separate binary (the macOS bundle): dedicated-server mode on the client.
	LUANTI_SERVER="$LUANTI --server"
	luanti_server() { command "$LUANTI" --server "$@"; }
else
	luanti_server() { echo "luanti_server: Luanti is not installed" >&2; return 127; }
fi

LUANTI_VERSION=""
if [ -n "$LUANTI" ]; then
	LUANTI_VERSION="$("$LUANTI" --version 2>/dev/null | head -1)"
fi

export LUANTI LUANTI_SERVER LUANTI_VERSION

# Sourced, so `return`; guard it in case someone executes the file anyway.
LUANTI_MISSING=0
if [ -z "$LUANTI" ]; then
	LUANTI_MISSING=1
	export LUANTI_MISSING
	return 1 2>/dev/null || exit 1
fi
export LUANTI_MISSING
return 0 2>/dev/null || exit 0
