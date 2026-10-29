#!/usr/bin/env python3
"""Make the placeholder app icon for each recipe template.

Each recipe template gets one 1024 x 1024 PNG in its AppIcon set, the single
size Xcode needs to make every other one:
https://developer.apple.com/documentation/xcode/configuring-your-app-icon

The icons are placeholders: a white shape on a colour per recipe, no text, no
alpha channel (RGB only). An app made from a recipe builds with an icon, and
its README says to replace it before shipping.

The drawing is plain Python (zlib for the PNG), so the same pixels come out on
any machine. --check compares the pixels of the committed icons with what this
script draws, so a hand-edited or missing icon fails.

Usage:
  python3 scripts/make-recipe-icons.py           # write every recipe's icon
  python3 scripts/make-recipe-icons.py --check   # exit 1 if any differs

Exit codes: 0 ok, 1 an icon is missing or differs (--check).
"""

import argparse
import math
import os
import struct
import sys
import zlib

SIZE = 1024
SUB = 4  # sub-scanlines per pixel row, for smooth edges
WHITE = (255, 255, 255)
ICON_PATH = "template/__APP_NAME__/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RECIPES = os.path.join(REPO, "plugins", "duology-recipes", "skills")


# Shapes are polygons (lists of (x, y) points), filled with the even-odd rule.

def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def circle(cx, cy, r, steps=180):
    return [(cx + r * math.cos(2 * math.pi * i / steps), cy + r * math.sin(2 * math.pi * i / steps))
            for i in range(steps)]


def star(cx, cy, outer, inner, points=5):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + math.pi * i / points
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# One colour and one or more shapes per recipe. Each entry is a layer:
# (shapes filled together with the even-odd rule, colour).
DESIGNS = {
    # Two players, one per half of the open phone.
    "recipe-two-player-game": ((229, 83, 61), [([circle(330, 512, 140)], WHITE),
                                               ([circle(694, 512, 140)], WHITE)]),
    # Three bars of a chart.
    "recipe-finance-dashboard": ((31, 138, 91), [([rect(292, 540, 412, 760)], WHITE),
                                                 ([rect(452, 420, 572, 760)], WHITE),
                                                 ([rect(612, 300, 732, 760)], WHITE)]),
    # A play button.
    "recipe-media-player": ((107, 75, 216), [([[(400, 300), (400, 724), (740, 512)]], WHITE)]),
    # Two facing pages.
    "recipe-reader": ((181, 101, 29), [([rect(272, 300, 500, 724)], WHITE),
                                       ([rect(524, 300, 752, 724)], WHITE)]),
    # A bag with a handle: a ring, then the bag over its lower half.
    "recipe-shop": ((43, 108, 176), [([circle(512, 400, 110), circle(512, 400, 70)], WHITE),
                                     ([rect(312, 400, 712, 760)], WHITE)]),
    # A star.
    "recipe-kids-learning": ((217, 119, 6), [([star(512, 530, 300, 125)], WHITE)]),
    # A page with three lines of text, and a four-point spark beside it.
    "recipe-notes-ai": ((13, 128, 128), [([rect(262, 300, 622, 780)], WHITE),
                                         ([rect(322, 420, 562, 450), rect(322, 510, 562, 540),
                                           rect(322, 600, 482, 630)], (13, 128, 128)),
                                         ([star(742, 330, 130, 34, points=4)], WHITE)]),
}


def coverage(shapes):
    """Fraction of each pixel the shapes cover, row by row, as a list of float rows."""
    edges = []
    for poly in shapes:
        for i, (x0, y0) in enumerate(poly):
            x1, y1 = poly[(i + 1) % len(poly)]
            if y0 != y1:
                edges.append((x0, y0, x1, y1))
    rows = []
    for py in range(SIZE):
        row = [0.0] * SIZE
        for s in range(SUB):
            y = py + (s + 0.5) / SUB
            xs = sorted(x0 + (y - y0) * (x1 - x0) / (y1 - y0)
                        for x0, y0, x1, y1 in edges if (y0 <= y < y1) or (y1 <= y < y0))
            for a, b in zip(xs[0::2], xs[1::2]):
                a, b = max(a, 0.0), min(b, float(SIZE))
                if b <= a:
                    continue
                first, last = int(a), min(int(b), SIZE - 1)
                for px in range(first, last + 1):
                    row[px] += (min(b, px + 1) - max(a, px)) / SUB
        rows.append(row)
    return rows


def draw(design):
    """RGB rows (bytes, three per pixel) for one design."""
    background, layers = design
    pixels = [[list(background) for _ in range(SIZE)] for _ in range(SIZE)]
    for shapes, colour in layers:
        for py, row in enumerate(coverage(shapes)):
            line = pixels[py]
            for px, c in enumerate(row):
                if c > 0:
                    c = min(c, 1.0)
                    p = line[px]
                    for k in range(3):
                        p[k] = p[k] * (1 - c) + colour[k] * c
    return [bytes(int(round(v)) for p in line for v in p) for line in pixels]


def png(rows):
    """A PNG file: 8-bit RGB (colour type 2), no alpha, no filter."""
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    raw = b"".join(b"\x00" + r for r in rows)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def read_png(path):
    """(width, height, colour type, RGB rows) of a PNG written by png(), or of any unfiltered one."""
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, header = 8, b"", None
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR" and len(body) == 13:
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    if header is None or not idat:
        raise ValueError("no IHDR or IDAT chunk")
    width, height, depth, ctype = header[0], header[1], header[2], header[3]
    raw = zlib.decompress(idat)
    stride = 1 + width * (3 if ctype == 2 else 4)
    rows = []
    for y in range(height):
        line = raw[y * stride:(y + 1) * stride]
        if line[0] != 0:
            raise ValueError("row %d uses PNG filter %d, so it wasn't written by this script; run it to rewrite"
                             % (y, line[0]))
        rows.append(line[1:])
    return width, height, depth, ctype, rows


def main(argv=None):
    parser = argparse.ArgumentParser(description="Make or check the recipe templates' placeholder app icons.")
    parser.add_argument("--check", action="store_true", help="compare the committed icons; write nothing")
    args = parser.parse_args(argv)
    failed = False
    for recipe in sorted(DESIGNS):
        path = os.path.join(RECIPES, recipe, ICON_PATH)
        rows = draw(DESIGNS[recipe])
        rel = os.path.relpath(path, REPO)
        if args.check:
            try:
                width, height, depth, ctype, found = read_png(path)
            except (OSError, ValueError, zlib.error, struct.error) as exc:
                print("%s: can't read it (%s)" % (rel, exc))
                failed = True
                continue
            if (width, height, depth, ctype) != (SIZE, SIZE, 8, 2) or found != rows:
                print("%s: differs from what make-recipe-icons.py draws; run it to rewrite" % rel)
                failed = True
            else:
                print("%s: ok" % rel)
        else:
            with open(path, "wb") as fh:
                fh.write(png(rows))
            print("wrote %s" % rel)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
