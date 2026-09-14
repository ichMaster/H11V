#!/usr/bin/env python3
"""Acceptance gate: the asset pack conforms to specification/ART-COLONY.md.

    tools/check_assets.py                 check the installed game tree
    tools/check_assets.py --pack          check the delivery of record instead
    tools/check_assets.py --verbose       print every file, not only findings

Checks the contract in ART-COLONY.md part two: every ordered file present at its
exact name and size (§6.1-6.5), the three alpha regimes and the animation strip
layout (§5.1), the colour budget and seamless tiling on node faces (§5), the
hotbar's identical cells (§6.3), and the absence of the metadata chunks that
outweigh a 32x32 texture twenty to one.

ART-COLONY.md, not ART.md: the retheme renamed every file (turf -> regolith,
stone -> lithic, crystal -> spire, and the gauntlet became the scanner), the
tables below are the colony names, and ART.md survives only as the record of what
v0 shipped. A docstring pointing at the old brief is how the --pack mode came to
audit the retired pack for a whole release.

One check here is not about art at all: the node ids ARCHITECTURE.md §Components
lists must be the ids nodes.lua registers. It lives in this gate because this gate
already parses the game tree and runs for every issue, and because the two lists
drifted for a whole release with nothing to notice. See check_node_catalogue.

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
# The colony delivery, accepted 14.09.2026 (ART-COLONY.md §11), and the pack
# tools/install_assets.sh installs from. This pointed at the retired v0 pack
# specification/art/h11v/ while the tables below were already colony names, so
# --pack answered with seventeen spurious "missing" findings and the delivery of
# record could not be audited at all (review finding H3).
PACK = ROOT / "specification" / "art" / "colony"

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
    so the gate measures the tree in front of it. h11_fines.png is the reference
    because it is a plain opaque square with no variants.

    A tree where the node textures disagree with each other is a half-finished
    install, and saying so is more useful than validating against either size.

    Returns (scale, pixels), with scale None when the measured size is neither
    sanctioned resolution. Only 32 (authored) and 16 (install_assets.sh --res=16)
    are installs this project ships. Accepting any divisor of the authored size
    instead let a double-halved tree — a downscaler run twice — report "node
    textures 8px" and then validate green against 8px, because every entry in the
    tables was divided by the same 4 (review finding L22).
    """
    tex = base / TEX
    ref = tex / "h11_fines.png"
    if not ref.is_file():
        return 1, None
    try:
        width = Png(ref).width
    except Exception:                                   # noqa: BLE001
        return 1, None
    authored = NODE_TEXTURES["h11_fines.png"][0]
    if width not in (authored, TARGET_NODE_PX):
        return None, width
    return authored // width, width

# name -> (width, height, alpha regime, max colours)
#   "opaque"  every pixel fully opaque
#   "binary"  every pixel either fully transparent or fully opaque
#   "partial" at least one genuinely semi-transparent pixel
#   "any"     not constrained
NODE_TEXTURES = {
    # the planet
    "h11_fines.png": (32, 32, "opaque", 16),
    "h11_regolith_top.png": (32, 32, "opaque", 16),
    "h11_regolith_side.png": (32, 32, "opaque", 16),
    "h11_lithic.png": (32, 32, "opaque", 16),
    "h11_lithic_top.png": (32, 32, "opaque", 16),
    "h11_drift.png": (32, 32, "opaque", 16),
    "h11_spire_top.png": (32, 32, "opaque", 16),
    "h11_spire_side.png": (32, 32, "opaque", 16),
    "h11_crust.png": (32, 32, "opaque", 16),
    "h11_bloom.png": (32, 32, "binary", 16),
    "h11_melt.png": (32, 256, "partial", 16),
    "h11_melt_flowing.png": (32, 512, "partial", 16),
    # the colony
    "h11_hull.png": (32, 32, "opaque", 16),
    "h11_prefab.png": (32, 32, "opaque", 16),
    "h11_crate_top.png": (32, 32, "opaque", 16),
    "h11_crate_side.png": (32, 32, "opaque", 16),
    "h11_beacon.png": (32, 32, "opaque", 16),
}
UI_TEXTURES = {
    "crosshair.png": (32, 32, "binary", 16),
    "h11_scanner.png": (64, 64, "binary", 16),
    "h11_hotbar.png": (512, 64, "partial", 16),
    "h11_hotbar_selected.png": (64, 64, "partial", 16),
}
MENU_IMAGES = {
    "icon.png": (256, 256, "any", 0),
    "header.png": (1024, 256, "any", 0),
    "background.png": (1920, 1080, "any", 0),
}
# Optional: ordered in ART-COLONY.md §6.5, used from v1 onward.
OPTIONAL = {
    f"h11_glyph_{c}.png": (16, 16, "binary", 4) for c in "abcdef"
} | {"h11_crust_2.png": (32, 32, "opaque", 16)}

