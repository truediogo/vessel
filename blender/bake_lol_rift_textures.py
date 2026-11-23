#!/usr/bin/env python3
"""
Hand-Painted League of Legends / Summoner's Rift Seamless Texture Pipeline:
Restores the user's seamless 512x512 hand-painted League of Legends mossy stone tile
texture (`image.png`) across plazas, roads, weathered ashlar stone walls, roof tiles,
Summoner's Rift mossy meadow & golden-earth terrain, emerald-jade canopy foliage, and
dark walnut timber planks — 100% seamless with zero divider lines and zero blurry bullseyes!
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lorencia_town")
REF_FLAGSTONE = "/Users/diogo.silva/OpenBot/Shared/Transfers/32890187-4388-4c85-ac1c-11b0a850082f/image.png"

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)


def save_both(img, filenames):
    for name in filenames:
        img.save(os.path.join(BLENDER_DIR, name), "PNG")
        img.save(os.path.join(OUT_GLB_DIR, "Lorencia_Town_" + name), "PNG")


def build_lol_hand_painted_stone_family():
    """
    Derives our stone, cobblestone, roof tile, and foliage textures directly pixel-for-pixel
    from the user's seamless 512x512 hand-painted League of Legends stone tile reference (`image.png`),
    preserving every hand-painted crack, chipped bevel, brushstroke, and moss crevice!
    """
    src = Image.open(REF_FLAGSTONE).convert("RGB")
    w, h = src.size
    src_px = src.load()

    flag_img = Image.new("RGB", (w, h))
    stone_img = Image.new("RGB", (w, h))
    roof_img = Image.new("RGB", (w, h))
    leaves_img = Image.new("RGB", (w, h))

    flag_px = flag_img.load()
    stone_px = stone_img.load()
    roof_px = roof_img.load()
    leaves_px = leaves_img.load()

    for y in range(h):
        for x in range(w):
            r, g, b = src_px[x, y]
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0

            # 1. T_LoL_Mossy_Flagstones & T_Real_Palia_Cobble:
            #    Exact hand-painted LoL mossy stone tiles lifted gently for clean daylight readability
            fr = min(1.0, (rf ** 0.74) * 1.04)
            fg = min(1.0, (gf ** 0.74) * 1.03)
            fb = min(1.0, (bf ** 0.76) * 0.98)
            flag_px[x, y] = (int(fr * 255), int(fg * 255), int(fb * 255))

            # 2. T_LoL_Weathered_Stone & T_Real_Palia_Stucco / T_Real_Palia_Stone:
            #    Shift green moss channel into warm weathered ashlar stone (RGB ~135..175, never flat white!)
            luma = 0.299 * fr + 0.587 * fg + 0.114 * fb
            sr = min(1.0, (fr * 0.45 + luma * 0.55) * 1.18 + 0.05)
            sg = min(1.0, (fg * 0.28 + luma * 0.72) * 1.10 + 0.04)
            sb = min(1.0, (fb * 0.40 + luma * 0.60) * 0.96 + 0.02)
            stone_px[x, y] = (int(sr * 255), int(sg * 255), int(sb * 255))

            # 3. T_Palia_Terracotta_Roof & T_Real_Palia_Terracotta:
            #    Same hand-painted tile bevels & dark crevices tinted into warm terracotta-crimson roof tiles
            tile_v = max(0.25, min(1.15, (luma ** 0.85) * 1.35))
            tr = min(1.0, tile_v * 0.78)
            tg = min(1.0, tile_v * 0.36)
            tb = min(1.0, tile_v * 0.26)
            roof_px[x, y] = (int(tr * 255), int(tg * 255), int(tb * 255))

            # 4. T_Real_Palia_Leaves:
            #    Hand-painted brush structure shifted into rich emerald-jade Summoner's Rift canopy foliage
            leaf_v = max(0.32, min(1.22, (luma ** 0.78) * 1.40))
            lr = min(1.0, leaf_v * 0.34)
            lg = min(1.0, leaf_v * 0.62)
            lb = min(1.0, leaf_v * 0.22)
            leaves_px[x, y] = (int(lr * 255), int(lg * 255), int(lb * 255))

    save_both(flag_img, ["T_LoL_Mossy_Flagstones.png", "T_Real_Palia_Cobble.png"])
    save_both(stone_img, ["T_LoL_Weathered_Stone.png", "T_Real_Palia_Stucco.png", "T_Real_Palia_Stone.png"])
    save_both(roof_img, ["T_Palia_Terracotta_Roof.png", "T_Real_Palia_Terracotta.png"])
    save_both(leaves_img, ["T_Real_Palia_Leaves.png"])
    print("Built seamless hand-painted LoL stone, roof, and foliage textures from image.png")


def build_seamless_lol_rift_terrain():
    """
    Combines the hand-painted brush variation of image.png with periodic 2D trigonometric waves
    into a 100% seamless hand-painted Summoner's Rift mossy meadow & golden-earth terrain texture
    (matching image-2.png & image-3.png) with wrapped tiny golden wildflowers — zero divider lines!
    """
    src = Image.open(REF_FLAGSTONE).convert("RGB")
    sw, sh = src.size
    src_px = src.load()

    W, H = 512, 512
    img = Image.new("RGB", (W, H))
    px = img.load()
    two_pi = 2.0 * math.pi

    for y in range(H):
        v = float(y) / float(H)
        ay = two_pi * v
        s1y = math.sin(ay)
        c1y = math.cos(ay)
        s2y = math.sin(2.0 * ay + 0.7)
        c2y = math.cos(2.0 * ay - 0.4)
        c4y = math.cos(4.0 * ay + 0.9)
        sy_idx = (y * sh) // H
        for x in range(W):
            u = float(x) / float(W)
            ax = two_pi * u
            sx_idx = (x * sw) // W
            sr, sg, sb = src_px[sx_idx, sy_idx]
            brush_luma = (0.299 * sr + 0.587 * sg + 0.114 * sb) / 255.0
            brush_mod = 0.86 + 0.34 * brush_luma

            w1 = math.sin(ax + 0.4) * c1y + math.cos(ax - 0.8) * s1y
            w2 = math.sin(2.0 * ax - 1.1) * s2y + math.cos(2.0 * ax + 0.5) * c2y
            w3 = math.sin(3.0 * ax + 2.0 * ay + 0.6) * 0.6 + math.cos(3.0 * ax - 2.0 * ay - 0.5) * 0.4
            w4 = math.sin(4.0 * ax - 0.3) * c4y + math.cos(5.0 * ax + 3.0 * ay) * 0.35

            t = max(0.0, min(1.0, 0.50 + 0.22 * w1 + 0.14 * w2 + 0.09 * w3 + 0.05 * w4))

            # Blend Deep Moss RGB(52,82,34) -> Lush Olive-Emerald Grass RGB(72,108,44) -> Warm Earth RGB(116,92,54)
            if t < 0.42:
                k = t / 0.42
                r = 52 + k * (72 - 52)
                g = 82 + k * (108 - 82)
                b = 34 + k * (44 - 34)
            elif t < 0.74:
                k = (t - 0.42) / 0.32
                r = 72 + k * (96 - 72)
                g = 108 + k * (116 - 108)
                b = 44 + k * (48 - 44)
            else:
                k = (t - 0.74) / 0.26
                r = 96 + k * (124 - 96)
                g = 116 + k * (98 - 116)
                b = 48 + k * (56 - 48)

            px[x, y] = (
                max(0, min(255, int(r * brush_mod))),
                max(0, min(255, int(g * brush_mod))),
                max(0, min(255, int(b * brush_mod))),
            )

    # Wrapped tiny golden wildflowers & moss flecks (100% seamless across boundaries)
    draw = ImageDraw.Draw(img)
    rng = random.Random(303)
    for _ in range(42):
        cx = rng.randint(0, W - 1)
        cy = rng.randint(0, H - 1)
        for _ in range(rng.randint(2, 4)):
            fx = (cx + rng.randint(-14, 14)) % W
            fy = (cy + rng.randint(-14, 14)) % H
            rad = rng.randint(2, 3)
            for ox in (-W, 0, W):
                for oy in (-H, 0, H):
                    draw.ellipse([fx + ox - rad, fy + oy - rad, fx + ox + rad, fy + oy + rad], fill=(232, 194, 68))

    img = img.filter(ImageFilter.SMOOTH)
    save_both(img, ["T_LoL_Rift_Terrain.png", "T_LoL_Ground_Canvas_2K.png", "T_Real_Palia_Grass.png"])
    print("Built 100% seamless Summoner's Rift mossy meadow & earth terrain texture.")


def build_seamless_walnut_wood():
    """
    100% periodic hand-painted dark walnut/mahogany timber planks (RGB ~(108, 72, 46))
    with warm bevel highlights and crisp dark plank seams.
    """
    W, H = 512, 512
    img = Image.new("RGB", (W, H))
    px = img.load()
    two_pi = 2.0 * math.pi

    for y in range(H):
        v = float(y) / float(H)
        plank_pos = (v * 8.0) % 1.0
        plank_id = int(v * 8.0)
        seam = 1.0
        if plank_pos < 0.06:
            seam = 0.62 + (plank_pos / 0.06) * 0.38
        elif plank_pos < 0.14:
            seam = 1.12
        elif plank_pos > 0.94:
            seam = 0.62 + ((1.0 - plank_pos) / 0.06) * 0.38

        for x in range(W):
            u = float(x) / float(W)
            grain = (
                math.sin(two_pi * (u * 2.0 + v * 1.0) + plank_id * 1.7) * 0.5
                + math.cos(two_pi * (u * 5.0 - v * 2.0) + plank_id * 0.9) * 0.3
                + math.sin(two_pi * (v * 24.0 + u * 1.0)) * 0.2
            )
            g_t = 0.5 + 0.35 * grain
            r = (92 + g_t * 34) * seam
            g = (60 + g_t * 24) * seam
            b = (38 + g_t * 16) * seam
            px[x, y] = (
                max(0, min(255, int(r))),
                max(0, min(255, int(g))),
                max(0, min(255, int(b))),
            )

    save_both(img, ["T_LoL_Walnut_Wood.png", "T_Real_Palia_Wood.png"])
    print("Built 100% seamless hand-painted Walnut Timber texture.")


if __name__ == "__main__":
    build_lol_hand_painted_stone_family()
    build_seamless_lol_rift_terrain()
    build_seamless_walnut_wood()
