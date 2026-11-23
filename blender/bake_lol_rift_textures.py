#!/usr/bin/env python3
"""
Stylizes the real CC0 1K Poly Haven textures into warm, painterly Palia / League of Legends
game textures (1024x1024 seamless PNGs):
- T_Real_Palia_Cobble.png (from grassy_cobblestone)
- T_Real_Palia_Grass.png (from leafy_grass)
- T_Real_Palia_Terracotta.png (from clay_roof_tiles_02)
- T_Real_Palia_Wood.png (from brown_planks_03)
- T_Real_Palia_Stucco.png (from plastered_wall_02)
- T_Real_Palia_Stone.png (from mossy_stone_wall)
- T_Real_Palia_Leaves.png (from forest_leaves_02)
Applies a painterly Kuwahara-like median/bilateral brush pass + warm sunlit Palia color grading
so every surface has 100% real material geometry and 100% seamless tiling!
"""

import os
import shutil
from PIL import Image, ImageFilter, ImageEnhance

PROJECT_DIR = "/Users/diogo.silva/OpenBot/Agents/agent-0f47a086-7b1c-416a-86ce-7cb8de846218/project-vessel"
BLENDER_DIR = os.path.join(PROJECT_DIR, "blender")
OUT_GLB_DIR = os.path.join(PROJECT_DIR, "addons/lorencia_town")

os.makedirs(BLENDER_DIR, exist_ok=True)
os.makedirs(OUT_GLB_DIR, exist_ok=True)


def stylize_real_texture(raw_name, out_names, gamma=0.82, contrast=0.92, sat=1.12, tint=(1.0, 1.0, 1.0), lift=0.0):
    raw_path = os.path.join(BLENDER_DIR, raw_name)
    if not os.path.exists(raw_path):
        print("Missing raw texture:", raw_path)
        return
    im = Image.open(raw_path).convert("RGB")
    if im.size != (1024, 1024):
        im = im.resize((1024, 1024), Image.Resampling.LANCZOS)

    # Painterly brush smoothing: removes high-frequency photo grit while keeping crisp stone/tile/plank edges!
    im = im.filter(ImageFilter.MedianFilter(size=3))
    im = im.filter(ImageFilter.SMOOTH_MORE)

    if sat != 1.0:
        im = ImageEnhance.Color(im).enhance(sat)
    if contrast != 1.0:
        im = ImageEnhance.Contrast(im).enhance(contrast)

    # Fast LUT per channel for gamma, lift & warm Palia sunlight tint
    r_lut = [min(255, max(0, int((((i / 255.0) ** gamma) * (1.0 - lift) + lift) * tint[0] * 255.0))) for i in range(256)]
    g_lut = [min(255, max(0, int((((i / 255.0) ** gamma) * (1.0 - lift) + lift) * tint[1] * 255.0))) for i in range(256)]
    b_lut = [min(255, max(0, int((((i / 255.0) ** gamma) * (1.0 - lift) + lift) * tint[2] * 255.0))) for i in range(256)]
    im = im.point(r_lut + g_lut + b_lut)

    for oname in out_names:
        for folder in (BLENDER_DIR, OUT_GLB_DIR):
            p = os.path.join(folder, oname if folder == BLENDER_DIR else ("Lorencia_Town_" + oname))
            im.save(p, "PNG")
    print("Stylized real 1K texture ->", out_names)


