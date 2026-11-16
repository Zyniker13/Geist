#!/usr/bin/env python3
"""G8 color-blind simulation review for Night Market's six stall accents.

Simulates protanomaly, deuteranomaly, and tritanomaly (Machado et al. 2009,
severity 1.0) on the stall accent palette and reports the pairwise CIE76
delta-E in Lab (D65). The review passes when every pair stays distinguishable
(delta-E >= 12) under every simulation, in both the standard and the
high-contrast palettes.
"""
import itertools
import json
import sys

STANDARD = {
    "noodles": 0xFF5A5F,
    "tea": 0x3DDC97,
    "skewers": 0xFFD23F,
    "dumplings": 0x2E7FFF,
    "sweets": 0xF062C8,
    "seafood": 0xFF8C42,
}
HIGH_CONTRAST = {
    "noodles": 0xFF3B44,
    "tea": 0x2BFFB0,
    "skewers": 0xFFE14D,
    "dumplings": 0x1FA7FF,
    "sweets": 0xFF5FD0,
    "seafood": 0xFF9E33,
}

# Machado, Oliveira, Fernandes 2009, severity 1.0 (rows: R, G, B).
MATRICES = {
    "protanopia": [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281, 0.099216],
        [-0.003882, -0.048116, 1.051998],
    ],
    "deuteranopia": [
        [0.367322, 0.860646, -0.227968],
        [0.280085, 0.672501, 0.047413],
        [-0.011820, 0.042940, 0.968881],
    ],
    "tritanopia": [
        [1.255528, -0.076849, -0.178729],
        [-0.078411, 0.930809, 0.147602],
        [0.004733, 0.691367, 0.303900],
    ],
}


def srgb_to_linear(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    c = max(0.0, min(1.0, c))
    c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return round(c * 255)


def simulate(rgb, matrix):
    linear = [srgb_to_linear(v) for v in rgb]
    out = [sum(m[i] * linear[i] for i in range(3)) for m in matrix]
    return [linear_to_srgb(v) for v in out]


def to_lab(rgb):
    # sRGB (D65) -> XYZ -> Lab.
    r, g, b = (srgb_to_linear(v) for v in rgb)

    def f(c):
        return c ** (1 / 3) if c > 216 / 24389 else (841 / 108) * c + 4 / 29

    x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
    y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
    xn, yn, zn = 0.95047, 1.0, 1.08883
    fx, fy, fz = f(x / xn), f(y / yn), f(z / zn)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def delta_e(a, b):
    la, lb = to_lab(a), to_lab(b)
    return sum((x - y) ** 2 for x, y in zip(la, lb)) ** 0.5


def review(palette, label, threshold=12.0):
    simulated = {
        name: {
            kind: simulate(list(v.to_bytes(3, "big")), m) for kind, m in MATRICES.items()
        }
        for name, v in palette.items()
    }
    worst = (1e9, None, None, None)
    for kind in MATRICES:
        for a, b in itertools.combinations(palette, 2):
            d = delta_e(simulated[a][kind], simulated[b][kind])
            if d < worst[0]:
                worst = (d, kind, a, b)
    ok = worst[0] >= threshold
    print(f"{label}: worst pair delta-E {worst[0]:.1f} ({worst[2]} vs {worst[3]} under {worst[1]}) -> {'PASS' if ok else 'FAIL'}")
    return ok, worst


def main():
    ok = True
    for palette, label in ((STANDARD, "standard"), (HIGH_CONTRAST, "high-contrast")):
        good, worst = review(palette, label)
        if not good:
            print(f"  details ({label}):", file=sys.stderr)
            for kind in MATRICES:
                for a, b in itertools.combinations(palette, 2):
                    d = delta_e(
                        simulate(list(palette[a].to_bytes(3, "big")), MATRICES[kind]),
                        simulate(list(palette[b].to_bytes(3, "big")), MATRICES[kind]),
                    )
                    print(f"  {kind:12s} {a:9s} vs {b:9s}: {d:5.1f}", file=sys.stderr)
        ok = ok and good
    print(json.dumps({"pass": ok}))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
