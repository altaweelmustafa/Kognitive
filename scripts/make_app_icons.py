#!/usr/bin/env python3
"""Renders the Kognitiv logo and every app icon from the master SVG.

    python3 scripts/make_app_icons.py

Needs Inkscape (to render the SVG) and Pillow. Writes:
  assets/logo/                  the logo for screens, and the Linux window icon
  ios/.../AppIcon.appiconset    iOS app icons (opaque, square)
  ios/.../LaunchImage.imageset  iOS launch screen logo
  android/.../mipmap-*          launcher icons: legacy and adaptive foreground
  android/.../drawable-*        splash screen logo
  web/                          favicon, PWA icons and the loading-screen logo
The near-black background colour is also set in
android/app/src/main/res/values/colors.xml and ios/Runner/Base.lproj/LaunchScreen.storyboard.
"""
import json
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG = os.path.join(ROOT, "design", "logo", "kognitiv_logo.svg")
BG = (14, 14, 17, 255)  # #0E0E11, almost black

with tempfile.TemporaryDirectory() as tmp:
    master = os.path.join(tmp, "logo.png")
    subprocess.run(
        ["inkscape", SVG, "--export-type=png", "--export-width=2048", f"--export-filename={master}"],
        check=True, capture_output=True,
    )
    logo = Image.open(master).convert("RGBA")
    logo.load()
logo = logo.crop(logo.getbbox())
root = ROOT


def place(size, frac, bg=None, dy=0.0):
    """The logo, `frac` of the canvas wide, centred (nudged by dy of the canvas)."""
    canvas = Image.new("RGBA", (size, size), bg or (0, 0, 0, 0))
    w = round(size * frac)
    h = round(w * logo.height / logo.width)
    l = logo.resize((w, h), Image.LANCZOS)
    canvas.alpha_composite(l, ((size - w) // 2, (size - h) // 2 + round(size * dy)))
    return canvas

def rounded(img, radius_frac):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), round(img.width * radius_frac), fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out

# Flutter asset: the logo itself, for screens.
os.makedirs(f"{root}/assets/logo", exist_ok=True)
w = 600
logo.resize((w, round(w * logo.height / logo.width)), Image.LANCZOS).save(f"{root}/assets/logo/kognitiv_logo.png", optimize=True)
# Square icon for the Linux window.
place(256, 0.66, BG).save(f"{root}/assets/logo/app_icon.png", optimize=True)

# iOS app icons: opaque, square (iOS rounds the corners itself).
ios = f"{root}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
for img in json.load(open(f"{ios}/Contents.json"))["images"]:
    pts = float(img["size"].split("x")[0]); scale = int(img["scale"][0])
    px = round(pts * scale)
    place(px, 0.66, BG).convert("RGB").save(f"{ios}/{img['filename']}")

# iOS launch image: the logo alone, 140 pt wide.
li = f"{root}/ios/Runner/Assets.xcassets/LaunchImage.imageset"
for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
    w = 140 * scale
    logo.resize((w, round(w * logo.height / logo.width)), Image.LANCZOS).save(f"{li}/{name}")

res = f"{root}/android/app/src/main/res"
dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for d, k in dens.items():
    # Legacy launcher icon (before Android 8): a rounded square.
    rounded(place(round(48 * k), 0.66, BG), 0.2).save(f"{res}/mipmap-{d}/ic_launcher.png")
    # Adaptive foreground: 108 dp, logo inside the 66 dp safe circle.
    place(round(108 * k), 0.44).save(f"{res}/mipmap-{d}/ic_launcher_foreground.png")
    # Splash logo, 140 dp wide.
    os.makedirs(f"{res}/drawable-{d}", exist_ok=True)
    w = round(140 * k)
    logo.resize((w, round(w * logo.height / logo.width)), Image.LANCZOS).save(f"{res}/drawable-{d}/launch_logo.png")

# Web: favicon, installable-app icons (maskable ones keep the logo in the
# central safe circle), and the logo on the loading screen.
web = f"{root}/web"
os.makedirs(f"{web}/icons", exist_ok=True)
os.makedirs(f"{web}/splash", exist_ok=True)
rounded(place(64, 0.72, BG), 0.22).save(f"{web}/favicon.png")
for px in (192, 512):
    place(px, 0.66, BG).save(f"{web}/icons/Icon-{px}.png")
    place(px, 0.5, BG).save(f"{web}/icons/Icon-maskable-{px}.png")
w = 280
logo.resize((w, round(w * logo.height / logo.width)), Image.LANCZOS).save(f"{web}/splash/logo.png")

print('Icons written.')