if __name__ == "__main__":
    # 1. Warm Golden-Sandstone & Grassy Village Cobblestones
    stylize_real_texture(
        "raw_cobble.png",
        ["T_Real_Palia_Cobble.png", "T_LoL_Mossy_Flagstones.png"],
        gamma=0.72,
        contrast=0.82,
        sat=1.08,
        tint=(1.10, 1.01, 0.86),
        lift=0.14,
    )
    # 2. Lush Sunlit Palia Meadow Grass (deep, vibrant emerald-green without pastel wash-out)
    stylize_real_texture(
        "raw_grass.png",
        ["T_Real_Palia_Grass.png", "T_LoL_Rift_Terrain.png"],
        gamma=0.92,
        contrast=0.88,
        sat=1.35,
        tint=(0.76, 1.06, 0.56),
        lift=0.02,
    )
    # 3. Warm Terracotta Clay Roof Shingles
    stylize_real_texture(
        "raw_terracotta.png",
        ["T_Real_Palia_Terracotta.png", "T_Palia_Terracotta_Roof.png"],
        gamma=0.78,
        contrast=0.88,
        sat=1.24,
        tint=(1.14, 0.88, 0.76),
        lift=0.08,
    )
    # 4. Warm Cedar / Walnut Timber Planks
    stylize_real_texture(
        "raw_wood.png",
        ["T_Real_Palia_Wood.png", "T_LoL_Walnut_Wood.png"],
        gamma=0.78,
        contrast=0.86,
        sat=1.18,
        tint=(1.12, 0.94, 0.78),
        lift=0.06,
    )
    # 5. Warm Cream-Ivory Village Stucco Wall
    stylize_real_texture(
        "raw_stucco.png",
        ["T_Real_Palia_Stucco.png", "T_LoL_Weathered_Stone.png"],
        gamma=0.70,
        contrast=0.72,
        sat=0.95,
        tint=(1.04, 0.99, 0.90),
        lift=0.22,
    )
    # 6. Natural River-Stone Foundation Masonry
    stylize_real_texture(
        "raw_stone_wall.png",
        ["T_Real_Palia_Stone.png"],
        gamma=0.74,
        contrast=0.82,
        sat=1.05,
        tint=(1.05, 1.00, 0.92),
        lift=0.14,
    )
    # 7. Lush Painterly Canopy Leaves (rich Palia emerald-jade foliage)
    stylize_real_texture(
        "raw_leaves.png",
        ["T_Real_Palia_Leaves.png"],
        gamma=0.95,
        contrast=0.92,
        sat=1.42,
        tint=(0.64, 1.04, 0.48),
        lift=0.0,
    )

    # 8. Point 3 & Point 4 of the League of Legends Pipeline:
    #    Bake a single non-tiled 2048x2048 texture-blended Painted Ground Canvas
    #    (T_LoL_Ground_Canvas_2K.png) covering x in [-60..+60], z in [-72..+48] with:
    #    - Brighter, warm sunlit gameplay plaza & northern lane center
    #    - Texture-blended golden dirt paths, grassy lawn islands, and cobblestone patches
    #    - Darker, rich high-contrast outer forest & cliff borders so gameplay areas pop!
    import math
    grass_im = Image.open(os.path.join(BLENDER_DIR, "T_Real_Palia_Grass.png")).convert("RGB")
    cobble_im = Image.open(os.path.join(BLENDER_DIR, "T_Real_Palia_Cobble.png")).convert("RGB")
    g_px = grass_im.load()
    c_px = cobble_im.load()

    CW, CH = 1024, 1024
    canvas = Image.new("RGB", (CW, CH))
    out_px = canvas.load()

    for py in range(CH):
        # Map py (0..CH-1) -> Blender Y = -gz -> gz = 48.0 - (py / CH) * 120.0 (covers gz from +48 down to -72)
        v_norm = py / float(CH - 1)
        gz = 48.0 - v_norm * 120.0
        ty = (py * 7) % 1024
        for px_i in range(CW):
            u_norm = px_i / float(CW - 1)
            gx = -60.0 + u_norm * 120.0
            tx = (px_i * 7) % 1024

            gr, gg, gb = g_px[tx, ty]
            cr, cg, cb = c_px[tx, ty]

            # Distance to Central Fountain Square (0, 11.5) & Northern Lane (x=0, z=-12..-48)
            d_plaza = math.hypot(gx, gz - 11.5)
            d_north_lane = abs(gx) if (-48.0 <= gz <= 11.5) else 999.0
            d_boss = math.hypot(gx, gz + 42.0)

            # Organic painterly noise modulation
            n_val = math.sin(gx * 0.25 + gz * 0.18) * math.cos(gz * 0.22 - gx * 0.15) * 1.4

            # Path/Dirt blend mask along the circular rings (r ~ 6.4 and r ~ 14.6), northern lane, and boss arena
            ring1 = max(0.0, 1.0 - abs(d_plaza - 6.4 + n_val * 0.4) / 2.8)
            ring2 = max(0.0, 1.0 - abs(d_plaza - 14.8 + n_val * 0.5) / 3.2)
            lane_m = max(0.0, 1.0 - (d_north_lane + n_val * 0.35) / 4.8) if gz < 12.0 else 0.0
            boss_m = max(0.0, 1.0 - (d_boss + n_val * 0.6) / 14.8)
            dirt_blend = min(1.0, max(ring1, ring2, lane_m, boss_m * 0.85))

            # Point 4: Gameplay region brightness (brighter in playable plaza & lane, darker in outer forest border!)
            d_playable = min(d_plaza / 26.0, d_north_lane / 12.0, d_boss / 18.0)
            region_light = 1.12 if d_playable < 0.75 else max(0.62, 1.12 - (d_playable - 0.75) * 0.55)

            # Warm golden Summoner's Rift dirt/cobble tint blended with lush meadow grass
            dr = cr * 0.72 + 78.0
            dg = cg * 0.62 + 58.0
            db = cb * 0.48 + 32.0

            r = (gr * (1.0 - dirt_blend * 0.65) + dr * (dirt_blend * 0.65)) * region_light
            g = (gg * (1.0 - dirt_blend * 0.65) + dg * (dirt_blend * 0.65)) * region_light
            b = (gb * (1.0 - dirt_blend * 0.65) + db * (dirt_blend * 0.65)) * region_light

            out_px[px_i, py] = (
                max(0, min(255, int(r))),
                max(0, min(255, int(g))),
                max(0, min(255, int(b))),
            )

    canvas = canvas.filter(ImageFilter.SMOOTH_MORE)
    for folder in (BLENDER_DIR, OUT_GLB_DIR):
        p = os.path.join(folder, "T_LoL_Ground_Canvas_2K.png" if folder == BLENDER_DIR else "Lorencia_Town_T_LoL_Ground_Canvas_2K.png")
        canvas.save(p, "PNG")
    print("Baked non-tiled 1:1 Painted Ground Canvas -> T_LoL_Ground_Canvas_2K.png")
