#!/usr/bin/env bash
# Install the asset pack into the game tree at a chosen node resolution.
#
#   tools/install_assets.sh              install at 32x32 (the shipping choice)
#   tools/install_assets.sh --res=16     install at 16x16
#
# This is the whole of the asset install, and the whole of the rollback. The
# delivered pack in specification/art/h11v/ is never modified — it stays the
# 32x32 delivery of record — so switching resolution is one command in either
# direction with nothing else to edit and nothing to restore from a backup.
#
#   rsync   the pack in, replacing whatever is there
#   halve   node textures, unless --res=32
#   strip   the content-credential metadata (146 KiB that would cross the
#           network on every deploy)
#
# tools/check_assets.py detects the installed resolution rather than being told
# it, so the gate follows this choice automatically.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK="$ROOT/specification/art/colony"
GAME="$ROOT/games/h11v"
RES=32

for arg in "$@"; do
	case "$arg" in
		--res=*) RES="${arg#*=}" ;;
		-h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
	esac
done

case "$RES" in 16|32) ;; *) echo "error: --res must be 16 or 32" >&2; exit 2 ;; esac
[ -d "$PACK" ] || { echo "error: no pack at $PACK" >&2; exit 1; }

echo "==> installing the asset pack at ${RES}x${RES}"

# Clear the node textures first. rsync without --delete leaves whatever was there
# before, and after the colony retheme that meant eleven v0 textures (h11_turf_*,
# h11_dirt, h11_water*, h11_hand...) sitting in the tree with nothing referencing
# them — invisible in game, shipped to the device on every deploy, and a trap for
# the next person who greps for a texture name. Textures come only from the pack,
# so emptying the directory is safe; everything else in $GAME is merged, not
# replaced, because game.conf and the mods live there too.
rm -rf "$GAME/mods/h11_world/textures"
rsync -a --exclude '.DS_Store' "$PACK/" "$GAME/" || exit 1

if [ "$RES" = 16 ]; then
	"$ROOT/tools/downscale_pack.py" "$GAME" | tail -1
else
	echo "  node textures left at the authored 32x32"
fi

"$ROOT/tools/strip_png_metadata.py" "$GAME" | tail -1

echo "==> verifying"
"$ROOT/tools/check_assets.py" | tail -1
