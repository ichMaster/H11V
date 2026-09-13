#!/usr/bin/env python3
"""Halve the node textures of an installed asset pack, 2:1, nearest-neighbour.

    tools/downscale_pack.py games/h11v          halve in place
    tools/downscale_pack.py --dry-run <path>    report what would change

The art is authored at 32x32 and ships at 16x16. That is deliberate rather than a
compromise: the delivered pack is drawn in roughly 2-pixel clusters, so taking
every other pixel reproduces the artist's intent exactly instead of approximating
it — verified by eye before this tool was written, and the H11 glyph on the crust
block is arguably crisper at 16 than at 32. Keeping the 32x32 set as the master
means an HD pack costs nothing later, and a re-delivery does not have to be
redrawn at a second size.

**Node textures only.** UI art (the hotbar, its selection frame, the crosshair)
and the first-person hand are sized in screen pixels or extruded into a mesh;
halving them would shrink them on the panel or coarsen the extrusion, neither of
which is what "16x16 textures" means. The glyph overlays are already 16.

Nearest-neighbour, never averaging: an averaged pixel is a colour the palette does
not contain, which on art held to ~16 colours is how a clean tile turns to mud.

Stdlib only, like the rest of the toolchain — see tools/check_assets.py.
"""

import argparse
import pathlib
import struct
import sys
import zlib

# UI art is sized in screen pixels, or extruded into a mesh; halving it shrinks it
# on the panel or coarsens the extrusion, neither of which is what "16x16
# textures" means.
SKIP = {
    "crosshair.png", "h11_hand.png", "h11_hotbar.png", "h11_hotbar_selected.png",
}

# Nothing is taken below the target resolution. Named by size rather than by file,
# because a name list silently stops protecting the moment a file is added — as
# happened on the first run here, which quietly took the 16x16 glyph overlays down
# to 8x8.
TARGET = 16


def read_png(path):
    """Return (width, height, channels, rows) for an 8-bit RGB/RGBA PNG."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    idat = bytearray()
    i = 8
    width = height = depth = color = None
    while i < len(data):
        (length,) = struct.unpack(">I", data[i:i + 4])
        typ = data[i + 4:i + 8].decode("latin1")
        if typ == "IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(
                ">IIBBBBB", data[i + 8:i + 8 + 13])
            if depth != 8 or color not in (2, 6) or interlace:
                raise ValueError(f"unsupported PNG (depth {depth}, colour {color})")
        elif typ == "IDAT":
            idat += data[i + 8:i + 8 + length]
        i += 12 + length
        if typ == "IEND":
            break

    ch = 4 if color == 6 else 3
    raw = zlib.decompress(bytes(idat))
    stride = width * ch
    rows, prev, pos = [], bytes(stride), 0
    for _ in range(height):
        ftype = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        for x in range(stride):
            a = line[x - ch] if x >= ch else 0
            b = prev[x]
            if ftype == 1:
                line[x] = (line[x] + a) & 0xFF
            elif ftype == 2:
                line[x] = (line[x] + b) & 0xFF
            elif ftype == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 0xFF
            elif ftype == 4:
                c = prev[x - ch] if x >= ch else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 0xFF
        rows.append(bytes(line))
        prev = line
    return width, height, ch, rows


def write_png(path, width, height, ch, rows):
    """Write an 8-bit RGB/RGBA PNG with no ancillary chunks at all."""
    raw = b"".join(b"\x00" + r for r in rows)          # filter type 0 per row
    def chunk(typ, payload):
        body = typ.encode("latin1") + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6 if ch == 4 else 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk("IHDR", ihdr)
        + chunk("IDAT", zlib.compress(raw, 9))
        + chunk("IEND", b"")
    )


def halve(path, dry_run):
    width, height, ch, rows = read_png(path)
    if width % 2 or height % 2:
        return None                                    # not halvable; leave alone
    if width <= TARGET:
        return None                                    # already at or below target
    new_rows = []
    for y in range(0, height, 2):
        src = rows[y]
        # Take every other pixel — the top-left of each 2x2 block. Never average.
        new_rows.append(b"".join(src[x * ch:(x + 1) * ch] for x in range(0, width, 2)))
    if not dry_run:
        write_png(path, width // 2, height // 2, ch, new_rows)
    return (width, height, width // 2, height // 2)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", type=pathlib.Path)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    tex = args.root / "mods" / "h11_world" / "textures"
    if not tex.is_dir():
        print(f"downscale_pack: no textures at {tex}", file=sys.stderr)
        return 1

    done = 0
    for f in sorted(tex.glob("*.png")):
        if f.name in SKIP:
            continue
        try:
            result = halve(f, args.dry_run)
        except Exception as exc:                        # noqa: BLE001
            print(f"  skip {f.name}: {exc}", file=sys.stderr)
            continue
        if result:
            w, h, nw, nh = result
            verb = "would halve" if args.dry_run else "halved"
            print(f"  {verb} {f.name:26} {w}x{h} -> {nw}x{nh}")
            done += 1
    print(f"{done} texture(s) {'would be ' if args.dry_run else ''}halved; "
          f"{len(SKIP)} UI file(s) left at their screen size")
    return 0


if __name__ == "__main__":
    sys.exit(main())
