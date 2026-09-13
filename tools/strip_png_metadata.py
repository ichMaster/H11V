#!/usr/bin/env python3
"""Strip non-image chunks from PNGs, in place.

    tools/strip_png_metadata.py games/h11v          strip a tree
    tools/strip_png_metadata.py --dry-run <path>    report what would go

Content credentials (caBX), colour profiles, EXIF and text chunks are ancillary:
a PNG decoder must skip them, so the engine never notices. On a 32x32 texture
one of them can be 95% of the file, and the whole pack crosses the network to
the device on every deploy. Run this after installing the asset pack.

Stdlib only — see tools/check_assets.py for why.
"""

import argparse
import pathlib
import struct
import sys

DROP = {"caBX", "iCCP", "eXIf", "tEXt", "iTXt", "zTXt", "tIME", "pHYs"}
MAGIC = b"\x89PNG\r\n\x1a\n"


def strip(path, dry_run):
    data = path.read_bytes()
    if data[:8] != MAGIC:
        return 0
    out = bytearray(MAGIC)
    removed = 0
    i = 8
    while i < len(data):
        (length,) = struct.unpack(">I", data[i:i + 4])
        typ = data[i + 4:i + 8].decode("latin1")
        chunk = data[i:i + 12 + length]
        if typ in DROP:
            removed += len(chunk)
        else:
            out += chunk
        i += 12 + length
        if typ == "IEND":
            break
    if removed and not dry_run:
        path.write_bytes(bytes(out))
    return removed


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("paths", nargs="+", type=pathlib.Path)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    files = []
    for p in args.paths:
        files += sorted(p.rglob("*.png")) if p.is_dir() else ([p] if p.suffix == ".png" else [])
    if not files:
        print("no PNGs found", file=sys.stderr)
        return 1

    total, touched = 0, 0
    for f in files:
        n = strip(f, args.dry_run)
        if n:
            touched += 1
            total += n
            print(f"  {'would strip' if args.dry_run else 'stripped'} {n:6} B  {f}")
    verb = "would free" if args.dry_run else "freed"
    print(f"{touched}/{len(files)} file(s), {verb} {total / 1024:.1f} KiB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
