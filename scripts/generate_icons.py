#!/usr/bin/env python3
"""Generates the Android launcher icons and splash images from
assets/app_icon.png. Re-run after changing the source icon:

    python3 scripts/generate_icons.py

Requires Pillow. Writes only under android/app/src/main/res/.

Outputs:
  mipmap-*/ic_launcher.png             legacy icon (Android 7), rounded square
  mipmap-*/ic_launcher_foreground.png  adaptive icon foreground (transparent)
  mipmap-*/ic_launcher_monochrome.png  themed icon layer (Android 13+)
  drawable-*/splash_icon.png           splash screen icon (transparent)
The XML resources (adaptive icon, colours, splash themes) are hand-written
and reference these files.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "app_icon.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Off-white of the icon's rounded square; must match
# values/colors.xml -> ic_launcher_background / splash_background.
BACKGROUND = (248, 247, 241)

DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

# Fraction of each canvas the artwork (the green ring) spans.
ADAPTIVE_CANVAS_DP, ADAPTIVE_CONTENT = 108, 0.54  # safe zone is 66/108 = 0.61
LEGACY_CANVAS_DP, LEGACY_CONTENT = 48, 0.68
LEGACY_SQUARE = 0.92  # rounded square size within the legacy canvas
SPLASH_CANVAS_DP, SPLASH_CONTENT = 288, 0.56  # fits 192dp (no bg) / 160dp (bg)


NOISE = 0.12  # alpha below this is background noise


def color_to_alpha(img: Image.Image, bg: tuple) -> Image.Image:
    """Makes `bg` transparent, keeping anti-aliased edges clean (like GIMP's
    "Color to Alpha")."""
    rgb = img.convert("RGB")
    out = Image.new("RGBA", rgb.size)
    src, dst = rgb.load(), out.load()
    w, h = rgb.size
    for y in range(h):
        for x in range(w):
            c = src[x, y]
            a = 0.0
            for ci, bi in zip(c, bg):
                if ci > bi:
                    a = max(a, (ci - bi) / (255 - bi))
                elif ci < bi:
                    a = max(a, (bi - ci) / bi)
            # The source background is slightly noisy: drop faint alpha and
            # rescale the rest so anti-aliased edges stay smooth.
            a = (a - NOISE) / (1 - NOISE)
            if a <= 0:
                dst[x, y] = (0, 0, 0, 0)
                continue
            a = min(1.0, a)
            col = tuple(
                max(0, min(255, round((ci - bi) / a + bi))) for ci, bi in zip(c, bg)
            )
            dst[x, y] = (*col, round(a * 255))
    return out


def extract_artwork(img: Image.Image) -> Image.Image:
    """Crops to a square around the artwork and removes the background."""
    rgb = img.convert("RGB")
    px = rgb.load()
    w, h = rgb.size
    # Sample the background just inside the rounded square, top centre.
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            c = px[x, y]
            if sum(abs(a - b) for a, b in zip(c, BACKGROUND)) > 60 and sum(c) < 3 * 250:
                xs.append(x)
                ys.append(y)
    left, right, top, bottom = min(xs), max(xs), min(ys), max(ys)
    side = max(right - left, bottom - top) + 8
    cx, cy = (left + right) // 2, (top + bottom) // 2
    box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    art = color_to_alpha(rgb.crop(box), BACKGROUND)
    # The artwork is circular: clear everything outside the ring.
    mask = Image.new("L", art.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, art.size[0] - 1, art.size[1] - 1), fill=255)
    art.putalpha(Image.composite(art.getchannel("A"), mask, mask))
    return art


def place(art: Image.Image, size: int, fraction: float) -> Image.Image:
    """Centres `art` scaled to `fraction` of a transparent `size` canvas."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = max(1, round(size * fraction))
    scaled = art.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    canvas.alpha_composite(scaled, (offset, offset))
    return canvas


def legacy_icon(art: Image.Image, size: int) -> Image.Image:
    """Rounded off-white square with the artwork, transparent corners."""
    scale = 4  # supersample for smooth corners
    big = size * scale
    square = round(big * LEGACY_SQUARE)
    margin = (big - square) // 2
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).rounded_rectangle(
        (margin, margin, margin + square - 1, margin + square - 1),
        radius=round(square * 0.22),
        fill=(*BACKGROUND, 255),
    )
    canvas.alpha_composite(place(art, big, LEGACY_CONTENT))
    return canvas.resize((size, size), Image.LANCZOS)


def monochrome(img: Image.Image) -> Image.Image:
    """White silhouette from the alpha channel (Android tints it)."""
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.putalpha(img.getchannel("A"))
    return out


def main() -> None:
    art = extract_artwork(Image.open(SOURCE))
    for name, factor in DENSITIES.items():
        mipmap = RES / f"mipmap-{name}"
        drawable = RES / f"drawable-{name}"
        mipmap.mkdir(parents=True, exist_ok=True)
        drawable.mkdir(parents=True, exist_ok=True)

        size = round(LEGACY_CANVAS_DP * factor)
        legacy_icon(art, size).save(mipmap / "ic_launcher.png", optimize=True)

        size = round(ADAPTIVE_CANVAS_DP * factor)
        fg = place(art, size, ADAPTIVE_CONTENT)
        fg.save(mipmap / "ic_launcher_foreground.png", optimize=True)
        monochrome(fg).save(mipmap / "ic_launcher_monochrome.png", optimize=True)

        size = round(SPLASH_CANVAS_DP * factor)
        place(art, size, SPLASH_CONTENT).save(
            drawable / "splash_icon.png", optimize=True
        )
    print(f"Icons written under {RES.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
