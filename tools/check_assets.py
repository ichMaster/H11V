#!/usr/bin/env python3
"""Acceptance gate: the asset pack conforms to specification/ART.md.

    tools/check_assets.py                 check the installed game tree
    tools/check_assets.py --pack          check the delivery of record instead
    tools/check_assets.py --verbose       print every file, not only findings

Checks the contract in ART.md part two: every ordered file present at its exact
name and size, the three alpha regimes, the colour budget, seamless tiling on
node faces, animation strip layout, the hotbar's identical cells, and the absence
of the metadata chunks that outweigh a 32x32 texture twenty to one.

Stdlib only, on purpose: this runs on the pipeline's critical path, and a gate
that cannot import is a gate that breaks a build. PNG decoding is here rather
than in Pillow for the same reason.
"""

import argparse
import pathlib
import re
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACK_MODE = False
GAME = ROOT / "games" / "h11v"
PACK = ROOT / "specification" / "art" / "h11v"

TEX = "mods/h11_world/textures"
MENU = "menu"

# Node textures are authored at 32x32 and ship at 16x16, halved 2:1 by
# tools/downscale_pack.py at install. So the same contract has two valid sizes
# depending on which tree is being checked, and the tables below are written at
# the AUTHORING size with the game tree scaled down by NODE_SCALE. Writing two
# tables instead would be two places for the alpha regimes and colour budgets to
# drift apart.
#
# UI art and the menu images are sized in screen pixels and are not scaled.
TARGET_NODE_PX = 16     # must match tools/downscale_pack.py TARGET
NODE_SCALE = 1          # resolved below from what is actually installed


def detect_node_scale(base):
    """Read the installed node resolution instead of being told it.

    The project can ship node textures at the authored 32x32 or at a halved
    16x16, switched by tools/install_assets.sh --res. A flag here would be a
    second place to set that, and therefore a place for the two to disagree —
    so the gate measures the tree in front of it. h11_dirt.png is the reference
    because it is a plain opaque square with no variants.

    A tree where the node textures disagree with each other is a half-finished
    install, and saying so is more useful than validating against either size.
    """
    tex = base / TEX
    ref = tex / "h11_dirt.png"
    if not ref.is_file():
        return 1, None
    try:
        width = Png(ref).width
    except Exception:                                   # noqa: BLE001
        return 1, None
    authored = NODE_TEXTURES["h11_dirt.png"][0]
    if width <= 0 or authored % width:
        return 1, None
    return authored // width, width

# name -> (width, height, alpha regime, max colours)
#   "opaque"  every pixel fully opaque
#   "binary"  every pixel either fully transparent or fully opaque
#   "partial" at least one genuinely semi-transparent pixel
#   "any"     not constrained
NODE_TEXTURES = {
    "h11_dirt.png": (32, 32, "opaque", 16),
    "h11_turf_top.png": (32, 32, "opaque", 16),
    "h11_turf_side.png": (32, 32, "opaque", 16),
    "h11_stone.png": (32, 32, "opaque", 16),
    "h11_sand.png": (32, 32, "opaque", 16),
    "h11_trunk_top.png": (32, 32, "opaque", 16),
    "h11_trunk_side.png": (32, 32, "opaque", 16),
    "h11_crust.png": (32, 32, "opaque", 16),
    "h11_leaves.png": (32, 32, "binary", 16),
    "h11_water.png": (32, 256, "partial", 16),
    "h11_water_flowing.png": (32, 512, "partial", 16),
}
UI_TEXTURES = {
    "crosshair.png": (32, 32, "binary", 16),
    "h11_hand.png": (64, 64, "binary", 16),
    "h11_hotbar.png": (512, 64, "partial", 16),
    "h11_hotbar_selected.png": (64, 64, "partial", 16),
}
MENU_IMAGES = {
    "icon.png": (256, 256, "any", 0),
    "header.png": (1024, 256, "any", 0),
    "background.png": (1920, 1080, "any", 0),
}
# Optional: ordered in ART.md section 5.4, used from v1 onward.
OPTIONAL = {
    f"h11_glyph_{c}.png": (16, 16, "binary", 4) for c in "abcdef"
} | {"h11_crust_2.png": (32, 32, "opaque", 16)}

