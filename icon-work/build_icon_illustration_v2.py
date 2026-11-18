#!/usr/bin/env python3
"""Build Mohalla launcher icons from the illustration-type Icon 2 source.

Source: flat vector-illustration gold M (two minarets + dome) on flat emerald.
Outputs (all 5 mipmap densities):
  ic_launcher.png          48/72/96/144/192  (full-bleed, artwork zoomed)
  ic_launcher_round.png    same sizes        (same image; system masks it)
  ic_launcher_foreground.png 108/162/216/324/432 (transparent bg, artwork
                              scaled to 70% of canvas height, centred)
Adaptive XMLs and launch_background.xml are NOT touched.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

SRC = "/home/hatch/workspace/mohalla-app/icon-work/media-generation-mohalla-icon-2-illustration-3d-0-abf914f2-0b06-48c8-a0eb-7d6736ff03fc.webp"
RES = "/home/hatch/workspace/mohalla-app/android/app/src/main/res"
BG = (0, 90, 69)  # #005A45, must match @color/ic_launcher_background

DENS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FG = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

src = Image.open(SRC).convert("RGB")
arr = np.asarray(src).astype(np.int32)
# Background colour sampled from a corner (flat emerald, ~ (1,84,67)).
bg_ref = arr[5, 5].astype(np.int16)
dist = np.sqrt(((arr - bg_ref) ** 2).sum(axis=2))
# Mask: 1 where artwork, 0 where background. Soft edge 8..28 for AA.
mask = np.clip((dist - 8) / 20.0, 0, 1)
mask_img = Image.fromarray((mask * 255).astype(np.uint8), "L")
mask_img = mask_img.filter(ImageFilter.GaussianBlur(0.6))

# --- Legacy + round: artwork composited onto exact #005A45 (seamless) ---
base = Image.new("RGB", src.size, BG)
legacy = Image.composite(src, base, mask_img)

# --- Foreground: artwork with transparent background, cropped to bbox ---
# Strict mask for the bbox: background noise stays below dist ~30, while
# gold artwork is >150 away, so dist > 60 isolates true artwork only.
strict = Image.fromarray(((dist > 60) * 255).astype(np.uint8), "L")
bbox = strict.getbbox()
# Small pad so anti-aliased artwork edges are not clipped.
pad = 4
bbox = (max(0, bbox[0]-pad), max(0, bbox[1]-pad),
        min(src.size[0], bbox[2]+pad), min(src.size[1], bbox[3]+pad))
alpha = mask_img
art = src.crop(bbox)
art_alpha = alpha.crop(bbox)
art_rgba = art.convert("RGBA")
art_rgba.putalpha(art_alpha)

for dens, size in DENS.items():
    d = os.path.join(RES, f"mipmap-{dens}")
    legacy.resize((size, size), Image.LANCZOS).save(
        os.path.join(d, "ic_launcher.png"))
    legacy.resize((size, size), Image.LANCZOS).save(
        os.path.join(d, "ic_launcher_round.png"))

for dens, size in FG.items():
    d = os.path.join(RES, f"mipmap-{dens}")
    # Artwork height = 72% of the 108dp canvas (zoomed, inside safe zone).
    target_h = int(round(size * 0.72))
    scale = target_h / art_rgba.size[1]
    target_w = int(round(art_rgba.size[0] * scale))
    fg_art = art_rgba.resize((target_w, target_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(fg_art, ((size - target_w) // 2, (size - target_h) // 2),
                 fg_art)
    canvas.save(os.path.join(d, "ic_launcher_foreground.png"))

print("done")
print("artwork bbox (of 1600):", bbox,
      "-> w %.2f h %.2f of source" % ((bbox[2]-bbox[0])/1600, (bbox[3]-bbox[1])/1600))