# Faces that must tile seamlessly with themselves. Side textures are checked
# horizontally only: regolith carries its biofilm fringe in the top rows by
# design, a stacked spire is meant to show its growth bands, and a crate flank
# has a lid edge. The beacon is excluded from tiling entirely — it is a single
# fixture with a lens in the middle, and a centred motif is exactly what a tiling
# check is built to reject.
TILE_BOTH = ["h11_fines.png", "h11_lithic.png", "h11_lithic_top.png", "h11_drift.png",
             "h11_regolith_top.png", "h11_spire_top.png", "h11_crust.png", "h11_crate_top.png"]
TILE_H_ONLY = ["h11_regolith_side.png", "h11_spire_side.png", "h11_crate_side.png",
               "h11_bloom.png"]

# Deliberately not tile-checked, and the reason is the same for all three: they
# are FIXTURES, not surfaces. The seam metric compares an edge against its
# opposite edge, so anything designed with a border fails it by construction —
# which is a statement about the metric, not about the art.
#
# Verified by rendering each one 3x3 rather than by argument: hull lays out as a
# grid of riveted plates with clean joints, prefab as ribbed panelling with a
# conduit stripe down every block, and both look like what they are meant to be.
# The beacon is a single lamp with a lens in the middle; a centred motif is
# exactly what a tiling check exists to reject.
TILE_NONE = ["h11_hull.png", "h11_prefab.png", "h11_beacon.png"]

ANIMATED = {"h11_melt.png": 8, "h11_melt_flowing.png": 16}

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
        self.trns = False
        idat = bytearray()
        i = 8
        while i < len(data):
            (length,) = struct.unpack(">I", data[i:i + 4])
            typ = data[i + 4:i + 8].decode("latin1")
            # Every chunk carries a CRC and checking it costs nothing here (zlib is
            # already imported for the IDAT). Without it a truncated or bit-rotted
            # file decoded to garbage and was then *classified* — colours counted,
            # seams measured, a verdict printed — rather than rejected, which is the
            # one thing a gate must never do with a file it cannot trust.
            body = data[i + 4:i + 8 + length]
            (want_crc,) = struct.unpack(">I", data[i + 8 + length:i + 12 + length])
            if zlib.crc32(body) & 0xFFFFFFFF != want_crc:
                raise ValueError(f"{typ} chunk fails its CRC — the file is corrupt")
            self.chunks.append((typ, length))
            if typ == "IDAT":
                idat += data[i + 8:i + 8 + length]
            elif typ == "tRNS":
                # Colour-key transparency, which this decoder does not apply. Recorded
                # so check_one can refuse to pronounce on an alpha regime it cannot see.
                self.trns = True
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
            # PNG defines filters 0-4. The chain below used to fall through to "no
            # filter" for anything else, so a corrupt row silently decoded as
            # whatever bytes it happened to contain and the file was then classified
            # against the contract. An unknown filter means the data is not a PNG
            # row, and the only honest answer is to refuse the file.
            if ftype > 4:
                raise ValueError(f"row {y} uses filter type {ftype}; PNG defines 0-4")
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
        """The alpha values present. A colour-type-2 file has none, hence {255}.

        That answer is honest about the pixels and useless as a regime verdict: an
        RGB file cannot be distinguished from an RGBA one that happens to be fully
        opaque. check_one therefore rejects colour type 2 outright wherever the
        contract asks for transparency, instead of reasoning about this set — see
        the comment there.
        """
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
        sub.trns = self.trns
        stride = self.width * self.channels
        sub.pixels = self.pixels[top * stride:(top + height) * stride]
        sub.chunks = []
        return sub


