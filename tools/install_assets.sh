#!/usr/bin/env bash
# Install the asset pack into the game tree at a chosen node resolution.
#
#   tools/install_assets.sh              install at 32x32 (the shipping choice)
#   tools/install_assets.sh --res=16     install at 16x16
#
# This is the whole of the asset install, and the whole of the rollback. The
# delivered pack in specification/art/colony/ is never modified — it stays the
# 32x32 delivery of record, and it is the colony pack, not the retired v0
# specification/art/h11v/ one — so switching resolution is one command in either
# direction with nothing else to edit and nothing to restore from a backup.
#
# One direction is currently RED, and knowing that beforehand is worth a line:
# --res=16 halves h11_crate_side.png into a broken horizontal wrap (59.4 against
# an interior of 10.0) and the verify step fails. It is not a regression — the
# same halving produced the same seam before v0.9 made the verify step's status
# actually count — but the 16px path cannot install green until that flank is
# redrawn or given a documented halving exception (review N2).
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
		-h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
	esac
done

die() { echo "error: $*" >&2; exit 1; }

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
rsync -a --exclude '.DS_Store' "$PACK/" "$GAME/" || die "rsync of the pack failed"

# Every step below is status checked, and that is not defensive habit. `pipefail`
# is set, so a step that dies does fail its pipeline — but nothing looked, and
# `set -e` is deliberately off, so the script sailed on. The halving failure in
# particular is invisible by construction: check_assets.py accepts node textures
# at 32px, because that is the other supported install, so a --res=16 run whose
# downscaler died left a 32px tree, printed a green gate and exited 0 (review
# finding M11).
if [ "$RES" = 16 ]; then
	"$ROOT/tools/downscale_pack.py" "$GAME" | tail -1 \
		|| die "the downscale step failed — the tree is still 32x32, not the 16x16 that was asked for"
else
	echo "  node textures left at the authored 32x32"
fi

"$ROOT/tools/strip_png_metadata.py" "$GAME" | tail -1 \
	|| die "the metadata strip failed — the tree still carries the content credentials, ~146 KiB per deploy"

echo "==> verifying"
# The verifier's findings are the whole value of a red verify, and `tail -1` eats
# them, so they are captured and printed in full when it fails. An install that
# leaves the tree non-conforming must not report success.
verify="$("$ROOT/tools/check_assets.py" 2>&1)" || {
	printf '%s\n' "$verify" >&2
	die "the installed tree does not conform — see the findings above"
}
printf '%s\n' "$verify" | tail -1
