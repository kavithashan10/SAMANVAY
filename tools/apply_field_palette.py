#!/usr/bin/env python3
"""Map SAMANVAY's legacy neon/navy hard-coded colours onto the field-journal
earth palette. Each colour keeps its alpha and lightness (so contrast between
foreground and background is preserved) while hue and saturation move into the
matching earth family. Usage: python3 tools/apply_field_palette.py app/main.dart"""
import colorsys
import re
import sys
from pathlib import Path

FAMILIES = [
    # (name, test(h, s, l), target hue degrees, saturation)
    ("neutral", lambda h, s, l: s < 0.12 or (190 <= h < 250 and (l < 0.3 or l > 0.7 or s < 0.3)), 36, None),
    ("sage", lambda h, s, l: 150 <= h < 190, 100, 0.22),
    ("water", lambda h, s, l: 190 <= h < 250, 205, 0.38),
    ("plum", lambda h, s, l: 250 <= h < 300, 315, 0.22),
    ("clay", lambda h, s, l: h >= 300 or h < 15, 9, None),
    ("gold", lambda h, s, l: 15 <= h < 70, 36, None),
    ("forest", lambda h, s, l: 70 <= h < 150, 130, 0.30),
]


def remap(argb: int) -> int:
    a = (argb >> 24) & 0xFF
    r, g, b = ((argb >> 16) & 0xFF) / 255, ((argb >> 8) & 0xFF) / 255, (argb & 0xFF) / 255
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    hd = h * 360
    if l >= 0.995 or l <= 0.005:  # pure white / black stay as they are
        return argb
    for name, test, hue, sat in FAMILIES:
        if test(hd, s, l):
            if name == "neutral":
                sat = 0.45 if l > 0.85 else (0.18 if l > 0.7 else 0.07)
            elif name == "clay":
                sat = min(s, 0.55)
            elif name == "gold":
                sat = min(s, 0.7)
            nr, ng, nb = colorsys.hls_to_rgb(hue / 360, l, sat)
            return (a << 24) | (round(nr * 255) << 16) | (round(ng * 255) << 8) | round(nb * 255)
    return argb


def main(paths):
    pattern = re.compile(r"Color\(0x([0-9A-Fa-f]{8})\)")
    for p in map(Path, paths):
        text = p.read_text()
        count = 0

        def sub(m):
            nonlocal count
            old = int(m.group(1), 16)
            new = remap(old)
            if new != old:
                count += 1
            return f"Color(0x{new:08X})"

        p.write_text(pattern.sub(sub, text))
        print(f"{p}: {count} colours remapped")


if __name__ == "__main__":
    main(sys.argv[1:])