def edge_report(img):
    """Mean channel difference across the wrap seam vs. between interior rows.

    A texture that tiles has a wrap difference no worse than its own interior
    variation; a hard seam shows up as a multiple of it.

    KNOWN LIMITATION, deliberately not fixed here (review finding M15, deferred to
    the next art re-delivery): the difference is RGB only, alpha is ignored, and
    both fully transparent pixels and the colour hiding under them count as normal
    image content. On a texture whose transparent area is uniform black — h11_bloom,
    47% clear — the interior average is dominated by hard black-to-lilac steps that
    nobody ever sees, so the interior-scaled threshold inflates (measured: 106.8
    against a real wrap of 5.8) and the check passes whatever the seam does. It is
    near-vacuous for exactly the one binary-alpha surface in TILE_H_ONLY, and sound
    for the opaque node faces, which is every other entry. An alpha-aware metric
    means re-deciding what a seam even is where both sides are transparent, and
    that is a conversation to have with the art, not a patch to slip in under a
    gate repair.
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


ARCHITECTURE = ROOT / "specification" / "ARCHITECTURE.md"
NODES_LUA = GAME / "mods" / "h11_world" / "nodes.lua"

# The two halves ARCHITECTURE.md §Components lists the block catalogue in, and the
# reason the list is parsed rather than copied here: a third copy of the same fact
# is a third thing to drift.
COMPONENT_HALVES = ("grown", "built")


def architecture_node_ids():
    """The node ids ARCHITECTURE.md §Components claims exist.

    Read out of the **grown** and **built** bullets of that section and nowhere
    else. That puts one requirement on the document, and it says so where it lists
    them: inside those two bullets, nothing is in backticks except a node id. The
    bullet is one wrapped paragraph and the match stops at the next bullet or the
    next blank line, which is what keeps the RETIRED alias names in the paragraph
    below it out of the comparison — those are old spellings on purpose.

    Returns (ids, error) with exactly one of the two set.
    """
    try:
        text = ARCHITECTURE.read_text()
    except OSError as exc:                                     # noqa: BLE001
        return None, f"cannot read specification/ARCHITECTURE.md ({exc})"
    section = re.search(r"^## Components$(.*?)^## ", text, re.S | re.M)
    if not section:
        return None, ("specification/ARCHITECTURE.md has no '## Components' section, so the node "
                      "catalogue has nothing to be checked against")
    ids = set()
    for half in COMPONENT_HALVES:
        bullet = re.search(r"\*\*" + half + r"\*\*(.*?)(?=\n[ \t]*\n|\n[ \t]*[-*] |\Z)",
                           section.group(1), re.S)
        if not bullet:
            return None, (f"specification/ARCHITECTURE.md §Components has no '**{half}**' bullet — "
                          "the documented block catalogue cannot be compared with nodes.lua")
        found = set(re.findall(r"`([a-z][a-z0-9_]*)`", bullet.group(1)))
        if not found:
            return None, (f"specification/ARCHITECTURE.md §Components '**{half}**' bullet names no "
                          "node ids in backticks")
        ids |= found
    return ids, None


def registered_node_ids():
    """The ids nodes.lua actually registers: the `id = "..."` rows of NODES.

    The retired-alias table is deliberately not matched — its rows read
    `turf = "regolith"`, not `id = "turf"`. An alias is a courtesy to a world
    generated before the retheme, not a block anything new may be written against.
    """
    try:
        src = NODES_LUA.read_text()
    except OSError as exc:                                     # noqa: BLE001
        return None, f"cannot read {NODES_LUA.relative_to(ROOT)} ({exc})"
    ids = set(re.findall(r'^\s*id = "([a-z0-9_]+)",?\s*$', src, re.M))
    if not ids:
        return None, (f"{NODES_LUA.relative_to(ROOT)} registers no ids this gate can see — the "
                      "NODES row shape changed and this check went blind rather than red")
    return ids, None


def check_node_catalogue(findings, verbose):
    """ARCHITECTURE.md §Components and nodes.lua must name the same blocks.

    Both directions matter and they fail differently. An id in the code and not in
    the document is an undocumented block. An id in the document and not in the
    code is worse: §Components is the list that same document tells a v1
    issue-writer the mutation rules "are rows over", so a phantom id becomes a rule
    that silently matches nothing.

    This exists because the two drifted for a whole release with every gate green —
    the document still described nine nodes under names the colony retheme had
    renamed away (review finding H7). Nothing checked a document against code, so
    nothing could notice. It is ROOT-relative rather than base-relative on purpose:
    the contract is between two committed files, it holds in --pack mode too, and
    choosing a mode must not be a way to skip it.
    """
    doc_ids, err = architecture_node_ids()
    if err:
        findings.append(err)
        return
    code_ids, err = registered_node_ids()
    if err:
        findings.append(err)
        return
    undocumented = sorted(code_ids - doc_ids)
    phantom = sorted(doc_ids - code_ids)
    if undocumented:
        findings.append(
            f"ARCHITECTURE.md §Components does not list {', '.join(undocumented)}: nodes.lua "
            f"registers {len(code_ids)} ids, the document names {len(doc_ids)} — and the document is "
            "what v1's mutation rules get written against")
    if phantom:
        findings.append(
            f"ARCHITECTURE.md §Components lists {', '.join(phantom)}, which nodes.lua does not "
            "register — a mutation rule addressing that id would match no block in the world")
    if verbose and not undocumented and not phantom:
        print(f"  ok  ARCHITECTURE.md §Components and nodes.lua agree on {len(code_ids)} node ids")


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
    # Two conditions: the entry comes from a table passed scalable=True, which is
    # the node textures and not the menu art (the reason the first draft of this
    # check did not try to "halve" the 1920x1080 background), and it was authored
    # wider than the target, which is what leaves the 16x16 glyph overlays alone.
    #
    # Only that second condition is shared with tools/downscale_pack.py. That tool
    # decides node-texture-or-not from its own hard-coded SKIP list of UI filenames,
    # not from these tables, so the exemptions are two lists coupled by hand: a UI
    # texture added to UI_TEXTURES here and not to SKIP there would be silently
    # halved on install and then measured against its full size here. Add UI art to
    # both. (An earlier version of this comment claimed the two tools share the
    # reasoning; they share half of it.)
    if not PACK_MODE and scalable and want_w > TARGET_NODE_PX:
        want_w, want_h = want_w // NODE_SCALE, want_h // NODE_SCALE
    if (img.width, img.height) != (want_w, want_h):
        where = "the authored pack" if PACK_MODE else "the shipped game"
        findings.append(f"{name}: is {img.width}x{img.height}, {where} wants {want_w}x{want_h}")

    # The alpha regimes (ART-COLONY.md §5.1). Two things have to be established
    # before the values can be read at all:
    #
    # A colour-type-2 (RGB) file has no alpha channel, so alphas() can only answer
    # {255} — and {255} is a subset of {0, 255}, which is how a flattened re-export
    # of h11_bloom or crosshair.png used to pass as "binary" with a green gate: the
    # bloom crown would render as solid cubes and the crosshair as an opaque black
    # tile over the view. Reproduced with a synthetic file (review finding M16, and
    # the fix is verified against one). So a regime that asks for transparency
    # demands a real alpha channel, and "binary" demands both values actually
    # present: an entirely opaque texture is not a binary-alpha one, it is opaque.
    #
    # A tRNS chunk is colour-key transparency this decoder does not apply, so the
    # alphas above are not what the engine will draw. Rather than half-support it,
    # the gate says it cannot tell.
    alphas = img.alphas()
    if img.trns and regime != "any":
        findings.append(f"{name}: carries a tRNS colour-key chunk, whose transparency this gate does "
                        f"not decode, so the ordered {regime} regime cannot be verified — re-export "
                        "with a real alpha channel")
    elif regime in ("binary", "partial") and img.channels == 3:
        findings.append(f"{name}: is PNG colour type 2 (RGB, no alpha channel) but {regime} alpha is "
                        "ordered — a flattened export would render fully opaque")
    elif regime == "opaque" and alphas != {255}:
        findings.append(f"{name}: must be fully opaque, has alpha values {sorted(alphas)[:4]}…")
    elif regime == "binary" and alphas != {0, 255}:
        mids = sorted(a for a in alphas if 0 < a < 255)
        if mids:
            findings.append(f"{name}: must use binary alpha (0 or 255), has {len(mids)} midtones e.g. {mids[:4]}")
        else:
            findings.append(f"{name}: must use binary alpha, but only {sorted(alphas)} occurs — "
                            "a binary-alpha texture has both transparent and opaque pixels")
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
                    help="check specification/art/colony (the delivery of record) instead of the game")
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
        if NODE_SCALE is None:
            # An unsanctioned size is a finding in itself, and the only one with an
            # explanation. The size checks below then run against the authored table,
            # so every mis-scaled texture is also listed: that is the tree's real
            # state, and this finding says why the whole list looks that way.
            findings.append(
                f"node textures are {node_px}px — this project ships 32 (the authored size) or "
                f"{TARGET_NODE_PX} (tools/install_assets.sh --res={TARGET_NODE_PX}), nothing else; "
                "re-install the pack rather than trusting the sizes below")
            NODE_SCALE = 1

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
            findings.append(f"{name}: {img.height // img.width} frames, ART-COLONY.md §5.1 orders {want_frames}")

    # Every texture the Lua actually names must exist. ART-COLONY.md's contract says
    # what the pack must contain; this says the code and the pack agree on spelling —
    # the half that a delivery audit cannot see. A mistyped name in a NODES row is
    # not an engine error: it is an unknown-texture placeholder, which looks like
    # an art problem and is a typo.
    #
    # Names are matched anywhere inside a string literal, not as the whole literal.
    # Engine texture strings are a modifier language: the overlay form v1 uses for
    # the mutation stencils is one PNG name, a caret, then another, and there are
    # [combine: and [colorize: forms as well. A pattern anchored to the closing
    # quote saw none of them — so the one composite that matters most, the glyph
    # overlay on a mutated block, was the one this check could not see.
    #
    # Literals rather than the whole file, so a name in a comment or in a
    # deliberately commented-out row is not reported as a missing texture.
    lua_dir = base / "mods" / "h11_world"
    tex_dir = base / TEX
    if lua_dir.is_dir() and tex_dir.is_dir():
        named = set()
        for lua in sorted(lua_dir.glob("*.lua")):
            src = lua.read_text()
            for literal in re.findall(r'"([^"\n]*)"', src) + re.findall(r"'([^'\n]*)'", src):
                named |= set(re.findall(r'h11_[a-z0-9_]+\.png', literal))
        have = {f.name for f in tex_dir.glob("*.png")}
        for name in sorted(named - have):
            findings.append(f"{name}: named in h11_world Lua but not installed in {TEX}/")
        if args.verbose:
            print(f"  ok  {len(named)} texture reference(s) in Lua all resolve")

    # And the other half of the same idea: the code and the ARCHITECTURE must agree
    # on which blocks exist, not only the code and the pack on which files exist.
    check_node_catalogue(findings, args.verbose)

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
                                "the 6-slot crop would not be lossless (ART-COLONY.md §6.3)")
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
