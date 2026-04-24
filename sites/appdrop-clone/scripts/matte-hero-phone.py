#!/usr/bin/env python3
"""Turn letterboxed black (or near-black) margins into transparency for hero phone PNGs."""
from __future__ import annotations

import argparse
import sys
from collections import deque

from PIL import Image


def matte_black_edges(im: Image.Image, threshold: int = 48) -> Image.Image:
    w, h = im.size
    px = im.load()
    visited = bytearray(w * h)

    def idx(x: int, y: int) -> int:
        return y * w + x

    def is_dark(x: int, y: int) -> bool:
        r, g, b, _a = px[x, y]
        return max(r, g, b) < threshold

    q: deque[tuple[int, int]] = deque()
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if is_dark(x, y):
            i = idx(x, y)
            if not visited[i]:
                visited[i] = 1
                q.append((x, y))

    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = idx(nx, ny)
                if not visited[j] and is_dark(nx, ny):
                    visited[j] = 1
                    q.append((nx, ny))

    return im


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("input_path")
    p.add_argument("output_path")
    p.add_argument("--threshold", type=int, default=48)
    args = p.parse_args()
    im = Image.open(args.input_path).convert("RGBA")
    matte_black_edges(im, threshold=args.threshold)
    im.save(args.output_path, "PNG", optimize=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
