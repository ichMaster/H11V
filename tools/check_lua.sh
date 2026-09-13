#!/usr/bin/env bash
# Acceptance gate: every Lua file in the game parses.
#
#   tools/check_lua.sh            check games/ and tools/
#   tools/check_lua.sh <path>...  check specific paths
#
# The cheapest gate there is, and the one that catches the most: a Luanti mod
# with a syntax error fails at load time with a message the headless server
# buries, so this runs before test_worldgen.sh rather than after it.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAC="${LUAC:-}"
if [ -z "$LUAC" ]; then
	for c in luac luac5.4 luac5.3 luac5.1 luajit; do
		command -v "$c" >/dev/null 2>&1 && { LUAC="$c"; break; }
	done
fi
[ -n "$LUAC" ] || {
	echo "check_lua: no luac on PATH (brew install lua, or apt install lua5.1)" >&2
	exit 2
}

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
	if [ "$(basename "$LUAC")" = "luajit" ]; then
		out="$("$LUAC" -bl "$f" -o /dev/null 2>&1)" || { echo "FAIL $f"; echo "$out" | head -3; fail=1; }
	else
		out="$("$LUAC" -p "$f" 2>&1)" || { echo "FAIL ${f#$ROOT/}"; echo "$out" | head -3; fail=1; }
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "check_lua: ${#files[@]} file(s) parse"
else
	echo "check_lua: syntax errors above" >&2
fi
exit "$fail"