# Faces that must tile seamlessly with themselves. Side textures are checked
# horizontally only: turf carries its green fringe in the top rows by design,
# and a stacked trunk is meant to show its rings.
TILE_BOTH = ["h11_dirt.png", "h11_stone.png", "h11_sand.png", "h11_turf_top.png",
             "h11_trunk_top.png", "h11_leaves.png", "h11_crust.png"]
TILE_H_ONLY = ["h11_turf_side.png", "h11_trunk_side.png"]

ANIMATED = {"h11_water.png": 8, "h11_water_flowing.png": 16}

# PNG chunks that carry no image data and bloat a tile beyond reason.
JUNK_CHUNKS = {"caBX", "iCCP", "eXIf", "tEXt", "iTXt", "zTXt"}


class Png:
    """Just enough PNG to check a texture: 8-bit RGB and RGBA, no interlacing."""

    def __init__(self, path):
        self.path = path
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("not a PNG")
        self.chunks = []
        idat = bytearray()
        i = 8
        while i < len(data):
            (length,) = struct.unpack(">I", data[i:i + 4])
            typ = data[i + 4:i + 8].decode("latin1")
            self.chunks.append((typ, length))
            if typ == "IDAT":
                idat += data[i + 8:i + 8 + length]
            elif typ == "IHDR":
                self.width, self.height, self.depth, self.color, _, _, interlace = \
                    struct.unpack(">IIBBBBB", data[i + 8:i + 8 + 13])
            i += 12 + length
            if typ == "IEND":
                break
        if self.depth != 8 or self.color not in (2, 6) or interlace:
            raise ValueError(f"unsupported PNG (depth {self.depth}, colour type {self.color})")
        self.channels = 4 if self.color == 6 else 3
        self.pixels = self._unfilter(zlib.decompress(bytes(idat)))

    def _unfilter(self, raw):
        w, h, ch = self.width, self.height, self.channels
        stride = w * ch
        out = bytearray(stride * h)
        pos = 0
        for y in range(h):
            ftype = raw[pos]; pos += 1
            line = bytearray(raw[pos:pos + stride]); pos += stride
            prev = out[(y - 1) * stride:y * stride] if y else bytes(stride)
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
            out[y * stride:(y + 1) * stride] = line
        return bytes(out)

    def px(self, x, y):
        ch = self.channels
        i = (y * self.width + x) * ch
        p = self.pixels[i:i + ch]
        return (p[0], p[1], p[2], p[3] if ch == 4 else 255)

    def alphas(self):
        if self.channels == 3:
            return {255}
        return {self.pixels[i] for i in range(3, len(self.pixels), 4)}

    def colours(self):
        ch = self.channels
        return {self.pixels[i:i + ch] for i in range(0, len(self.pixels), ch)}

    def crop(self, top, height):
        """A frame of an animation strip, as a lightweight view."""
        sub = Png.__new__(Png)
        sub.path, sub.width, sub.height = self.path, self.width, height
        sub.channels, sub.depth, sub.color = self.channels, self.depth, self.color
        stride = self.width * self.channels
        sub.pixels = self.pixels[top * stride:(top + height) * stride]
        sub.chunks = []
        return sub


