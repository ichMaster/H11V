#!/usr/bin/env bash
# Acceptance gate: every Lua file in the game parses.
#
#   tools/check_lua.sh            check games/ and tools/
#   tools/check_lua.sh <path>...  check specific paths
#   LUAC=luac5.1 tools/check_lua.sh   force a particular checker
#
# The cheapest gate there is, and the one that catches the most: a Luanti mod
# with a syntax error fails at load time with a message the headless server
# buries, so this runs before test_worldgen.sh rather than after it.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The dialect matters, and it is not the newest Lua on the box. Both engines embed
# LuaJIT 2.1 — recorded per platform in docs/decisions.md, 2.1.1764270282 on the
# Mac's 5.17 and 2.1.1737090214 on the device's 5.10 — so the syntax that counts is
# Lua 5.1, and a 5.4 luac accepts a pile of things LuaJIT rejects at mod load.
# Measured here: `local a = 1 // 2` passes `luac -p` from Homebrew's Lua 5.4.7.
# Lua 5.1 has no floor-division operator, so that line is a syntax error to LuaJIT
# and fails at load inside the headless server — the buried failure this script's
# own header says it exists to pre-empt, waved through by the gate.
#
# So: 5.1-capable checkers first, and whichever one actually ran is printed. When
# only a newer luac is installed the gate still runs — a parse check against the
# wrong dialect still catches unbalanced `end`s — but it says so out loud, because
# a green that means less than it looks like is worse than a missing gate.
LUAC="${LUAC:-}"
if [ -z "$LUAC" ]; then
	for c in luac5.1 luajit luac luac5.4 luac5.3; do
		command -v "$c" >/dev/null 2>&1 && { LUAC="$c"; break; }
	done
fi
[ -n "$LUAC" ] || {
	echo "check_lua: no Lua checker on PATH." >&2
	echo "  the dialect the engine runs is 5.1: apt install luajit (or lua5.1), brew install luajit" >&2
	exit 2
}

LUAC_NAME="$(basename "$LUAC")"
# The banner, minus the copyright line noise: "Lua 5.1.5", "LuaJIT 2.1.0-beta3".
# luajit writes its copyright after a "--", hence the optional dashes.
LUAC_BANNER="$("$LUAC" -v 2>&1 | head -1 | sed -E 's/ *(--)? *Copyright.*//')"
case "$LUAC_BANNER" in
	*LuaJIT*|*5.1*) DIALECT_OK=1 ;;
	*)              DIALECT_OK=0 ;;
esac

# An interpreter checks a file with loadfile; a compiler with -p.
case "$LUAC_NAME" in
	luajit|lua|lua5.1) MODE="loadfile" ;;
	*)                 MODE="compile" ;;
esac

# `loadfile` parses a file and returns the compiled chunk WITHOUT running it, so
# this is a parse check and nothing more. Verified with the standalone `lua` on
# this Mac (good file 0, syntax error 1); the contract is word for word the same
# in 5.1 and LuaJIT. The path travels in the environment rather than as an
# argument because the first non-option argument after -e is the *script to run*,
# and running the mod under test is not what a syntax gate does.
#
# The form here used to be `luajit -bl "$f" -o /dev/null`. In -b mode luajit's -o
# is the target-OS override, not an output path, so that was never a verified
# parse check — it was a guess that happened to exit 0.
LOADFILE_CHUNK='local p = os.getenv("H11V_LUA_FILE")
local chunk, err = loadfile(p)
if not chunk then io.stderr:write(err, "\n"); os.exit(1) end'

if [ "$#" -gt 0 ]; then
	targets=("$@")
else
	targets=("$ROOT/games" "$ROOT/tools")
fi

files=()
for t in "${targets[@]}"; do
	[ -e "$t" ] || continue
	while IFS= read -r f; do files+=("$f"); done < <(find "$t" -name '*.lua' -type f 2>/dev/null)
done

if [ "${#files[@]}" -eq 0 ]; then
	echo "check_lua: no .lua files yet — nothing to check"
	exit 0
fi

fail=0
for f in "${files[@]}"; do
	if [ "$MODE" = "loadfile" ]; then
		out="$(H11V_LUA_FILE="$f" "$LUAC" -e "$LOADFILE_CHUNK" 2>&1)" \
			|| { echo "FAIL ${f#"$ROOT"/}"; echo "$out" | head -3; fail=1; }
	else
		out="$("$LUAC" -p "$f" 2>&1)" \
			|| { echo "FAIL ${f#"$ROOT"/}"; echo "$out" | head -3; fail=1; }
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "check_lua: ${#files[@]} file(s) parse — checker: $LUAC_NAME ($LUAC_BANNER)"
	if [ "$DIALECT_OK" -eq 0 ]; then
		echo "check_lua: NOTE — that checker is not Lua 5.1, and the engine's LuaJIT is." >&2
		echo "  5.2+ syntax (// goto <const> and the bitwise operators) passes here and fails at mod load." >&2
		echo "  Install luajit or lua5.1 for a gate that speaks the engine's dialect." >&2
	fi
else
	echo "check_lua: syntax errors above (checker: $LUAC_NAME — $LUAC_BANNER)" >&2
fi
exit "$fail"
