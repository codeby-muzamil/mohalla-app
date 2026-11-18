#!/usr/bin/env python3
"""Build Mohalla launcher icons from the REALISTIC 3D Icon 2 source (user-final).

Source: realistic rendered-gold 3D M (two minarets + dome) on flat emerald,
media-generation-mohalla-icon-2-3d-zoomed-0-88b14d17-0749-4996-af7d-acda3a2a7a6d.png
(1600x1600). This is the icon the user confirmed final on 2026-11-17 ~15:56 PKT.
Outputs (all 5 mipmap densities):
  ic_launcher.png          48/72/96/144/192  (full-bleed, light 94% centre zoom)
  ic_launcher_round.png    same sizes        (same image; system masks it)
  ic_launcher_foreground.png 108/162/216/324/432 (transparent bg, artwork
                              scaled to 72% of canvas height, centred)
Adaptive XMLs and launch_background.xml are NOT touched.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

SRC = "/home/hatch/workspace/mohalla-app/icon-work/media-generation-mohalla-icon-2-3d-zoomed-0-88b14d17-0749-4996-af7d-acda3a2a7a6d.png"
RES = "/home/hatch/workspace/mohalla-app/android/app/src/main/res"
BG = (0, 90, 69)  # #005A45, must match @color/ic_launcher_background

DENS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FG = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

src = Image.open(SRC).convert("RGB")
arr = np.asarray(src).astype(np.int32)
bg_ref = arr[5, 5].astype(np.int16)
dist = np.sqrt(((arr - bg_ref) ** 2).sum(axis=2))
mask = np.clip((dist - 8) / 20.0, 0, 1)
mask_img = Image.fromarray((mask * 255).astype(np.uint8), "L")
mask_img = mask_img.filter(ImageFilter.GaussianBlur(0.6))

# --- Legacy + round: artwork composited onto exact #005A45, light 94% zoom ---
base = Image.new("RGB", src.size, BG)
legacy_full = Image.composite(src, base, mask_img)
w, h = legacy_full.size
crop = (int(w * 0.03), int(h * 0.03), int(w * 0.97), int(h * 0.97))
legacy = legacy_full.crop(crop).resize((w, h), Image.LANCZOS)

# --- Foreground: artwork with transparent background, cropped to bbox ---
strict = Image.fromarray(((dist > 60) * 255).astype(np.uint8), "L")
bbox = strict.getbbox()
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
    target_h = int(round(size * 0.72))
    scale = target_h / art_rgba.size[1]
    target_w = int(round(art_rgba.size[0] * scale))
    fg_art = art_rgba.resize((target_w, target_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(fg_art, ((size - target_w) // 2, (size - target_h) // 2),
                 fg_art)
    canvas.save(os.path.join(d, "ic_launcher_foreground.png"))

# --- Preview: legacy + adaptive composite + circle mask, for visual check ---
prev = Image.new("RGB", (3 * 220 + 40, 220), (255, 255, 255))
leg192 = legacy.resize((192, 192), Image.LANCZOS)
prev.paste(leg192, (10, 14))
fg432 = Image.open(os.path.join(RES, "mipmap-xxxhdpi/ic_launcher_foreground.png"))
comp = Image.new("RGB", (432, 432), BG)
comp.paste(fg432, (0, 0), fg432)
prev.paste(comp.resize((192, 192), Image.LANCZOS), (240, 14))
circ = Image.new("L", (192, 192), 0)
from PIL import ImageDraw
ImageDraw.Draw(circ).ellipse((0, 0, 192, 192), fill=255)
masked = Image.composite(comp.resize((192, 192), Image.LANCZOS),
                         Image.new("RGB", (192, 192), (255, 255, 255)), circ)
prev.paste(masked, (470, 14))
prev.save("/home/hatch/workspace/mohalla-app/icon-work/preview-realistic-3d-final.png")

print("done")
print("artwork bbox (of 1600):", bbox,
      "-> w %.2f h %.2f of source" % ((bbox[2]-bbox[0])/1600, (bbox[3]-bbox[1])/1600))
print("legacy corner pixel:", legacy.getpixel((0, 0)))
print("foreground centre alpha:",
      Image.open(os.path.join(RES, "mipmap-xxxhdpi/ic_launcher_foreground.png")).getpixel((216, 216))[3])