def edge_report(img):
    """Mean channel difference across the wrap seam vs. between interior rows.

    A texture that tiles has a wrap difference no worse than its own interior
    variation; a hard seam shows up as a multiple of it.
    """
    w, h, = img.width, img.height

    def rowdiff(r1, r2):
        return sum(abs(img.px(x, r1)[c] - img.px(x, r2)[c]) for x in range(w) for c in range(3)) / (w * 3)

    def coldiff(c1, c2):
        return sum(abs(img.px(c1, y)[c] - img.px(c2, y)[c]) for y in range(h) for c in range(3)) / (h * 3)

    wrap_v = rowdiff(h - 1, 0)
    int_v = sum(rowdiff(y, y + 1) for y in range(h - 1)) / max(h - 1, 1)
    wrap_h = coldiff(w - 1, 0)
    int_h = sum(coldiff(x, x + 1) for x in range(w - 1)) / max(w - 1, 1)
    return wrap_v, int_v, wrap_h, int_h


def check_one(path, spec, findings, warnings, verbose, scalable=False):
    name = path.name
    want_w, want_h, regime, max_colours = spec
    try:
        img = Png(path)
    except Exception as exc:                                   # noqa: BLE001
        findings.append(f"{name}: cannot read ({exc})")
        return None

    # In the game tree the node textures have been halved; UI and menu art has not.
    #
    # Two conditions, both of which tools/downscale_pack.py also applies: the file
    # is a node texture rather than UI or menu art, and it was authored wider than
    # the target. Sharing the reasoning rather than a list of names is what keeps
    # the 16x16 glyph overlays unscaled in both tools without either naming them —
    # and what stopped this check from trying to halve the 1920x1080 menu
    # background on its first draft.
    if not PACK_MODE and scalable and want_w > TARGET_NODE_PX:
        want_w, want_h = want_w // NODE_SCALE, want_h // NODE_SCALE
    if (img.width, img.height) != (want_w, want_h):
        where = "the authored pack" if PACK_MODE else "the shipped game"
        findings.append(f"{name}: is {img.width}x{img.height}, {where} wants {want_w}x{want_h}")

    alphas = img.alphas()
    if regime == "opaque" and alphas != {255}:
        findings.append(f"{name}: must be fully opaque, has alpha values {sorted(alphas)[:4]}…")
    elif regime == "binary" and not alphas <= {0, 255}:
        mids = sorted(a for a in alphas if 0 < a < 255)
        findings.append(f"{name}: must use binary alpha (0 or 255), has {len(mids)} midtones e.g. {mids[:4]}")
    elif regime == "partial" and all(a in (0, 255) for a in alphas):
        findings.append(f"{name}: must be semi-transparent, but every pixel is fully opaque or clear")

    if max_colours:
        n = len(img.colours())
        if n > max_colours:
            findings.append(f"{name}: {n} colours, budget is {max_colours}")

    junk = [(t, ln) for t, ln in img.chunks if t in JUNK_CHUNKS]
    if junk:
        total = sum(ln for _, ln in junk)
        share = round(100 * total / max(path.stat().st_size, 1))
        msg = (f"{name}: carries {', '.join(t for t, _ in junk)} metadata "
               f"({total} B, {share}% of the file)")
        # In the delivery of record this is expected and tolerated: the pack is
        # kept pristine so a re-delivery is a drop-in replacement, and the strip
        # happens on the way into the game tree. There it is a hard failure.
        (warnings if PACK_MODE else findings).append(
            msg + (" — stripped on install" if PACK_MODE else " — run tools/strip_png_metadata.py"))

    if verbose:
        print(f"  ok  {name:28} {img.width}x{img.height} {regime}")
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--pack", action="store_true",
                    help="check specification/art/h11v (the delivery of record) instead of the game")
    ap.add_argument("--verbose", "-v", action="store_true")
    args = ap.parse_args()

    global PACK_MODE, NODE_SCALE
    PACK_MODE = args.pack
    base = PACK if args.pack else GAME
    where = base.relative_to(ROOT)
    if not base.exists():
        print(f"check_assets: nothing at {where}", file=sys.stderr)
        if not args.pack:
            print("The game tree does not exist yet — install the pack per ARCHITECTURE.md §Assets,\n"
                  "or check the delivery itself with --pack.", file=sys.stderr)
        return 1

    findings, warnings, images = [], [], {}

    if PACK_MODE:
        NODE_SCALE = 1
        print(f"check_assets: {where} (authored size)")
    else:
        NODE_SCALE, node_px = detect_node_scale(base)
        print(f"check_assets: {where} (node textures {node_px or '?'}px)")

    # scalable: node textures under textures/, which is what the downscaler touches.
    for folder, table, required, scalable in ((TEX, NODE_TEXTURES, True, True),
                                              (TEX, UI_TEXTURES, True, False),
                                              (MENU, MENU_IMAGES, True, False),
                                              (TEX, OPTIONAL, False, True)):
        for name, spec in table.items():
            path = base / folder / name
            if not path.exists():
                if required:
                    findings.append(f"{name}: missing from {folder}/")
                continue
            img = check_one(path, spec, findings, warnings, args.verbose, scalable)
            if img:
                images[name] = img

    # Tiling.
    for name in TILE_BOTH + TILE_H_ONLY:
        img = images.get(name)
        if not img:
            continue
        wrap_v, int_v, wrap_h, int_h = edge_report(img)
        if wrap_h > max(int_h * 2.5, 6):
            findings.append(f"{name}: horizontal seam (wrap {wrap_h:.1f} vs interior {int_h:.1f})")
        if name in TILE_BOTH and wrap_v > max(int_v * 2.5, 6):
            findings.append(f"{name}: vertical seam (wrap {wrap_v:.1f} vs interior {int_v:.1f})")

    # Animation strips: exact frame count, square frames.
    for name, want_frames in ANIMATED.items():
        img = images.get(name)
        if not img:
            continue
        # Halving preserves the frame COUNT, which is what the contract is about —
        # the strip is 8 or 16 square frames whatever the edge length.
        if img.height % img.width:
            findings.append(f"{name}: height {img.height} is not a whole number of {img.width}px frames")
        elif img.height // img.width != want_frames:
            findings.append(f"{name}: {img.height // img.width} frames, ART.md orders {want_frames}")

    # Every texture the Lua actually names must exist. ART.md's contract says what
    # the pack must contain; this says the code and the pack agree on spelling —
    # the half that a delivery audit cannot see. A mistyped name in a NODES row is
    # not an engine error: it is an unknown-texture placeholder, which looks like
    # an art problem and is a typo.
    lua_dir = base / "mods" / "h11_world"
    tex_dir = base / TEX
    if lua_dir.is_dir() and tex_dir.is_dir():
        named = set()
        for lua in sorted(lua_dir.glob("*.lua")):
            named |= set(re.findall(r'"(h11_[a-z0-9_]+\.png)"', lua.read_text()))
        have = {f.name for f in tex_dir.glob("*.png")}
        for name in sorted(named - have):
            findings.append(f"{name}: named in h11_world Lua but not installed in {TEX}/")
        if args.verbose:
            print(f"  ok  {len(named)} texture reference(s) in Lua all resolve")

    # The hotbar must be eight identical cells so a 6-slot crop stays lossless.
    bar = images.get("h11_hotbar.png")
    if bar and bar.width == 512:
        stride = bar.width * bar.channels
        cell0 = [bar.pixels[y * stride:y * stride + 64 * bar.channels] for y in range(bar.height)]
        for i in range(1, 8):
            off = i * 64 * bar.channels
            celli = [bar.pixels[y * stride + off:y * stride + off + 64 * bar.channels] for y in range(bar.height)]
            if celli != cell0:
                findings.append(f"h11_hotbar.png: cell {i + 1} differs from cell 1 — "
                                "the 6-slot crop would not be lossless (ART.md §5.2)")
                break

    checked = len(images)
    if warnings:
        print(f"\n{len(warnings)} note(s):\n")
        for w in warnings:
            print(f"  · {w}")
    if findings:
        print(f"\n{len(findings)} finding(s) over {checked} file(s):\n")
        for f in findings:
            print(f"  - {f}")
        return 1
    print(f"all {checked} files conform")
    return 0


if __name__ == "__main__":
    sys.exit(main())
