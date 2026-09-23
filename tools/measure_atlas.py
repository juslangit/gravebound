#!/usr/bin/env python3
"""Measure connected sprite silhouettes; never alter the original painted PNGs.

AI sprite sheets do not reliably follow their requested cell grid. This read-only
image analysis locates each complete character, records its source rectangle and
anchors the character by its feet, so bows are not cut off by guessed boundaries.
Requires numpy and Pillow for this development tool; the game only reads JSON.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def measure(name, rows, columns):
    image = Image.open(ROOT / f"assets/characters/ranger_{name}.png").convert("RGBA")
    remaining = np.asarray(image)[:, :, 3] > 30
    height, width = remaining.shape
    sprites = []
    for y, x in zip(*np.nonzero(remaining)):
        if not remaining[y, x]:
            continue
        remaining[y, x] = False
        queue = [(int(x), int(y))]
        pixels = []
        while queue:
            px, py = queue.pop()
            pixels.append((px, py))
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                nx, ny = px + dx, py + dy
                if 0 <= nx < width and 0 <= ny < height and remaining[ny, nx]:
                    remaining[ny, nx] = False
                    queue.append((nx, ny))
        if len(pixels) < 500:
            continue
        xs, ys = zip(*pixels)
        left, top, right, bottom = min(xs), min(ys), max(xs), max(ys)
        foot_xs = [px for px, py in pixels if py >= bottom - (bottom - top) * .16]
        anchor_x = (min(foot_xs) + max(foot_xs)) / 2
        # Row envelopes let the runtime crop a complete character without stray
        # pixels from a neighbouring pose whose rectangular bounds overlap it.
        scanlines = {}
        for px, py in pixels:
            for offset in [-1, 0, 1]:
                line = py + offset
                if top <= line <= bottom:
                    previous = scanlines.get(line, [right, left])
                    scanlines[line] = [max(left, min(previous[0], px - 1)), min(right, max(previous[1], px + 1))]
        sprites.append({
            "rect": [left, top, right - left + 1, bottom - top + 1],
            "foot_x": anchor_x - left,
            "foot_y": bottom - top + 1,
            "pixels": len(pixels),
            "spans": [[line-top, limits[0]-left, limits[1]-limits[0]+1] for line, limits in sorted(scanlines.items())],
        })
    assert len(sprites) == rows * columns, (name, len(sprites), rows * columns)
    # Feet cluster into rows even when a tall bow reaches above its neighbours.
    sprites.sort(key=lambda s: s["rect"][1] + s["rect"][3])
    ordered = []
    for row in range(rows):
        ordered.extend(sorted(sprites[row * columns:(row + 1) * columns], key=lambda s: s["rect"][0]))
    print(f"{name}: {len(ordered)} complete silhouettes measured")
    return ordered


if __name__ == "__main__":
    data = {name: measure(name, rows, cols) for name, rows, cols in [
        ("attack", 8, 8), ("run", 8, 8), ("axial", 4, 8), ("walk", 4, 4)
    ]}
    (ROOT / "assets/characters/atlas.json").write_text(json.dumps(data, indent=2) + "\n")
