#!/usr/bin/env python3
"""ctos-pick - inspect the exact colours in a shell render.

The notch is drawn with a three-stop gradient border over a translucent navy
surface, and a screenshot is the only way to confirm those are the values the
design specifies. This prints the dominant colours and, optionally, samples a
specific pixel, so "is that border actually #EB4ADF" is a checkable question
rather than an impression.

Usage:
    ctos-pick FILE.png [--top N] [--crop X,Y,W,H] [--at X,Y]
"""
import argparse
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    sys.exit("ctos-pick: Pillow is required (python3Packages.pillow)")


def hexof(rgb):
    return "#{:02X}{:02X}{:02X}".format(*rgb[:3])


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("image")
    ap.add_argument("--top", type=int, default=12, help="how many colours to list")
    ap.add_argument("--crop", help="X,Y,W,H to restrict analysis to")
    ap.add_argument("--at", help="X,Y to sample a single pixel")
    args = ap.parse_args()

    img = Image.open(args.image).convert("RGB")

    if args.at:
        x, y = (int(v) for v in args.at.split(","))
        r, g, b = img.getpixel((x, y))
        print(f"{args.at}  {hexof((r, g, b))}  rgb({r},{g},{b})")
        return

    if args.crop:
        x, y, w, h = (int(v) for v in args.crop.split(","))
        img = img.crop((x, y, x + w, y + h))

    # getcolors rather than getdata(): the latter is deprecated in Pillow 12.
    raw = img.getcolors(maxcolors=1 << 24) or []
    counts = Counter()
    for n, rgb in raw:
        counts[rgb] += n
    total = sum(counts.values())

    print(f"{args.image}  {img.width}x{img.height}  {len(counts)} distinct colours")
    print()
    print(f"{'colour':<10} {'share':>8}  {'px':>9}")
    for rgb, n in counts.most_common(args.top):
        share = (n / total) * 100.0
        print(f"{hexof(rgb):<10} {share:>7.2f}%  {n:>9}")

    # A render that is mostly one flat colour means a surface failed to appear.
    top_share = (counts.most_common(1)[0][1] / total) * 100.0 if total else 0.0
    if top_share > 92.0:
        print()
        print(
            f"WARNING: one colour covers {top_share:.1f}% of the frame. "
            "That usually means no shell surface was captured."
        )


if __name__ == "__main__":
    main()
