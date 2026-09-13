#!/usr/bin/env bash
# Install the asset pack into the game tree at a chosen node resolution.
#
#   tools/install_assets.sh              install at 16x16 (the shipping choice)
#   tools/install_assets.sh --res=32     install at 32x32 (the authored size)
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
PACK="$ROOT/specification/art/h11v"
GAME="$ROOT/games/h11v"
RES=16

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
rsync -a --exclude '.DS_Store' "$PACK/" "$GAME/" || exit 1

if [ "$RES" = 16 ]; then
	"$ROOT/tools/downscale_pack.py" "$GAME" | tail -1
else
	echo "  node textures left at the authored 32x32"
fi

"$ROOT/tools/strip_png_metadata.py" "$GAME" | tail -1

echo "==> verifying"
"$ROOT/tools/check_assets.py" | tail -1
